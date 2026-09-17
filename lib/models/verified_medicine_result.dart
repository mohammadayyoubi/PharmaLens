import 'ai_handwriting_result.dart';
import 'medicine_knowledge.dart';
import 'medicine_price.dart';

enum MedicineVerificationStatus {
  verified,
  possible,
  notFound,
  skipped,
  failed,
}

enum MedicineSelectionSource {
  automatic,
  manual,
}

class VerifiedMedicineResult {
  const VerifiedMedicineResult({
    required this.suggestion,
    required this.status,
    required this.candidate,
    required this.knowledge,
    required this.verificationScore,
    required this.candidateCount,
    required this.message,
    this.selectionSource = MedicineSelectionSource.automatic,
  });

  final AiMedicineSuggestion suggestion;

  final MedicineVerificationStatus status;

  /// Database product selected by the verification flow.
  ///
  /// A candidate existing here does NOT automatically mean that the
  /// prescription-to-product match was verified.
  final MedicinePrice? candidate;

  /// Reviewed educational/clinical information associated with the product.
  ///
  /// This must never be displayed unless [canShowEducationalProfile] is true.
  final MedicineKnowledge? knowledge;

  /// Prescription/product matching score.
  ///
  /// This is NOT:
  /// - medication safety;
  /// - dispensing approval;
  /// - clinical confidence.
  final double verificationScore;

  /// Number of plausible database products considered by verification.
  final int candidateCount;

  /// Safe service-generated message.
  ///
  /// This must never contain:
  /// - stack traces;
  /// - raw database errors;
  /// - HTTP provider responses;
  /// - secrets.
  final String message;

  final MedicineSelectionSource selectionSource;

  bool get isVerified {
    return status == MedicineVerificationStatus.verified;
  }

  bool get isPossible {
    return status == MedicineVerificationStatus.possible;
  }

  bool get isNotFound {
    return status == MedicineVerificationStatus.notFound;
  }

  bool get wasSkipped {
    return status == MedicineVerificationStatus.skipped;
  }

  bool get failed {
    return status == MedicineVerificationStatus.failed;
  }

  bool get isManualSelection {
    return selectionSource == MedicineSelectionSource.manual;
  }

  bool get isAutomaticSelection {
    return selectionSource == MedicineSelectionSource.automatic;
  }

  bool get hasCandidate {
    return candidate != null;
  }

  bool get hasKnowledge {
    return knowledge != null;
  }

  bool get hasMultipleCandidates {
    return candidateCount > 1;
  }

  /// True only when PharmaLens automatically verified the prescription
  /// against one active database product with a stable identity.
  ///
  /// Manual selection intentionally does not satisfy this.
  bool get hasVerifiedPrescriptionMatch {
    final medicine = candidate;

    return isVerified &&
        isAutomaticSelection &&
        medicine != null &&
        medicine.isActive &&
        medicine.hasMedicineId;
  }

  /// Compatibility alias.
  bool get hasVerifiedIdentity {
    return hasVerifiedPrescriptionMatch;
  }

  bool get canConfirmPrescriptionMatch {
    return hasVerifiedPrescriptionMatch;
  }

  /// True when we know exactly which catalog product the user is looking at.
  ///
  /// This can happen by:
  ///
  /// - verified automatic match;
  /// - explicit manual product selection.
  bool get hasSelectedProductIdentity {
    final medicine = candidate;

    return medicine != null &&
        medicine.isActive &&
        medicine.hasMedicineId;
  }

  bool get hasReviewedKnowledge {
    final profile = knowledge;

    return profile != null &&
        profile.canBeDisplayedAsReviewed;
  }

