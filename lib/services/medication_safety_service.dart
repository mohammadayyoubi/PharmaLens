import 'package:flutter/foundation.dart';

import '../l10n/app_text.dart';
import '../models/medicine_price.dart';
import '../utils/medicine_equivalence.dart';
import 'health_profile_service.dart';

enum SafetyAlertType {
  /// A product's class (ATC) is known to affect one of the person's health
  /// conditions, e.g. a beta blocker for someone with asthma.
  condition,

  /// A prescribed product contains something on the user's allergy list.
  allergy,

  /// The same active ingredient appears in two or more prescribed products.
  duplicateIngredient,

  /// Two or more products from the same therapeutic class (ATC).
  sameClass,

  /// A product from the same chemical class as an ingredient on the allergy
  /// list (for example ampicillin for someone allergic to amoxicillin).
  relatedAllergy,
}

class SafetyAlert {
  const SafetyAlert({
    required this.type,
    required this.medicines,
    required this.subjectEn,
    required this.subjectAr,
    this.uncertain = false,
    this.condition,
    this.drugClassEn = '',
    this.drugClassAr = '',
    this.effectEn = '',
    this.effectAr = '',
  });

  final SafetyAlertType type;
  final List<String> medicines;

  /// The ingredient, allergy, class or health condition the alert is about.
  final String subjectEn;
  final String subjectAr;

  /// True when the product is only a possible match for the prescription
  /// line, so the alert applies only if that is the right product.
  final bool uncertain;

  /// For [SafetyAlertType.condition]: the condition, the medicines' group
  /// and what that group can do to the condition.
  final HealthCondition? condition;
  final String drugClassEn;
  final String drugClassAr;
  final String effectEn;
  final String effectAr;

  bool get isHighPriority => type != SafetyAlertType.sameClass;

  String title({required bool isArabic}) {
    switch (type) {
      case SafetyAlertType.condition:
        return appText(isArabic).checkWithYourDoctorCondition(isArabic ? subjectAr : subjectEn);
      case SafetyAlertType.allergy:
        return isArabic ? 'تنبيه حساسية: $subjectAr' : 'Allergy alert: $subjectEn';
      case SafetyAlertType.relatedAllergy:
        return isArabic ? 'قريب من حساسيتك: $subjectAr' : 'Related to your allergy: $subjectEn';
      case SafetyAlertType.duplicateIngredient:
        return isArabic ? 'مادة فعالة مكررة: $subjectAr' : 'Same ingredient twice: $subjectEn';
      case SafetyAlertType.sameClass:
        return isArabic ? 'دواءان من الفئة نفسها: $subjectAr' : 'Two medicines from one class: $subjectEn';
    }
  }

  String message({required bool isArabic}) {
    final names = medicines.join(isArabic ? '، ' : ', ');
    final prefix = uncertain
        ? (appText(isArabic).ifThisLineIs(names))
        : '';
    switch (type) {
      case SafetyAlertType.condition:
        return appText(isArabic).conditionAlertMessage(
          prefix,
          names,
          isArabic ? drugClassAr : drugClassEn,
          isArabic ? effectAr : effectEn,
        );
      case SafetyAlertType.allergy:
        return appText(isArabic).mayContainSomethingOnYourAllergy(prefix, names);
      case SafetyAlertType.relatedAllergy:
        return appText(isArabic).isInTheSameDrugClass(prefix, names);
      case SafetyAlertType.duplicateIngredient:
        return appText(isArabic).theSameActiveIngredientIsIn(names);
      case SafetyAlertType.sameClass:
        return appText(isArabic).belongToTheSameTherapeuticClass(names);
    }
  }
}

/// Checks a set of verified MOPH products against each other and against
/// the user's allergy list, using registry ingredients and ATC codes only.
///
/// This is a safety net, not an interaction checker: it cannot see doses,
/// timing or the patient's conditions, and finding nothing does not mean a
/// combination is safe.
class MedicationSafetyService {
  const MedicationSafetyService();

