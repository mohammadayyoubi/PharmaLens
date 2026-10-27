import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_handwriting_result.dart';
import 'gemini_client.dart';

enum AiHandwritingErrorCode {
  invalidImage,
  unsupportedImage,
  authenticationUnavailable,
  rateLimited,
  timeout,
  serviceUnavailable,
  invalidResponse,
  unexpected,
}

class AiHandwritingException implements Exception {
  const AiHandwritingException({
    required this.code,
    required this.message,
    this.retryable = true,
  });

  final AiHandwritingErrorCode code;
  final String message;
  final bool retryable;

  @override
  String toString() {
    return message;
  }
}

class AiHandwritingService {
  static const int _maximumImageBytes =
      12 * 1024 * 1024;

  /// Longest wait for one Gemini request. Answers normally take 2-20 s; a
  /// model that is overloaded can hang, so fail over to the next one early.
  static const Duration _requestTimeout =
  Duration(
    seconds: 35,
  );

  /// Longest wait for the whole reading, across every model fallback.
  static const Duration _totalBudget =
  Duration(
    seconds: 100,
  );

  Future<AiHandwritingResult>
  analyzePrescriptionImage({
    required Uint8List imageBytes,
    required String imageMimeType,
    required String ocrText,
    required String doctorContext,
    required String medicineCatalog,
    required String responseLanguage,
  }) async {
    _validateImage(
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
    );

    final apiKeys =
        GeminiClient.apiKeys;

    final models =
        GeminiClient.models;

    if (apiKeys.isEmpty) {
      throw const AiHandwritingException(
        code:
        AiHandwritingErrorCode.authenticationUnavailable,
        message:
        'Prescription reading is not set up yet: a Gemini API key is missing.',
        retryable: false,
      );
    }

    if (models.isEmpty) {
      throw const AiHandwritingException(
        code:
        AiHandwritingErrorCode.serviceUnavailable,
        message:
        'Prescription analysis is not configured correctly.',
        retryable: false,
      );
    }

    final deadline =
    DateTime.now().add(
      _totalBudget,
    );

    Object? lastError;

    modelLoop:
    for (final model in models) {
      for (
      var keyIndex = 0;
      keyIndex < apiKeys.length;
      keyIndex++
      ) {
        if (deadline.difference(DateTime.now()) <
            const Duration(seconds: 5)) {
          lastError ??= TimeoutException(
            'Prescription reading timed out.',
          );
          break modelLoop;
        }

        try {
          return await _sendWithRecovery(
            deadline:
            deadline,
            apiKey:
            apiKeys[keyIndex],
            keyIndex:
            keyIndex + 1,
            model:
            model,
            imageBytes:
            imageBytes,
            imageMimeType:
            imageMimeType,
            ocrText:
            ocrText,
            doctorContext:
            doctorContext,
            medicineCatalog:
            medicineCatalog,
            responseLanguage:
            responseLanguage,
          );
        } on TimeoutException catch (
    error,
    stackTrace
    ) {
    lastError =
    error;

    _debugLog(
    'Gemini request timed out.',
    error,
    stackTrace,
    );

    // A timeout is not specific to a key; try the next model.
    continue modelLoop;
    } catch (
    error,
    stackTrace
    ) {
    lastError =
    error;

    _debugLog(
    'Gemini request failed.',
    error,
    stackTrace,
    );

    if (!_shouldTryNext(
    error.toString(),
    )) {
    break;
    }
    }
    }
    }

    final errorText =
    lastError
        ?.toString()
        .toLowerCase() ??
    '';

    if (errorText.contains(
    'status 429',
    ) ||
    errorText.contains(
    'quota',
    ) ||
    errorText.contains(
    'rate limit',
    )) {
    throw const AiHandwritingException(
    code:
    AiHandwritingErrorCode.rateLimited,
    message:
    'Too many prescription analysis requests. Please try again later.',
    );
    }

    if (errorText.contains(
    'timeout',
    ) ||
    errorText.contains(
    'timed out',
    ) ||
    errorText.contains(
    'status 408',
    ) ||
    errorText.contains(
    'status 504',
    )) {
    throw const AiHandwritingException(
    code:
    AiHandwritingErrorCode.timeout,
    message:
    'Prescription reading took too long. Check your internet connection and try again.',
    );
    }

    if (errorText.contains(
    'status 401',
    ) ||
    errorText.contains(
    'status 403',
    ) ||
    errorText.contains(
    'api key',
    )) {
    throw const AiHandwritingException(
    code:
    AiHandwritingErrorCode.authenticationUnavailable,
    message:
    'Prescription analysis could not connect to the AI service.',
    );
    }

    throw const AiHandwritingException(
    code:
    AiHandwritingErrorCode.serviceUnavailable,
    message:
    'Prescription analysis is temporarily unavailable. Please try again.',
    );
  }