  /// Ensures reviewed clinical knowledge belongs to the selected product.
  ///
  /// Priority:
  ///
  /// 1. Exact stable product ID.
  /// 2. Exact composition + strength + dosage form + compatible route.
  bool get knowledgeMatchesCandidate {
    final medicine = candidate;
    final profile = knowledge;

    if (medicine == null ||
        profile == null) {
      return false;
    }

    final candidateId = _normalizeIdentity(
      medicine.medicineId,
    );

    final knowledgeId = _normalizeIdentity(
      profile.medicineId,
    );

    if (candidateId.isNotEmpty &&
        knowledgeId.isNotEmpty) {
      return candidateId ==
          knowledgeId;
    }

    final profileProduct =
    _knowledgeToMedicinePrice(
      profile,
    );

    return medicine.hasSameCompositionAs(
      profileProduct,
    ) &&
        medicine.hasSameStrengthAs(
          profileProduct,
        ) &&
        medicine.hasSameDosageFormAs(
          profileProduct,
        ) &&
        medicine.hasCompatibleRouteWith(
          profileProduct,
        );
  }

  /// Clinical content is unlocked only after:
  ///
  /// - automatic verified prescription match; OR
  /// - explicit manual exact-product selection;
  ///
  /// AND reviewed knowledge is available for the same product.
  bool get canShowEducationalProfile {
    final allowedSelection =
        hasVerifiedPrescriptionMatch ||
            isManualSelection;

    return allowedSelection &&
        hasSelectedProductIdentity &&
        hasReviewedKnowledge &&
        knowledgeMatchesCandidate;
  }

  /// Compatibility alias for older screens.
  bool get canShowClinicalKnowledge {
    return canShowEducationalProfile;
  }

  /// V3 alternatives are NOT dependent on MedicineKnowledge.
  ///
  /// They depend on:
  ///
  /// - exact selected product identity;
  /// - verified V3 composition mapping.
  ///
  /// A possible automatic candidate cannot search alternatives until the
  /// exact product is confirmed.
  bool get canSearchAlternatives {
    final allowedSelection =
        hasVerifiedPrescriptionMatch ||
            isManualSelection;

    return allowedSelection &&
        hasSelectedProductIdentity;
  }

  bool get prescriptionMatchRequiresReview {
    if (hasVerifiedPrescriptionMatch) {
      return false;
    }

    return isPossible ||
        isManualSelection;
  }

  int get verificationPercentage {
    final score =
    verificationScore.isFinite
        ? verificationScore
        .clamp(
      0.0,
      1.0,
    )
        .toDouble()
        : 0.0;

    return (score * 100).round();
  }

  String get safeMessage {
    return _sanitizeMessage(
      message,
    );
  }

  String get displayName {
    final databaseName =
        candidate?.brandName.trim() ?? '';

    if (_isRealDisplayValue(
      databaseName,
    ) &&
        databaseName.toLowerCase() !=
            'unknown medicine') {
      return databaseName;
    }

    final readName =
    suggestion.displayTitle.trim();

    if (_isRealDisplayValue(
      readName,
    )) {
      return readName;
    }

    return 'Unknown medicine';
  }

  /// Official/catalog generic name has priority.
  ///
  /// AI generic text is used only when there is no selected database product.
  String get displayGenericName {
    final medicine = candidate;

    if (medicine != null) {
      final databaseGeneric =
          medicine.genericName?.trim() ??
              '';

      if (_isRealDisplayValue(
        databaseGeneric,
      )) {
        return databaseGeneric;
      }

      if (canShowEducationalProfile) {
        final reviewedGeneric =
            knowledge?.genericName.trim() ??
                '';

        if (_isRealDisplayValue(
          reviewedGeneric,
        )) {
          return reviewedGeneric;
        }
      }

      return '';
    }

    final aiGeneric =
    suggestion.genericName.trim();

    if (_isRealDisplayValue(
      aiGeneric,
    )) {
      return aiGeneric;
    }

    return '';
  }

  List<String> get displayCompositionItems {
    final medicine = candidate;

    if (medicine != null) {
      final values =
      <String>[
        ...medicine.activeIngredients,
        if (medicine
            .activeIngredients
            .isEmpty &&
            medicine.hasGenericName)
          medicine.genericName!.trim(),
      ];

      return _uniqueDisplayValues(
        values,
      );
    }

    if (canShowEducationalProfile) {
      final profile = knowledge;

      if (profile != null) {
        return _uniqueDisplayValues(
          profile.activeIngredients,
        );
      }
    }

    return const <String>[];
  }

  String get displayComposition {
    final values =
        displayCompositionItems;

    if (values.isEmpty) {
      return '—';
    }

    return values.join(' + ');
  }