  /// Classes where taking two products together is a common, avoidable risk.
  static const Map<String, (String, String)> _watchedClasses = {
    'M01A': ('NSAIDs (anti-inflammatory painkillers)', 'مضادات الالتهاب غير الستيرويدية'),
    'N02A': ('Opioids', 'المسكنات الأفيونية'),
    'N05B': ('Anxiolytics', 'مضادات القلق'),
    'N05C': ('Hypnotics and sedatives', 'المنومات والمهدئات'),
    'B01A': ('Antithrombotic agents (blood thinners)', 'مضادات التخثر (مسيلات الدم)'),
    'C07': ('Beta blockers', 'حاصرات بيتا'),
    'C09': ('Renin-angiotensin system agents', 'أدوية نظام الرينين-أنجيوتنسين'),
    'A02BC': ('Proton pump inhibitors', 'مثبطات مضخة البروتون'),
    'C10AA': ('Statins', 'الستاتينات'),
    'H02AB': ('Systemic corticosteroids', 'الكورتيكوستيرويدات الجهازية'),
    'R06A': ('Antihistamines', 'مضادات الهيستامين'),
    'N06AB': ('SSRI antidepressants', 'مضادات الاكتئاب من فئة SSRI'),
  };

  /// Allergy words that refer to a whole class, mapped to ATC prefixes.
  static const Map<String, (List<String>, String, String)> _allergyClasses = {
    'penicillin': (['J01C'], 'Penicillins', 'البنسلينات'),
    'بنسلين': (['J01C'], 'Penicillins', 'البنسلينات'),
    'cephalosporin': (['J01DB', 'J01DC', 'J01DD', 'J01DE', 'J01DI'], 'Cephalosporins', 'السيفالوسبورينات'),
    'سيفالوسبورين': (['J01DB', 'J01DC', 'J01DD', 'J01DE', 'J01DI'], 'Cephalosporins', 'السيفالوسبورينات'),
    'sulfa': (['J01E'], 'Sulfonamides', 'السلفوناميدات'),
    'sulfonamide': (['J01E'], 'Sulfonamides', 'السلفوناميدات'),
    'سلفا': (['J01E'], 'Sulfonamides', 'السلفوناميدات'),
    'nsaid': (['M01A', 'N02BA'], 'NSAIDs', 'مضادات الالتهاب غير الستيرويدية'),
    'aspirin': (['N02BA', 'B01AC06'], 'Aspirin', 'الأسبرين'),
    'أسبرين': (['N02BA', 'B01AC06'], 'Aspirin', 'الأسبرين'),
    'اسبرين': (['N02BA', 'B01AC06'], 'Aspirin', 'الأسبرين'),
    'macrolide': (['J01FA'], 'Macrolides', 'الماكروليدات'),
    'quinolone': (['J01M'], 'Quinolones', 'الكينولونات'),
    'fluoroquinolone': (['J01MA'], 'Fluoroquinolones', 'الفلوروكينولونات'),
    'tetracycline': (['J01AA'], 'Tetracyclines', 'التتراسيكلينات'),
    'opioid': (['N02A', 'R05DA'], 'Opioids', 'المسكنات الأفيونية'),
    'codeine': (['R05DA04', 'N02AJ'], 'Codeine', 'الكودايين'),
  };

