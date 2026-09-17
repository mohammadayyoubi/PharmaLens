import 'package:flutter/material.dart';

import '../models/ai_handwriting_result.dart';
import '../models/verified_medicine_result.dart';

class PrescriptionPurposeResult {
  const PrescriptionPurposeResult({
    required this.analyzed,
    required this.hasPurpose,
    required this.basedOnCategoriesOnly,
    required this.summaryEn,
    required this.summaryAr,
    required this.confidence,
    required this.evidenceMedicines,
  });

  final bool analyzed;
  final bool hasPurpose;

  /// True when no exact medicine profile was available and the result was
  /// inferred only from readable medicine categories such as:
  /// "Antibiotic Eye Ointment" or "Analgesic Drug".
  final bool basedOnCategoriesOnly;

  final String summaryEn;
  final String summaryAr;
  final double confidence;
  final List<String> evidenceMedicines;

  factory PrescriptionPurposeResult.empty() {
    return const PrescriptionPurposeResult(
      analyzed: false,
      hasPurpose: false,
      basedOnCategoriesOnly: false,
      summaryEn: '',
      summaryAr: '',
      confidence: 0,
      evidenceMedicines: [],
    );
  }

  factory PrescriptionPurposeResult.insufficient({
    List<String> evidenceMedicines = const [],
  }) {
    return PrescriptionPurposeResult(
      analyzed: true,
      hasPurpose: false,
      basedOnCategoriesOnly: false,
      summaryEn:
          'The likely prescription purpose could not be determined safely from the readable and verified information.',
      summaryAr:
          'تعذّر تحديد الغرض المحتمل من الوصفة بأمان اعتمادًا على المعلومات المقروءة والمتحقّق منها.',
      confidence: 0,
      evidenceMedicines: List.unmodifiable(evidenceMedicines),
    );
  }

  bool get isVisible => analyzed;

  int get confidencePercentage {
    return (confidence.clamp(0.0, 1.0) * 100).round();
  }

  String summary({required bool isArabic}) {
    return isArabic ? summaryAr : summaryEn;
  }

  String subtitle({required bool isArabic}) {
    if (basedOnCategoriesOnly) {
      return isArabic
          ? 'تقدير اعتمادًا على الفئات الدوائية المكتوبة؛ لم يتم تحديد المنتجات الدقيقة'
          : 'Estimated from written medicine categories; exact products were not identified';
    }

    return isArabic
        ? 'اعتمادًا على الأدوية المتحقّق منها والمعلومات الطبية المراجَعة'
        : 'Based on verified medicines and reviewed clinical information';
  }

  String disclaimer({required bool isArabic}) {
    if (basedOnCategoriesOnly) {
      return isArabic
          ? 'هذا تقدير عام منخفض الثقة مبني على فئات الأدوية فقط، وليس تشخيصًا أو تعليمات علاجية. يجب على الصيدلي تأكيد أسماء المنتجات والوصفة.'
          : 'This is a low-confidence category-level estimate, not a diagnosis or treatment instruction. A pharmacist must confirm the exact products and prescription.';
    }

    return isArabic
        ? 'هذه خلاصة للاستعمالات الشائعة للأدوية المتحقّق منها، وليست تشخيصًا ولا بديلًا عن الطبيب أو الصيدلي.'
        : 'This summarizes common uses of verified medicines. It is not a diagnosis and does not replace a doctor or pharmacist.';
  }
}

class PrescriptionPurposeService {
  const PrescriptionPurposeService();

