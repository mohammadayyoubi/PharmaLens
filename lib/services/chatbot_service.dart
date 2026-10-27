import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'gemini_client.dart';
import 'medical_domain_guard_service.dart';
import 'moph_medicine_service.dart';
import 'nearby_healthcare_service.dart';

class ChatbotService {
  ChatbotService._internal();

  static final ChatbotService _instance = ChatbotService._internal();

  factory ChatbotService() => _instance;

  static const Duration _requestTimeout = Duration(seconds: 45);

  final List<ChatMessage> _conversationHistory = <ChatMessage>[];

  List<ChatMessage> get conversationHistory =>
      List<ChatMessage>.unmodifiable(_conversationHistory);

  void clearHistory() {
    _conversationHistory.clear();
  }

  void addWelcomeMessage(String greetingText) {
    _conversationHistory.clear();
    _conversationHistory.add(
      ChatMessage(
        id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
        sender: ChatMessageSender.bot,
        text: greetingText,
        sources: const ['MOPH Lebanon Official Registry', 'PharmaLens Local Datasets'],
      ),
    );
  }

  List<String> _getApiKeys() => GeminiClient.apiKeys;

  List<String> _getModels() => GeminiClient.models;

  /// Sends user message (with optional attached image) and generates an AI response.
  Future<ChatMessage> sendMessage({
    required String userText,
    Uint8List? imageBytes,
    String? imageMimeType,
    String responseLanguage = 'en',
  }) async {
    final userMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    final userMsg = ChatMessage(
      id: userMessageId,
      sender: ChatMessageSender.user,
      text: userText,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
    );

    _conversationHistory.add(userMsg);

    final botMessageId = (DateTime.now().millisecondsSinceEpoch + 1).toString();

    try {
      final isArabic = responseLanguage.toLowerCase() == 'ar' ||
          RegExp(r'[\u0600-\u06FF]').hasMatch(userText);

      final langCode = isArabic ? 'ar' : 'en';

      // 1. Gather local contextual evidence (Medicines & Pharmacies)
      final localMedContext = await _buildLocalMedicineContext(userText);
      final catalogMatchFound = localMedContext.contains('MOPH Official Database');

      // 2. Strict Medical Domain Guard (blocks programming, code, non-medical topics immediately)
      final guardDecision = const MedicalDomainGuardService().evaluateText(
        input: userText,
        responseLanguage: isArabic ? 'Arabic' : 'English',
        hasAttachedImage: imageBytes != null && imageBytes.isNotEmpty,
        catalogMatchFound: catalogMatchFound,
      );

      if (!guardDecision.allowed) {
        final botMsg = ChatMessage(
          id: botMessageId,
          sender: ChatMessageSender.bot,
          text: guardDecision.userMessage,
          sources: const ['PharmaLens Medical Domain Guard'],
        );
        _conversationHistory.add(botMsg);
        return botMsg;
      }

      final localPharmContext = await _buildLocalPharmacyContext(
        userText,
        langCode,
      );

      // 3. Build multi-turn prompt payload for Gemini
      final sources = <String>[];

      if (localMedContext.contains('MOPH Official Database')) {
        sources.add('MOPH Lebanon Official Registry');
      }

      if (localPharmContext.contains('Pharmacies')) {
        sources.add('Local Pharmacies Dataset');
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        sources.add('Gemini Prescription Vision AI');
      } else if (sources.isEmpty) {
        sources.add('Gemini Medical Intelligence');
      }

      final botResponseText = await _invokeGemini(
        userText: userText,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType ?? 'image/jpeg',
        localMedicineContext: localMedContext,
        localPharmacyContext: localPharmContext,
        responseLanguage: isArabic ? 'Arabic' : 'English',
      );

      final botMsg = ChatMessage(
        id: botMessageId,
        sender: ChatMessageSender.bot,
        text: botResponseText,
        sources: sources,
      );

      _conversationHistory.add(botMsg);
      return botMsg;
    } catch (error, stackTrace) {
      _debugLog('ChatbotService error', error, stackTrace);

      final isArabic = responseLanguage.toLowerCase() == 'ar' ||
          RegExp(r'[\u0600-\u06FF]').hasMatch(userText);

      final fallbackText = isArabic
          ? 'عذرًا، واجهت مشكلة أثناء معالجة الطلب. يرجى المحاولة مرة أخرى أو التأكد من الاتصال بالإنترنت.'
          : 'Sorry, I encountered an issue processing your request. Please try again or check your internet connection.';

      final errorMsg = ChatMessage(
        id: botMessageId,
        sender: ChatMessageSender.bot,
        text: fallbackText,
        isError: true,
        sources: const ['Local Fallback Engine'],
      );

      _conversationHistory.add(errorMsg);
      return errorMsg;
    }
  }