  Future<AiHandwritingResult>
  _sendWithRecovery({
    required DateTime deadline,
    required String apiKey,
    required int keyIndex,
    required String model,
    required Uint8List imageBytes,
    required String imageMimeType,
    required String ocrText,
    required String doctorContext,
    required String medicineCatalog,
    required String responseLanguage,
  }) async {
    Object? primaryError;

    try {
      final primaryResult =
      await _makeGeminiRequest(
        deadline:
        deadline,
        apiKey:
        apiKey,
        keyIndex:
        keyIndex,
        model:
        model,
        imageBytes:
        imageBytes,
        imageMimeType:
        imageMimeType,
        prompt:
        _buildPrimaryPrompt(
          ocrText:
          ocrText,
          doctorContext:
          doctorContext,
          medicineCatalog:
          medicineCatalog,
          responseLanguage:
          responseLanguage,
        ),
        schema:
        _transcriptionResponseSchema(),
        maxOutputTokens:
        8192,
      );

      if (primaryResult
          .hasSuggestions) {
        return primaryResult;
      }
    } catch (error) {
      primaryError =
          error;

      if (!_canUseRecovery(
        error.toString(),
      )) {
        rethrow;
      }
    }

    try {
      final recoveryResult =
      await _makeGeminiRequest(
        deadline:
        deadline,
        apiKey:
        apiKey,
        keyIndex:
        keyIndex,
        model:
        model,
        imageBytes:
        imageBytes,
        imageMimeType:
        imageMimeType,
        prompt:
        _buildRecoveryPrompt(
          ocrText:
          ocrText,
          responseLanguage:
          responseLanguage,
        ),
        schema:
        _transcriptionResponseSchema(),
        maxOutputTokens:
        6144,
      );

      if (recoveryResult
          .hasSuggestions) {
        return recoveryResult;
      }

      return AiHandwritingResult(
        detectedDoctorName:
        recoveryResult
            .detectedDoctorName,
        detectedSpecialty:
        recoveryResult
            .detectedSpecialty,
        detectedPatientProblem:
        recoveryResult
            .detectedPatientProblem,
        rawInterpretation:
        recoveryResult
            .rawInterpretation,
        suggestions:
        const [],
        generalWarnings:
        <String>[
          responseLanguage
              .trim()
              .toLowerCase() ==
              'arabic'
              ? 'لم يتم استخراج سطور دوائية قابلة للاستخدام. قرّب الصورة من منطقة الأدوية وحاول مجددًا.'
              : 'No usable medication lines were extracted. Crop closer to the medicine area and try again.',
        ],
      );
    } catch (recoveryError) {
      throw Exception(
        'Primary reading failed: '
            '${primaryError ?? "empty result"}. '
            'Recovery reading failed: '
            '$recoveryError',
      );
    }
  }