  PrescriptionPurposeResult analyze({
    required List<VerifiedMedicineResult> verificationResults,
    required List<AiMedicineSuggestion> aiSuggestions,
  }) {
    final verifiedMedicines = verificationResults
        .where((result) => result.isVerified)
        .toList();

    final medicinesWithReviewedKnowledge = verifiedMedicines
        .where(
          (result) =>
              result.canShowClinicalKnowledge && result.knowledge != null,
        )
        .toList();

    if (medicinesWithReviewedKnowledge.isNotEmpty) {
      return _analyzeVerifiedKnowledge(
        verificationResults: verificationResults,
        verifiedMedicines: medicinesWithReviewedKnowledge,
      );
    }

    final readableCategories = aiSuggestions
        .where(
          (suggestion) =>
              suggestion.isCategoryOnly &&
              !suggestion.isUnreadable &&
              suggestion.hasUsefulResult,
        )
        .toList();

    if (readableCategories.isNotEmpty) {
      return _analyzeCategoryOnlySuggestions(
        allSuggestions: aiSuggestions,
        categorySuggestions: readableCategories,
      );
    }

    return PrescriptionPurposeResult.insufficient(
      evidenceMedicines: _uniqueMedicineNames(verifiedMedicines),
    );
  }

  PrescriptionPurposeResult _analyzeVerifiedKnowledge({
    required List<VerifiedMedicineResult> verificationResults,
    required List<VerifiedMedicineResult> verifiedMedicines,
  }) {
    final categoryScores = <String, double>{};

    for (final result in verifiedMedicines) {
      final knowledge = result.knowledge!;

      final searchableText = _normalize(
        [
          knowledge.usesEn,
          knowledge.usesAr,
          knowledge.therapeuticClassEn,
          knowledge.therapeuticClassAr,
          ...knowledge.activeIngredients,
        ].join(' '),
      );

      _addCategoryScores(
        target: categoryScores,
        searchableText: searchableText,
        scoreMultiplier: 1,
      );
    }

    if (categoryScores.isEmpty) {
      return PrescriptionPurposeResult.insufficient(
        evidenceMedicines: _uniqueMedicineNames(verifiedMedicines),
      );
    }

    final selectedCategories = _selectCategories(
      categoryScores,
      maximumCategories: 2,
    );

    if (selectedCategories.isEmpty) {
      return PrescriptionPurposeResult.insufficient(
        evidenceMedicines: _uniqueMedicineNames(verifiedMedicines),
      );
    }

    final averageVerificationScore =
        verifiedMedicines
            .map(
              (result) => result.verificationScore.clamp(0.0, 1.0).toDouble(),
            )
            .fold<double>(0, (total, value) => total + value) /
        verifiedMedicines.length;

    final coverage = verificationResults.isEmpty
        ? 0.0
        : verifiedMedicines.length / verificationResults.length;

    final topScore = categoryScores.values.reduce(
      (first, second) => first > second ? first : second,
    );

    final evidenceStrength = (topScore / 3.6).clamp(0.0, 1.0).toDouble();

    var confidence =
        averageVerificationScore * 0.60 +
        coverage * 0.25 +
        evidenceStrength * 0.15;

    if (verifiedMedicines.length == 1) {
      confidence -= 0.08;
    }

    confidence = confidence.clamp(0.50, 0.96).toDouble();

    return PrescriptionPurposeResult(
      analyzed: true,
      hasPurpose: true,
      basedOnCategoriesOnly: false,
      summaryEn: _buildEnglishSummary(selectedCategories, categoryLevel: false),
      summaryAr: _buildArabicSummary(selectedCategories, categoryLevel: false),
      confidence: confidence,
      evidenceMedicines: _uniqueMedicineNames(verifiedMedicines),
    );
  }

