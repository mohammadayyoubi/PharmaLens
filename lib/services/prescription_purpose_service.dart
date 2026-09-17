import '../models/verified_medicine_result.dart';

class PrescriptionPurposeResult {
  const PrescriptionPurposeResult({
    required this.analyzed,
    required this.hasPurpose,
    required this.summaryEn,
    required this.summaryAr,
    required this.confidence,
    required this.evidenceMedicines,
  });

  final bool analyzed;
  final bool hasPurpose;
  final String summaryEn;
  final String summaryAr;
  final double confidence;
  final List<String> evidenceMedicines;

  factory PrescriptionPurposeResult.empty() {
    return const PrescriptionPurposeResult(
      analyzed: false,
      hasPurpose: false,
      summaryEn: '',
      summaryAr: '',
      confidence: 0,
      evidenceMedicines: [],
    );
  }

  factory PrescriptionPurposeResult.insufficient({
    List<String> medicines = const [],
  }) {
    return PrescriptionPurposeResult(
      analyzed: true,
      hasPurpose: false,
      summaryEn:
          'The likely purpose could not be determined safely from the verified medicine information.',
      summaryAr:
          'تعذّر تحديد الغرض المحتمل من الوصفة بأمان اعتمادًا على معلومات الأدوية المتحقّق منها.',
      confidence: 0,
      evidenceMedicines: List.unmodifiable(medicines),
    );
  }

  bool get isVisible => analyzed;

  int get confidencePercentage {
    return (confidence.clamp(0.0, 1.0) * 100).round();
  }

  String summary({required bool isArabic}) {
    return isArabic ? summaryAr : summaryEn;
  }
}

class PrescriptionPurposeService {
  const PrescriptionPurposeService();