  /// Medicine groups (ATC prefixes) with a well-known effect on a health
  /// condition. Each entry: condition, ATC prefixes, group name and what
  /// the group can do (completing "which ..."). Cautions only: the alert
  /// sends the user to their doctor and never says a medicine is unsafe or
  /// safe for them.
  static const List<(HealthCondition, List<String>, String, String, String, String)> _conditionRules = [
    // Asthma: beta blockers (also as eye drops) and aspirin or NSAIDs.
    (HealthCondition.asthma, ['C07', 'S01ED'], 'Beta blockers', 'حاصرات بيتا',
        'can narrow the airways and trigger asthma attacks', 'قد تضيّق المجاري التنفسية وتسبب نوبات ربو'),
    (HealthCondition.asthma, ['M01A', 'N02BA', 'B01AC06'], 'NSAIDs and aspirin', 'مضادات الالتهاب غير الستيرويدية والأسبرين',
        'can trigger asthma attacks in some people', 'قد تسبب نوبات ربو لدى بعض الأشخاص'),
    // COPD: non-selective beta blockers; medicines that slow breathing
    // (R05DA04 is codeine; other R05DA cough medicines are not opioids
    // in this sense).
    (HealthCondition.copd, ['C07AA', 'C07AG', 'S01ED'], 'Non-selective beta blockers', 'حاصرات بيتا غير الانتقائية',
        'can narrow the airways', 'قد تضيّق المجاري التنفسية'),
    (HealthCondition.copd, ['N05B', 'N05C', 'N02A', 'R05DA04'], 'Sedatives and opioids', 'المهدئات والمسكنات الأفيونية',
        'can slow breathing', 'قد تبطئ التنفس'),
    // Kidney disease.
    (HealthCondition.kidney, ['M01A'], 'NSAIDs (anti-inflammatory painkillers)', 'مضادات الالتهاب غير الستيرويدية',
        'can harm the kidneys', 'قد تضر بالكلى'),
    (HealthCondition.kidney, ['A10BA'], 'Metformin', 'الميتفورمين',
        'may need a lower dose, or be stopped, when the kidneys are weak', 'قد تحتاج إلى جرعة أقل أو إيقاف عند ضعف الكلى'),
    (HealthCondition.kidney, ['J01GB'], 'Aminoglycoside antibiotics', 'المضادات الحيوية من فئة الأمينوغليكوزيد',
        'can harm the kidneys', 'قد تضر بالكلى'),
    // Liver disease.
    (HealthCondition.liver, ['N02BE01'], 'Paracetamol', 'الباراسيتامول',
        'has a lower safe daily maximum in liver disease', 'لها حد يومي آمن أقل عند أمراض الكبد'),
    (HealthCondition.liver, ['C10AA'], 'Statins', 'الستاتينات',
        'may need liver checks or a different medicine', 'قد تحتاج إلى فحوص للكبد أو دواء آخر'),
    // Pregnancy.
    (HealthCondition.pregnant, ['C09A', 'C09B', 'C09C', 'C09D'], 'ACE inhibitors and sartans', 'مثبطات الإنزيم المحول والسارتانات',
        'can harm the unborn baby', 'قد تضر بالجنين'),
    (HealthCondition.pregnant, ['B01AA'], 'Warfarin-type blood thinners', 'مسيلات الدم من نوع الوارفارين',
        'can harm the unborn baby', 'قد تضر بالجنين'),
    (HealthCondition.pregnant, ['D10BA', 'N03AG01'], 'Isotretinoin and valproate', 'الإيزوتريتينوين والفالبروات',
        'can cause serious birth defects', 'قد تسبب تشوهات خلقية خطيرة'),
    (HealthCondition.pregnant, ['J01AA'], 'Tetracycline antibiotics', 'المضادات الحيوية من فئة التتراسيكلين',
        "can affect the baby's teeth and bones", 'قد تؤثر على أسنان الجنين وعظامه'),
    (HealthCondition.pregnant, ['C10AA', 'J01MA'], 'Statins and quinolone antibiotics', 'الستاتينات ومضادات الكينولون الحيوية',
        'are usually avoided in pregnancy', 'يُتجنب استعمالها عادةً أثناء الحمل'),
    (HealthCondition.pregnant, ['M01A'], 'NSAIDs (anti-inflammatory painkillers)', 'مضادات الالتهاب غير الستيرويدية',
        'are usually avoided in pregnancy, especially in its last months', 'يُتجنب استعمالها عادةً أثناء الحمل خاصةً في أشهره الأخيرة'),
    // Children (under 12, also from the age saved in My Health).
    (HealthCondition.child, ['N02BA', 'B01AC06'], 'Aspirin and salicylates', 'الأسبرين والساليسيلات',
        "are not given to children (risk of Reye's syndrome)", 'لا تُعطى للأطفال (خطر متلازمة راي)'),
    (HealthCondition.child, ['R05DA04', 'N02AJ', 'N02AX02'], 'Codeine, tramadol and similar opioid painkillers',
        'الكودايين والترامادول والمسكنات الأفيونية المشابهة',
        'are not used in children under 12', 'لا تُستعمل للأطفال دون 12 سنة'),
    (HealthCondition.child, ['J01AA', 'J01MA'], 'Tetracycline and quinolone antibiotics', 'مضادات التتراسيكلين والكينولون الحيوية',
        'are usually avoided in children', 'يُتجنب استعمالها عادةً عند الأطفال'),
    // Heart disease and high blood pressure.
    (HealthCondition.heart, ['M01A'], 'NSAIDs (anti-inflammatory painkillers)', 'مضادات الالتهاب غير الستيرويدية',
        'can raise the risk of heart problems and fluid retention', 'قد تزيد خطر مشاكل القلب واحتباس السوائل'),
    (HealthCondition.heart, ['R01BA'], 'Decongestants taken by mouth', 'مزيلات الاحتقان عن طريق الفم',
        'can raise the heart rate and blood pressure', 'قد ترفع نبض القلب وضغط الدم'),
    (HealthCondition.highBloodPressure, ['M01A', 'R01BA', 'H02AB'], 'NSAIDs, decongestants and corticosteroids',
        'مضادات الالتهاب ومزيلات الاحتقان والكورتيزون', 'can raise blood pressure', 'قد ترفع ضغط الدم'),
    // Diabetes.
    (HealthCondition.diabetes, ['H02AB'], 'Corticosteroids (cortisone)', 'الكورتيكوستيرويدات (الكورتيزون)',
        'can raise blood sugar', 'قد ترفع السكر في الدم'),
  ];

