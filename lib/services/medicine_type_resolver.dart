import '../l10n/app_text.dart';
import '../models/medicine_knowledge.dart';
import '../models/medicine_price.dart';

enum MedicineTypeSource {
  reviewedProfile,
  atcClassification,
  activeIngredientClassification,
}

class MedicineTypeInfo {
  const MedicineTypeInfo({
    required this.english,
    required this.arabic,
    required this.source,
  });

  final String english;
  final String arabic;
  final MedicineTypeSource source;

  String localizedLabel({required bool isArabic}) {
    return isArabic ? arabic : english;
  }

  String sourceLabel({required bool isArabic}) {
    switch (source) {
      case MedicineTypeSource.reviewedProfile:
        return appText(isArabic).fromTheReviewedMedicineProfile;

      case MedicineTypeSource.atcClassification:
        return appText(isArabic).basedOnTheAtcCodeIn;

      case MedicineTypeSource.activeIngredientClassification:
        return appText(isArabic).basedOnTheRegisteredActiveIngredient;
    }
  }
}

/// Resolves a useful medicine type for pharmacists and patients.
///
/// Priority:
///
/// 1. Reviewed therapeutic class from MedicineKnowledge.
/// 2. ATC classification from the medicine database.
/// 3. Conservative active-ingredient classification.
///
/// This resolver does not generate uses, doses, warnings, or side effects.
/// It only returns a broad medicine category such as:
///
/// - Analgesic
/// - Anti-inflammatory
/// - Antibiotic
/// - Corticosteroid
/// - Antihistamine
class MedicineTypeResolver {
  const MedicineTypeResolver();

  MedicineTypeInfo? resolve({
    required MedicinePrice medicine,
    MedicineKnowledge? knowledge,
  }) {
    final reviewedType = _resolveFromReviewedProfile(knowledge);

    if (reviewedType != null) {
      return reviewedType;
    }

    final atcCode = _firstUsableValue(<String>[
      medicine.atcCode ?? '',
      knowledge?.atcCode ?? '',
    ]);

    final atcType = _resolveFromAtcCode(atcCode);

    if (atcType != null) {
      return atcType;
    }

    final ingredientText = <String>[
      ...medicine.activeIngredients,
      medicine.genericName ?? '',
      ...?knowledge?.activeIngredients,
      knowledge?.genericName ?? '',
    ].join(' ');

    return _resolveFromActiveIngredient(ingredientText);
  }

  MedicineTypeInfo? _resolveFromReviewedProfile(MedicineKnowledge? knowledge) {
    if (knowledge == null) {
      return null;
    }

    final english = knowledge.therapeuticClassEn.trim();

    final arabic = knowledge.therapeuticClassAr.trim();

    if (english.isEmpty && arabic.isEmpty) {
      return null;
    }

    return MedicineTypeInfo(
      english: english.isNotEmpty ? english : arabic,
      arabic: arabic.isNotEmpty ? arabic : english,
      source: MedicineTypeSource.reviewedProfile,
    );
  }