  String get displayStrength {
    final medicine = candidate;

    if (medicine != null) {
      final databaseStrength =
          medicine.strength?.trim() ??
              '';

      if (_isRealDisplayValue(
        databaseStrength,
      )) {
        return databaseStrength;
      }

      return '—';
    }

    final aiStrength =
    suggestion.strength.trim();

    return _isRealDisplayValue(
      aiStrength,
    )
        ? aiStrength
        : '—';
  }

  String get displayDosageForm {
    final medicine = candidate;

    if (medicine != null) {
      final databaseForm =
          medicine.dosageForm?.trim() ??
              '';

      if (_isRealDisplayValue(
        databaseForm,
      )) {
        return databaseForm;
      }

      return '—';
    }

    final aiForm =
    suggestion.form.trim();

    return _isRealDisplayValue(
      aiForm,
    )
        ? aiForm
        : '—';
  }

  String displayRoute({
    required bool isArabic,
  }) {
    final medicine = candidate;

    if (medicine != null) {
      final databaseRoute =
          medicine.route?.trim() ?? '';

      if (_isRealDisplayValue(
        databaseRoute,
      )) {
        return databaseRoute;
      }
    }

    if (canShowEducationalProfile) {
      final reviewedRoute =
          knowledge
              ?.localizedRoute(
            isArabic:
            isArabic,
          )
              .trim() ??
              '';

      if (_isRealDisplayValue(
        reviewedRoute,
      )) {
        return reviewedRoute;
      }
    }

    return '—';
  }

  String get displayPackSize {
    final value =
        candidate?.packSize?.trim() ??
            '';

    return _isRealDisplayValue(
      value,
    )
        ? value
        : '—';
  }

  String get displayManufacturer {
    final value =
        candidate?.manufacturer?.trim() ??
            '';

    return _isRealDisplayValue(
      value,
    )
        ? value
        : '—';
  }

  String get displayAtcCode {
    final databaseAtc =
        candidate?.atcCode?.trim() ??
            '';

    if (_isRealDisplayValue(
      databaseAtc,
    )) {
      return databaseAtc;
    }

    if (canShowEducationalProfile) {
      final reviewedAtc =
          knowledge?.atcCode.trim() ??
              '';

      if (_isRealDisplayValue(
        reviewedAtc,
      )) {
        return reviewedAtc;
      }
    }

    return '—';
  }

  String get prescriptionDirections {
    final structured =
    suggestion.displayDirections.trim();

    if (_isRealDisplayValue(
      structured,
    )) {
      return structured;
    }

    final written =
    suggestion
        .writtenInstructions
        .trim();

    if (_isRealDisplayValue(
      written,
    )) {
      return written;
    }

    return '';
  }

  String get identityDetailsLine {
    final values =
    <String>[
      displayGenericName,
      displayStrength,
      displayDosageForm,
    ];

    return _uniqueDisplayValues(
      values.where(
        _isRealDisplayValue,
      ),
    ).join(' • ');
  }

  String statusLabel({
    required bool isArabic,
  }) {
    if (failed) {
      return isArabic
          ? 'تعذر التحقق'
          : 'Verification unavailable';
    }

    if (wasSkipped) {
      return suggestion.isCategoryOnly
          ? isArabic
          ? 'تم تحديد فئة فقط'
          : 'Category only'
          : isArabic
          ? 'النص غير مقروء'
          : 'Unreadable medicine';
    }

    if (isNotFound) {
      return isArabic
          ? 'لا يوجد منتج مؤكد'
          : 'No confirmed product';
    }

    if (isManualSelection) {
      return isArabic
          ? 'منتج مختار يدويًا'
          : 'Database product selected';
    }

    if (hasVerifiedPrescriptionMatch) {
      return isArabic
          ? 'مطابقة الوصفة مؤكدة'
          : 'Prescription match verified';
    }

    if (isPossible &&
        hasMultipleCandidates) {
      return isArabic
          ? 'يجب تحديد المنتج الدقيق'
          : 'Exact variant needs confirmation';
    }

    if (isPossible) {
      return isArabic
          ? 'مطابقة وصفة محتملة'
          : 'Possible prescription match';
    }

    return isArabic
        ? 'يتطلب مراجعة'
        : 'Requires review';
  }