  Future<AiHandwritingResult>
  _makeGeminiRequest({
    required DateTime deadline,
    required String apiKey,
    required int keyIndex,
    required String model,
    required Uint8List imageBytes,
    required String imageMimeType,
    required String prompt,
    required Map<String, dynamic> schema,
    required int maxOutputTokens,
  }) async {
    final cleanModel =
    model
        .trim()
        .replaceFirst(
      'models/',
      '',
    );

    final remaining =
    deadline.difference(
      DateTime.now(),
    );

    if (remaining <
        const Duration(seconds: 3)) {
      throw TimeoutException(
        'Prescription reading timed out.',
      );
    }

    final timeout =
    remaining < _requestTimeout
        ? remaining
        : _requestTimeout;

    final uri =
    Uri.parse(
      'https://generativelanguage.googleapis.com/'
          'v1beta/models/$cleanModel:generateContent',
    );

    final response =
    await http
        .post(
      uri,
      headers:
      <String, String>{
        'Content-Type':
        'application/json',
        'x-goog-api-key':
        apiKey,
      },
      body:
      jsonEncode(
        <String, dynamic>{
          'contents':
          <Map<String, dynamic>>[
            <String, dynamic>{
              'role':
              'user',
              'parts':
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'inline_data':
                  <String, dynamic>{
                    'mime_type':
                    imageMimeType
                        .trim()
                        .toLowerCase(),
                    'data':
                    base64Encode(
                      imageBytes,
                    ),
                  },
                },
                <String, dynamic>{
                  'text':
                  prompt,
                },
              ],
            },
          ],
          'generationConfig':
          GeminiClient.generationConfig(
            model:
            cleanModel,
            maxOutputTokens:
            maxOutputTokens,
            responseSchema:
            schema,
          ),
        },
      ),
    )
        .timeout(
      timeout,
    );

    if (response.statusCode <
        200 ||
        response.statusCode >=
            300) {
      throw Exception(
        'Gemini key $keyIndex '
            'with model $cleanModel failed. '
            'Status ${response.statusCode}: '
            '${response.body}',
      );
    }

    final decodedValue =
    jsonDecode(
      response.body,
    );

    if (decodedValue is! Map) {
      throw Exception(
        'Gemini returned an unexpected response format.',
      );
    }

    final decoded =
    Map<String, dynamic>.from(
      decodedValue,
    );

    final outputText =
    GeminiClient.extractText(
      decoded,
    );

    final jsonMap =
    _extractJson(
      outputText,
    );

    return AiHandwritingResult
        .fromJson(
      jsonMap,
    );
  }

  String _buildPrimaryPrompt({
    required String ocrText,
    required String doctorContext,
    required String medicineCatalog,
    required String responseLanguage,
  }) {
    return '''
You are PharmaLens AI, a safety-first prescription transcription assistant.

REQUESTED UI LANGUAGE:
$responseLanguage

TASK:
Transcribe every visible medication order from the prescription image.

Your job is transcription and structure extraction only.

Do not provide final medicine verification, diagnosis, treatment advice,
clinical recommendations, or dispensing approval.

LINE TYPES:

1. exact_medicine:
A medicine name is clearly readable.

2. possible_medicine:
Part of a medicine name is readable but uncertain.

3. category_only:
Only a medicine category or dosage-form order is readable.

4. unreadable:
A medication line exists but cannot be transcribed safely.

STRICT RULES:

- The prescription image is the primary evidence.
- OCR text is secondary evidence only.
- Create one structured result for every visible medication order.
- Preserve the complete readable line in exactWrittenText.
- Preserve only the visible medicine-name fragment in writtenFragment.
- Never invent a medicine name.
- Never invent a brand.
- Never invent a generic ingredient.
- Never invent a strength.
- Never invent a dosage form.
- Never invent a route.
- Never invent a dose.
- Never invent a frequency.
- Never invent a duration.
- Never invent an indication.
- Never invent a diagnosis.
- Never generate side effects.
- Never generate contraindications.
- Never generate interactions.
- Never generate pregnancy advice.
- Never recommend a substitute.
- Never approve dispensing.

- genericName must be empty unless it is explicitly visible.
- name may contain a cleaned transcription of visible medicine text only.
- A medicine category must never be converted into a specific medicine.
- Doctor specialty must never be used to identify a medicine.
- Doctor specialty must never be used to infer diagnosis.
- detectedPatientProblem must remain empty unless explicitly written.
- requiresDoctorConfirmation must be true whenever identity or important
  prescription details are uncertain.

DOSAGE FORM RULES:

- "tab", "tablet", "tabs" => Tablet.
- "cap", "capsule", "caps" => Capsule.
- "syr", "syrup" => Syrup.
- "susp", "suspension" => Suspension.
- "cream" => Cream.
- "ointment" => Ointment.
- "gel" => Gel.
- "drops" must not imply eye/ear/nasal unless supported by context.
- "inj", "injection" => Injection.

IMPORTANT FORM EXAMPLE:

If the prescription says:
"Frenaler Cort tab"

then:
name = "Frenaler Cort"
form = "Tablet"

Do NOT output Syrup.

STRENGTH RULE:

If a brand name is visible but no strength is written,
leave strength empty.

Example:

"Funzol"

must NOT automatically become:
"Funzol 150 mg"

ROUTE RULES:

- Tablet, capsule, syrup, suspension, PO, or oral supports ORAL.
- Suppository, supp, PR, or rectal supports RECTAL.
- Eye drops, ophthalmic, E.D., or E.O. supports OPHTHALMIC.
- Ear drops or otic supports OTIC.
- Cream, ointment, gel, or topical supports TOPICAL unless clearly ophthalmic.
- Nasal explicitly supports NASAL.
- Inhaled/inhaler supports INHALED.
- SC/subcutaneous explicitly supports SUBCUTANEOUS.
- SL/sublingual explicitly supports SUBLINGUAL.
- IM/intramuscular explicitly supports IM.
- IV/intravenous explicitly supports IV.
- Injection without explicit IM or IV must use UNKNOWN.
- Use UNKNOWN whenever route evidence is insufficient.
- routeExplicitlyWritten may be true only when the route itself is explicitly
  supported by visible prescription text.

CONFIDENCE:

Confidence describes transcription confidence only.
It is NOT medicine verification confidence.

DOCTOR CONTEXT — weak metadata only:
$doctorContext

SECONDARY OCR TEXT:
$ocrText

LOCAL CATALOG:
$medicineCatalog

The local catalog may help with spelling only after handwriting supports the
same medicine text. It must never confirm or invent medicine identity.
''';
  }

  String _buildRecoveryPrompt({
    required String ocrText,
    required String responseLanguage,
  }) {
    return '''
Read this prescription image as a strict medication transcription task.

Requested UI language:
$responseLanguage

Return one structured result for every visible medication order.

Do not provide:
- medicine uses
- side effects
- interactions
- contraindications
- diagnoses
- treatment recommendations
- substitution advice
- dispensing approval

Rules:

- Image evidence is primary.
- OCR text is secondary.
- Preserve readable line text in exactWrittenText.
- Preserve visible medicine fragment in writtenFragment.
- Do not guess a medicine.
- Do not invent a brand.
- Do not invent generic ingredients.
- Do not invent strengths.
- Do not invent dosage forms.
- Do not invent routes.
- Do not invent directions.

Form rules:

- tab => Tablet
- cap => Capsule
- syr => Syrup
- susp => Suspension
- inj => Injection

Route rules:

- clear tablet/capsule/syrup supports ORAL.
- eye drops supports OPHTHALMIC.
- ear drops supports OTIC.
- topical cream/ointment/gel supports TOPICAL.
- IM only when explicitly written.
- IV only when explicitly written.
- injection without explicit IM/IV => UNKNOWN.
- unreadable when the line cannot be transcribed safely.

Secondary OCR:
$ocrText
''';
  }

  Map<String, dynamic>
  _transcriptionResponseSchema() {
    return <String, dynamic>{
      'type':
      'OBJECT',
      'properties':
      <String, dynamic>{
        'detectedDoctorName':
        <String, dynamic>{
          'type':
          'STRING',
        },
        'detectedSpecialty':
        <String, dynamic>{
          'type':
          'STRING',
        },
        'detectedPatientProblem':
        <String, dynamic>{
          'type':
          'STRING',
        },
        'rawInterpretation':
        <String, dynamic>{
          'type':
          'STRING',
        },
        'suggestions':
        <String, dynamic>{
          'type':
          'ARRAY',
          'items':
          <String, dynamic>{
            'type':
            'OBJECT',
            'properties':
            <String, dynamic>{
              'identificationStatus':
              <String, dynamic>{
                'type':
                'STRING',
                'enum':
                <String>[
                  'exact_medicine',
                  'possible_medicine',
                  'category_only',
                  'unreadable',
                ],
              },
              'exactWrittenText':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'writtenFragment':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'medicineCategory':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'name':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'genericName':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'strength':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'form':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'dose':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'frequency':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'duration':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'writtenInstructions':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'route':
              <String, dynamic>{
                'type':
                'STRING',
                'enum':
                <String>[
                  'ORAL',
                  'RECTAL',
                  'IM',
                  'IV',
                  'TOPICAL',
                  'OPHTHALMIC',
                  'OTIC',
                  'NASAL',
                  'INHALED',
                  'SUBCUTANEOUS',
                  'SUBLINGUAL',
                  'UNKNOWN',
                ],
              },
              'routeConfidence':
              <String, dynamic>{
                'type':
                'STRING',
                'enum':
                <String>[
                  'low',
                  'medium',
                  'high',
                ],
              },
              'routeEvidence':
              <String, dynamic>{
                'type':
                'STRING',
              },
              'routeExplicitlyWritten':
              <String, dynamic>{
                'type':
                'BOOLEAN',
              },
              'confidence':
              <String, dynamic>{
                'type':
                'STRING',
                'enum':
                <String>[
                  'low',
                  'medium',
                  'high',
                ],
              },
              'reasons':
              <String, dynamic>{
                'type':
                'ARRAY',
                'items':
                <String, dynamic>{
                  'type':
                  'STRING',
                },
              },
              'pharmacistChecks':
              <String, dynamic>{
                'type':
                'ARRAY',
                'items':
                <String, dynamic>{
                  'type':
                  'STRING',
                },
              },
              'warnings':
              <String, dynamic>{
                'type':
                'ARRAY',
                'items':
                <String, dynamic>{
                  'type':
                  'STRING',
                },
              },
              'requiresDoctorConfirmation':
              <String, dynamic>{
                'type':
                'BOOLEAN',
              },
            },
            'required':
            <String>[
              'identificationStatus',
              'exactWrittenText',
              'writtenFragment',
              'medicineCategory',
              'name',
              'genericName',
              'strength',
              'form',
              'dose',
              'frequency',
              'duration',
              'writtenInstructions',
              'route',
              'routeConfidence',
              'routeEvidence',
              'routeExplicitlyWritten',
              'confidence',
              'reasons',
              'pharmacistChecks',
              'warnings',
              'requiresDoctorConfirmation',
            ],
          },
        },
        'generalWarnings':
        <String, dynamic>{
          'type':
          'ARRAY',
          'items':
          <String, dynamic>{
            'type':
            'STRING',
          },
        },
      },
      'required':
      <String>[
        'detectedDoctorName',
        'detectedSpecialty',
        'detectedPatientProblem',
        'rawInterpretation',
        'suggestions',
        'generalWarnings',
      ],
    };
  }

  void _validateImage({
    required Uint8List imageBytes,
    required String imageMimeType,
  }) {
    if (imageBytes.isEmpty) {
      throw const AiHandwritingException(
        code:
        AiHandwritingErrorCode.invalidImage,
        message:
        'The selected prescription image is empty.',
        retryable: false,
      );
    }

    if (imageBytes.lengthInBytes >
        _maximumImageBytes) {
      throw const AiHandwritingException(
        code:
        AiHandwritingErrorCode.invalidImage,
        message:
        'The prescription image is too large. Please use a smaller image.',
        retryable: false,
      );
    }

    final mimeType =
    imageMimeType
        .trim()
        .toLowerCase();

    const allowed =
    <String>{
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    };

    if (!allowed.contains(
      mimeType,
    )) {
      throw const AiHandwritingException(
        code:
        AiHandwritingErrorCode.unsupportedImage,
        message:
        'This prescription image format is not supported.',
        retryable: false,
      );
    }
  }

  bool _canUseRecovery(
      String errorText,
      ) {
    final lower =
    errorText
        .toLowerCase();

    return lower.contains(
      'schema',
    ) ||
        lower.contains(
          'status 400',
        ) ||
        lower.contains(
          'invalid argument',
        ) ||
        lower.contains(
          'no text output',
        ) ||
        lower.contains(
          'valid json',
        ) ||
        lower.contains(
          'unexpected response',
        );
  }

  bool _shouldTryNext(
      String errorText,
      ) {
    final lower =
    errorText
        .toLowerCase();

    return lower.contains(
      'status 400',
    ) ||
        lower.contains(
          'status 401',
        ) ||
        lower.contains(
          'status 403',
        ) ||
        lower.contains(
          'status 404',
        ) ||
        lower.contains(
          'status 408',
        ) ||
        lower.contains(
          'status 409',
        ) ||
        lower.contains(
          'status 429',
        ) ||
        lower.contains(
          'status 500',
        ) ||
        lower.contains(
          'status 502',
        ) ||
        lower.contains(
          'status 503',
        ) ||
        lower.contains(
          'status 504',
        ) ||
        lower.contains(
          'not_found',
        ) ||
        lower.contains(
          'model',
        ) ||
        lower.contains(
          'api key',
        ) ||
        lower.contains(
          'quota',
        ) ||
        lower.contains(
          'rate limit',
        ) ||
        lower.contains(
          'timeout',
        ) ||
        lower.contains(
          'timed out',
        );
  }

  Map<String, dynamic> _extractJson(
      String text,
      ) {
    final cleaned =
    text
        .replaceAll(
      '```json',
      '',
    )
        .replaceAll(
      '```JSON',
      '',
    )
        .replaceAll(
      '```',
      '',
    )
        .trim();

    try {
      final decoded =
      jsonDecode(
        cleaned,
      );

      if (decoded is! Map) {
        throw const FormatException(
          'Decoded response is not an object.',
        );
      }

      return Map<String, dynamic>.from(
        decoded,
      );
    } catch (_) {
      final match =
      RegExp(
        r'\{[\s\S]*\}',
      ).firstMatch(
        cleaned,
      );

      if (match == null) {
        throw Exception(
          'Gemini did not return valid JSON.',
        );
      }

      final decoded =
      jsonDecode(
        match.group(0)!,
      );

      if (decoded is! Map) {
        throw Exception(
          'Gemini JSON result is not an object.',
        );
      }

      return Map<String, dynamic>.from(
        decoded,
      );
    }
  }

  void _debugLog(
      String message,
      Object error,
      StackTrace stackTrace,
      ) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '$message\n$error',
    );

    debugPrintStack(
      stackTrace:
      stackTrace,
    );
  }
}