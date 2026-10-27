import '../models/medicine_price.dart';
import '../utils/medicine_equivalence.dart';

enum SafetyAlertType {
  /// A prescribed product contains something on the user's allergy list.
  allergy,

  /// The same active ingredient appears in two or more prescribed products.
  duplicateIngredient,

  /// Two or more products from the same therapeutic class (ATC).
  sameClass,
}

class SafetyAlert {
  const SafetyAlert({
    required this.type,
    required this.medicines,
    required this.subjectEn,
    required this.subjectAr,
  });

  final SafetyAlertType type;
  final List<String> medicines;

  /// The ingredient, allergy or class the alert is about.
  final String subjectEn;
  final String subjectAr;

  bool get isHighPriority => type != SafetyAlertType.sameClass;

  String title({required bool isArabic}) {
    switch (type) {
      case SafetyAlertType.allergy:
        return isArabic ? 'تنبيه حساسية: $subjectAr' : 'Allergy alert: $subjectEn';
      case SafetyAlertType.duplicateIngredient:
        return isArabic ? 'مادة فعالة مكررة: $subjectAr' : 'Same ingredient twice: $subjectEn';
      case SafetyAlertType.sameClass:
        return isArabic ? 'دواءان من الفئة نفسها: $subjectAr' : 'Two medicines from one class: $subjectEn';
    }
  }

  String message({required bool isArabic}) {
    final names = medicines.join(isArabic ? '، ' : ', ');
    switch (type) {
      case SafetyAlertType.allergy:
        return isArabic
            ? '$names قد يحتوي على مادة سجلت أن لديك حساسية منها. لا تتناوله قبل التحدث مع طبيبك أو الصيدلي.'
            : '$names may contain something on your allergy list. Do not take it before talking to your doctor or pharmacist.';
      case SafetyAlertType.duplicateIngredient:
        return isArabic
            ? 'المادة نفسها موجودة في: $names. تناولها معًا قد يتجاوز الجرعة الآمنة. تأكد من الطبيب أو الصيدلي.'
            : 'The same active ingredient is in: $names. Taking them together can exceed a safe dose. Check with your doctor or pharmacist.';
      case SafetyAlertType.sameClass:
        return isArabic
            ? '$names من الفئة العلاجية نفسها. اسأل الطبيب أو الصيدلي إن كان المقصود تناولهما معًا.'
            : '$names belong to the same therapeutic class. Ask your doctor or pharmacist whether both are intended.';
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

  List<SafetyAlert> check(
    List<MedicinePrice> medicines, {
    List<String> allergies = const <String>[],
  }) {
    final products = <String, MedicinePrice>{};
    for (final medicine in medicines) {
      products.putIfAbsent(medicine.medicineId.isNotEmpty ? medicine.medicineId : medicine.brandName, () => medicine);
    }
    final list = products.values.toList();

    return <SafetyAlert>[
      ..._allergyAlerts(list, allergies),
      ..._duplicateIngredientAlerts(list),
      ..._sameClassAlerts(list),
    ];
  }

  List<SafetyAlert> _allergyAlerts(List<MedicinePrice> medicines, List<String> allergies) {
    final alerts = <SafetyAlert>[];

    for (final allergy in allergies) {
      final term = allergy.trim().toLowerCase();
      if (term.length < 3) continue;

      final classEntry = _allergyClasses.entries.where((e) => term.contains(e.key)).firstOrNull;
      final allergyKey = _ingredientSynonyms[term] ?? MedicineEquivalence.ingredientKey(term);

      final matches = medicines.where((medicine) {
        final atc = (medicine.atcCode ?? '').toUpperCase();
        if (classEntry != null && classEntry.value.$1.any(atc.startsWith)) return true;

        return medicine.activeIngredients.any((ingredient) {
          final key = MedicineEquivalence.ingredientKey(ingredient);
          return key.isNotEmpty && (key == allergyKey || key.split(' ').contains(allergyKey));
        });
      }).map((m) => m.brandName).toList();

      if (matches.isNotEmpty) {
        alerts.add(SafetyAlert(
          type: SafetyAlertType.allergy,
          medicines: matches,
          subjectEn: classEntry?.value.$2 ?? allergy.trim(),
          subjectAr: classEntry?.value.$3 ?? allergy.trim(),
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
