import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../l10n/app_text.dart';
import '../models/chat_message.dart';
import '../models/verified_medicine_result.dart';
import 'ai_handwriting_service.dart';
import 'chatbot_tools.dart';
import 'gemini_client.dart';
import 'medical_domain_guard_service.dart';
import 'medicine_verification_service.dart';

/// The in-app assistant.
///
/// Gemini writes the answers, but facts come from the app: the model calls
/// [ChatbotTools] (MOPH list, the user's health data, doctors, pharmacies)
/// and follows assets/chatbot/knowledge_notes.md. A prescription photo goes
/// through the same reading and MOPH verification pipeline as a scan, so the
/// model only ever sees verified products.
class ChatbotService {
  ChatbotService._internal();

  static final ChatbotService _instance = ChatbotService._internal();

  factory ChatbotService() => _instance;

  static const String _notesAsset = 'assets/chatbot/knowledge_notes.md';

  /// Earlier turns sent with each question, for follow-ups such as
  /// "and for children?".
  static const int _historyTurns = 10;

  final List<ChatMessage> _conversationHistory = <ChatMessage>[];
  String? _notes;

  /// Name of the tool running right now, for the typing indicator.
  final ValueNotifier<String?> activeTool = ValueNotifier<String?>(null);

  List<ChatMessage> get conversationHistory => List<ChatMessage>.unmodifiable(_conversationHistory);

  void clearHistory() {
    _conversationHistory.clear();
  }

  void addWelcomeMessage(String greetingText) {
    _conversationHistory
      ..clear()
      ..add(
        ChatMessage(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          sender: ChatMessageSender.bot,
          text: greetingText,
          isWelcome: true,
        ),
      );
  }

  Future<String> _knowledgeNotes() async {
    if (_notes != null) return _notes!;
    try {
      _notes = await rootBundle.loadString(_notesAsset);
    } catch (error) {
      debugPrint('ChatbotService: knowledge notes missing: $error');
      _notes = 'You are the PharmaLens medicine assistant for Lebanon. Use the tools for every fact.';
    }
    return _notes!;
  }

