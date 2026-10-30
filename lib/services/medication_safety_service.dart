import '../l10n/app_text.dart';
import '../models/medicine_price.dart';
import '../utils/medicine_equivalence.dart';

enum SafetyAlertType {
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
  });

  final SafetyAlertType type;
  final List<String> medicines;

  /// The ingredient, allergy or class the alert is about.
  final String subjectEn;
  final String subjectAr;

  /// True when the product is only a possible match for the prescription
  /// line, so the alert applies only if that is the right product.
  final bool uncertain;

  bool get isHighPriority => type != SafetyAlertType.sameClass;

  String title({required bool isArabic}) {
    switch (type) {
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
  /// products that only probably match a line; they get allergy checks only,
  /// worded as "if this line is ...". [catalog] lets an ingredient allergy
  /// extend to its chemical class (amoxicillin -> other penicillins).
  List<SafetyAlert> check(
    List<MedicinePrice> medicines, {
    List<String> allergies = const <String>[],
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
      ..._duplicateIngredientAlerts(list),
      ..._sameClassAlerts(list),
    ];
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
