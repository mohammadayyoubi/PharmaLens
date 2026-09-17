import 'dart:convert';

enum MedicineFoodInstruction {
  unknown,
  beforeFood,
  afterFood,
  withFood,
  emptyStomach,
  withOrWithoutFood,
  avoidSpecificFood;

  static MedicineFoodInstruction fromValue(dynamic value) {
    final normalized = value
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    switch (normalized) {
      case 'before_food':
      case 'before_meal':
      case 'before_meals':
        return MedicineFoodInstruction.beforeFood;

      case 'after_food':
      case 'after_meal':
      case 'after_meals':
        return MedicineFoodInstruction.afterFood;

      case 'with_food':
      case 'with_meal':
      case 'with_meals':
        return MedicineFoodInstruction.withFood;

      case 'empty_stomach':
      case 'on_empty_stomach':
        return MedicineFoodInstruction.emptyStomach;

      case 'with_or_without_food':
      case 'with_or_without_meals':
        return MedicineFoodInstruction.withOrWithoutFood;

      case 'avoid_specific_food':
      case 'food_restriction':
      case 'food_restrictions':
        return MedicineFoodInstruction.avoidSpecificFood;

      default:
        return MedicineFoodInstruction.unknown;
    }
  }

  String get databaseValue {
    switch (this) {
      case MedicineFoodInstruction.unknown:
        return 'unknown';
      case MedicineFoodInstruction.beforeFood:
        return 'before_food';
      case MedicineFoodInstruction.afterFood:
        return 'after_food';
      case MedicineFoodInstruction.withFood:
        return 'with_food';
      case MedicineFoodInstruction.emptyStomach:
        return 'empty_stomach';
      case MedicineFoodInstruction.withOrWithoutFood:
        return 'with_or_without_food';
      case MedicineFoodInstruction.avoidSpecificFood:
        return 'avoid_specific_food';
    }
  }

  String localizedLabel({
    required bool isArabic,
  }) {
    switch (this) {
      case MedicineFoodInstruction.unknown:
        return '';

      case MedicineFoodInstruction.beforeFood:
        return isArabic ? 'يؤخذ قبل الطعام' : 'Take before food';

      case MedicineFoodInstruction.afterFood:
        return isArabic ? 'يؤخذ بعد الطعام' : 'Take after food';

      case MedicineFoodInstruction.withFood:
        return isArabic ? 'يؤخذ مع الطعام' : 'Take with food';

      case MedicineFoodInstruction.emptyStomach:
        return isArabic
            ? 'يؤخذ على معدة فارغة'
            : 'Take on an empty stomach';

      case MedicineFoodInstruction.withOrWithoutFood:
        return isArabic
            ? 'يمكن تناوله مع الطعام أو بدونه'
            : 'May be taken with or without food';

      case MedicineFoodInstruction.avoidSpecificFood:
        return isArabic
            ? 'توجد أطعمة أو مشروبات يجب تجنبها'
            : 'Specific foods or drinks must be avoided';
    }
  }
}

class MedicineKnowledge {
  const MedicineKnowledge({
    required this.medicineId,
    required this.genericName,
    required this.brandNames,
    required this.activeIngredients,
    required this.therapeuticClassEn,
    required this.therapeuticClassAr,
    required this.usesEn,
    required this.usesAr,
    required this.howToTakeEn,
    required this.howToTakeAr,
    required this.foodInstructionsEn,
    required this.foodInstructionsAr,
    required this.commonSideEffectsEn,
    required this.commonSideEffectsAr,
    required this.seriousWarningsEn,
    required this.seriousWarningsAr,
    required this.contraindicationsEn,
    required this.contraindicationsAr,
    required this.interactionsEn,
    required this.interactionsAr,
    required this.pregnancyWarningEn,
    required this.pregnancyWarningAr,
    required this.storageEn,
    required this.storageAr,
    required this.sourceName,
    required this.sourceUrl,
    required this.lastReviewedAt,
    required this.isVerified,
    required this.reviewedBy,
    this.strength = '',
    this.dosageForm = '',
    this.routeEn = '',
    this.routeAr = '',
    this.atcCode = '',
    this.foodInstruction = MedicineFoodInstruction.unknown,
    this.sourceVersion = '',
    this.reviewedByRole = '',
  });

  final String medicineId;
  final String genericName;

  final List<String> brandNames;
  final List<String> activeIngredients;

  final String strength;
  final String dosageForm;

  final String routeEn;
  final String routeAr;