  PrescriptionPurposeResult _analyzeCategoryOnlySuggestions({
    required List<AiMedicineSuggestion> allSuggestions,
    required List<AiMedicineSuggestion> categorySuggestions,
  }) {
    final categoryScores = <String, double>{};

    for (final suggestion in categorySuggestions) {
      final searchableText = _normalize(
        [
          suggestion.displayTitle,
          suggestion.medicineCategory,
          suggestion.exactWrittenText,
          suggestion.writtenFragment,
          suggestion.form,
          suggestion.route == 'UNKNOWN' ? '' : suggestion.route,
          suggestion.writtenInstructions,
        ].join(' '),
      );

      _addCategoryScores(
        target: categoryScores,
        searchableText: searchableText,
        scoreMultiplier: 1,
      );
    }

    if (categoryScores.isEmpty) {
      return PrescriptionPurposeResult.insufficient(
        evidenceMedicines: _uniqueCategoryNames(categorySuggestions),
      );
    }

    final selectedCategories = _selectCategories(
      categoryScores,
      maximumCategories: 3,
    );

    if (selectedCategories.isEmpty) {
      return PrescriptionPurposeResult.insufficient(
        evidenceMedicines: _uniqueCategoryNames(categorySuggestions),
      );
    }

    final averageAiConfidence =
        categorySuggestions
            .map(
              (suggestion) => _categoryConfidenceValue(suggestion.confidence),
            )
            .fold<double>(0, (total, value) => total + value) /
        categorySuggestions.length;

    final coverage = allSuggestions.isEmpty
        ? 0.0
        : categorySuggestions.length / allSuggestions.length;

    final topScore = categoryScores.values.reduce(
      (first, second) => first > second ? first : second,
    );

    final evidenceStrength = (topScore / 2.4).clamp(0.0, 1.0).toDouble();

    final confidence =
        (averageAiConfidence * 0.65 + coverage * 0.20 + evidenceStrength * 0.15)
            .clamp(0.45, 0.68)
            .toDouble();

    return PrescriptionPurposeResult(
      analyzed: true,
      hasPurpose: true,
      basedOnCategoriesOnly: true,
      summaryEn: _buildEnglishSummary(selectedCategories, categoryLevel: true),
      summaryAr: _buildArabicSummary(selectedCategories, categoryLevel: true),
      confidence: confidence,
      evidenceMedicines: _uniqueCategoryNames(categorySuggestions),
    );
  }

  void _addCategoryScores({
    required Map<String, double> target,
    required String searchableText,
    required double scoreMultiplier,
  }) {
    for (final category in _categories) {
      final matchCount = category.keywords.where((keyword) {
        return searchableText.contains(_normalize(keyword));
      }).length;

      if (matchCount == 0) {
        continue;
      }

      final double rawScore;

      if (matchCount >= 3) {
        rawScore = 1.8;
      } else if (matchCount == 2) {
        rawScore = 1.4;
      } else {
        rawScore = 1.0;
      }

      final score = rawScore * scoreMultiplier;

      target.update(
        category.key,
        (currentScore) => currentScore + score,
        ifAbsent: () => score,
      );
    }
  }