  String statusExplanation({
    required bool isArabic,
  }) {
    if (failed) {
      return isArabic
          ? 'تمت قراءة الوصفة، لكن تعذر الوصول إلى قاعدة الأدوية حاليًا.'
          : 'The prescription was read, but the medicine database could not be checked.';
    }

    if (wasSkipped &&
        suggestion.isCategoryOnly) {
      return isArabic
          ? 'تم اكتشاف فئة دوائية فقط. لا يمكن تحديد منتج دوائي أو عرض معلومات خاصة بمنتج.'
          : 'Only a medicine category was detected. An exact product cannot be selected safely.';
    }

    if (wasSkipped) {
      return isArabic
          ? 'تعذر قراءة اسم الدواء بأمان. لا يجوز تخمين المنتج.'
          : 'The medicine name could not be read safely. Do not guess the product.';
    }

    if (isNotFound) {
      return isArabic
          ? 'تمت قراءة النص، لكن لم يتم العثور على منتج مطابق بأمان في قاعدة البيانات.'
          : 'The text was read, but no safe matching medicine product was confirmed in the database.';
    }

    if (isManualSelection) {
      return isArabic
          ? 'تم اختيار هذا المنتج يدويًا من قاعدة البيانات. هوية المنتج معروفة، لكن مطابقته مع الوصفة لم يتم تأكيدها تلقائيًا.'
          : 'This product was selected manually from the database. Its product identity is known, but its prescription match was not automatically verified.';
    }

    if (hasVerifiedPrescriptionMatch) {
      return isArabic
          ? 'تمت مطابقة نص الوصفة مع هذا المنتج في قاعدة البيانات.'
          : 'The prescription text was matched to this database product.';
    }

    if (isPossible &&
        candidateCount > 1) {
      return isArabic
          ? 'تم العثور على أكثر من منتج محتمل. يجب مراجعة التركيز والشكل الدوائي لتحديد المنتج الدقيق.'
          : 'Multiple product variants remain possible. Review strength and dosage form before confirming the exact product.';
    }

    if (isPossible) {
      return isArabic
          ? 'هذا المنتج مرشح محتمل فقط ويحتاج إلى تأكيد قبل اعتماد مطابقته مع الوصفة.'
          : 'This is only a possible database candidate and requires confirmation before accepting the prescription match.';
    }

    return isArabic
        ? 'يجب مراجعة المنتج قبل المتابعة.'
        : 'The product must be reviewed before continuing.';
  }

  String localizedTherapeuticClass({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return '';
    }

    return knowledge
        ?.localizedTherapeuticClass(
      isArabic:
      isArabic,
    )
        .trim() ??
        '';
  }

  String localizedUses({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return '';
    }

    return knowledge
        ?.localizedUses(
      isArabic:
      isArabic,
    )
        .trim() ??
        '';
  }

  String localizedHowToTake({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return '';
    }

    return knowledge
        ?.localizedHowToTake(
      isArabic:
      isArabic,
    )
        .trim() ??
        '';
  }

  String localizedFoodInstructions({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return '';
    }

    return knowledge
        ?.localizedFoodInstructions(
      isArabic:
      isArabic,
    )
        .trim() ??
        '';
  }

  List<String> localizedCommonSideEffects({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return const <String>[];
    }

    return knowledge
        ?.localizedCommonSideEffects(
      isArabic:
      isArabic,
    ) ??
        const <String>[];
  }

  List<String> localizedSeriousWarnings({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return const <String>[];
    }

    return knowledge
        ?.localizedSeriousWarnings(
      isArabic:
      isArabic,
    ) ??
        const <String>[];
  }

  List<String> localizedContraindications({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return const <String>[];
    }

    return knowledge
        ?.localizedContraindications(
      isArabic:
      isArabic,
    ) ??
        const <String>[];
  }

  List<String> localizedInteractions({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return const <String>[];
    }

    return knowledge
        ?.localizedInteractions(
      isArabic:
      isArabic,
    ) ??
        const <String>[];
  }

