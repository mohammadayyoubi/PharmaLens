import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

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

    if (GeminiClient.apiKeys.isEmpty) {
      throw const AiHandwritingException(
        code:
        AiHandwritingErrorCode.authenticationUnavailable,
        message:
        'Prescription reading is not set up yet: a Gemini API key is missing.',
        retryable: false,
      );
    }

    if (GeminiClient.models.isEmpty) {
      throw const AiHandwritingException(
        code:
        AiHandwritingErrorCode.serviceUnavailable,
        message:
        'Prescription analysis is not configured correctly.',
        retryable: false,
      );
    }

    final stopwatch =
    Stopwatch()..start();

    final image =
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
    };

    // GeminiClient walks the model and key fallbacks within the remaining
    // budget, and moves to the next model when one returns invalid JSON.
    Future<AiHandwritingResult> read(
        String prompt,
        int maxOutputTokens,
        ) async {
      final json =
      await const GeminiClient()
          .generateJson(
        parts:
        <Map<String, dynamic>>[
          image,
          <String, dynamic>{
            'text':
            prompt,
          },
        ],
        responseSchema:
        _transcriptionResponseSchema(),
        maxOutputTokens:
        maxOutputTokens,
        requestTimeout:
        _requestTimeout,
        totalBudget:
        _totalBudget -
            stopwatch.elapsed,
      );

      return AiHandwritingResult
          .fromJson(
        json,
      );
    }

    try {
      final primary =
      await read(
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
        8192,
      );

      if (primary
          .hasSuggestions) {
        return primary;
      }

      // The full prompt found no medicine lines; a shorter, stricter one
      // sometimes does when there is time left for it.
      var lastResult =
          primary;

      if (_totalBudget -
          stopwatch.elapsed >
          const Duration(seconds: 15)) {
        final recovery =
        await read(
          _buildRecoveryPrompt(
            ocrText:
            ocrText,
            responseLanguage:
            responseLanguage,
          ),
          6144,
        );

        if (recovery
            .hasSuggestions) {
          return recovery;
        }

        lastResult =
            recovery;
      }

      return AiHandwritingResult(
        detectedDoctorName:
        lastResult
            .detectedDoctorName,
        detectedSpecialty:
        lastResult
            .detectedSpecialty,
        detectedPatientProblem:
        lastResult
            .detectedPatientProblem,
        rawInterpretation:
        lastResult
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
    } on GeminiException catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Prescription reading failed.',
        error,
        stackTrace,
      );

      throw _readingException(
        error,
      );
    }
  }

  AiHandwritingException _readingException(
      GeminiException error,
      ) {
    switch (error.kind) {
      case GeminiErrorKind.rateLimited:
        return const AiHandwritingException(
          code:
          AiHandwritingErrorCode.rateLimited,
          message:
          'Too many prescription analysis requests. Please try again later.',
        );

      case GeminiErrorKind.timeout:
        return const AiHandwritingException(
          code:
          AiHandwritingErrorCode.timeout,
          message:
          'Prescription reading took too long. Check your internet connection and try again.',
        );

      case GeminiErrorKind.notConfigured:
      case GeminiErrorKind.unauthorized:
        return const AiHandwritingException(
          code:
          AiHandwritingErrorCode.authenticationUnavailable,
          message:
          'Prescription analysis could not connect to the AI service.',
        );

      case GeminiErrorKind.badResponse:
      case GeminiErrorKind.unavailable:
        return const AiHandwritingException(
          code:
          AiHandwritingErrorCode.serviceUnavailable,
          message:
          'Prescription analysis is temporarily unavailable. Please try again.',
        );
    }
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

DIRECTIONS (how to take each medicine):

Doctors often write the directions on the line(s) under the medicine name,
or beside it, and very often in Arabic, e.g.
"حبة صباحاً ومساءً", "ملعقة ٣ مرات يومياً بعد الأكل", "مرتين باليوم لمدة ٧ أيام",
"عند اللزوم", or with Arabic-Indic digits (١ ٢ ٣). Latin forms are common too:
"1x3", "1-0-1", "bid", "tid", "q8h", "prn", "x 7 days".

- Copying written directions is transcription, not invention: whenever any
  directions are visible for a medicine, fill writtenInstructions with them,
  exactly as written and in their original language. Do not translate them.
- Also fill dose, frequency and duration with the parts of those written
  directions that state them; leave a field empty only when that part is not
  written.
- Attach each directions line to the medicine it belongs to (normally the
  medicine directly above it).
- A directions line is never a separate medication order.
- When one directions line clearly applies to several medicines (a bracket,
  "للاثنين", "for both", "same"), copy it to each of them.
- Leave writtenInstructions empty only when no directions are written for
  that medicine at all.

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
- Do not invent directions, but copy every written direction (often Arabic,
  often on the line under the medicine name) into writtenInstructions as
  written, and into dose / frequency / duration. A directions line belongs
  to the medicine above it and is never a separate medication order.

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
                'description':
                'Amount per intake as written (e.g. "1 tablet", "حبة", "5 ml"); empty if not written.',
              },
              'frequency':
              <String, dynamic>{
                'type':
                'STRING',
                'description':
                'How often, as written (e.g. "3 times a day", "صباحاً ومساءً", "q8h"); empty if not written.',
              },
              'duration':
              <String, dynamic>{
                'type':
                'STRING',
                'description':
                'For how long, as written (e.g. "7 days", "لمدة أسبوع"); empty if not written.',
              },
              'writtenInstructions':
              <String, dynamic>{
                'type':
                'STRING',
                'description':
                'All directions written for this medicine, copied exactly in their original language (often Arabic, often on the line under the name). Empty only when none are written.',
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