  static const Map<String, String> _ingredientSynonyms = {
    'acetaminophen': 'paracetamol',
    'aspirin': 'acetylsalicylic acid',
  };

  /// Arabic names people commonly type for allergens, mapped to the INN
  /// used by the MOPH list. Matched after Arabic letter normalization.
  static const Map<String, String> _arabicIngredients = {
    'باراسيتامول': 'paracetamol',
    'براسيتامول': 'paracetamol',
    'بنادول': 'paracetamol',
    'اسيتامينوفين': 'paracetamol',
    'اموكسيسيلين': 'amoxicillin',
    'اموكسسيلين': 'amoxicillin',
    'اموكسيل': 'amoxicillin',
    'اوغمنتين': 'amoxicillin',
    'اوجمنتين': 'amoxicillin',
    'امبيسيلين': 'ampicillin',
    'ايبوبروفين': 'ibuprofen',
    'بروفين': 'ibuprofen',
    'ديكلوفيناك': 'diclofenac',
    'فولتارين': 'diclofenac',
    'نابروكسين': 'naproxen',
    'كيتوبروفين': 'ketoprofen',
    'ميتاميزول': 'metamizole',
    'نوفالجين': 'metamizole',
    'ازيثرومايسين': 'azithromycin',
    'زيثرومكس': 'azithromycin',
    'كلاريثرومايسين': 'clarithromycin',
    'اريثرومايسين': 'erythromycin',
    'سيبروفلوكساسين': 'ciprofloxacin',
    'ليفوفلوكساسين': 'levofloxacin',
    'دوكسيسيكلين': 'doxycycline',
    'تتراسيكلين': 'tetracycline',
    'سيفالكسين': 'cefalexin',
    'سيفوروكسيم': 'cefuroxime',
    'سيفترياكسون': 'ceftriaxone',
    'سيفيكسيم': 'cefixime',
    'ميترونيدازول': 'metronidazole',
    'فلاجيل': 'metronidazole',
    'كوتريموكسازول': 'sulfamethoxazole',
    'سلفاميثوكسازول': 'sulfamethoxazole',
    'كودايين': 'codeine',
    'كودين': 'codeine',
    'ترامادول': 'tramadol',
    'مورفين': 'morphine',
    'ليدوكايين': 'lidocaine',
    'ليدوكائين': 'lidocaine',
    'كاربامازيبين': 'carbamazepine',
    'لاموتريجين': 'lamotrigine',
    'الوبيورينول': 'allopurinol',
    'كلوبيدوغريل': 'clopidogrel',
    'ميتفورمين': 'metformin',
    'هيبارين': 'heparin',
    'انسولين': 'insulin',
    'يود': 'iodine',
    'كلورهيكسيدين': 'chlorhexidine',
  };