  MedicineTypeInfo? _resolveFromAtcCode(String atcCode) {
    final code = atcCode.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (code.isEmpty) {
      return null;
    }

    final mappings = <_AtcTypeMapping>[
      const _AtcTypeMapping(
        prefix: 'M01',
        english: 'Non-steroidal anti-inflammatory and analgesic',
        arabic: 'مضاد التهاب غير ستيرويدي ومسكن للألم',
      ),
      const _AtcTypeMapping(
        prefix: 'N02',
        english: 'Analgesic / pain reliever',
        arabic: 'مسكن للألم',
      ),
      const _AtcTypeMapping(
        prefix: 'H02',
        english: 'Systemic corticosteroid / anti-inflammatory',
        arabic: 'كورتيكوستيرويد جهازي ومضاد للالتهاب',
      ),
      const _AtcTypeMapping(
        prefix: 'D07',
        english: 'Topical corticosteroid / anti-inflammatory',
        arabic: 'كورتيكوستيرويد موضعي ومضاد للالتهاب',
      ),
      const _AtcTypeMapping(
        prefix: 'J01',
        english: 'Antibacterial antibiotic',
        arabic: 'مضاد حيوي للبكتيريا',
      ),
      const _AtcTypeMapping(
        prefix: 'J02',
        english: 'Antifungal medicine',
        arabic: 'دواء مضاد للفطريات',
      ),
      const _AtcTypeMapping(
        prefix: 'J05',
        english: 'Antiviral medicine',
        arabic: 'دواء مضاد للفيروسات',
      ),
      const _AtcTypeMapping(
        prefix: 'R06',
        english: 'Antihistamine / allergy medicine',
        arabic: 'مضاد هيستامين ودواء للحساسية',
      ),
      const _AtcTypeMapping(
        prefix: 'R03',
        english: 'Airway medicine / bronchodilator group',
        arabic: 'دواء للمجاري التنفسية وموسع للقصبات',
      ),
      const _AtcTypeMapping(
        prefix: 'A02',
        english: 'Medicine for acid-related stomach disorders',
        arabic: 'دواء لاضطرابات حموضة المعدة',
      ),
      const _AtcTypeMapping(
        prefix: 'A03',
        english: 'Antispasmodic / gastrointestinal medicine',
        arabic: 'مضاد للتشنج ودواء للجهاز الهضمي',
      ),
      const _AtcTypeMapping(
        prefix: 'A04',
        english: 'Antiemetic / nausea and vomiting medicine',
        arabic: 'دواء للغثيان والقيء',
      ),
      const _AtcTypeMapping(
        prefix: 'A06',
        english: 'Laxative medicine',
        arabic: 'دواء ملين',
      ),
      const _AtcTypeMapping(
        prefix: 'A07',
        english: 'Antidiarrheal / intestinal medicine',
        arabic: 'دواء للإسهال والأمعاء',
      ),
      const _AtcTypeMapping(
        prefix: 'A10',
        english: 'Antidiabetic medicine',
        arabic: 'دواء للسكري',
      ),
      const _AtcTypeMapping(
        prefix: 'B01',
        english: 'Antithrombotic / blood-thinning medicine',
        arabic: 'دواء مضاد للتخثر أو مميع للدم',
      ),
      const _AtcTypeMapping(
        prefix: 'B03',
        english: 'Medicine for anemia / blood formation',
        arabic: 'دواء لفقر الدم وتكوين الدم',
      ),
      const _AtcTypeMapping(
        prefix: 'C01',
        english: 'Cardiac medicine',
        arabic: 'دواء للقلب',
      ),
      const _AtcTypeMapping(
        prefix: 'C03',
        english: 'Diuretic medicine',
        arabic: 'دواء مدر للبول',
      ),
      const _AtcTypeMapping(
        prefix: 'C07',
        english: 'Beta blocker / cardiovascular medicine',
        arabic: 'حاصر بيتا ودواء للقلب والضغط',
      ),
      const _AtcTypeMapping(
        prefix: 'C08',
        english: 'Calcium-channel blocker / antihypertensive',
        arabic: 'حاصر قنوات الكالسيوم ودواء للضغط',
      ),
      const _AtcTypeMapping(
        prefix: 'C09',
        english: 'Renin-angiotensin system medicine / antihypertensive',
        arabic: 'دواء لنظام الرينين أنجيوتنسين وضغط الدم',
      ),
      const _AtcTypeMapping(
        prefix: 'C10',
        english: 'Lipid-lowering medicine',
        arabic: 'دواء لخفض الدهون والكوليسترول',
      ),
      const _AtcTypeMapping(
        prefix: 'G03',
        english: 'Hormonal medicine',
        arabic: 'دواء هرموني',
      ),
      const _AtcTypeMapping(
        prefix: 'H01',
        english: 'Pituitary or hypothalamic hormone medicine',
        arabic: 'دواء لهرمونات الغدة النخامية أو الوطاء',
      ),
      const _AtcTypeMapping(
        prefix: 'H03',
        english: 'Thyroid medicine',
        arabic: 'دواء للغدة الدرقية',
      ),
      const _AtcTypeMapping(
        prefix: 'L01',
        english: 'Antineoplastic medicine',
        arabic: 'دواء مضاد للأورام',
      ),
      const _AtcTypeMapping(
        prefix: 'L04',
        english: 'Immunosuppressant medicine',
        arabic: 'دواء مثبط للمناعة',
      ),
      const _AtcTypeMapping(
        prefix: 'N03',
        english: 'Antiepileptic / anticonvulsant medicine',
        arabic: 'دواء للصرع ومضاد للتشنجات',
      ),
      const _AtcTypeMapping(
        prefix: 'N04',
        english: 'Anti-Parkinson medicine',
        arabic: 'دواء لمرض باركنسون',
      ),
      const _AtcTypeMapping(
        prefix: 'N05A',
        english: 'Antipsychotic medicine',
        arabic: 'دواء مضاد للذهان',
      ),
      const _AtcTypeMapping(
        prefix: 'N05B',
        english: 'Anxiolytic medicine',
        arabic: 'دواء للقلق',
      ),
      const _AtcTypeMapping(
        prefix: 'N05C',
        english: 'Sedative / hypnotic medicine',
        arabic: 'دواء مهدئ أو منوم',
      ),
      const _AtcTypeMapping(
        prefix: 'N06A',
        english: 'Antidepressant medicine',
        arabic: 'دواء مضاد للاكتئاب',
      ),
      const _AtcTypeMapping(
        prefix: 'P01',
        english: 'Antiprotozoal / antiparasitic medicine',
        arabic: 'دواء مضاد للأوالي والطفيليات',
      ),
      const _AtcTypeMapping(
        prefix: 'P02',
        english: 'Anthelmintic medicine',
        arabic: 'دواء مضاد للديدان',
      ),
      const _AtcTypeMapping(
        prefix: 'S01',
        english: 'Ophthalmic medicine',
        arabic: 'دواء للعين',
      ),
      const _AtcTypeMapping(
        prefix: 'S02',
        english: 'Ear medicine',
        arabic: 'دواء للأذن',
      ),
    ];

    mappings.sort(
      (first, second) => second.prefix.length.compareTo(first.prefix.length),
    );

    for (final mapping in mappings) {
      if (code.startsWith(mapping.prefix)) {
        return MedicineTypeInfo(
          english: mapping.english,
          arabic: mapping.arabic,
          source: MedicineTypeSource.atcClassification,
        );
      }
    }

    return null;
  }

