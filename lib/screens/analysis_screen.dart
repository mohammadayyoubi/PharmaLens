import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../localization/localization_extension.dart';
import '../models/ai_handwriting_result.dart';
import '../models/doctor_context.dart';
import '../models/medicine_price.dart';
import '../models/prescription_record.dart';
import '../models/verified_medicine_result.dart';
import '../services/ai_handwriting_service.dart';
import '../services/health_profile_service.dart';
import '../services/medication_safety_service.dart';
import '../services/medicine_verification_service.dart';
import '../services/ocr_service.dart';
import '../services/prescription_history_service.dart';
import '../services/specialty_context_service.dart';
import '../theme/pharmalens_theme.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/reminder_editor.dart';
import '../widgets/responsive.dart';
import '../widgets/safety_alert_card.dart';
import 'medicine_details_screen.dart';
import 'medicine_search_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.imagePath,
    required this.imageBytes,
  });

  final String imagePath;
  final Uint8List imageBytes;

  @override
  State<AnalysisScreen> createState() {
    return _AnalysisScreenState();
  }
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final OcrService _ocrService = OcrService();

  final SpecialtyContextService _specialtyContextService =
  SpecialtyContextService();

  final AiHandwritingService _aiHandwritingService =
  AiHandwritingService();

  final MedicineVerificationService _verificationService =
  MedicineVerificationService();

  final TextEditingController _ocrController =
  TextEditingController();

  /// Id of this scan in the on-device history, once saved.
  String? _historyRecordId;

  /// Serializes history writes so a quick manual pick cannot create a
  /// second record while the first save is still running.
  Future<void> _historyWrite = Future<void>.value();

  bool _isPreparing = true;
  bool _isAiAnalyzing = false;
  bool _isVerifying = false;

  String _errorMessage = '';

  DoctorContext _doctorContext =
  DoctorContext.empty();

  AiHandwritingResult? _aiResult;

  List<VerifiedMedicineResult> _verificationResults =
  const <VerifiedMedicineResult>[];

  int _analysisRequestId = 0;

  bool get _isBusy {
    return _isPreparing ||
        _isAiAnalyzing ||
        _isVerifying;
  }

  @override
  void initState() {
    super.initState();

    _startAnalysis();
  }

  @override
  void dispose() {
    _analysisRequestId++;

    _ocrController.dispose();

    if (!kIsWeb) {
      _ocrService.close();
    }

    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final requestId =
    ++_analysisRequestId;

    setState(() {
      _isPreparing = true;
      _isAiAnalyzing = false;
      _isVerifying = false;

      _errorMessage = '';

      _doctorContext =
          DoctorContext.empty();

      _aiResult = null;

      _verificationResults =
      const <VerifiedMedicineResult>[];

      _ocrController.clear();
    });

    if (widget.imageBytes.isEmpty) {
      if (!_isCurrentRequest(requestId)) {
        return;
      }

      setState(() {
        _isPreparing = false;

        _errorMessage =
        'The selected prescription image could not be read.';
      });

      return;
    }

    await _runSupportingOcr(
      requestId,
    );

    if (!_isCurrentRequest(requestId)) {
      return;
    }

    setState(() {
      _isPreparing = false;
    });

    await _runAiAnalysis(
      requestId,
    );
  }

  Future<void> _runSupportingOcr(
      int requestId,
      ) async {
    if (kIsWeb) {
      return;
    }

    final path =
    widget.imagePath.trim();

    if (path.isEmpty) {
      return;
    }

    try {
      final text =
      await _ocrService.readTextFromImage(
        path,
      );

      if (!_isCurrentRequest(requestId)) {
        return;
      }

      _ocrController.text = text;

      if (text.trim().isNotEmpty) {
        _doctorContext =
            _specialtyContextService
                .detectDoctorContext(
              text,
            );
      }
    } on OcrException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Supporting OCR failed.',
    error,
    stackTrace,
    );
    } catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Unexpected supporting OCR failure.',
    error,
    stackTrace,
    );
    }
  }

  Future<void> _runAiAnalysis(
      int requestId,
      ) async {
    if (!_isCurrentRequest(requestId)) {
      return;
    }

    final tr =
    AppLocalizations.of(context);

    setState(() {
      _isAiAnalyzing = true;
      _isVerifying = false;
      _errorMessage = '';
    });

    try {
      final result =
      await _aiHandwritingService
          .analyzePrescriptionImage(
        imageBytes:
        widget.imageBytes,
        imageMimeType:
        _detectImageMimeType(),
        ocrText:
        _ocrController.text.trim(),
        doctorContext:
        _doctorContextText(),
        medicineCatalog: '',
        responseLanguage:
        tr.isArabic
            ? 'Arabic'
            : 'English',
      );

      if (!_isCurrentRequest(requestId)) {
        return;
      }

      final readableText =
      result
          .toPrescriptionTextForMatching()
          .trim();

      setState(() {
        _aiResult = result;

        _doctorContext =
            _doctorContextFromAi(
              result,
            );

        if (readableText.isNotEmpty) {
          _ocrController.text =
              readableText;
        }

        _isAiAnalyzing = false;
        _isVerifying = true;
      });

      final verificationResults =
      await _verificationService
          .verifySuggestions(
        result.suggestions,
      );

      if (!_isCurrentRequest(requestId)) {
        return;
      }

      setState(() {
        _verificationResults =
        List<VerifiedMedicineResult>.unmodifiable(
          verificationResults,
        );

        _isVerifying = false;
      });

      _saveHistory();
    } on AiHandwritingException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Prescription AI analysis failed.',
    error,
    stackTrace,
    );

    if (!_isCurrentRequest(requestId)) {
    return;
    }

    setState(() {
    _isAiAnalyzing = false;
    _isVerifying = false;
    _errorMessage = error.message;
    });
    } catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Unexpected prescription analysis failure.',
    error,
    stackTrace,
    );

    if (!_isCurrentRequest(requestId)) {
    return;
    }

    setState(() {
    _isAiAnalyzing = false;
    _isVerifying = false;

    _errorMessage = _localText(
    tr,
    en:
    'Prescription analysis is temporarily unavailable. Please try again.',
    ar:
    "تحليل الوصفة غير متاح مؤقتًا. يرجى إعادة المحاولة.",
    );
    });
    }
  }

  bool _isCurrentRequest(
      int requestId,
      ) {
    return mounted &&
        requestId == _analysisRequestId;
  }

  String _doctorContextText() {
    return <String>[
      _doctorContext.detectedDoctorName,
      _doctorContext.detectedSpecialty,
    ]
        .map(
          (value) => value.trim(),
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .join(' | ');
  }

  DoctorContext _doctorContextFromAi(
      AiHandwritingResult result,
      ) {
    final doctor =
    result.detectedDoctorName.trim();

    final specialty =
    result.detectedSpecialty.trim();

    if (doctor.isEmpty &&
        specialty.isEmpty) {
      return _doctorContext;
    }

    var confidence = 0.0;

    if (doctor.isNotEmpty) {
      confidence += 0.35;
    }

    if (specialty.isNotEmpty) {
      confidence += 0.45;
    }

    return DoctorContext(
      detectedDoctorName:
      doctor.isNotEmpty
          ? doctor
          : _doctorContext
          .detectedDoctorName,
      detectedSpecialty:
      specialty.isNotEmpty
          ? specialty
          : _doctorContext
          .detectedSpecialty,
      confidence:
      confidence
          .clamp(
        0.0,
        1.0,
      )
          .toDouble(),
    );
  }

  String _detectImageMimeType() {
    final bytes =
        widget.imageBytes;

    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    final path =
    widget.imagePath
        .trim()
        .toLowerCase();

    if (path.endsWith('.png')) {
      return 'image/png';
    }

    if (path.endsWith('.webp')) {
      return 'image/webp';
    }

    if (path.endsWith('.heic') ||
        path.endsWith('.heif')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }

  VerifiedMedicineResult?
  _verificationAt(
      int index,
      ) {
    if (index < 0 ||
        index >=
            _verificationResults.length) {
      return null;
    }

    return _verificationResults[index];
  }

  List<_PrescriptionEntry> _entries() {
    final result =
        _aiResult;

    if (result == null) {
      return const <_PrescriptionEntry>[];
    }

    final output =
    <_PrescriptionEntry>[];

    final seen =
    <String>{};

    for (
    var index = 0;
    index < result.suggestions.length;
    index++
    ) {
      final suggestion =
      result.suggestions[index];

      final verification =
      _verificationAt(index);

      final key = _dedupeKey(
        suggestion,
        verification,
      );

      if (key.isNotEmpty &&
          !seen.add(key)) {
        continue;
      }

      output.add(
        _PrescriptionEntry(
          index: index,
          suggestion: suggestion,
          verification: verification,
        ),
      );
    }

    return output;
  }

  String _dedupeKey(
      AiMedicineSuggestion suggestion,
      VerifiedMedicineResult?
      verification,
      ) {
    final medicineId =
        verification
            ?.candidate
            ?.medicineId
            .trim() ??
            '';

    if (medicineId.isNotEmpty &&
        (verification
            ?.hasVerifiedPrescriptionMatch ==
            true ||
            verification
                ?.isManualSelection ==
                true)) {
      return 'product:'
          '${medicineId.toLowerCase()}';
    }

    final values = <String>[
      suggestion.writtenFragment,
      suggestion.name,
      suggestion.exactWrittenText,
      suggestion.displayTitle,
    ];

    for (final value in values) {
      final normalized =
      _normalizeKey(value);

      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return '';
  }

  String _normalizeKey(
      String value,
      ) {
    return value
        .toLowerCase()
        .replaceAll(
      RegExp(
        r'[\u064B-\u065F]',
      ),
      '',
    )
        .replaceAll(
      RegExp(
        r'[إأآا]',
      ),
      'ا',
    )
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(
      RegExp(
        r'[^a-z0-9\u0600-\u06FF]+',
      ),
      '',
    )
        .trim();
  }

  Future<void> _openEntry(
      _PrescriptionEntry entry,
      ) async {
    final suggestion =
        entry.suggestion;

    if (suggestion.isUnreadable) {
      final tr =
      AppLocalizations.of(context);

      _showMessage(
        _localText(
          tr,
          en:
          'This medicine name could not be read safely. Take a clearer image.',
          ar:
          "تعذر قراءة اسم هذا الدواء بأمان. التقط صورة أوضح.",
        ),
      );

      return;
    }

    if (suggestion.isCategoryOnly) {
      final tr =
      AppLocalizations.of(context);

      _showMessage(
        _localText(
          tr,
          en:
          'Only a medicine category was detected. The exact medicine name is required.',
          ar:
          "تم اكتشاف فئة دوائية فقط. يجب تحديد اسم الدواء الدقيق.",
        ),
      );

      return;
    }

    final verification =
        entry.verification;

    if (verification != null &&
        verification.candidate != null &&
        (verification
            .hasVerifiedPrescriptionMatch ||
            verification
                .isManualSelection)) {
      _openDetails(
        verification,
      );

      return;
    }

    await _selectExactProduct(
      entry,
    );
  }

  Future<void> _selectExactProduct(
      _PrescriptionEntry entry,
      ) async {
    final tr =
    AppLocalizations.of(context);

    final suggestion =
        entry.suggestion;

    final query =
    suggestion.verificationQuery.trim();

    if (query.isEmpty) {
      _showMessage(
        _localText(
          tr,
          en:
          'There is not enough readable medicine information to search safely.',
          ar:
          "لا توجد معلومات مقروءة كافية للبحث عن الدواء بأمان.",
        ),
      );

      return;
    }

    final selected =
    await Navigator.of(context)
        .push<MedicinePrice>(
      MaterialPageRoute<MedicinePrice>(
        builder: (_) =>
            MedicineSearchScreen(
              initialQuery: query,
              selectionMode: true,
            ),
      ),
    );

    if (!mounted ||
        selected == null) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final selectedResult =
      await _verificationService
          .confirmManualSelection(
        suggestion: suggestion,
        selectedMedicine: selected,
      );

      if (!mounted) {
        return;
      }

      final updated =
      List<VerifiedMedicineResult>.from(
        _verificationResults,
      );

      if (entry.index >= 0 &&
          entry.index < updated.length) {
        updated[entry.index] =
            selectedResult;
      }

      setState(() {
        _verificationResults =
        List<VerifiedMedicineResult>.unmodifiable(
          updated,
        );

        _isVerifying = false;
      });

      _saveHistory();

      _openDetails(
        selectedResult,
      );
    } catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Manual medicine selection failed.',
    error,
    stackTrace,
    );

    if (!mounted) {
    return;
    }

    setState(() {
    _isVerifying = false;
    });

    _showMessage(
    _localText(
    tr,
    en:
    'The selected medicine could not be opened. Please try again.',
    ar:
    "تعذر فتح الدواء المختار. يرجى إعادة المحاولة.",
    ),
    );
    }
  }

  bool _isConfirmed(
      VerifiedMedicineResult? verification,
      ) {
    return verification != null &&
        verification.candidate != null &&
        (verification.hasVerifiedPrescriptionMatch ||
            verification.isManualSelection);
  }

  /// MOPH products confirmed for this prescription, for safety checks.
  List<MedicinePrice> _confirmedProducts() {
    return _entries()
        .where(
          (entry) => _isConfirmed(
        entry.verification,
      ),
    )
        .map(
          (entry) => entry.verification!.candidate!,
    )
        .toList();
  }

  String _instructionsFor(
      AiMedicineSuggestion suggestion,
      ) {
    final written =
    suggestion.writtenInstructions.trim();

    if (written.isNotEmpty) {
      return written;
    }

    return <String>[
      suggestion.dose,
      suggestion.frequency,
      suggestion.duration,
    ]
        .map(
          (value) => value.trim(),
    )
        .where(
          (value) =>
      value.isNotEmpty &&
          value.toLowerCase() != 'unknown',
    )
        .join(' · ');
  }

  PrescriptionMedicineEntry _historyEntry(
      _PrescriptionEntry entry,
      ) {
    final suggestion =
        entry.suggestion;

    final verification =
        entry.verification;

    final product =
    _isConfirmed(
      verification,
    )
        ? verification!.candidate
        : null;

    return PrescriptionMedicineEntry(
      writtenName: _PrescriptionMedicineTile._readName(
        suggestion,
      ),
      medicineId: product?.medicineId ?? '',
      brandName: product?.brandName ?? '',
      strength: product?.strength ??
          suggestion.strength,
      dosageForm: product?.dosageForm ??
          suggestion.form,
      ingredients: product?.activeIngredients ??
          const <String>[],
      instructions: _instructionsFor(
        suggestion,
      ),
      verified: product != null,
    );
  }

  void _saveHistory() {
    final medicines = _entries()
        .where(
          (entry) => !entry.suggestion.isUnreadable,
    )
        .map(
      _historyEntry,
    )
        .toList();

    if (medicines.isEmpty) {
      return;
    }

    final history =
    PrescriptionHistoryService();

    _historyWrite = _historyWrite.then((_) async {
      try {
        final id =
            _historyRecordId;

        if (id == null) {
          final record = await history.add(
            medicines: medicines,
            doctorName: _doctorContext.detectedDoctorName,
            specialty: _doctorContext.detectedSpecialty,
            imageBytes: widget.imageBytes,
          );

          _historyRecordId = record.id;
        } else {
          await history.updateMedicines(
            id,
            medicines,
          );
        }
      } catch (
      error,
      stackTrace
      ) {
        _debugLog(
          'Saving prescription history failed.',
          error,
          stackTrace,
        );
      }
    });
  }

  void _remind(
      _PrescriptionEntry entry,
      ) {
    final verification =
        entry.verification;

    final product =
    _isConfirmed(
      verification,
    )
        ? verification!.candidate
        : null;

    showReminderEditor(
      context,
      medicineName: product?.brandName ??
          _PrescriptionMedicineTile._readName(
            entry.suggestion,
          ),
      medicineId: product?.medicineId ?? '',
      doseNote: _instructionsFor(
        entry.suggestion,
      ),
    );
  }

  void _openDetails(
      VerifiedMedicineResult result,
      ) {
    if (result.candidate == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MedicineDetailsScreen(
              result: result,
            ),
      ),
    );
  }

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  String _localText(
      AppLocalizations tr, {
        required String en,
        required String ar,
      }) {
    return tr.isArabic
        ? ar
        : en;
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
      stackTrace: stackTrace,
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final tr =
    AppLocalizations.of(context);

    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Directionality(
      textDirection:
      tr.isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: palette.background,
        floatingActionButton: const FloatingChatbotButton(),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: palette.pageGradient,
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (
                  context,
                  constraints,
                  ) {
                final wide =
                    constraints.maxWidth >= 1000;

                final gutter =
                Breakpoints.gutter(
                  constraints.maxWidth,
                );

                final column = Column(
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        0,
                      ),
                      child: _buildHeader(
                        tr,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Expanded(
                      child: _buildBody(
                        tr,
                      ),
                    ),
                  ],
                );

                if (!wide) {
                  return Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(
                        maxWidth: 820,
                      ),
                      child: column,
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints:
                    const BoxConstraints(
                      maxWidth: 1400,
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            gutter,
                            16,
                            8,
                            16,
                          ),
                          child: SizedBox(
                            width: constraints.maxWidth * 0.36,
                            child: _PrescriptionImagePanel(
                              imageBytes: widget.imageBytes,
                              isArabic: tr.isArabic,
                              onExpand: _showImagePreview,
                            ),
                          ),
                        ),
                        Expanded(
                          child: column,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      AppLocalizations tr,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return SizedBox(
      height: 50,
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment:
                  AlignmentDirectional
                      .centerStart,
                  child: Text(
                    tr.prescriptionAnalysis,
                    maxLines: 1,
                    style: TextStyle(
                      color:
                      palette.textPrimary,
                      fontSize: 20,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  _localText(
                    tr,
                    en:
                    'Medicines found in the prescription',
                    ar:
                    "الأدوية المقروءة من الوصفة",
                  ),
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                    palette.textSecondary,
                    fontSize: 9.8,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          _HeaderButton(
            icon:
            Icons.image_outlined,
            onTap:
            _showImagePreview,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      AppLocalizations tr,
      ) {
    if (_isBusy &&
        _aiResult == null) {
      return _buildLoading(
        tr,
      );
    }

    if (_errorMessage.isNotEmpty) {
      return _buildError(
        tr,
      );
    }

    return _buildResults(
      tr,
    );
  }

  Widget _buildResults(
      AppLocalizations tr,
      ) {
    final entries =
    _entries();

    final warnings =
        _aiResult?.generalWarnings ??
            const <String>[];

    return ListView(
      physics:
      const BouncingScrollPhysics(),
      padding:
      const EdgeInsets.fromLTRB(
        12,
        4,
        12,
        28,
      ),
      children: [
        _PrescriptionResultHero(
          count: entries.length,
          isArabic: tr.isArabic,
          hasNotes:
          warnings.isNotEmpty,
          onNotesTap:
          warnings.isEmpty
              ? null
              : () {
            _showReviewNotes(
              warnings,
              tr,
            );
          },
        ),
        const SizedBox(
          height: 18,
        ),
        ListenableBuilder(
          listenable: HealthProfileService(),
          builder: (
              context,
              _,
              ) {
            final alerts =
            const MedicationSafetyService().check(
              _confirmedProducts(),
              allergies: HealthProfileService().allergies,
            );

            if (alerts.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(
                bottom: 18,
              ),
              child: Column(
                children: [
                  for (final alert in alerts)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: SafetyAlertCard(
                        alert: alert,
                        isArabic: tr.isArabic,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Text(
          _localText(
            tr,
            en: 'Medicines',
            ar: "الأدوية",
          ),
          style: TextStyle(
            color:
            PharmaLensTheme
                .paletteOf(
              context,
            ).textPrimary,
            fontSize: 19,
            fontWeight:
            FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          _localText(
            tr,
            en:
            'Tap a medicine to view its information.',
            ar:
            "اضغط على الدواء لعرض معلوماته.",
          ),
          style: TextStyle(
            color:
            PharmaLensTheme
                .paletteOf(
              context,
            ).textSecondary,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(
          height: 12,
        ),
        if (_isVerifying)
          const Padding(
            padding:
            EdgeInsets.only(
              bottom: 10,
            ),
            child:
            LinearProgressIndicator(
              minHeight: 2,
            ),
          ),
        if (entries.isEmpty)
          _EmptyResult(
            isArabic:
            tr.isArabic,
          )
        else
          ...entries.map(
                (entry) => Padding(
              padding:
              const EdgeInsets.only(
                bottom: 10,
              ),
              child:
              _PrescriptionMedicineTile(
                entry: entry,
                isArabic:
                tr.isArabic,
                isVerifying:
                _isVerifying &&
                    entry.verification ==
                        null,
                onTap: () {
                  _openEntry(
                    entry,
                  );
                },
                onRemind: entry.suggestion.isUnreadable ||
                    entry.suggestion.isCategoryOnly
                    ? null
                    : () {
                  _remind(
                    entry,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoading(
      AppLocalizations tr,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Center(
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            padding:
            const EdgeInsets.all(
              19,
            ),
            decoration:
            BoxDecoration(
              color:
              palette.tealSurface,
              borderRadius:
              BorderRadius.circular(
                21,
              ),
            ),
            child:
            const CircularProgressIndicator(
              strokeWidth: 2.7,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            _isVerifying
                ? _localText(
              tr,
              en:
              'Checking medicines...',
              ar:
              "جارٍ التحقق من الأدوية...",
            )
                : _localText(
              tr,
              en:
              'Reading prescription...',
              ar:
              "جارٍ قراءة الوصفة...",
            ),
            style: TextStyle(
              color:
              palette.textPrimary,
              fontSize: 17,
              fontWeight:
              FontWeight.w900,
            ),
          ),
          if (!_isVerifying) ...[
            const SizedBox(
              height: 6,
            ),
            Text(
              _localText(
                tr,
                en:
                'This usually takes 10 to 30 seconds.',
                ar:
                "يستغرق ذلك عادةً من 10 إلى 30 ثانية.",
              ),
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                palette.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(
      AppLocalizations tr,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(
          16,
        ),
        child: Container(
          width: double.infinity,
          constraints:
          const BoxConstraints(
            maxWidth: 480,
          ),
          padding:
          const EdgeInsets.all(
            18,
          ),
          decoration:
          BoxDecoration(
            color:
            palette.surface,
            borderRadius:
            BorderRadius.circular(
              22,
            ),
            border:
            Border.all(
              color:
              PharmaLensColors
                  .danger
                  .withValues(
                alpha: 0.22,
              ),
            ),
            boxShadow:
            palette.cardShadow,
          ),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .error_outline_rounded,
                color:
                PharmaLensColors
                    .danger,
                size: 38,
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                _localText(
                  tr,
                  en:
                  'Analysis could not be completed',
                  ar:
                  "تعذر إكمال التحليل",
                ),
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  color:
                  palette.textPrimary,
                  fontSize: 17,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                _errorMessage,
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  color:
                  palette.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(
                height: 14,
              ),
              SizedBox(
                width:
                double.infinity,
                child:
                FilledButton.icon(
                  onPressed:
                  _startAnalysis,
                  icon:
                  const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                  label:
                  Text(
                    tr.tryAgain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReviewNotes(
      List<String> notes,
      AppLocalizations tr,
      ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (
          sheetContext,
          ) {
        final palette =
        PharmaLensTheme.paletteOf(
          sheetContext,
        );

        return Container(
          constraints:
          BoxConstraints(
            maxHeight:
            MediaQuery.of(
              sheetContext,
            ).size.height *
                0.70,
          ),
          padding:
          const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            18,
          ),
          decoration:
          BoxDecoration(
            color:
            palette.surface,
            borderRadius:
            const BorderRadius.vertical(
              top:
              Radius.circular(
                26,
              ),
            ),
          ),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration:
                BoxDecoration(
                  color:
                  palette.border,
                  borderRadius:
                  BorderRadius.circular(
                    99,
                  ),
                ),
              ),
              const SizedBox(
                height: 14,
              ),
              Row(
                children: [
                  const Icon(
                    Icons
                        .info_outline_rounded,
                    color:
                    PharmaLensColors
                        .warning,
                  ),
                  const SizedBox(
                    width: 9,
                  ),
                  Expanded(
                    child: Text(
                      _localText(
                        tr,
                        en:
                        'Reading notes',
                        ar:
                        "ملاحظات القراءة",
                      ),
                      style: TextStyle(
                        color:
                        palette.textPrimary,
                        fontSize: 18,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 12,
              ),
              Flexible(
                child:
                ListView.separated(
                  shrinkWrap: true,
                  itemCount:
                  notes.length,
                  separatorBuilder:
                      (
                      context,
                      index,
                      ) =>
                  const SizedBox(
                    height: 8,
                  ),
                  itemBuilder:
                      (
                      context,
                      index,
                      ) {
                    return Container(
                      padding:
                      const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        palette.surfaceSoft,
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                        border:
                        Border.all(
                          color:
                          palette.border,
                        ),
                      ),
                      child:
                      Text(
                        notes[index],
                        style:
                        TextStyle(
                          color:
                          palette
                              .textSecondary,
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showImagePreview() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (
          sheetContext,
          ) {
        final palette =
        PharmaLensTheme.paletteOf(
          sheetContext,
        );

        return Container(
          height:
          MediaQuery.of(
            sheetContext,
          ).size.height *
              0.82,
          padding:
          const EdgeInsets.fromLTRB(
            14,
            10,
            14,
            16,
          ),
          decoration:
          BoxDecoration(
            color:
            palette.surface,
            borderRadius:
            const BorderRadius.vertical(
              top:
              Radius.circular(
                26,
              ),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                decoration:
                BoxDecoration(
                  color:
                  palette.border,
                  borderRadius:
                  BorderRadius.circular(
                    99,
                  ),
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              Expanded(
                child:
                InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child:
                    Image.memory(
                      widget.imageBytes,
                      fit:
                      BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrescriptionEntry {
  const _PrescriptionEntry({
    required this.index,
    required this.suggestion,
    required this.verification,
  });

  final int index;
  final AiMedicineSuggestion suggestion;
  final VerifiedMedicineResult? verification;
}

class _HeaderButton
    extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Material(
      color: palette.surface,
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        child: Container(
          width: 44,
          height: 44,
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color: palette.border,
            ),
          ),
          child: Icon(
            icon,
            color:
            palette.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PrescriptionResultHero
    extends StatelessWidget {
  const _PrescriptionResultHero({
    required this.count,
    required this.isArabic,
    required this.hasNotes,
    required this.onNotesTap,
  });

  final int count;
  final bool isArabic;
  final bool hasNotes;
  final VoidCallback? onNotesTap;

  @override
  Widget build(
      BuildContext context,
      ) {
    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(
        17,
      ),
      decoration:
      PharmaLensDecorations.heroCard(
        borderRadius:
        BorderRadius.circular(
          24,
        ),
        isDark: isDark,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration:
            BoxDecoration(
              color:
              Colors.white
                  .withValues(
                alpha: 0.11,
              ),
              borderRadius:
              BorderRadius.circular(
                17,
              ),
            ),
            child: const Icon(
              Icons
                  .medication_liquid_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(
            width: 13,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? '$count أدوية'
                      : '$count medicines found',
                  style:
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  isArabic
                      ? "اضغط على أي دواء لعرض معلوماته."
                      : 'Tap any medicine to open its information.',
                  style: TextStyle(
                    color:
                    Colors.white
                        .withValues(
                      alpha: 0.72,
                    ),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (hasNotes)
            IconButton(
              onPressed:
              onNotesTap,
              style:
              IconButton.styleFrom(
                backgroundColor:
                Colors.white
                    .withValues(
                  alpha: 0.10,
                ),
                foregroundColor:
                PharmaLensColors
                    .brightCyan,
              ),
              icon:
              const Icon(
                Icons
                    .info_outline_rounded,
              ),
            ),
        ],
      ),
    );
  }
}

class _PrescriptionMedicineTile
    extends StatelessWidget {
  const _PrescriptionMedicineTile({
    required this.entry,
    required this.isArabic,
    required this.isVerifying,
    required this.onTap,
    this.onRemind,
  });

  final _PrescriptionEntry entry;
  final bool isArabic;
  final bool isVerifying;
  final VoidCallback onTap;
  final VoidCallback? onRemind;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final suggestion =
        entry.suggestion;

    final verification =
        entry.verification;

    final selected =
        verification != null &&
            verification.candidate !=
                null &&
            (verification
                .hasVerifiedPrescriptionMatch ||
                verification
                    .isManualSelection);

    final title =
    selected
        ? verification.displayName
        : _readName(
      suggestion,
    );

    final subtitle =
    selected
        ? _selectedSubtitle(
      verification,
    )
        : _readSubtitle(
      suggestion,
    );

    final unusable =
        suggestion.isUnreadable ||
            suggestion.isCategoryOnly;

    final accent =
    unusable
        ? PharmaLensColors.warning
        : PharmaLensColors.teal;

    return Material(
      color:
      Colors.transparent,
      borderRadius:
      BorderRadius.circular(
        20,
      ),
      child: InkWell(
        onTap:
        isVerifying
            ? null
            : onTap,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        child: Ink(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          decoration:
          BoxDecoration(
            color:
            palette.surface,
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            border:
            Border.all(
              color:
              palette.border,
            ),
            boxShadow:
            palette.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                BoxDecoration(
                  color:
                  accent
                      .withValues(
                    alpha:
                    PharmaLensTheme
                        .isDark(
                      context,
                    )
                        ? 0.15
                        : 0.075,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),
                child: Icon(
                  _medicineIcon(
                    selected
                        ? verification
                        .candidate
                        ?.dosageForm
                        : suggestion.form,
                  ),
                  color: accent,
                  size: 25,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textDirection:
                      TextDirection.ltr,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                        palette.textPrimary,
                        fontSize: 17,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                    if (subtitle
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        subtitle,
                        textDirection:
                        TextDirection.ltr,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                          palette
                              .textSecondary,
                          fontSize: 11.8,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              if (onRemind != null &&
                  !isVerifying)
                IconButton(
                  tooltip: isArabic
                      ? 'تذكير'
                      : 'Remind me',
                  onPressed: onRemind,
                  icon: const Icon(
                    Icons.alarm_add_rounded,
                    color: PharmaLensColors.teal,
                  ),
                ),
              if (isVerifying)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                  BoxDecoration(
                    color:
                    palette.tealSurface,
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color:
                    PharmaLensColors
                        .teal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _readName(
      AiMedicineSuggestion suggestion,
      ) {
    final values =
    <String>[
      suggestion.writtenFragment,
      suggestion.name,
      suggestion.displayTitle,
      suggestion.exactWrittenText,
    ];

    for (final value in values) {
      final cleaned =
      value.trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return 'Medicine';
  }

  static String _readSubtitle(
      AiMedicineSuggestion suggestion,
      ) {
    final values =
    <String>[
      suggestion.strength.trim(),
      suggestion.form.trim(),
    ].where(
          (value) =>
      value.isNotEmpty &&
          value.toLowerCase() !=
              'unknown',
    );

    return values
        .toSet()
        .join(' • ');
  }

  static String _selectedSubtitle(
      VerifiedMedicineResult result,
      ) {
    return <String>[
      result.displayGenericName,
      result.displayStrength,
      result.displayDosageForm,
    ]
        .where(
          (value) {
        final normalized =
        value
            .trim()
            .toLowerCase();

        return normalized
            .isNotEmpty &&
            normalized !=
                '—';
      },
    )
        .toSet()
        .join(' • ');
  }
}

class _EmptyResult
    extends StatelessWidget {
  const _EmptyResult({
    required this.isArabic,
  });

  final bool isArabic;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Container(
      padding:
      const EdgeInsets.all(
        22,
      ),
      decoration:
      BoxDecoration(
        color:
        palette.surface,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border:
        Border.all(
          color:
          palette.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color:
            palette.textMuted,
            size: 38,
          ),
          const SizedBox(
            height: 9,
          ),
          Text(
            isArabic
                ? "لم يتم العثور على أدوية مقروءة بأمان."
                : 'No medicines were identified safely.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color:
              palette.textSecondary,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _medicineIcon(
    String? dosageForm,
    ) {
  final form =
      dosageForm
          ?.trim()
          .toLowerCase() ??
          '';

  if (form.contains('inject') ||
      form.contains('ampoule') ||
      form.contains('ampule') ||
      form.contains('vial')) {
    return Icons.vaccines_outlined;
  }

  if (form.contains('syrup') ||
      form.contains('solution') ||
      form.contains('suspension')) {
    return Icons.local_drink_outlined;
  }

  if (form.contains('drop')) {
    return Icons.water_drop_outlined;
  }

  if (form.contains('cream') ||
      form.contains('ointment') ||
      form.contains('gel')) {
    return Icons.sanitizer_outlined;
  }

  if (form.contains('spray') ||
      form.contains('inhal')) {
    return Icons.air_rounded;
  }

  return Icons.medication_outlined;
}

/// The prescription photo, kept beside the results on wide windows so the
/// user can compare what was read against the original.
class _PrescriptionImagePanel extends StatelessWidget {
  const _PrescriptionImagePanel({
    required this.imageBytes,
    required this.isArabic,
    required this.onExpand,
  });

  final Uint8List imageBytes;
  final bool isArabic;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
        boxShadow: palette.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isArabic ? 'صورة الوصفة' : 'Prescription photo',
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: isArabic ? 'تكبير' : 'Enlarge',
                  onPressed: onExpand,
                  icon: const Icon(Icons.open_in_full_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: Semantics(
              image: true,
              label: isArabic ? 'صورة الوصفة الطبية' : 'Prescription photo',
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