  List<_PurposeCategory> _selectCategories(
    Map<String, double> categoryScores, {
    required int maximumCategories,
  }) {
    final rankedCategories = categoryScores.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));

    if (rankedCategories.isEmpty) {
      return [];
    }

    final topScore = rankedCategories.first.value;

    return rankedCategories
        .where(
          (entry) =>
              entry.key == rankedCategories.first.key ||
              entry.value >= topScore * 0.58,
        )
        .take(maximumCategories)
        .map((entry) => _categoryByKey(entry.key))
        .whereType<_PurposeCategory>()
        .toList();
  }

  double _categoryConfidenceValue(String confidence) {
    switch (confidence.trim().toLowerCase()) {
      case 'high':
        return 0.68;
      case 'medium':
        return 0.58;
      default:
        return 0.48;
    }
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

  List<String> _uniqueCategoryNames(List<AiMedicineSuggestion> suggestions) {
    final names = <String>[];
    final usedNames = <String>{};

    for (final suggestion in suggestions) {
      final name = suggestion.displayTitle.trim();

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

  String _buildEnglishSummary(
    List<_PurposeCategory> categories, {
    required bool categoryLevel,
  }) {
    final prefix = categoryLevel
        ? 'The written medicine categories are commonly associated with '
        : 'The verified medicines in this prescription are commonly used for ';

    if (categories.length == 1) {
      return '$prefix${categories.first.labelEn}.';
    }

    if (categories.length == 2) {
      return '$prefix${categories[0].labelEn} and ${categories[1].labelEn}.';
    }

    return '$prefix${categories[0].labelEn}, ${categories[1].labelEn}, and ${categories[2].labelEn}.';
  }

  String _buildArabicSummary(
    List<_PurposeCategory> categories, {
    required bool categoryLevel,
  }) {
    final prefix = categoryLevel
        ? 'ترتبط الفئات الدوائية المكتوبة غالبًا بـ'
        : 'تُستخدم الأدوية المتحقّق منها في هذه الوصفة غالبًا من أجل ';

    if (categories.length == 1) {
      return '$prefix${categories.first.labelAr}.';
    }

    if (categories.length == 2) {
      return '$prefix${categories[0].labelAr} و${categories[1].labelAr}.';
    }

    return '$prefix${categories[0].labelAr} و${categories[1].labelAr} و${categories[2].labelAr}.';
  }

  _PurposeCategory? _categoryByKey(String key) {
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
      key: 'eye_dryness_irritation',
      labelEn: 'relief of dry eyes or eye irritation',
      labelAr: 'تخفيف جفاف العين أو تهيّجها',
      keywords: [
        'lubricant eye drops',
        'lubricating eye drops',
        'ocular lubricant',
        'artificial tears',
        'dry eye',
        'مرطب للعين',
        'قطره مرطبه للعين',
        'دموع صناعيه',
        'جفاف العين',
      ],
    ),
    _PurposeCategory(
      key: 'eye_infection',
      labelEn: 'treatment of a possible bacterial eye infection',
      labelAr: 'التعامل مع عدوى بكتيرية محتملة في العين',
      keywords: [
        'antibiotic eye ointment',
        'antibiotic eye drops',
        'ophthalmic antibiotic',
        'eye antibiotic',
        'antibacterial eye',
        'مرهم مضاد حيوي للعين',
        'قطره مضاد حيوي للعين',
        'مضاد حيوي للعين',
        'التهاب بكتيري في العين',
      ],
    ),
    _PurposeCategory(
      key: 'infection',
      labelEn: 'treatment of infections or inflammation',
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
      labelEn: 'relief of pain or fever',
      labelAr: 'تخفيف الألم أو الحرارة',
      keywords: [
        'analgesic drug',
        'analgesic',
        'antipyretic',
        'pain relief',
        'fever',
        'paracetamol',
        'acetaminophen',
        'ibuprofen',
        'مسكن',
        'خافض للحراره',
        'حمى',
        'حراره',
        'الم',
      ],
    ),
    _PurposeCategory(
      key: 'allergy',
      labelEn: 'relief of allergy symptoms',
      labelAr: 'تخفيف أعراض الحساسية',
      keywords: [
        'antihistamine',
        'allergy',
        'allergic',
        'rhinitis',
        'urticaria',
        'حساسيه',
        'مضاد هيستامين',
        'شرى',
      ],
    ),
    _PurposeCategory(
      key: 'digestive',
      labelEn: 'relief of stomach symptoms, cramps, nausea, or spasms',
      labelAr: 'تخفيف مشاكل المعدة أو المغص والغثيان والتشنجات',
      keywords: [
        'antispasmodic',
        'belladonna',
        'abdominal cramp',
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
        'حموضه',
        'معده',
      ],
    ),
    _PurposeCategory(
      key: 'fluid_pressure_heart',
      labelEn:
          'management of fluid retention, blood pressure, or selected heart conditions',
      labelAr: 'التعامل مع احتباس السوائل أو ارتفاع الضغط وبعض حالات القلب',
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
        'وذمه',
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
        'blood glucose',
        'blood sugar',
        'insulin',
        'سكري',
        'سكر الدم',
        'انسولين',
      ],
    ),
    _PurposeCategory(
      key: 'respiratory',
      labelEn:
          'relief of respiratory symptoms such as cough or breathing difficulty',
      labelAr: 'تخفيف أعراض الجهاز التنفسي مثل السعال أو صعوبة التنفس',
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
      labelEn: 'management of skin conditions',
      labelAr: 'التعامل مع مشاكل جلدية',
      keywords: [
        'dermatology',
        'dermatological',
        'topical',
        'eczema',
        'rash',
        'fungal skin',
        'جلدي',
        'اكزيما',
        'طفح',
        'فطريات الجلد',
      ],
    ),
    _PurposeCategory(
      key: 'eye_ear',
      labelEn: 'management of eye or ear symptoms',
      labelAr: 'التعامل مع مشاكل العين أو الأذن',
      keywords: ['ophthalmic', 'otic', 'ear drops', 'عين', 'اذن', 'قطره اذن'],
    ),
    _PurposeCategory(
      key: 'urinary',
      labelEn: 'management of urinary-tract symptoms',
      labelAr: 'التعامل مع مشاكل المسالك البولية',
      keywords: [
        'urinary',
        'urinary tract',
        'cystitis',
        'prostate',
        'مسالك بوليه',
        'التهاب البول',
        'مثانه',
        'بروستات',
      ],
    ),
  ];
}