  MedicineTypeInfo? _resolveFromActiveIngredient(String value) {
    final text = _normalize(value);

    if (text.isEmpty) {
      return null;
    }

    if (_containsAny(text, const <String>[
      'paracetamol',
      'acetaminophen',
      'metamizole',
      'dipyrone',
    ])) {
      return const MedicineTypeInfo(
        english: 'Analgesic and antipyretic',
        arabic: 'مسكن للألم وخافض للحرارة',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'ibuprofen',
      'diclofenac',
      'naproxen',
      'ketoprofen',
      'indomethacin',
      'meloxicam',
      'celecoxib',
      'etoricoxib',
      'piroxicam',
      'aceclofenac',
      'ketorolac',
    ])) {
      return const MedicineTypeInfo(
        english: 'Non-steroidal anti-inflammatory and analgesic',
        arabic: 'مضاد التهاب غير ستيرويدي ومسكن للألم',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'dexamethasone',
      'prednisolone',
      'prednisone',
      'methylprednisolone',
      'hydrocortisone',
      'betamethasone',
      'triamcinolone',
      'budesonide',
      'fluticasone',
    ])) {
      return const MedicineTypeInfo(
        english: 'Corticosteroid / anti-inflammatory',
        arabic: 'كورتيكوستيرويد ومضاد للالتهاب',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'amoxicillin',
      'ampicillin',
      'azithromycin',
      'clarithromycin',
      'erythromycin',
      'cefuroxime',
      'cefixime',
      'cefalexin',
      'cephalexin',
      'ceftriaxone',
      'cefotaxime',
      'ciprofloxacin',
      'levofloxacin',
      'moxifloxacin',
      'doxycycline',
      'clindamycin',
      'metronidazole',
      'trimethoprim',
      'sulfamethoxazole',
    ])) {
      return const MedicineTypeInfo(
        english: 'Antibacterial antibiotic',
        arabic: 'مضاد حيوي للبكتيريا',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'fluconazole',
      'itraconazole',
      'ketoconazole',
      'clotrimazole',
      'miconazole',
      'terbinafine',
      'nystatin',
    ])) {
      return const MedicineTypeInfo(
        english: 'Antifungal medicine',
        arabic: 'دواء مضاد للفطريات',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'acyclovir',
      'aciclovir',
      'valacyclovir',
      'oseltamivir',
      'remdesivir',
    ])) {
      return const MedicineTypeInfo(
        english: 'Antiviral medicine',
        arabic: 'دواء مضاد للفيروسات',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'loratadine',
      'desloratadine',
      'cetirizine',
      'levocetirizine',
      'fexofenadine',
      'chlorpheniramine',
      'diphenhydramine',
      'hydroxyzine',
    ])) {
      return const MedicineTypeInfo(
        english: 'Antihistamine / allergy medicine',
        arabic: 'مضاد هيستامين ودواء للحساسية',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'omeprazole',
      'esomeprazole',
      'pantoprazole',
      'lansoprazole',
      'rabeprazole',
    ])) {
      return const MedicineTypeInfo(
        english: 'Proton-pump inhibitor / acid-reducing medicine',
        arabic: 'مثبط مضخة البروتون ودواء لتخفيف حموضة المعدة',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'famotidine',
      'cimetidine',
      'nizatidine',
    ])) {
      return const MedicineTypeInfo(
        english: 'H2 blocker / acid-reducing medicine',
        arabic: 'حاصر مستقبلات H2 ودواء لتخفيف حموضة المعدة',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'ondansetron',
      'metoclopramide',
      'domperidone',
      'granisetron',
    ])) {
      return const MedicineTypeInfo(
        english: 'Antiemetic / nausea and vomiting medicine',
        arabic: 'دواء للغثيان والقيء',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'salbutamol',
      'albuterol',
      'formoterol',
      'salmeterol',
      'ipratropium',
      'tiotropium',
    ])) {
      return const MedicineTypeInfo(
        english: 'Bronchodilator / airway medicine',
        arabic: 'موسع قصبات ودواء للمجاري التنفسية',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'metformin',
      'gliclazide',
      'glimepiride',
      'glibenclamide',
      'sitagliptin',
      'linagliptin',
      'empagliflozin',
      'dapagliflozin',
      'insulin',
    ])) {
      return const MedicineTypeInfo(
        english: 'Antidiabetic medicine',
        arabic: 'دواء للسكري',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'amlodipine',
      'nifedipine',
      'verapamil',
      'diltiazem',
    ])) {
      return const MedicineTypeInfo(
        english: 'Calcium-channel blocker / antihypertensive',
        arabic: 'حاصر قنوات الكالسيوم ودواء للضغط',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'bisoprolol',
      'metoprolol',
      'atenolol',
      'propranolol',
      'carvedilol',
      'nebivolol',
    ])) {
      return const MedicineTypeInfo(
        english: 'Beta blocker / cardiovascular medicine',
        arabic: 'حاصر بيتا ودواء للقلب والضغط',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'enalapril',
      'ramipril',
      'lisinopril',
      'perindopril',
      'captopril',
    ])) {
      return const MedicineTypeInfo(
        english: 'ACE inhibitor / antihypertensive',
        arabic: 'مثبط الإنزيم المحول للأنجيوتنسين ودواء للضغط',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'losartan',
      'valsartan',
      'candesartan',
      'irbesartan',
      'telmisartan',
      'olmesartan',
    ])) {
      return const MedicineTypeInfo(
        english: 'Angiotensin receptor blocker / antihypertensive',
        arabic: 'حاصر مستقبلات الأنجيوتنسين ودواء للضغط',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'furosemide',
      'hydrochlorothiazide',
      'spironolactone',
      'indapamide',
      'bumetanide',
    ])) {
      return const MedicineTypeInfo(
        english: 'Diuretic medicine',
        arabic: 'دواء مدر للبول',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'atorvastatin',
      'rosuvastatin',
      'simvastatin',
      'pravastatin',
    ])) {
      return const MedicineTypeInfo(
        english: 'Lipid-lowering medicine',
        arabic: 'دواء لخفض الدهون والكوليسترول',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'aspirin',
      'clopidogrel',
      'ticagrelor',
    ])) {
      return const MedicineTypeInfo(
        english: 'Antiplatelet / blood-thinning medicine',
        arabic: 'دواء مضاد لتجمع الصفائح ومميع للدم',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'warfarin',
      'apixaban',
      'rivaroxaban',
      'dabigatran',
      'enoxaparin',
      'heparin',
    ])) {
      return const MedicineTypeInfo(
        english: 'Anticoagulant / blood-thinning medicine',
        arabic: 'دواء مضاد للتخثر ومميع للدم',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'sertraline',
      'fluoxetine',
      'escitalopram',
      'citalopram',
      'paroxetine',
      'venlafaxine',
      'duloxetine',
      'mirtazapine',
    ])) {
      return const MedicineTypeInfo(
        english: 'Antidepressant medicine',
        arabic: 'دواء مضاد للاكتئاب',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'diazepam',
      'lorazepam',
      'alprazolam',
      'clonazepam',
      'bromazepam',
    ])) {
      return const MedicineTypeInfo(
        english: 'Anxiolytic / sedative medicine',
        arabic: 'دواء للقلق ومهدئ',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>[
      'levetiracetam',
      'carbamazepine',
      'valproate',
      'valproic acid',
      'lamotrigine',
      'gabapentin',
      'pregabalin',
      'phenytoin',
    ])) {
      return const MedicineTypeInfo(
        english: 'Antiepileptic / anticonvulsant medicine',
        arabic: 'دواء للصرع ومضاد للتشنجات',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    if (_containsAny(text, const <String>['levothyroxine', 'thyroxine'])) {
      return const MedicineTypeInfo(
        english: 'Thyroid hormone replacement medicine',
        arabic: 'دواء لتعويض هرمون الغدة الدرقية',
        source: MedicineTypeSource.activeIngredientClassification,
      );
    }

    return null;
  }

  bool _containsAny(String text, List<String> values) {
    return values.any((value) => text.contains(_normalize(value)));
  }

  String _firstUsableValue(List<String> values) {
    for (final value in values) {
      final cleaned = value.trim();
      final normalized = cleaned.toLowerCase();

      if (cleaned.isEmpty ||
          cleaned == '—' ||
          normalized == 'unknown' ||
          normalized == 'null' ||
          normalized == 'n/a') {
        continue;
      }

      return cleaned;
    }

    return '';
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('µg', 'mcg')
        .replaceAll('μg', 'mcg')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
        .replaceAll(RegExp(r'[إأآا]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _AtcTypeMapping {
  const _AtcTypeMapping({
    required this.prefix,
    required this.english,
    required this.arabic,
  });

  final String prefix;
  final String english;
  final String arabic;
}