  PrescriptionPurposeResult analyze(
    List<VerifiedMedicineResult> verificationResults,
  ) {
    final verifiedIdentities = verificationResults
        .where((result) => result.isVerified)
        .toList();

    final evidenceMedicines = _uniqueMedicineNames(verifiedIdentities);

    final medicinesWithKnowledge = verifiedIdentities
        .where(
          (result) =>
              result.canShowClinicalKnowledge && result.knowledge != null,
        )
        .toList();

    if (medicinesWithKnowledge.isEmpty) {
      return PrescriptionPurposeResult.insufficient(
        medicines: evidenceMedicines,
      );
    }

    final scores = <String, double>{};

    for (final result in medicinesWithKnowledge) {
      final knowledge = result.knowledge!;

      final medicalText = _normalize(
        [
          knowledge.usesEn,
          knowledge.usesAr,
          knowledge.therapeuticClassEn,
          knowledge.therapeuticClassAr,
          ...knowledge.activeIngredients,
        ].join(' '),
      );

      for (final category in _categories) {
        final matches = category.keywords.where((keyword) {
          return medicalText.contains(_normalize(keyword));
        }).length;

        if (matches == 0) {
          continue;
        }

        double categoryScore;

        if (matches >= 3) {
          categoryScore = 1.8;
        } else if (matches == 2) {
          categoryScore = 1.4;
        } else {
          categoryScore = 1.0;
        }

        scores.update(
          category.key,
          (oldScore) => oldScore + categoryScore,
          ifAbsent: () => categoryScore,
        );
      }
    }

    if (scores.isEmpty) {
      return PrescriptionPurposeResult.insufficient(
        medicines: evidenceMedicines,
      );
    }

    final rankedScores = scores.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));

    final highestScore = rankedScores.first.value;

    final selectedCategories = rankedScores
        .where(
          (entry) =>
              entry.key == rankedScores.first.key ||
              entry.value >= highestScore * 0.58,
        )
        .take(2)
        .map((entry) => _findCategory(entry.key))
        .whereType<_PurposeCategory>()
        .toList();

    if (selectedCategories.isEmpty) {
      return PrescriptionPurposeResult.insufficient(
        medicines: evidenceMedicines,
      );
    }

    final averageVerificationScore =
        medicinesWithKnowledge
            .map(
              (result) => result.verificationScore.clamp(0.0, 1.0).toDouble(),
            )
            .fold<double>(0, (total, score) => total + score) /
        medicinesWithKnowledge.length;

    final coverage = verificationResults.isEmpty
        ? 0.0
        : medicinesWithKnowledge.length / verificationResults.length;

    final evidenceStrength = (highestScore / 3.6).clamp(0.0, 1.0).toDouble();

    var confidence =
        averageVerificationScore * 0.60 +
        coverage * 0.25 +
        evidenceStrength * 0.15;

    if (medicinesWithKnowledge.length == 1) {
      confidence -= 0.08;
    }

    confidence = confidence.clamp(0.50, 0.96).toDouble();

    return PrescriptionPurposeResult(
      analyzed: true,
      hasPurpose: true,
      summaryEn: _buildEnglishSummary(selectedCategories),
      summaryAr: _buildArabicSummary(selectedCategories),
      confidence: confidence,
      evidenceMedicines: evidenceMedicines,
    );
  }

  List<String> _uniqueMedicineNames(List<VerifiedMedicineResult> results) {
    final names = <String>[];
    final usedNames = <String>{};

    for (final result in results) {
      final name = result.displayName.trim();

      if (name.isEmpty) {
        continue;
      }

      final normalizedName = _normalize(name);

      if (usedNames.add(normalizedName)) {
        names.add(name);
      }
    }

    return names;
  }

  String _buildEnglishSummary(List<_PurposeCategory> categories) {
    if (categories.length == 1) {
      return 'The verified medicines in this prescription are commonly used for ${categories.first.labelEn}.';
    }

    return 'The verified medicines in this prescription are commonly used for ${categories[0].labelEn}, and may also support ${categories[1].labelEn}.';
  }

  String _buildArabicSummary(List<_PurposeCategory> categories) {
    if (categories.length == 1) {
      return 'تُستخدم الأدوية المتحقّق منها في هذه الوصفة غالبًا من أجل ${categories.first.labelAr}.';
    }

    return 'تُستخدم الأدوية المتحقّق منها في هذه الوصفة غالبًا من أجل ${categories[0].labelAr}، وقد تشمل أيضًا ${categories[1].labelAr}.';
  }

  _PurposeCategory? _findCategory(String key) {
    for (final category in _categories) {
      if (category.key == key) {
        return category;
      }
    }

    return null;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[إأآا]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const List<_PurposeCategory> _categories = [
    _PurposeCategory(
      key: 'infection',
      labelEn: 'infections or inflammation',
      labelAr: 'التعامل مع التهابات أو عدوى',
      keywords: [
        'antibiotic',
        'antimicrobial',
        'anti infective',
        'infection',
        'bacterial infection',
        'inflammation',
        'مضاد حيوي',
        'مضاد للعدوى',
        'التهاب',
        'عدوى',
      ],
    ),
    _PurposeCategory(
      key: 'pain_fever',
      labelEn: 'pain or fever relief',
      labelAr: 'تخفيف الألم أو الحرارة',
      keywords: [
        'analgesic',
        'antipyretic',
        'pain relief',
        'fever',
        'paracetamol',
        'acetaminophen',
        'ibuprofen',
        'مسكن',
        'خافض للحرارة',
        'حمى',
        'حرارة',
        'ألم',
      ],
    ),
    _PurposeCategory(
      key: 'allergy',
      labelEn: 'allergy symptoms',
      labelAr: 'تخفيف أعراض الحساسية',
      keywords: [
        'antihistamine',
        'allergy',
        'allergic',
        'rhinitis',
        'urticaria',
        'حساسية',
        'مضاد هيستامين',
        'شرى',
      ],
    ),
    _PurposeCategory(
      key: 'digestive',
      labelEn: 'stomach symptoms, cramps, nausea, or spasms',
      labelAr: 'مشاكل المعدة أو المغص والغثيان والتشنجات',
      keywords: [
        'antispasmodic',
        'belladonna',
        'abdominal cramps',
        'cramp',
        'spasm',
        'nausea',
        'vomiting',
        'gastric',
        'reflux',
        'ulcer',
        'antacid',
        'مغص',
        'تشنج',
        'غثيان',
        'قيء',
        'حموضة',
        'معدة',
      ],
    ),
    _PurposeCategory(
      key: 'fluid_pressure_heart',
      labelEn: 'fluid retention, blood pressure, or selected heart conditions',
      labelAr: 'احتباس السوائل أو ارتفاع الضغط وبعض حالات القلب',
      keywords: [
        'diuretic',
        'furosemide',
        'lasix',
        'hypertension',
        'high blood pressure',
        'edema',
        'fluid retention',
        'heart failure',
        'مدر للبول',
        'ارتفاع الضغط',
        'ضغط الدم',
        'وذمة',
        'احتباس السوائل',
        'قصور القلب',
      ],
    ),
    _PurposeCategory(
      key: 'diabetes',
      labelEn: 'blood-sugar control',
      labelAr: 'تنظيم سكر الدم',
      keywords: [
        'antidiabetic',
        'diabetes',
        'blood sugar',
        'blood glucose',
        'insulin',
        'سكري',
        'سكر الدم',
        'إنسولين',
      ],
    ),
    _PurposeCategory(
      key: 'respiratory',
      labelEn: 'respiratory symptoms such as cough or breathing difficulty',
      labelAr: 'أعراض الجهاز التنفسي مثل السعال أو صعوبة التنفس',
      keywords: [
        'bronchodilator',
        'asthma',
        'cough',
        'wheezing',
        'respiratory',
        'inhaler',
        'ربو',
        'سعال',
        'صفير',
        'تنفس',
        'بخاخ',
      ],
    ),
    _PurposeCategory(
      key: 'skin',
      labelEn: 'skin conditions',
      labelAr: 'مشاكل جلدية',
      keywords: [
        'dermatology',
        'dermatological',
        'topical',
        'eczema',
        'rash',
        'fungal skin',
        'جلدي',
        'أكزيما',
        'طفح',
        'فطريات الجلد',
      ],
    ),
    _PurposeCategory(
      key: 'eye_ear',
      labelEn: 'eye or ear conditions',
      labelAr: 'مشاكل العين أو الأذن',
      keywords: [
        'ophthalmic',
        'eye drops',
        'eye infection',
        'otic',
        'ear drops',
        'عين',
        'قطرة عين',
        'أذن',
        'قطرة أذن',
      ],
    ),
    _PurposeCategory(
      key: 'urinary',
      labelEn: 'urinary-tract symptoms',
      labelAr: 'مشاكل المسالك البولية',
      keywords: [
        'urinary',
        'urinary tract',
        'cystitis',
        'prostate',
        'مسالك بولية',
        'التهاب البول',
        'مثانة',
        'بروستات',
      ],
    ),
  ];
}

class _PurposeCategory {
  const _PurposeCategory({
    required this.key,
    required this.labelEn,
    required this.labelAr,
    required this.keywords,
  });

  final String key;
  final String labelEn;
  final String labelAr;
  final List<String> keywords;
}