  final String atcCode;

  final String therapeuticClassEn;
  final String therapeuticClassAr;

  final String usesEn;
  final String usesAr;

  final String howToTakeEn;
  final String howToTakeAr;

  final MedicineFoodInstruction foodInstruction;
  final String foodInstructionsEn;
  final String foodInstructionsAr;

  final List<String> commonSideEffectsEn;
  final List<String> commonSideEffectsAr;

  final List<String> seriousWarningsEn;
  final List<String> seriousWarningsAr;

  final List<String> contraindicationsEn;
  final List<String> contraindicationsAr;

  final List<String> interactionsEn;
  final List<String> interactionsAr;

  final String pregnancyWarningEn;
  final String pregnancyWarningAr;

  final String storageEn;
  final String storageAr;

  final String sourceName;
  final String sourceUrl;
  final String sourceVersion;

  final DateTime? lastReviewedAt;

  final bool isVerified;
  final String reviewedBy;
  final String reviewedByRole;

  factory MedicineKnowledge.fromJson(
      Map<String, dynamic> json,
      ) {
    return MedicineKnowledge(
      medicineId: _readFirstText(
        json,
        const <String>[
          'medicine_id',
          'product_id',
          'id',
        ],
      ),
      genericName: _readFirstText(
        json,
        const <String>[
          'generic_name',
          'generic',
        ],
      ),
      brandNames: _readFirstStringList(
        json,
        const <String>[
          'brand_names',
          'brands',
          'brand_name',
        ],
      ),
      activeIngredients: _readFirstStringList(
        json,
        const <String>[
          'active_ingredients',
          'ingredients',
          'composition',
        ],
      ),
      strength: _readFirstText(
        json,
        const <String>[
          'strength',
          'product_strength',
        ],
      ),
      dosageForm: _readFirstText(
        json,
        const <String>[
          'dosage_form',
          'form',
          'pharmaceutical_form',
        ],
      ),
      routeEn: _readFirstText(
        json,
        const <String>[
          'route_en',
          'administration_route_en',
        ],
      ),
      routeAr: _readFirstText(
        json,
        const <String>[
          'route_ar',
          'administration_route_ar',
        ],
      ),
      atcCode: _readFirstText(
        json,
        const <String>[
          'atc_code',
          'atc',
        ],
      ),
      therapeuticClassEn: _readText(
        json['therapeutic_class_en'],
      ),
      therapeuticClassAr: _readText(
        json['therapeutic_class_ar'],
      ),
      usesEn: _readText(json['uses_en']),
      usesAr: _readText(json['uses_ar']),
      howToTakeEn: _readText(json['how_to_take_en']),
      howToTakeAr: _readText(json['how_to_take_ar']),
      foodInstruction: MedicineFoodInstruction.fromValue(
        json['food_instruction_code'] ??
            json['food_timing_code'],
      ),
      foodInstructionsEn: _readText(
        json['food_instructions_en'],
      ),
      foodInstructionsAr: _readText(
        json['food_instructions_ar'],
      ),
      commonSideEffectsEn: _readStringList(
        json['common_side_effects_en'],
      ),
      commonSideEffectsAr: _readStringList(
        json['common_side_effects_ar'],
      ),
      seriousWarningsEn: _readStringList(
        json['serious_warnings_en'],
      ),
      seriousWarningsAr: _readStringList(
        json['serious_warnings_ar'],
      ),
      contraindicationsEn: _readStringList(
        json['contraindications_en'],
      ),
      contraindicationsAr: _readStringList(
        json['contraindications_ar'],
      ),
      interactionsEn: _readStringList(
        json['interactions_en'],
      ),
      interactionsAr: _readStringList(
        json['interactions_ar'],
      ),
      pregnancyWarningEn: _readText(
        json['pregnancy_warning_en'],
      ),
      pregnancyWarningAr: _readText(
        json['pregnancy_warning_ar'],
      ),
      storageEn: _readText(json['storage_en']),
      storageAr: _readText(json['storage_ar']),
      sourceName: _readText(json['source_name']),
      sourceUrl: _readText(json['source_url']),
      sourceVersion: _readFirstText(
        json,
        const <String>[
          'source_version',
          'label_version',
        ],
      ),
      lastReviewedAt: _readDate(
        json['last_reviewed_at'] ??
            json['reviewed_at'],
      ),
      isVerified: _readBool(json['is_verified']),
      reviewedBy: _readText(json['reviewed_by']),
      reviewedByRole: _readFirstText(
        json,
        const <String>[
          'reviewed_by_role',
          'reviewer_role',
        ],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'medicine_id': medicineId,
      'generic_name': genericName,
      'brand_names': brandNames,
      'active_ingredients': activeIngredients,
      'strength': strength,
      'dosage_form': dosageForm,
      'route_en': routeEn,
      'route_ar': routeAr,
      'atc_code': atcCode,
      'therapeutic_class_en': therapeuticClassEn,
      'therapeutic_class_ar': therapeuticClassAr,
      'uses_en': usesEn,
      'uses_ar': usesAr,
      'how_to_take_en': howToTakeEn,
      'how_to_take_ar': howToTakeAr,
      'food_instruction_code': foodInstruction.databaseValue,
      'food_instructions_en': foodInstructionsEn,
      'food_instructions_ar': foodInstructionsAr,
      'common_side_effects_en': commonSideEffectsEn,
      'common_side_effects_ar': commonSideEffectsAr,
      'serious_warnings_en': seriousWarningsEn,
      'serious_warnings_ar': seriousWarningsAr,
      'contraindications_en': contraindicationsEn,
      'contraindications_ar': contraindicationsAr,
      'interactions_en': interactionsEn,
      'interactions_ar': interactionsAr,
      'pregnancy_warning_en': pregnancyWarningEn,
      'pregnancy_warning_ar': pregnancyWarningAr,
      'storage_en': storageEn,
      'storage_ar': storageAr,
      'source_name': sourceName,
      'source_url': sourceUrl,
      'source_version': sourceVersion,
      'last_reviewed_at': lastReviewedAt?.toUtc().toIso8601String(),
      'is_verified': isVerified,
      'reviewed_by': reviewedBy,
      'reviewed_by_role': reviewedByRole,
    };
  }

  bool get hasMedicineId {
    return medicineId.trim().isNotEmpty;
  }

  bool get hasGenericName {
    return genericName.trim().isNotEmpty;
  }

  bool get hasBrandNames {
    return brandNames.isNotEmpty;
  }

  bool get hasStrength {
    return strength.trim().isNotEmpty;
  }

  bool get hasDosageForm {
    return dosageForm.trim().isNotEmpty;
  }

  bool get hasRoute {
    return routeEn.trim().isNotEmpty ||
        routeAr.trim().isNotEmpty;
  }

  bool get hasAtcCode {
    return atcCode.trim().isNotEmpty;
  }

  bool get hasComposition {
    return activeIngredients.isNotEmpty ||
        genericName.trim().isNotEmpty;
  }

  bool get hasTherapeuticClass {
    return therapeuticClassEn.trim().isNotEmpty ||
        therapeuticClassAr.trim().isNotEmpty;
  }

  bool get hasUses {
    return usesEn.trim().isNotEmpty ||
        usesAr.trim().isNotEmpty;
  }

  bool get hasHowToTake {
    return howToTakeEn.trim().isNotEmpty ||
        howToTakeAr.trim().isNotEmpty;
  }

  bool get hasFoodInstructions {
    return foodInstruction !=
        MedicineFoodInstruction.unknown ||
        foodInstructionsEn.trim().isNotEmpty ||
        foodInstructionsAr.trim().isNotEmpty;
  }

  bool get hasCommonSideEffects {
    return commonSideEffectsEn.isNotEmpty ||
        commonSideEffectsAr.isNotEmpty;
  }

  bool get hasSeriousWarnings {
    return seriousWarningsEn.isNotEmpty ||
        seriousWarningsAr.isNotEmpty;
  }

  bool get hasContraindications {
    return contraindicationsEn.isNotEmpty ||
        contraindicationsAr.isNotEmpty;
  }

  bool get hasInteractions {
    return interactionsEn.isNotEmpty ||
        interactionsAr.isNotEmpty;
  }

  bool get hasPregnancyWarning {
    return pregnancyWarningEn.trim().isNotEmpty ||
        pregnancyWarningAr.trim().isNotEmpty;
  }

  bool get hasStorageInformation {
    return storageEn.trim().isNotEmpty ||
        storageAr.trim().isNotEmpty;
  }

  bool get hasSource {
    return sourceName.trim().isNotEmpty ||
        sourceUrl.trim().isNotEmpty;
  }

  bool get hasTraceableSource {
    return sourceName.trim().isNotEmpty &&
        sourceUri != null;
  }

  bool get hasReviewer {
    return reviewedBy.trim().isNotEmpty;
  }

  bool get hasReviewerRole {
    return reviewedByRole.trim().isNotEmpty;
  }

  bool get hasReviewDate {
    return lastReviewedAt != null;
  }

  bool get hasReviewAudit {
    return hasReviewer && hasReviewDate;
  }

  bool get hasExactIdentity {
    return hasMedicineId && hasGenericName;
  }

  bool get hasClinicalContent {
    return hasComposition ||
        hasTherapeuticClass ||
        hasUses ||
        hasHowToTake ||
        hasFoodInstructions ||
        hasCommonSideEffects ||
        hasSeriousWarnings ||
        hasContraindications ||
        hasInteractions ||
        hasPregnancyWarning ||
        hasStorageInformation;
  }

  bool get canBeDisplayedAsReviewed {
    return isVerified &&
        hasExactIdentity &&
        hasClinicalContent &&
        hasTraceableSource &&
        hasReviewAudit;
  }

  Uri? get sourceUri {
    final value = sourceUrl.trim();

    if (value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    return uri;
  }

  List<String> get compositionItems {
    final items = <String>[
      ...activeIngredients,
      if (activeIngredients.isEmpty && genericName.trim().isNotEmpty)
        genericName.trim(),
      if (strength.trim().isNotEmpty)
        strength.trim(),
      if (dosageForm.trim().isNotEmpty)
        dosageForm.trim(),
    ];

    return _uniqueStrings(items);
  }

  String localizedTherapeuticClass({
    required bool isArabic,
  }) {
    return _localizedText(
      isArabic: isArabic,
      english: therapeuticClassEn,
      arabic: therapeuticClassAr,
    );
  }

  String localizedUses({
    required bool isArabic,
  }) {
    return _localizedText(
      isArabic: isArabic,
      english: usesEn,
      arabic: usesAr,
    );
  }

  String localizedHowToTake({
    required bool isArabic,
  }) {
    return _localizedText(
      isArabic: isArabic,
      english: howToTakeEn,
      arabic: howToTakeAr,
    );
  }

  String localizedFoodInstructions({
    required bool isArabic,
  }) {
    final explicitText = _localizedText(
      isArabic: isArabic,
      english: foodInstructionsEn,
      arabic: foodInstructionsAr,
    );

    if (explicitText.isNotEmpty) {
      return explicitText;
    }

    return foodInstruction.localizedLabel(
      isArabic: isArabic,
    );
  }

  String localizedRoute({
    required bool isArabic,
  }) {
    return _localizedText(
      isArabic: isArabic,
      english: routeEn,
      arabic: routeAr,
    );
  }

  List<String> localizedCommonSideEffects({
    required bool isArabic,
  }) {
    return _localizedList(
      isArabic: isArabic,
      english: commonSideEffectsEn,
      arabic: commonSideEffectsAr,
    );
  }

  List<String> localizedSeriousWarnings({
    required bool isArabic,
  }) {
    return _localizedList(
      isArabic: isArabic,
      english: seriousWarningsEn,
      arabic: seriousWarningsAr,
    );
  }

  List<String> localizedContraindications({
    required bool isArabic,
  }) {
    return _localizedList(
      isArabic: isArabic,
      english: contraindicationsEn,
      arabic: contraindicationsAr,
    );
  }

  List<String> localizedInteractions({
    required bool isArabic,
  }) {
    return _localizedList(
      isArabic: isArabic,
      english: interactionsEn,
      arabic: interactionsAr,
    );
  }

  String localizedPregnancyWarning({
    required bool isArabic,
  }) {
    return _localizedText(
      isArabic: isArabic,
      english: pregnancyWarningEn,
      arabic: pregnancyWarningAr,
    );
  }

  String localizedStorage({
    required bool isArabic,
  }) {
    return _localizedText(
      isArabic: isArabic,
      english: storageEn,
      arabic: storageAr,
    );
  }

  String get displaySourceName {
    final value = sourceName.trim();

    if (value.isEmpty) {
      return 'Source unavailable';
    }

    return value;
  }

  String get formattedReviewedDate {
    final date = lastReviewedAt;

    if (date == null) {
      return '';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String get identityFingerprint {
    return <String>[
      _normalizeForComparison(genericName),
      _normalizeStrength(strength),
      _normalizeForComparison(dosageForm),
    ].join('|');
  }

  static String _localizedText({
    required bool isArabic,
    required String english,
    required String arabic,
  }) {
    final cleanEnglish = english.trim();
    final cleanArabic = arabic.trim();

    if (isArabic) {
      if (cleanArabic.isNotEmpty) {
        return cleanArabic;
      }

      return cleanEnglish;
    }

    if (cleanEnglish.isNotEmpty) {
      return cleanEnglish;
    }

    return cleanArabic;
  }

  static List<String> _localizedList({
    required bool isArabic,
    required List<String> english,
    required List<String> arabic,
  }) {
    if (isArabic) {
      if (arabic.isNotEmpty) {
        return List<String>.unmodifiable(arabic);
      }

      return List<String>.unmodifiable(english);
    }

    if (english.isNotEmpty) {
      return List<String>.unmodifiable(english);
    }

    return List<String>.unmodifiable(arabic);
  }

  static String _readFirstText(
      Map<String, dynamic> json,
      List<String> keys,
      ) {
    for (final key in keys) {
      final text = _readText(json[key]);

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  static List<String> _readFirstStringList(
      Map<String, dynamic> json,
      List<String> keys,
      ) {
    for (final key in keys) {
      final values = _readStringList(json[key]);

      if (values.isNotEmpty) {
        return values;
      }
    }

    return const <String>[];
  }

  static String _readText(dynamic value) {
    if (value == null) {
      return '';
    }

    var text = value
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.length >= 2) {
      final startsWithQuote =
          text.startsWith('"') || text.startsWith("'");

      final endsWithQuote =
          text.endsWith('"') || text.endsWith("'");

      if (startsWithQuote && endsWithQuote) {
        text = text.substring(1, text.length - 1);
      }
    }

    const ignoredValues = <String>{
      '',
      'null',
      'none',
      'n/a',
      'na',
      '-',
      'unknown',
    };

    if (ignoredValues.contains(text.toLowerCase())) {
      return '';
    }

    return text.trim();
  }

  static List<String> _readStringList(dynamic value) {
    if (value == null) {
      return const <String>[];
    }

    final rawItems = <dynamic>[];

    if (value is List) {
      rawItems.addAll(value);
    } else if (value is String) {
      final cleaned = value.trim();

      if (cleaned.isEmpty) {
        return const <String>[];
      }

      if (cleaned.startsWith('[') &&
          cleaned.endsWith(']')) {
        try {
          final decoded = jsonDecode(cleaned);

          if (decoded is List) {
            rawItems.addAll(decoded);
          } else {
            rawItems.add(decoded);
          }
        } catch (_) {
          rawItems.addAll(
            cleaned
                .substring(1, cleaned.length - 1)
                .split(','),
          );
        }
      } else if (cleaned.startsWith('{') &&
          cleaned.endsWith('}')) {
        rawItems.addAll(
          cleaned
              .substring(1, cleaned.length - 1)
              .split(RegExp(r'\s*,\s*')),
        );
      } else {
        rawItems.addAll(
          cleaned.split(
            RegExp(r'\r?\n|\||;'),
          ),
        );
      }
    } else {
      rawItems.add(value);
    }

    final results = <String>[];
    final seen = <String>{};

    for (final item in rawItems) {
      final text = _readText(item);

      if (text.isEmpty) {
        continue;
      }

      final normalized =
      _normalizeForComparison(text);

      if (normalized.isEmpty) {
        continue;
      }

      if (seen.add(normalized)) {
        results.add(text);
      }
    }

    return List<String>.unmodifiable(results);
  }

  static List<String> _uniqueStrings(
      Iterable<String> values,
      ) {
    final results = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final cleaned = value.trim();

      if (cleaned.isEmpty) {
        continue;
      }

      final normalized =
      _normalizeForComparison(cleaned);

      if (normalized.isEmpty ||
          !seen.add(normalized)) {
        continue;
      }

      results.add(cleaned);
    }

    return List<String>.unmodifiable(results);
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
    value?.toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'y';
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final raw = value.toInt();

      try {
        if (raw > 100000000000) {
          return DateTime.fromMillisecondsSinceEpoch(
            raw,
          );
        }

        if (raw > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(
            raw * 1000,
          );
        }
      } catch (_) {
        return null;
      }
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static String _normalizeStrength(String value) {
    return value
        .toLowerCase()
        .replaceAll(',', '.')
        .replaceAll('µg', 'mcg')
        .replaceAll('μg', 'mcg')
        .replaceAll('ug', 'mcg')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
  }

  static String _normalizeForComparison(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
        .replaceAll(RegExp(r'[إأآا]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