  static String _normalizeArabic(String value) => value
      .replaceAll(RegExp(r'[ً-ْـ]'), '')
      .replaceAll(RegExp('[إأآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'^ال'), '')
      .trim();

  /// The ingredient key an allergy entry refers to, or '' when unknown.
  /// Arabic entries are translated through [_arabicIngredients].
  static String allergyIngredientKey(String allergy) {
    final term = allergy.trim().toLowerCase();
    if (RegExp(r'[؀-ۿ]').hasMatch(term)) {
      final arabic = _normalizeArabic(term);
      for (final entry in _arabicIngredients.entries) {
        final key = _normalizeArabic(entry.key);
        if (arabic == key || arabic.split(' ').contains(key)) return entry.value;
      }
      return '';
    }
    return _ingredientSynonyms[term] ?? MedicineEquivalence.ingredientKey(term);
  }

  /// Whether [allergy] is something the checks can recognize: a known class
  /// word, or an ingredient present in [catalog].
  static bool isRecognizedAllergy(String allergy, List<MedicinePrice> catalog) {
    final term = allergy.trim().toLowerCase();
    if (_allergyClasses.keys.any(term.contains)) return true;
    final key = allergyIngredientKey(allergy);
    if (key.isEmpty) return false;
    return catalog.any((medicine) => medicine.activeIngredients.any((ingredient) => _ingredientMatches(ingredient, key)));
  }

  static bool _ingredientMatches(String ingredient, String allergyKey) {
    final key = MedicineEquivalence.ingredientKey(ingredient);
    return key.isNotEmpty && (key == allergyKey || key.split(' ').contains(allergyKey));
  }

  /// [medicines] are products confirmed for the prescription. [possible] are
  /// products that only probably match a line; they get allergy and
  /// condition checks only, worded as "if this line is ...". [catalog] lets
  /// an ingredient allergy extend to its chemical class (amoxicillin ->
  /// other penicillins). [conditions] are the person's health conditions
  /// (see HealthProfile.effectiveConditions).
  List<SafetyAlert> check(
    List<MedicinePrice> medicines, {
    List<String> allergies = const <String>[],
    Set<HealthCondition> conditions = const <HealthCondition>{},
    List<MedicinePrice> possible = const <MedicinePrice>[],
    List<MedicinePrice> catalog = const <MedicinePrice>[],
  }) {
    final products = <String, MedicinePrice>{};
    for (final medicine in medicines) {
      products.putIfAbsent(medicine.medicineId.isNotEmpty ? medicine.medicineId : medicine.brandName, () => medicine);
    }
    final list = products.values.toList();
    final possibleList = possible.where((m) => !products.containsKey(m.medicineId.isNotEmpty ? m.medicineId : m.brandName)).toList();

    return <SafetyAlert>[
      ..._allergyAlerts(list, allergies, catalog),
      ..._allergyAlerts(possibleList, allergies, catalog, uncertain: true),
      ..._conditionAlerts(list, conditions),
      ..._conditionAlerts(possibleList, conditions, uncertain: true),
      ..._duplicateIngredientAlerts(list),
      ..._sameClassAlerts(list),
    ];
  }

  /// The ATC prefixes of every condition rule, for tests.
  @visibleForTesting
  static List<List<String>> get conditionRulePrefixes => [for (final rule in _conditionRules) rule.$2];

  /// The conditions [alerts] already warn about. The others still deserve
  /// a reminder to tell the doctor (see the analysis screen).
  static Set<HealthCondition> conditionsWithAlerts(List<SafetyAlert> alerts) =>
      <HealthCondition>{for (final alert in alerts) if (alert.condition != null) alert.condition!};

  List<SafetyAlert> _conditionAlerts(
    List<MedicinePrice> medicines,
    Set<HealthCondition> conditions, {
    bool uncertain = false,
  }) {
    final alerts = <SafetyAlert>[];
    if (medicines.isEmpty || conditions.isEmpty) return alerts;

    for (final rule in _conditionRules) {
      if (!conditions.contains(rule.$1)) continue;
      final matching = medicines.where((medicine) {
        final atc = (medicine.atcCode ?? '').toUpperCase();
        return atc.isNotEmpty && rule.$2.any(atc.startsWith);
      }).toList();
      if (matching.isEmpty) continue;

      alerts.add(SafetyAlert(
        type: SafetyAlertType.condition,
        medicines: matching.map((m) => m.brandName).toList(),
        subjectEn: rule.$1.label(isArabic: false),
        subjectAr: rule.$1.label(isArabic: true),
        uncertain: uncertain,
        condition: rule.$1,
        drugClassEn: rule.$3,
        drugClassAr: rule.$4,
        effectEn: rule.$5,
        effectAr: rule.$6,
      ));
    }
    return alerts;
  }

  List<SafetyAlert> _allergyAlerts(
    List<MedicinePrice> medicines,
    List<String> allergies,
    List<MedicinePrice> catalog, {
    bool uncertain = false,
  }) {
    final alerts = <SafetyAlert>[];
    if (medicines.isEmpty) return alerts;

    for (final allergy in allergies) {
      final term = allergy.trim().toLowerCase();
      if (term.length < 3 && !RegExp(r'[؀-ۿ]').hasMatch(term)) continue;

      final classEntry = _allergyClasses.entries.where((e) => term.contains(e.key)).firstOrNull;
      final allergyKey = allergyIngredientKey(term);

      final direct = medicines.where((medicine) {
        final atc = (medicine.atcCode ?? '').toUpperCase();
        if (classEntry != null && classEntry.value.$1.any(atc.startsWith)) return true;
        return allergyKey.isNotEmpty && medicine.activeIngredients.any((ingredient) => _ingredientMatches(ingredient, allergyKey));
      }).toList();

      if (direct.isNotEmpty) {
        alerts.add(SafetyAlert(
          type: SafetyAlertType.allergy,
          medicines: direct.map((m) => m.brandName).toList(),
          subjectEn: classEntry?.value.$2 ?? allergy.trim(),
          subjectAr: classEntry?.value.$3 ?? allergy.trim(),
          uncertain: uncertain,
        ));
      }

      // Same chemical subgroup (ATC level 4, e.g. J01CA penicillins with
      // extended spectrum) as the allergen, found through the catalog.
      if (classEntry != null || allergyKey.isEmpty || catalog.isEmpty) continue;
      final allergenClasses = <String>{
        for (final medicine in catalog)
          if ((medicine.atcCode ?? '').length >= 5 &&
              medicine.activeIngredients.length == 1 &&
              _ingredientMatches(medicine.activeIngredients.first, allergyKey))
            medicine.atcCode!.toUpperCase().substring(0, 5),
      };
      if (allergenClasses.isEmpty) continue;

      final related = medicines.where((medicine) {
        if (direct.contains(medicine)) return false;
        final atc = (medicine.atcCode ?? '').toUpperCase();
        return atc.length >= 5 && allergenClasses.contains(atc.substring(0, 5));
      }).toList();

      if (related.isNotEmpty) {
        alerts.add(SafetyAlert(
          type: SafetyAlertType.relatedAllergy,
          medicines: related.map((m) => m.brandName).toList(),
          subjectEn: allergy.trim(),
          subjectAr: allergy.trim(),
          uncertain: uncertain,
        ));
      }
    }

    return alerts;
  }

  List<SafetyAlert> _duplicateIngredientAlerts(List<MedicinePrice> medicines) {
    final byIngredient = <String, List<MedicinePrice>>{};
    final displayName = <String, String>{};

    for (final medicine in medicines) {
      final keys = <String>{};
      for (final ingredient in medicine.activeIngredients) {
        final key = MedicineEquivalence.ingredientKey(ingredient);
        if (key.isEmpty || !keys.add(key)) continue;
        byIngredient.putIfAbsent(key, () => <MedicinePrice>[]).add(medicine);
        displayName.putIfAbsent(key, () => ingredient.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim());
      }
    }

    return byIngredient.entries
        .where((e) => e.value.length > 1)
        .map((e) => SafetyAlert(
              type: SafetyAlertType.duplicateIngredient,
              medicines: e.value.map((m) => m.brandName).toList(),
              subjectEn: displayName[e.key]!,
              subjectAr: displayName[e.key]!,
            ))
        .toList();
  }

  List<SafetyAlert> _sameClassAlerts(List<MedicinePrice> medicines) {
    final alerts = <SafetyAlert>[];

    for (final entry in _watchedClasses.entries) {
      final inClass = medicines.where((m) => (m.atcCode ?? '').toUpperCase().startsWith(entry.key)).toList();
      if (inClass.length < 2) continue;

      // Already reported as a duplicate ingredient if they share an active moiety.
      final compositions = inClass.map(MedicineEquivalence.compositionKey).toSet();
      if (compositions.length < 2) continue;

      alerts.add(SafetyAlert(
        type: SafetyAlertType.sameClass,
        medicines: inClass.map((m) => m.brandName).toList(),
        subjectEn: entry.value.$1,
        subjectAr: entry.value.$2,
      ));
    }

    return alerts;
  }
}