  /// Sends a user message (with an optional prescription photo) and returns
  /// the assistant's reply, which is also added to the history.
  Future<ChatMessage> sendMessage({
    required String userText,
    Uint8List? imageBytes,
    String? imageMimeType,
    String responseLanguage = 'en',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;
    final isArabic = responseLanguage.toLowerCase() == 'ar' || RegExp(r'[؀-ۿ]').hasMatch(userText);

    final hadConversation = _conversationHistory.any((m) => m.isUser);

    _conversationHistory.add(ChatMessage(
      id: '$now',
      sender: ChatMessageSender.user,
      text: userText,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
    ));

    ChatMessage reply(String text, {List<String> sources = const <String>[], bool isError = false}) {
      final message = ChatMessage(
        id: '${now + 1}',
        sender: ChatMessageSender.bot,
        text: text,
        sources: sources,
        isError: isError,
      );
      _conversationHistory.add(message);
      return message;
    }

    final decision = const MedicalDomainGuardService().evaluateText(
      input: userText,
      responseLanguage: isArabic ? 'Arabic' : 'English',
      hasAttachedImage: hasImage,
      hasConversationContext: hadConversation,
    );
    if (!decision.allowed) {
      return reply(decision.userMessage);
    }

    try {
      final tools = ChatbotTools(languageCode: isArabic ? 'ar' : 'en');
      final extraSources = <String>[];

      var question = userText;
      if (hasImage) {
        activeTool.value = 'read_prescription';
        final scan = await _scanPrescription(imageBytes, imageMimeType ?? 'image/jpeg', isArabic);
        question = '$userText\n\n[Prescription photo attached. Result of the PharmaLens scan pipeline, '
            'already checked against the MOPH list]\n$scan';
        extraSources.add(appText(isArabic).pharmalensPrescriptionReading);
      }

      final run = await const GeminiClient().chatWithTools(
        systemInstruction: await _systemInstruction(isArabic),
        contents: _contents(question),
        tools: ChatbotTools.declarations,
        runTool: tools.run,
        onToolCall: (name) => activeTool.value = name,
      );

      final sources = <String>[
        ...extraSources,
        ...ChatbotTools.sourcesFor(run.toolsUsed, isArabic: isArabic),
      ];
      if (sources.isEmpty) {
        sources.add(appText(isArabic).generalAiKnowledge);
      }

      return reply(run.text, sources: sources);
    } catch (error, stackTrace) {
      _debugLog('ChatbotService error', error, stackTrace);

      final kind = error is GeminiException ? error.kind : null;
      final text = switch (kind) {
        GeminiErrorKind.rateLimited => appText(isArabic).theAssistantIsBusyRightNow,
        GeminiErrorKind.notConfigured || GeminiErrorKind.unauthorized => appText(isArabic).theAssistantIsNotSetUp,
        _ => appText(isArabic).sorryICouldNotAnswerRight,
      };
      return reply(text, isError: true);
    } finally {
      activeTool.value = null;
    }
  }

  Future<String> _systemInstruction(bool isArabic) async {
    final notes = await _knowledgeNotes();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return '$notes\n\n## Context\n- Today: $today\n- App language: ${isArabic ? 'Arabic' : 'English'}\n';
  }

  /// Earlier text turns plus the new question. Tool calls from earlier
  /// turns are not replayed; their results are already in the answers.
  List<Map<String, dynamic>> _contents(String question) {
    final earlier = _conversationHistory
        .where((m) => !m.isError && !m.isWelcome && m.text.trim().isNotEmpty)
        .toList();
    // The last entry is the new question itself.
    final past = earlier.length > 1 ? earlier.sublist(0, earlier.length - 1) : <ChatMessage>[];
    final recent = past.length > _historyTurns ? past.sublist(past.length - _historyTurns) : past;

    return <Map<String, dynamic>>[
      for (final message in recent)
        <String, dynamic>{
          'role': message.isUser ? 'user' : 'model',
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': message.text},
          ],
        },
      <String, dynamic>{
        'role': 'user',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'text': question},
        ],
      },
    ];
  }

  /// Reads a prescription photo with the scan pipeline and summarizes the
  /// verified products as JSON for the model.
  Future<String> _scanPrescription(Uint8List bytes, String mimeType, bool isArabic) async {
    try {
      final reading = await AiHandwritingService().analyzePrescriptionImage(
        imageBytes: bytes,
        imageMimeType: mimeType,
        ocrText: '',
        doctorContext: '',
        medicineCatalog: '',
        responseLanguage: isArabic ? 'Arabic' : 'English',
      );
      final verified = await MedicineVerificationService().verifySuggestions(reading.suggestions);

      return const JsonEncoder.withIndent(' ').convert(<String, dynamic>{
        if (reading.detectedDoctorName.isNotEmpty) 'doctor': reading.detectedDoctorName,
        'lines': <Map<String, dynamic>>[
          for (final result in verified)
            <String, dynamic>{
              'written': result.suggestion.exactWrittenText.isNotEmpty
                  ? result.suggestion.exactWrittenText
                  : result.suggestion.name,
              if (result.suggestion.writtenInstructions.isNotEmpty) 'directions_as_written': result.suggestion.writtenInstructions,
              'status': switch (result.status) {
                MedicineVerificationStatus.verified => 'verified',
                MedicineVerificationStatus.possible => 'possible (unconfirmed)',
                _ => 'not matched',
              },
              if (result.candidate != null) ...<String, dynamic>{
                'medicine_id': result.candidate!.medicineId,
                'product': result.candidate!.brandName,
                if ((result.candidate!.strength ?? '').isNotEmpty) 'strength': result.candidate!.strength,
              },
            },
        ],
      });
    } on AiHandwritingException catch (error) {
      return '{"error": "The photo could not be read: ${error.message}"}';
    }
  }

  void _debugLog(String message, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('$message\n$error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