  /// Searches local MOPH database for medicines mentioned in text query.
  Future<String> _buildLocalMedicineContext(String query) async {
    if (query.trim().isEmpty) return '';

    try {
      final mophService = MophMedicineService();
      await mophService.initialize();

      // Extract candidate medicine names from user query (handles questions & sentences)
      var matches = await mophService.extractMedicinesFromText(query, limit: 4);

      if (matches.isEmpty) {
        matches = await mophService.searchMedicines(query, limit: 4);
      }

      if (matches.isEmpty) {
        return '';
      }

      final sb = StringBuffer('=== LOCAL MOPH LEBANON MEDICINE DATABASE CONTEXT ===\n');

      for (final med in matches) {
        sb.writeln('• Brand Name: ${med.brandName}');
        sb.writeln('  Generic Name / Active Ingredients: ${med.genericName ?? med.activeIngredients.join(", ")}');
        if (med.strength != null) sb.writeln('  Strength: ${med.strength}');
        if (med.dosageForm != null) sb.writeln('  Form: ${med.dosageForm}');
        if (med.priceLbp != null) {
          sb.writeln('  Official MOPH Price: ${med.formattedPriceLbp} LBP');
        } else {
          sb.writeln('  Price: Available in MOPH Tariff');
        }
        if (med.manufacturer != null) sb.writeln('  Manufacturer: ${med.manufacturer}');
        sb.writeln('  Source: MOPH Official Database (Lebanon)');

        // Look up alternative/cheaper options
        try {
          final alts = await mophService.findExactAlternatives(med, limit: 3);
          if (alts.isNotEmpty) {
            sb.writeln('  [Generic / Equivalent Alternatives]:');
            for (final alt in alts) {
              final priceInfo = alt.priceLbp != null ? '${alt.formattedPriceLbp} LBP' : 'MOPH priced';
              sb.writeln('    - ${alt.brandName} (${alt.strength ?? ""}) | Price: $priceInfo | Maker: ${alt.manufacturer ?? "Generic"}');
            }
          }
        } catch (_) {}

        sb.writeln();
      }

      return sb.toString();
    } catch (e) {
      debugPrint('Error fetching local medicine context: $e');
      return '';
    }
  }

