import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../private/api_keys.dart';

/// Why a Gemini request failed, for user-facing messages.
enum GeminiErrorKind { notConfigured, rateLimited, timeout, unauthorized, badResponse, unavailable }

class GeminiException implements Exception {
  const GeminiException(this.kind, [this.detail = '']);

  final GeminiErrorKind kind;

  /// Diagnostic text for logs. Never contains an API key.
  final String detail;

  @override
  String toString() => 'GeminiException(${kind.name}): $detail';
}

/// A tool the model may call during [GeminiClient.chatWithTools].
class GeminiTool {
  const GeminiTool({required this.name, required this.description, this.parameters});

  final String name;
  final String description;

  /// OpenAPI-style schema of the arguments (type OBJECT), or null for none.
  final Map<String, dynamic>? parameters;

  Map<String, dynamic> toDeclaration() => <String, dynamic>{
        'name': name,
        'description': description,
        if (parameters != null) 'parameters': parameters,
      };
}

/// The final answer of a tool conversation and the tools it used.
class GeminiToolRun {
  const GeminiToolRun({required this.text, required this.toolsUsed, required this.model});

  final String text;
  final List<String> toolsUsed;
  final String model;
}

/// The one place for Gemini keys, model order, request settings and the
/// model/key fallback loop. Every Gemini caller in the app (prescription
/// reading, chat, medicine information) goes through this class.
class GeminiClient {
  const GeminiClient({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

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

  /// Posts a generateContent request built by [body] for each model and key
  /// in turn until [parse] accepts a response. [parse] may throw a
  /// [FormatException] to reject an answer (the next model is then tried).
  /// Gives up when [totalBudget] is spent, so a slow model cannot keep the
  /// caller waiting for every fallback in a row.
  Future<(T, String)> send<T>({
    required Map<String, dynamic> Function(String model) body,
    required T Function(Map<String, dynamic> response) parse,
    Duration requestTimeout = const Duration(seconds: 40),
    Duration totalBudget = const Duration(seconds: 75),
    List<String>? onlyModels,
  }) async {
    final keys = apiKeys;
    final modelList = onlyModels ?? models;
    if (keys.isEmpty || modelList.isEmpty) {
      throw const GeminiException(GeminiErrorKind.notConfigured, 'No Gemini key or model is configured.');
    }

    final client = _httpClient ?? http.Client();
    final stopwatch = Stopwatch()..start();
    var lastKind = GeminiErrorKind.unavailable;
    var lastDetail = '';

    try {
      for (final model in modelList) {
        keyLoop:
        for (var keyIndex = 0; keyIndex < keys.length; keyIndex++) {
          final remaining = totalBudget - stopwatch.elapsed;
          if (remaining < const Duration(seconds: 4)) {
            throw GeminiException(GeminiErrorKind.timeout, 'Budget of ${totalBudget.inSeconds}s spent. Last: $lastDetail');
          }

          try {
            final response = await client
                .post(
                  Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
                  headers: <String, String>{'Content-Type': 'application/json', 'x-goog-api-key': keys[keyIndex]},
                  body: jsonEncode(body(model)),
                )
                .timeout(remaining < requestTimeout ? remaining : requestTimeout);

            final status = response.statusCode;
            if (status >= 200 && status < 300) {
              final decoded = jsonDecode(utf8.decode(response.bodyBytes));
              if (decoded is! Map) throw const FormatException('Response is not a JSON object.');
              return (parse(Map<String, dynamic>.from(decoded)), model);
            }

            lastDetail = 'model $model, key ${keyIndex + 1}: HTTP $status';
            final badKey = status == 401 || status == 403 || (status == 400 && response.body.contains('API_KEY'));
            if (badKey) {
              lastKind = GeminiErrorKind.unauthorized;
              continue keyLoop;
            }
            if (status == 429) {
              // Quota is per key (and per project): another key may have room.
              lastKind = GeminiErrorKind.rateLimited;
              continue keyLoop;
            }
            // 400 (a setting this model rejects), 404 (unknown model) and
            // 5xx (overloaded) are model-wide: another key will not help.
            lastKind = status >= 500 ? GeminiErrorKind.unavailable : GeminiErrorKind.badResponse;
            break keyLoop;
          } on TimeoutException {
            lastKind = GeminiErrorKind.timeout;
            lastDetail = 'model $model timed out';
            break keyLoop;
          } on FormatException catch (error) {
            lastKind = GeminiErrorKind.badResponse;
            lastDetail = 'model $model: ${error.message}';
            break keyLoop;
          } on GeminiException {
            rethrow;
          } catch (error) {
            // Network errors: the next key will fail the same way, try the
            // next model only once the connection may have recovered.
            lastKind = GeminiErrorKind.unavailable;
            lastDetail = 'model $model: ${error.runtimeType}';
            break keyLoop;
          }
        }
      }
    } finally {
      if (_httpClient == null) client.close();
    }

    debugPrint('GeminiClient: all attempts failed ($lastKind): $lastDetail');
    throw GeminiException(lastKind, lastDetail);
  }

  /// Sends [parts] and returns the JSON object the model wrote, shaped by
  /// [responseSchema].
  Future<Map<String, dynamic>> generateJson({
    required List<Map<String, dynamic>> parts,
    required Map<String, dynamic> responseSchema,
    int maxOutputTokens = 8192,
    Duration requestTimeout = const Duration(seconds: 40),
    Duration totalBudget = const Duration(seconds: 75),
  }) async {
    final (json, _) = await send<Map<String, dynamic>>(
      body: (model) => <String, dynamic>{
        'contents': <Map<String, dynamic>>[
          <String, dynamic>{'role': 'user', 'parts': parts},
        ],
        'generationConfig': generationConfig(
          model: model,
          maxOutputTokens: maxOutputTokens,
          responseSchema: responseSchema,
        ),
      },
      parse: (response) => decodeJsonObject(extractText(response)),
      requestTimeout: requestTimeout,
      totalBudget: totalBudget,
    );
    return json;
  }

  /// A conversation in which the model may call [tools]. Each requested
  /// call is run through [runTool] and its result sent back, until the model
  /// writes a final answer or [maxToolRounds] is reached.
  ///
  /// Once a model answers, the rest of the conversation stays on that model:
  /// Gemini 3 attaches thought signatures to function calls that only the
  /// same model accepts back.
  Future<GeminiToolRun> chatWithTools({
    required String systemInstruction,
    required List<Map<String, dynamic>> contents,
    required List<GeminiTool> tools,
    required Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> args) runTool,
    void Function(String name)? onToolCall,
    int maxOutputTokens = 4096,
    int maxToolRounds = 5,
    Duration requestTimeout = const Duration(seconds: 40),
    Duration totalBudget = const Duration(seconds: 90),
  }) async {
    final stopwatch = Stopwatch()..start();
    final history = List<Map<String, dynamic>>.of(contents);
    final used = <String>[];
    String? model;

    for (var round = 0; round <= maxToolRounds; round++) {
      final lastRound = round == maxToolRounds;
      final remaining = totalBudget - stopwatch.elapsed;

      final (content, answeredBy) = await send<Map<String, dynamic>>(
        onlyModels: model == null ? null : <String>[model],
        requestTimeout: requestTimeout,
        totalBudget: remaining,
        body: (name) => <String, dynamic>{
          'systemInstruction': <String, dynamic>{
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{'text': systemInstruction},
            ],
          },
          'contents': history,
          if (tools.isNotEmpty) ...<String, dynamic>{
            'tools': <Map<String, dynamic>>[
              <String, dynamic>{'functionDeclarations': tools.map((t) => t.toDeclaration()).toList()},
            ],
            // On the last round the model must answer with what it has.
            'toolConfig': <String, dynamic>{
              'functionCallingConfig': <String, dynamic>{'mode': lastRound ? 'NONE' : 'AUTO'},
            },
          },
          'generationConfig': generationConfig(model: name, maxOutputTokens: maxOutputTokens, legacyTemperature: 0.3),
        },
        parse: _candidateContent,
      );
      model = answeredBy;

      final parts = (content['parts'] as List).whereType<Map>().toList();
      final calls = parts.where((part) => part['functionCall'] is Map).toList();

      if (calls.isEmpty) {
        final text = parts
            .where((part) => part['thought'] != true)
            .map((part) => '${part['text'] ?? ''}')
            .join()
            .trim();
        if (text.isEmpty) throw const GeminiException(GeminiErrorKind.badResponse, 'Empty answer.');
        return GeminiToolRun(text: text, toolsUsed: used, model: answeredBy);
      }

      // Keep the model turn exactly as sent, thought signatures included.
      history.add(<String, dynamic>{'role': 'model', 'parts': parts});

      final responses = <Map<String, dynamic>>[];
      for (final part in calls) {
        final call = Map<String, dynamic>.from(part['functionCall'] as Map);
        final name = '${call['name'] ?? ''}';
        final args = call['args'] is Map ? Map<String, dynamic>.from(call['args'] as Map) : <String, dynamic>{};
        onToolCall?.call(name);
        used.add(name);

        Map<String, dynamic> result;
        try {
          result = await runTool(name, args);
        } catch (error) {
          debugPrint('GeminiClient: tool $name failed: $error');
          result = <String, dynamic>{'error': 'The tool could not run: ${error.runtimeType}.'};
        }

        responses.add(<String, dynamic>{
          'functionResponse': <String, dynamic>{
            if (call['id'] != null) 'id': call['id'],
            'name': name,
            'response': result,
          },
        });
      }
      history.add(<String, dynamic>{'role': 'user', 'parts': responses});
    }

    throw const GeminiException(GeminiErrorKind.badResponse, 'No final answer.');
  }

  static Map<String, dynamic> _candidateContent(Map<String, dynamic> response) {
    final candidates = response['candidates'];
    if (candidates is List && candidates.isNotEmpty && candidates.first is Map) {
      final candidate = candidates.first as Map;
      final content = candidate['content'];
      if (content is Map && content['parts'] is List && (content['parts'] as List).isNotEmpty) {
        return Map<String, dynamic>.from(content);
      }
      throw FormatException('No content. Finish reason: ${candidate['finishReason']}');
    }
    final blocked = response['promptFeedback'];
    throw FormatException(blocked == null ? 'No candidates.' : 'Prompt blocked: $blocked');
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
          throw FormatException('Gemini returned no text. Finish reason: $finishReason');
        }
      }
    }
    throw const FormatException('No text output returned from Gemini.');
  }

  static Map<String, dynamic> decodeJsonObject(String text) {
    final cleaned = text.replaceAll(RegExp(r'```(json|JSON)?'), '').trim();
    Object? decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        try {
          decoded = jsonDecode(match.group(0)!);
        } catch (_) {}
      }
    }
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Gemini did not return valid JSON.');
  }
}