class PrescriptionPurposeCard extends StatelessWidget {
  const PrescriptionPurposeCard({
    super.key,
    required this.result,
    required this.isArabic,
  });

  final PrescriptionPurposeResult result;
  final bool isArabic;

  String _text({required String en, required String ar}) {
    return isArabic ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    final isCategoryEstimate =
        result.hasPurpose && result.basedOnCategoriesOnly;

    final accentColor = !result.hasPurpose || isCategoryEstimate
        ? const Color(0xFFB7791F)
        : const Color(0xFF087F5B);

    final backgroundColor = !result.hasPurpose || isCategoryEstimate
        ? const Color(0xFFFFF8E8)
        : const Color(0xFFEAF9F5);

    final borderColor = !result.hasPurpose || isCategoryEstimate
        ? const Color(0xFFF2D38A)
        : const Color(0xFFBDE9D8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  result.hasPurpose
                      ? Icons.medical_information_outlined
                      : Icons.help_outline_rounded,
                  color: accentColor,
                  size: 27,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(
                        en: 'Likely prescription purpose',
                        ar: 'الغرض المحتمل من الوصفة',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF12233D),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.subtitle(isArabic: isArabic),
                      style: const TextStyle(
                        color: Color(0xFF526577),
                        height: 1.35,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isCategoryEstimate) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                _text(
                  en: 'Category-level estimate',
                  ar: 'تقدير حسب الفئات فقط',
                ),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            result.summary(isArabic: isArabic),
            style: const TextStyle(
              color: Color(0xFF243B53),
              height: 1.55,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (result.hasPurpose) ...[
            const SizedBox(height: 13),
            _PurposeConfidenceRow(
              percentage: result.confidencePercentage,
              isArabic: isArabic,
              accentColor: accentColor,
            ),
          ],
          if (result.evidenceMedicines.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _text(
                en: isCategoryEstimate
                    ? 'Written categories used as evidence'
                    : 'Verified medicines used as evidence',
                ar: isCategoryEstimate
                    ? 'الفئات المكتوبة المستخدمة كدليل'
                    : 'الأدوية المتحقّق منها المستخدمة كدليل',
              ),
              style: const TextStyle(
                color: Color(0xFF526577),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: result.evidenceMedicines
                  .take(6)
                  .map(
                    (medicineName) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        medicineName,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 19,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.disclaimer(isArabic: isArabic),
                    style: const TextStyle(
                      color: Color(0xFF526577),
                      height: 1.45,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurposeConfidenceRow extends StatelessWidget {
  const _PurposeConfidenceRow({
    required this.percentage,
    required this.isArabic,
    required this.accentColor,
  });

  final int percentage;
  final bool isArabic;
  final Color accentColor;

  String get label {
    if (percentage >= 82) {
      return isArabic ? 'ثقة مرتفعة' : 'High confidence';
    }

    if (percentage >= 65) {
      return isArabic ? 'ثقة متوسطة' : 'Medium confidence';
    }

    return isArabic ? 'ثقة محدودة' : 'Limited confidence';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 9,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$label • $percentage%',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: accentColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
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