  /// Searches local pharmacy dataset and Google Places if nearby pharmacy requested.
  Future<String> _buildLocalPharmacyContext(String query, String langCode) async {
    final lower = query.toLowerCase();

    final isPharmacyQuery = lower.contains('pharmacy') ||
        lower.contains('pharmacies') ||
        lower.contains('near me') ||
        lower.contains('صيدلية') ||
        lower.contains('صيدليات') ||
        lower.contains('قريبة') ||
        lower.contains('موقع') ||
        lower.contains('عنوان');

    if (!isPharmacyQuery) return '';

    final sb = StringBuffer('=== LOCAL PHARMACIES DATASET CONTEXT ===\n');

    // Try fetching device location nearby pharmacies
    try {
      final service = NearbyHealthcareService();

      Position? position;

      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 5)),
          );
        }
      } catch (_) {}

      final lat = position?.latitude ?? 33.8938; // Default Beirut
      final lng = position?.longitude ?? 35.5018;

      final places = await service.loadNearby(
        latitude: lat,
        longitude: lng,
        languageCode: langCode,
        radiusMeters: 5000,
        maxResults: 6,
      );

      if (places.isNotEmpty) {
        sb.writeln(position != null
            ? 'Live Nearby Pharmacies (Distance sorted):'
            : 'Pharmacies near central Beirut (the user\'s location is unavailable; say so):');

        for (final place in places) {
          final openText = place.openNow == true
              ? 'Open Now'
              : (place.openNow == false ? 'Closed' : 'Status unknown');

          sb.writeln('• ${place.name}');
          if (place.address.isNotEmpty) sb.writeln('  Address: ${place.address}');
          if (place.phone.isNotEmpty) sb.writeln('  Phone: ${place.phone}');
          sb.writeln('  Status: $openText');
          if (place.googleMapsUri.isNotEmpty) sb.writeln('  Google Maps: ${place.googleMapsUri}');
          sb.writeln();
        }
      }
    } catch (e) {
      debugPrint('Nearby pharmacy context note: $e');
    }

    return sb.toString();
  }

  /// Performs multi-turn REST call to Gemini API with fallback across models and keys.
  Future<String> _invokeGemini({
    required String userText,
    Uint8List? imageBytes,
    required String imageMimeType,
    required String localMedicineContext,
    required String localPharmacyContext,
    required String responseLanguage,
  }) async {
    final apiKeys = _getApiKeys();
    final models = _getModels();

    if (apiKeys.isEmpty || models.isEmpty) {
      throw Exception('Gemini API is not properly configured.');
    }

    // Build System Instructions
    final systemPrompt = '''
You are PharmaLens AI, an expert, safety-first pharmaceutical and prescription assistant built for Lebanon and international users.

USER LANGUAGE REQUEST: $responseLanguage

YOUR CAPABILITIES & INSTRUCTIONS:
1. PRESCRIPTION ANALYSIS (If an image is attached):
   - Transcribe visible medications on the prescription.
   - For EACH medicine detected:
     a) **How the Doctor wrote on prescription to use each medicine**: Write the dosage, frequency, timing (e.g. 1 tablet every 12 hours after food), and duration as written by doctor.
     b) **Official Price**: Check and state the price in LBP / USD using MOPH Lebanon price database context.
     c) **Suggest Alternative with Dose if Available**: List exact generic / composition-equivalent lower-cost alternative brand with strength and dose if available in MOPH database.

2. MEDICINE INQUIRIES & PRICES:
   - Provide active ingredients, primary indications, dosage forms, price, and exact composition alternatives.
   - Always highlight price savings for generic alternatives.

3. NEARBY PHARMACIES INQUIRIES:
   - Provide names, areas, addresses, opening status, and phone numbers for pharmacies based on local database or user vicinity.

4. DATA SOURCES TRANSPARENCY:
   - At the bottom of your answer or alongside medicine details, state the source of the data clearly, such as:
     - `[Source: MOPH Lebanon Official Registry]`
     - `[Source: Local Pharmacies Dataset]`
     - `[Source: Original Brand Channel / Pharmacopeia]`

5. SAFETY & MEDICAL RESPONSIBILITY:
   - Always encourage consulting a doctor or pharmacist for final prescription changes.

6. STRICT DOMAIN RESTRICTION:
   - You are exclusively a medical, pharmaceutical, and prescription AI assistant (PharmaLens).
   - You MUST NEVER answer questions about programming languages (e.g., JavaScript, Python, C++, Dart, etc.), software engineering, sports, entertainment, politics, or general non-healthcare trivia.
   - If the user asks anything outside medicine, healthcare, prescriptions, and pharmacy, politely decline to answer and remind them that PharmaLens is strictly dedicated to healthcare support.

CONVERSATION CONTEXT & LOCAL DATASETS PROVIDED BELOW:
$localMedicineContext
$localPharmacyContext
''';

    // Construct Gemini multi-turn `contents` payload
    final contents = <Map<String, dynamic>>[];

    // Include last 8 conversation history messages for context memory
    final historyToInclude = _conversationHistory.length > 10
        ? _conversationHistory.sublist(_conversationHistory.length - 10)
        : _conversationHistory;

    for (var i = 0; i < historyToInclude.length; i++) {
      final msg = historyToInclude[i];

      final isLatestMsg = i == historyToInclude.length - 1;

      if (msg.isUser) {
        final parts = <Map<String, dynamic>>[];

        // If latest message has image, add image inline data
        if (isLatestMsg && imageBytes != null && imageBytes.isNotEmpty) {
          parts.add(<String, dynamic>{
            'inline_data': <String, dynamic>{
              'mime_type': imageMimeType.trim().toLowerCase(),
              'data': base64Encode(imageBytes),
            },
          });
        }

        // Add message text with system prompt injected into the latest request
        var promptText = msg.text;

        if (isLatestMsg) {
          promptText = '$systemPrompt\n\nUser Question: ${msg.text}';
        }

        parts.add(<String, dynamic>{
          'text': promptText,
        });

        contents.add(<String, dynamic>{
          'role': 'user',
          'parts': parts,
        });
      } else if (msg.isBot && !msg.isError) {
        contents.add(<String, dynamic>{
          'role': 'model',
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': msg.text,
            },
          ],
        });
      }
    }

    Object? lastError;

    for (final model in models) {
      final cleanModel = model.replaceFirst('models/', '').trim();

      for (var k = 0; k < apiKeys.length; k++) {
        final apiKey = apiKeys[k];

        try {
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent',
          );

          final response = await http
              .post(
                uri,
                headers: <String, String>{
                  'Content-Type': 'application/json',
                  'x-goog-api-key': apiKey,
                },
                body: jsonEncode(<String, dynamic>{
                  'contents': contents,
                  'generationConfig': GeminiClient.generationConfig(
                    model: cleanModel,
                    maxOutputTokens: 4096,
                    legacyTemperature: 0.2,
                  ),
                }),
              )
              .timeout(_requestTimeout);

          if (response.statusCode >= 200 && response.statusCode < 300) {
            final decoded = jsonDecode(response.body);

            if (decoded is Map<String, dynamic>) {
              final text = _extractGeminiText(decoded);

              if (text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          } else {
            debugPrint('Gemini key index $k model $cleanModel status ${response.statusCode}: ${response.body}');
          }
        } catch (err) {
          lastError = err;
          debugPrint('Gemini call failed for model $cleanModel key $k: $err');
        }
      }
    }

    throw Exception('All Gemini API attempts failed. Last error: $lastError');
  }

  String _extractGeminiText(Map<String, dynamic> json) {
    try {
      final candidates = json['candidates'];

      if (candidates is List && candidates.isNotEmpty) {
        final firstCandidate = candidates.first;

        if (firstCandidate is Map) {
          final content = firstCandidate['content'];

          if (content is Map) {
            final parts = content['parts'];

            if (parts is List) {
              final sb = StringBuffer();

              for (final part in parts) {
                if (part is Map && part.containsKey('text')) {
                  sb.write(part['text']);
                }
              }

              return sb.toString();
            }
          }
        }
      }
    } catch (_) {}

    return '';
  }

  void _debugLog(String message, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('$message\n$error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
