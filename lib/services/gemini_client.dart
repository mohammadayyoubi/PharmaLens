import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../private/api_keys.dart';

/// Shared Gemini configuration: API keys, model order and per-model request
/// settings. Every Gemini caller in the app should build its
/// `generationConfig` here so thinking and temperature stay correct when the
/// model list changes.
class GeminiClient {
  const GeminiClient();

  static const String _apiKeysFromTerminal = String.fromEnvironment('GEMINI_API_KEYS');
  static const String _singleApiKeyFromTerminal = String.fromEnvironment('GEMINI_API_KEY');
  static const String _modelFromTerminal = String.fromEnvironment('GEMINI_MODEL');

  static const Set<String> _placeholderKeys = <String>{
    'PASTE_YOUR_NEW_GEMINI_API_KEY_HERE',
    'PASTE_YOUR_GEMINI_KEY_HERE',
    'YOUR_API_KEY_HERE',
  };

  static List<String> get apiKeys {
    final keys = <String>[
      ...GeminiPrivateConfig.geminiApiKeys,
      ..._apiKeysFromTerminal.split(','),
      _singleApiKeyFromTerminal,
    ].map((key) => key.trim()).where((key) => key.isNotEmpty && !_placeholderKeys.contains(key));

    return keys.toSet().toList();
  }

  static List<String> get models {
    final models = <String>[
      _modelFromTerminal,
      ...GeminiPrivateConfig.geminiModels,
    ].map((model) => model.trim().replaceFirst('models/', '')).where((model) => model.isNotEmpty);

    return models.toSet().toList();
  }

  static bool get isConfigured => apiKeys.isNotEmpty && models.isNotEmpty;

  /// Request settings that suit [model].
  ///
  /// Gemini 3 models think at a high level by default, and Google advises
  /// against lowering their temperature (below 1.0 they can loop). Both make
  /// structured extraction slow or cut off, because thinking tokens count
  /// toward [maxOutputTokens]. Older 2.x models keep a low temperature.
  static Map<String, dynamic> generationConfig({
    required String model,
    required int maxOutputTokens,
    Map<String, dynamic>? responseSchema,
    String thinkingLevel = 'low',
    double legacyTemperature = 0.0,
  }) {
    final name = model.toLowerCase();
    final isGemini2 = name.contains('gemini-2');
    final isGemini1 = name.contains('gemini-1');

    return <String, dynamic>{
      'candidateCount': 1,
      'maxOutputTokens': maxOutputTokens,
      if (responseSchema != null) ...<String, dynamic>{
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
      },
      if (isGemini1) 'temperature': legacyTemperature,
      if (isGemini2) ...<String, dynamic>{
        'temperature': legacyTemperature,
        // Pro models cannot switch thinking off; Flash and Flash-Lite can.
        'thinkingConfig': <String, dynamic>{'thinkingBudget': name.contains('pro') ? 128 : 0},
      },
      // Gemini 3 and the "-latest" aliases.
      if (!isGemini1 && !isGemini2) 'thinkingConfig': <String, dynamic>{'thinkingLevel': thinkingLevel},
    };
  }

  /// Sends [parts] to each configured model and key in turn until one returns
  /// JSON. Gives up when [totalBudget] is spent, so a slow model cannot keep
  /// the caller waiting for every fallback in a row.
  Future<Map<String, dynamic>> generateJson({
    required List<Map<String, dynamic>> parts,
    required Map<String, dynamic> responseSchema,
    int maxOutputTokens = 8192,
    Duration requestTimeout = const Duration(seconds: 40),
    Duration totalBudget = const Duration(seconds: 75),
  }) async {
    final keys = apiKeys;
    final modelList = models;
    if (keys.isEmpty || modelList.isEmpty) {
      throw StateError('Gemini is not configured.');
    }

    final stopwatch = Stopwatch()..start();
    Object? lastError;

    for (final model in modelList) {
      for (final key in keys) {
        final remaining = totalBudget - stopwatch.elapsed;
        if (remaining < const Duration(seconds: 5)) {
          throw TimeoutException('Gemini did not answer in time.', totalBudget);
        }

        try {
          final response = await http
              .post(
                Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
                headers: <String, String>{'Content-Type': 'application/json', 'x-goog-api-key': key},
                body: jsonEncode(<String, dynamic>{
                  'contents': <Map<String, dynamic>>[
                    <String, dynamic>{'role': 'user', 'parts': parts},
                  ],
                  'generationConfig': generationConfig(
                    model: model,
                    maxOutputTokens: maxOutputTokens,
                    responseSchema: responseSchema,
                  ),
                }),
              )
              .timeout(remaining < requestTimeout ? remaining : requestTimeout);

          final badKey = response.statusCode == 400 && response.body.contains('API_KEY');
          if ((response.statusCode == 404 || response.statusCode == 400) && !badKey) {
            // Unknown model name or a setting this model rejects: the next
            // model may work, another key will not.
            lastError = 'Model $model returned ${response.statusCode}';
            break;
          }
          if (response.statusCode < 200 || response.statusCode >= 300) {
            lastError = 'Model $model returned ${response.statusCode}';
            continue;
          }

          return decodeJsonObject(extractText(jsonDecode(response.body)));
        } on TimeoutException catch (error) {
          // Timeouts are not key-specific; move on to the next model.
          lastError = error;
          break;
        } catch (error) {
          lastError = error;
        }
      }
    }

    debugPrint('GeminiClient: all attempts failed: $lastError');
    throw Exception('Gemini request failed: $lastError');
  }

  static String extractText(Object? decoded) {
    if (decoded is Map) {
      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty && candidates.first is Map) {
        final content = (candidates.first as Map)['content'];
        final parts = content is Map ? content['parts'] : null;
        if (parts is List) {
          final text = parts
              .whereType<Map>()
              // Thought summaries are not part of the answer.
              .where((part) => part['thought'] != true)
              .map((part) => '${part['text'] ?? ''}')
              .join()
              .trim();
          if (text.isNotEmpty) return text;
        }
        final finishReason = (candidates.first as Map)['finishReason'];
        if (finishReason != null) {
          throw Exception('Gemini returned no text. Finish reason: $finishReason');
        }
      }
    }
    throw Exception('No text output returned from Gemini.');
  }

  static Map<String, dynamic> decodeJsonObject(String text) {
    final cleaned = text.replaceAll(RegExp(r'```(json|JSON)?'), '').trim();
    Object? decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) decoded = jsonDecode(match.group(0)!);
    }
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Gemini did not return valid JSON.');
  }
}