  String localizedPregnancyWarning({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return '';
    }

    return knowledge
        ?.localizedPregnancyWarning(
      isArabic:
      isArabic,
    )
        .trim() ??
        '';
  }

  String localizedStorage({
    required bool isArabic,
  }) {
    if (!canShowEducationalProfile) {
      return '';
    }

    return knowledge
        ?.localizedStorage(
      isArabic:
      isArabic,
    )
        .trim() ??
        '';
  }

  VerifiedMedicineResult copyWith({
    AiMedicineSuggestion? suggestion,
    MedicineVerificationStatus? status,
    MedicinePrice? candidate,
    MedicineKnowledge? knowledge,
    double? verificationScore,
    int? candidateCount,
    String? message,
    MedicineSelectionSource? selectionSource,
    bool clearCandidate = false,
    bool clearKnowledge = false,
  }) {
    return VerifiedMedicineResult(
      suggestion:
      suggestion ?? this.suggestion,
      status:
      status ?? this.status,
      candidate:
      clearCandidate
          ? null
          : candidate ??
          this.candidate,
      knowledge:
      clearKnowledge
          ? null
          : knowledge ??
          this.knowledge,
      verificationScore:
      verificationScore ??
          this.verificationScore,
      candidateCount:
      candidateCount ??
          this.candidateCount,
      message:
      message ?? this.message,
      selectionSource:
      selectionSource ??
          this.selectionSource,
    );
  }

  static MedicinePrice _knowledgeToMedicinePrice(
      MedicineKnowledge profile,
      ) {
    return MedicinePrice(
      medicineId:
      profile.medicineId,
      brandName:
      profile.brandNames.isNotEmpty
          ? profile.brandNames.first
          : '',
      genericName:
      profile.genericName,
      activeIngredients:
      profile.activeIngredients,
      strength:
      profile.strength,
      dosageForm:
      profile.dosageForm,
      route:
      profile.localizedRoute(
        isArabic: false,
      ),
      packSize: null,
      manufacturer: null,
      atcCode:
      profile.atcCode,
      registrationNumber: null,
      priceLbp: null,
      currency: 'LBP',
      effectiveDate: null,
      similarityScore: 1,
      dataSource:
      'medicine_knowledge',
      sourceName:
      profile.sourceName,
      sourceUrl:
      profile.sourceUrl,
      isActive: true,
      isVerified:
      profile.isVerified,
    );
  }

  static List<String> _uniqueDisplayValues(
      Iterable<String> values,
      ) {
    final output =
    <String>[];

    final seen =
    <String>{};

    for (final rawValue in values) {
      final value =
      rawValue.trim();

      if (!_isRealDisplayValue(
        value,
      )) {
        continue;
      }

      final key =
      value.toLowerCase();

      if (seen.add(key)) {
        output.add(
          value,
        );
      }
    }

    return List<String>.unmodifiable(
      output,
    );
  }

  static bool _isRealDisplayValue(
      String value,
      ) {
    final normalized =
    value.trim().toLowerCase();

    const placeholders =
    <String>{
      '',
      '-',
      '--',
      '—',
      'unknown',
      'unreadable',
      'not available',
      'not specified',
      'none',
      'null',
      'n/a',
      'na',
    };

    return !placeholders.contains(
      normalized,
    );
  }

  static String _normalizeIdentity(
      String value,
      ) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(
        r'[^a-z0-9\u0600-\u06FF]',
      ),
      '',
    );
  }

  static String _sanitizeMessage(
      String value,
      ) {
    final cleaned =
    value
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();

    if (cleaned.isEmpty) {
      return '';
    }

    final lower =
    cleaned.toLowerCase();

    const blockedMarkers =
    <String>[
      'stacktrace',
      'stack trace',
      'exception:',
      'postgrestexception',
      'socketexception',
      'clientexception',
      'nosuchmethoderror',
      'typeerror',
      'failed host lookup',
      'status code:',
      'http status',
      'authorization:',
      'apikey',
      'api_key',
      'bearer ',
    ];

    for (final marker
    in blockedMarkers) {
      if (lower.contains(
        marker,
      )) {
        return '';
      }
    }

    return cleaned;
  }
}