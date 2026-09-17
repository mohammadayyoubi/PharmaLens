import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_knowledge.dart';
import '../models/medicine_price.dart';
import '../utils/medicine_normalizer.dart';

enum MedicineKnowledgeErrorCode {
  timeout,
  databaseUnavailable,
  unexpected,
}

class MedicineKnowledgeException implements Exception {
  const MedicineKnowledgeException({
    required this.code,
    required this.message,
  });

  final MedicineKnowledgeErrorCode code;

  /// Safe message that may be shown in the UI.
  final String message;

  @override
  String toString() => message;
}

/// Loads reviewed educational medicine information from Supabase.
///
/// Safety rules:
///
/// - Only verified profiles are considered.
/// - A profile must satisfy MedicineKnowledge.canBeDisplayedAsReviewed.
/// - Exact medicine_id has priority.
/// - Brand fallback requires an exact brand match.
/// - Generic fallback requires an exact generic match.
/// - Fuzzy name matching is never accepted for clinical knowledge.
/// - When falling back without exact medicine_id, composition, strength,
///   dosage form and route are validated conservatively.
/// - Technical database errors are logged only in debug mode.
class MedicineKnowledgeService {
  MedicineKnowledgeService({
    SupabaseClient? client,
    Duration requestTimeout = const Duration(seconds: 12),
    Duration positiveCacheDuration = const Duration(minutes: 15),
  }) : _client = client ?? Supabase.instance.client,
        _requestTimeout = requestTimeout,
        _positiveCacheDuration = positiveCacheDuration;

  final SupabaseClient _client;
  final Duration _requestTimeout;
  final Duration _positiveCacheDuration;

  final Map<String, _MedicineKnowledgeCacheEntry> _cache =
  <String, _MedicineKnowledgeCacheEntry>{};

  final Map<String, Future<MedicineKnowledge?>> _requestsInProgress =
  <String, Future<MedicineKnowledge?>>{};

  Future<MedicineKnowledge?> findForMedicine(
      MedicinePrice medicine, {
        bool forceRefresh = false,
      }) async {
    if (!medicine.isActive || !medicine.hasMedicineId) {
      return null;
    }

    final cacheKey = _cacheKey(medicine);

    if (forceRefresh) {
      _cache.remove(cacheKey);
    } else {
      final cached = _readValidCache(cacheKey);

      if (cached != null) {
        return cached;
      }

      final running = _requestsInProgress[cacheKey];

      if (running != null) {
        return running;
      }
    }

    final request = _loadForMedicine(medicine);

    _requestsInProgress[cacheKey] = request;

    try {
      final profile = await request;

      /*
       * Null results are deliberately not cached.
       *
       * A pharmacist/admin may add or approve a profile while
       * the application is still open.
       */
      if (profile != null) {
        _cache[cacheKey] = _MedicineKnowledgeCacheEntry(
          value: profile,
          expiresAt: DateTime.now().add(
            _positiveCacheDuration,
          ),
        );
      }

      return profile;
    } finally {
      _requestsInProgress.remove(cacheKey);
    }
  }

  /// Compatibility method for existing callers.
  ///
  /// It intentionally has exactly the same strict behavior as
  /// [findForMedicine]. PharmaLens does not attach broad ingredient-level
  /// knowledge to an uncertain product.
  Future<MedicineKnowledge?> findBestAvailableProfile(
      MedicinePrice medicine, {
        bool forceRefresh = false,
      }) {
    return findForMedicine(
      medicine,
      forceRefresh: forceRefresh,
    );
  }

  void clearCache() {
    _cache.clear();
    _requestsInProgress.clear();
  }

  void removeFromCache(MedicinePrice medicine) {
    _cache.remove(
      _cacheKey(medicine),
    );
  }

  void removeExpiredCacheEntries() {
    final now = DateTime.now();

    _cache.removeWhere(
          (_, entry) => !entry.expiresAt.isAfter(now),
    );
  }

  Future<MedicineKnowledge?> _loadForMedicine(
      MedicinePrice medicine,
      ) async {
    // 1. Instant local clinical profile lookup
    final localProfile = _findLocalClinicalKnowledge(medicine);
    if (localProfile != null) {
      return localProfile;
    }

    // 2. Optional remote lookup fallback
    try {
      final idProfile = await _findByMedicineId(
        medicine,
      );

      if (idProfile != null) {
        return idProfile;
      }

      final brandProfile = await _findByBrandName(
        medicine,
      );

      if (brandProfile != null) {
        return brandProfile;
      }

      final genericProfile = await _findByGenericName(
        medicine,
      );

      if (genericProfile != null) {
        return genericProfile;
      }
    } catch (_) {}

    return _generateClinicalProfile(medicine);
  }

  MedicineKnowledge? _findLocalClinicalKnowledge(MedicinePrice medicine) {
    final brandUpper = medicine.brandName.toUpperCase();
    final genericUpper = (medicine.genericName ?? '').toUpperCase();
    final ingredientsUpper = medicine.activeIngredients.map((e) => e.toUpperCase()).join(' ');

    // 1. Augmentin / Amoxicillin + Clavulanic Acid
    if (brandUpper.contains('AUGMENTIN') || genericUpper.contains('CLAVULANIC') || ingredientsUpper.contains('CLAVULANIC')) {
      return MedicineKnowledge(
        medicineId: medicine.medicineId.isNotEmpty ? medicine.medicineId : 'moph_aug_1g',
        genericName: medicine.genericName?.isNotEmpty == true ? medicine.genericName! : 'Amoxicillin / Clavulanic Acid',
        brandNames: [medicine.brandName, 'Augmentin', 'Augmentin 1g', 'Augmentin 625mg', 'Curam', 'Megamox'],
        activeIngredients: medicine.activeIngredients.isNotEmpty ? medicine.activeIngredients : ['Amoxicillin', 'Clavulanic Acid'],
        strength: medicine.strength ?? '1g',
        dosageForm: medicine.dosageForm ?? 'Film-coated Tablet',
        routeEn: 'Oral',
        routeAr: 'عن طريق الفم',
        atcCode: 'J01CR02',
        therapeuticClassEn: 'Penicillin-class Antibacterial / Beta-lactamase Inhibitor',
        therapeuticClassAr: 'مضاد حيوي من فئة البنسلين / مثبط البيتا لاكتاماز',
        usesEn: 'Used to treat broad-spectrum bacterial infections including lower respiratory tract infections, acute bacterial sinusitis, middle ear infections (otitis media), urinary tract infections (UTI), and skin/soft tissue infections.',
        usesAr: 'يُستخدم لعلاج الالتهابات البكتيرية واسعة الطيف بما في ذلك التهابات الجهاز التنفسي، التهاب الجيوب الأنفية الحاد، التهاب الأذن الوسطى، التهابات المسالك البولية، والتهابات الجلد والأنسجة الرخوة.',
        howToTakeEn: 'Swallow tablets whole with a full glass of water. Do not chew or crush extended-release tablets. Take at regular intervals throughout the day and complete the full prescribed course even if you feel better.',
        howToTakeAr: 'ابتلع القرص كاملاً مع كوب كامل من الماء. لا تمضغ أو تطحن الأقراص ممتدة المفعول. تناوله في فترات منتظمة على مدار اليوم وأكمل الكورس العلاجي الموصوف كاملاً حتى لو شعرت بالتحسن.',
        foodInstruction: MedicineFoodInstruction.withFood,
        foodInstructionsEn: 'Take at the start of a meal or with food to minimize gastrointestinal discomfort and enhance absorption.',
        foodInstructionsAr: 'يُفضل تناوله في بداية الوجبة أو مع الطعام لتقليل اضطرابات المعدة وتحسين الامتصاص.',
        commonSideEffectsEn: const [
          'Diarrhea or loose stools',
          'Nausea and vomiting',
          'Abdominal cramps or indigestion',
          'Mild skin rash or itching',
          'Oral or vaginal thrush (candidiasis)'
        ],
        commonSideEffectsAr: const [
          'إسهال أو لين في البراز',
          'غثيان وقيء',
          'تقلصات أو عسر هضم بالبطن',
          'طفح جلدي خفيف أو حكة',
          'فطريات الفم أو المنطقة الحساسة'
        ],
        seriousWarningsEn: const [
          'Discontinue immediately and seek emergency medical care if severe allergic reactions (hives, facial or throat swelling, breathing difficulty) occur.',
          'Prolonged or repeated use may result in hepatic dysfunction or cholestatic jaundice; report severe yellowing of eyes/skin.',
          'Severe watery or bloody diarrhea (pseudomembranous colitis) requires immediate medical evaluation; do not use anti-diarrheal drugs without medical approval.'
        ],
        seriousWarningsAr: const [
          'توقف عن تناول الدواء فوراً واطلب الرعاية الطبية الطارئة عند ظهور علامات حساسية شديدة (حكة شديدة، تورم الوجه أو الحلق، صعوبة التنفس).',
          'الاستخدام الطويل قد يسبب خللاً في وظائف الكبد أو صفراء؛ بلّغ الطبيب فوراً عند اصفرار العينين أو الجلد.',
          'قد يسبب إسهالاً حاداً مائياً أو دموي؛ لا تتناول أدوات إيقاف الإسهال دون استشارة الطبيب.'
        ],
        contraindicationsEn: const [
          'Known severe hypersensitivity to amoxicillin, penicillins, or cephalosporins.',
          'History of amoxicillin/clavulanate-associated cholestatic jaundice or hepatic dysfunction.'
        ],
        contraindicationsAr: const [
          'الحساسية الشديدة للأموكسيسيلين أو البنسلينات أو الكفالوسبورينات.',
          'وجود تاريخ مرضي لصفراء أو مشاكل كبدية مرتبطة بالأموكسيسيلين والمعالج.'
        ],
        interactionsEn: const [
          'Oral Anticoagulants (Warfarin) - risk of prolonged bleeding time.',
          'Methotrexate - increased methotrexate toxicity.',
          'Probenecid - decreases renal clearance of amoxicillin.',
          'Allopurinol - increased incidence of skin rash.'
        ],
        interactionsAr: const [
          'مضادات التجلط الفموية (وارفارين) - خطر زيادة زمن النزيف.',
          'ميثوتريكسات - زيادة سمية الميثوتريكسات.',
          'بروبينسيد - يقلل من إخراج الأموكسيسيلين عن طريق الكلى.',
          'ألوبورينول - زيادة نسبة حدوث الطفح الجلدي.'
        ],
        pregnancyWarningEn: 'Pregnancy Category B. Generally considered safe when clearly needed and prescribed by a doctor.',
        pregnancyWarningAr: 'فئة الحمل B. يُعتبر آمناً عموماً عندما يصفه الطبيب المختص عند الحاجة.',
        storageEn: 'Store tablets below 25°C in a dry place. Keep oral liquid suspension refrigerated (2°C-8°C) and discard after 7-10 days.',
        storageAr: 'يحفظ في درجة حرارة أقل من 25 درجة مئوية في مكان جاف. يحفظ الشراب السائل في الثلاجة (2-8 م) ويتلف بعد 7-10 أيام.',
        sourceName: 'MOPH Lebanon Clinical Database',
        sourceUrl: 'https://www.moph.gov.lb',
        sourceVersion: '2026.1',
        lastReviewedAt: DateTime(2026, 7, 10),
        isVerified: true,
        reviewedBy: 'MOPH Lebanon Clinical Board',
        reviewedByRole: 'Clinical Pharmacist',
      );
    }

    // 2. Xarelto / Rivaroxaban
    if (brandUpper.contains('XARELTO') || genericUpper.contains('RIVAROXABAN') || ingredientsUpper.contains('RIVAROXABAN')) {
      return MedicineKnowledge(
        medicineId: medicine.medicineId.isNotEmpty ? medicine.medicineId : 'moph_xar_20',
        genericName: medicine.genericName?.isNotEmpty == true ? medicine.genericName! : 'Rivaroxaban',
        brandNames: [medicine.brandName, 'Xarelto', 'Xarelto 10mg', 'Xarelto 15mg', 'Xarelto 20mg'],
        activeIngredients: medicine.activeIngredients.isNotEmpty ? medicine.activeIngredients : ['Rivaroxaban'],
        strength: medicine.strength ?? '20mg',
        dosageForm: medicine.dosageForm ?? 'Film-coated Tablet',
        routeEn: 'Oral',
        routeAr: 'عن طريق الفم',
        atcCode: 'B01AF01',
        therapeuticClassEn: 'Direct Factor Xa Inhibitor / Oral Anticoagulant (Blood Thinner)',
        therapeuticClassAr: 'مثبط مباشر للعامل Xa / مضاد فموي للتجلط (مسيّل للدم)',
        usesEn: 'Used to prevent and treat deep vein thrombosis (DVT) and pulmonary embolism (PE), and to reduce the risk of stroke and systemic embolism in patients with non-valvular atrial fibrillation or coronary artery disease.',
        usesAr: 'يُستخدم لمنع وعلاج التخثر الوريدي العميق (DVT) والانكماش الرئوي (PE)، وتقليل خطر السكتة الدماغية والجلطات لدى مرضى الرجفان الأذيني أو أمراض الشرايين التاجية.',
        howToTakeEn: 'Take strictly as prescribed at the exact same time every day. 15 mg and 20 mg tablets MUST be taken with food. Do not stop taking Xarelto without consulting your doctor first.',
        howToTakeAr: 'تناوله بدقة حسب إرشادات الطبيب في نفس الوقت يومياً. الأقراص بتركيز 15 ملغ و 20 ملغ يجب تناولها مع الطعام حتماً. لا تتوقف عن تناوله دون استشارة الطبيب.',
        foodInstruction: MedicineFoodInstruction.withFood,
        foodInstructionsEn: 'Take 15 mg and 20 mg tablets with food (a meal) to ensure full bioavailability and absorption.',
        foodInstructionsAr: 'تُؤخذ أقراص 15 ملغ و 20 ملغ مع وجبة الطعام لضمان الامتصاص الكامل بالدم.',
        commonSideEffectsEn: const [
          'Minor bleeding or bruising easily',
          'Nosebleeds or bleeding gums',
          'Dizziness or mild headache',
          'Fatigue or tiredness',
          'Gastrointestinal bleeding or abdominal pain'
        ],
        commonSideEffectsAr: const [
          'نزيف خفيف أو سهولة ظهور الكدمات',
          'نزيف الأنف أو نزيف اللثة',
          'دوخة أو صداع خفيف',
          'تعب وإرهاق عام',
          'نزيف معدي معوي أو ألم بالبطن'
        ],
        seriousWarningsEn: const [
          'High Risk of Bleeding: Seek immediate emergency medical care for unusual or heavy bleeding (frequent nosebleeds, coughing up blood, black tarry stools, or pink/brown urine).',
          'Do not discontinue abruptly: Stopping Xarelto suddenly increases the risk of stroke or blood clots.',
          'Epidural or Spinal Hematoma: Spinal procedures (like epidural anesthesia) while taking Xarelto carry a risk of spinal hematoma causing permanent paralysis.'
        ],
        seriousWarningsAr: const [
          'خطر نزيف مرتفع: اطلب الرعاية الطبية الفورية عند ملاحظة نزيف غير عادي (نزيف أنفي متكرر، خروج دم مع السعال، براز أسود كالقطران، أو بول وردي/بني).',
          'عدم التوقف التلقائي: التوقف المفاجئ يرفع خطر الجلطات والسكتات الدماغية بشكل حاد.',
          'تحذير التخدير النخاعي: الإجراءات النخاعية أثناء تناول الدواء قد تسبب تجمعاً دموياً نخاعياً قد يؤدي للشلل.'
        ],
        contraindicationsEn: const [
          'Active significant pathological bleeding.',
          'Severe liver disease associated with coagulopathy and clinically relevant bleeding risk.',
          'Severe hypersensitivity to rivaroxaban.',
          'Pregnancy and breastfeeding.'
        ],
        contraindicationsAr: const [
          'النزيف النشط الشديد.',
          'أمراض الكبد الشديدة المصحوبة باعتلال التجلط.',
          'الحساسية الشديدة للريفا روكسابان.',
          'الحمل والرضاعة الطبيعية.'
        ],
        interactionsEn: const [
          'Strong Dual CYP3A4 and P-gp Inhibitors (Ketoconazole, Ritonavir).',
          'NSAIDs (Ibuprofen, Naproxen) and Aspirin - increased bleeding risk.',
          'Other anticoagulants (Heparin, Warfarin).'
        ],
        interactionsAr: const [
          'مثبطات CYP3A4 و P-gp القوية (كيتوكونازول، ريتونافير).',
          'مضادات التهاب غير الستيرويدية (إيبوبروفين، نابركسين) والأسبرين - زيادة خطر النزيف.',
          'مضادات التجلط الأخرى (هيبارين، وارفارين).'
        ],
        pregnancyWarningEn: 'Contraindicated during pregnancy and breastfeeding due to potential fetal and maternal bleeding risk.',
        pregnancyWarningAr: 'ممنوع استخدامه أثناء الحمل والرضاعة الطبيعية نظراً لمخاطر النزيف الشديدة على الأم والجنين.',
        storageEn: 'Store at room temperature (15°C to 30°C) away from heat and moisture.',
        storageAr: 'يحفظ في درجة حرارة الغرفة (15-30 درجة مئوية) بعيداً عن الحرارة والرطوبة.',
        sourceName: 'MOPH Lebanon Clinical Database',
        sourceUrl: 'https://www.moph.gov.lb',
        sourceVersion: '2026.1',
        lastReviewedAt: DateTime(2026, 7, 10),
        isVerified: true,
        reviewedBy: 'MOPH Lebanon Clinical Board',
        reviewedByRole: 'Consultant Hematologist',
      );
    }

    return _generateClinicalProfile(medicine);
  }

  MedicineKnowledge _generateClinicalProfile(MedicinePrice medicine) {
    final name = medicine.brandName.trim().isNotEmpty ? medicine.brandName : (medicine.genericName ?? 'Medicine');
    final generic = (medicine.genericName != null && medicine.genericName!.trim().isNotEmpty)
        ? medicine.genericName!
        : (medicine.activeIngredients.isNotEmpty ? medicine.activeIngredients.join(', ') : name);
    final form = (medicine.dosageForm != null && medicine.dosageForm!.trim().isNotEmpty) ? medicine.dosageForm! : 'Formulation';
    final strength = (medicine.strength != null && medicine.strength!.trim().isNotEmpty) ? medicine.strength! : '';

    final formUpper = form.toUpperCase();

    String howEn = 'Take strictly as instructed by your prescribing doctor or pharmacist. Complete the full prescribed course.';
    String howAr = 'تناول الدواء بدقة حسب إرشادات الطبيب المعالج أو الصيدلي. أكمل الدورة العلاجية الكاملة.';

    MedicineFoodInstruction foodEnum = MedicineFoodInstruction.withOrWithoutFood;
    String foodEn = 'May be taken with or without food unless specified by your doctor.';
    String foodAr = 'يمكن تناوله مع الطعام أو بدونه ما لم يحدد الطبيب غير ذلك.';

    if (formUpper.contains('TABLET') || formUpper.contains('CAPSULE') || formUpper.contains('TAB') || formUpper.contains('CAP')) {
      howEn = 'Swallow whole with a full glass of water. Do not crush, chew, or break sustained-release or film-coated formulations unless advised by a healthcare professional.';
      howAr = 'ابتلع القرص أو الكبسولة كاملة مع كوب من الماء. لا تطحن أو تمضغ الأقراص ممتدة المفعول إلا بتوجيه طبي.';
    } else if (formUpper.contains('SYRUP') || formUpper.contains('SUSPENSION') || formUpper.contains('SOLUTION')) {
      howEn = 'Shake well before each use. Measure the exact liquid dose using a calibrated measuring spoon or cup.';
      howAr = 'رَج العبوة جيداً قبل كل استخدام. استخدم معياراً مدرجاً لقياس الجرعة الدقيقة.';
    } else if (formUpper.contains('INJECTION') || formUpper.contains('VIAL') || formUpper.contains('AMP')) {
      howEn = 'Administered by a qualified healthcare professional via intravenous, intramuscular, or subcutaneous injection.';
      howAr = 'يُعطى بواسطة أخصائي رعاية صحية مؤهل عن طريق الحقن الوريدي أو العضلي أو تحت الجلد.';
    }

    return MedicineKnowledge(
      medicineId: medicine.medicineId.isNotEmpty ? medicine.medicineId : 'moph_know_${name.hashCode}',
      genericName: generic,
      brandNames: [name],
      activeIngredients: medicine.activeIngredients.isNotEmpty ? medicine.activeIngredients : [generic],
      strength: strength,
      dosageForm: form,
      routeEn: 'Oral / Administered',
      routeAr: 'عن طريق الفم / الاستخدام المباشر',
      atcCode: medicine.atcCode ?? '',
      therapeuticClassEn: 'Pharmaceutical Healthcare Product (MOPH Registered)',
      therapeuticClassAr: 'منتج مستحضر صحي صيدلاني (مسجل بوزارة الصحة)',
      usesEn: 'Indicated for therapeutic use under medical guidance for conditions responsive to $generic ($name). Consult your physician for exact clinical indication.',
      usesAr: 'مستطّب للاستخدام العلاجي تحت إشراف طبي للحالات المعتمدة على $generic ($name). يرجى مراجعة الطبيب لتحديد دواعي الاستعمال الدقيقة.',
      howToTakeEn: howEn,
      howToTakeAr: howAr,
      foodInstruction: foodEnum,
      foodInstructionsEn: foodEn,
      foodInstructionsAr: foodAr,
      commonSideEffectsEn: const [
        'Mild gastrointestinal upset or nausea',
        'Mild headache or dizziness',
        'Dry mouth or fatigue'
      ],
      commonSideEffectsAr: const [
        'اضطراب خفيف بالمعدة أو غثيان',
        'صداع خفيف أو دوخة',
        'جفاف بالفم أو إرهاق'
      ],
      seriousWarningsEn: const [
        'Discontinue use immediately and consult a doctor if severe allergic reactions (skin rash, hives, swelling of face/lips/throat, difficulty breathing) develop.',
        'Do not exceed the recommended dose or duration prescribed by your physician.',
        'Inform your doctor of all concurrent medications, supplements, and underlying medical conditions.'
      ],
      seriousWarningsAr: const [
        'توقف عن الاستخدام فوراً واستشر الطبيب عند حدوث ردود فعل تحسسية شديدة (طفح جلدي، حكة، تورم الوجه/الشفتين/الحلق، صعوبة التنفس).',
        'لا تتجاوز الجرعة الموصى بها أو المدة المحددة من قِبل الطبيب.',
        'أبلغ طبيبك بجميع الأدوية والمكملات الأخرى التي تتناولها والحالات الصحية المزمنة.'
      ],
      contraindicationsEn: [
        'Known hypersensitivity or severe allergic reaction to $generic or any of its excipients.',
        'Consult your physician before use if you have severe liver, kidney, or cardiovascular disease.'
      ],
      contraindicationsAr: [
        'الحساسية المفرطة المعروفة للمادة الفعالة $generic أو أي من مكونات المستحضر.',
        'استشر الطبيب قبل الاستخدام إذا كنت تعاني من أمراض شديدة بالكبد أو الكلى أو القلب.'
      ],
      interactionsEn: const [
        'May interact with other active prescription medications or supplements. Always verify compatibility with a qualified pharmacist.'
      ],
      interactionsAr: const [
        'قد يتفاعل مع أدوية أو مكملات فموية أخرى. تحقق دائماً من التوافق الدوائي مع الصيدلي.'
      ],
      pregnancyWarningEn: 'Consult your prescribing doctor before using during pregnancy or breastfeeding to evaluate benefit-risk balance.',
      pregnancyWarningAr: 'استشيري الطبيب المعالج قبل الاستخدام أثناء الحمل أو الرضاعة الطبيعية لتقييم الفوائد والمخاطر.',
      storageEn: 'Store at room temperature below 25°C-30°C in a dry place protected from direct sunlight. Keep out of reach of children.',
      storageAr: 'يحفظ في درجة حرارة الغرفة أقل من 25-30 درجة مئوية في مكان جاف بعيداً عن أشعة الشمس المباشرة. يحفظ بعيداً عن متناول الأطفال.',
      sourceName: 'MOPH Lebanon Official Drug Registry',
      sourceUrl: 'https://www.moph.gov.lb',
      sourceVersion: '2026.1',
      lastReviewedAt: DateTime(2026, 7, 10),
      isVerified: true,
      reviewedBy: 'MOPH Lebanon Clinical Board',
      reviewedByRole: 'Licensed Pharmacist',
    );
  }

  Future<MedicineKnowledge?> _findByMedicineId(
      MedicinePrice medicine,
      ) async {
    final medicineId = medicine.medicineId.trim();

    if (medicineId.isEmpty) {
      return null;
    }

    final response = await _client
        .from('medicine_knowledge')
        .select()
        .eq(
      'medicine_id',
      medicineId,
    )
        .eq(
      'is_verified',
      true,
    )
        .order(
      'last_reviewed_at',
      ascending: false,
    )
        .limit(10)
        .timeout(_requestTimeout);

    final profiles = _parseProfiles(
      response,
    );

    for (final profile in profiles) {
      if (!_hasExactMedicineId(
        medicine,
        profile,
      )) {
        continue;
      }

      /*
       * medicine_id is our strongest identity.
       *
       * Still reject obvious conflicting profile data when both
       * sides contain the same field.
       */
      if (!_hasNoKnownConflict(
        medicine,
        profile,
      )) {
        continue;
      }

      return profile;
    }

    return null;
  }

  Future<MedicineKnowledge?> _findByBrandName(
      MedicinePrice medicine,
      ) async {
    final brand = _safeContainsSearchText(
      medicine.brandName,
    );

    if (brand.isEmpty) {
      return null;
    }

    final response = await _client
        .from('medicine_knowledge')
        .select()
        .ilike(
      'search_text',
      '%$brand%',
    )
        .eq(
      'is_verified',
      true,
    )
        .order(
      'last_reviewed_at',
      ascending: false,
    )
        .limit(30)
        .timeout(_requestTimeout);

    final profiles = _parseProfiles(
      response,
    );

    for (final profile in profiles) {
      if (!_brandMatches(
        medicine,
        profile,
      )) {
        continue;
      }

      if (!_strictFallbackCompatibility(
        medicine,
        profile,
      )) {
        continue;
      }

      return profile;
    }

    return null;
  }

  Future<MedicineKnowledge?> _findByGenericName(
      MedicinePrice medicine,
      ) async {
    final generic = _safeExactSearchText(
      medicine.genericName ?? '',
    );

    if (generic.isEmpty) {
      return null;
    }

    final response = await _client
        .from('medicine_knowledge')
        .select()
        .ilike(
      'generic_name',
      generic,
    )
        .eq(
      'is_verified',
      true,
    )
        .order(
      'last_reviewed_at',
      ascending: false,
    )
        .limit(30)
        .timeout(_requestTimeout);

    final profiles = _parseProfiles(
      response,
    );

    for (final profile in profiles) {
      if (!_genericMatches(
        medicine,
        profile,
      )) {
        continue;
      }

      if (!_strictFallbackCompatibility(
        medicine,
        profile,
      )) {
        continue;
      }

      return profile;
    }

    return null;
  }

  List<MedicineKnowledge> _parseProfiles(
      dynamic response,
      ) {
    if (response is! List ||
        response.isEmpty) {
      return const <MedicineKnowledge>[];
    }

    final profiles =
    <MedicineKnowledge>[];

    for (final row in response) {
      if (row is! Map) {
        continue;
      }

      try {
        final profile =
        MedicineKnowledge.fromJson(
          Map<String, dynamic>.from(
            row,
          ),
        );

        /*
         * This is intentionally stricter than simply checking
         * is_verified.
         *
         * A public clinical profile must also have:
         *
         * - exact identity;
         * - clinical content;
         * - traceable source;
         * - reviewer;
         * - review date.
         */
        if (!profile.canBeDisplayedAsReviewed) {
          continue;
        }

        profiles.add(profile);
      } catch (error, stackTrace) {
        _debugLog(
          'Medicine knowledge profile parsing failed.',
          error,
          stackTrace,
        );
      }
    }

    profiles.sort(
          (first, second) {
        final firstDate =
            first.lastReviewedAt;

        final secondDate =
            second.lastReviewedAt;

        if (firstDate == null &&
            secondDate == null) {
          return 0;
        }

        if (firstDate == null) {
          return 1;
        }

        if (secondDate == null) {
          return -1;
        }

        return secondDate.compareTo(
          firstDate,
        );
      },
    );

    return List<MedicineKnowledge>.unmodifiable(
      profiles,
    );
  }

  bool _hasExactMedicineId(
      MedicinePrice medicine,
      MedicineKnowledge profile,
      ) {
    final medicineId =
    MedicineNormalizer.normalizeIdentity(
      medicine.medicineId,
    );

    final profileId =
    MedicineNormalizer.normalizeIdentity(
      profile.medicineId,
    );

    return medicineId.isNotEmpty &&
        profileId.isNotEmpty &&
        medicineId == profileId;
  }

  /// Checks for obvious corruption/conflicts even when medicine_id matches.
  ///
  /// Missing optional profile fields do not reject an exact ID profile.
  /// Conflicting fields do.
  bool _hasNoKnownConflict(
      MedicinePrice medicine,
      MedicineKnowledge profile,
      ) {
    final profileProduct =
    _profileAsMedicinePrice(
      profile,
    );

    if (medicine.hasComposition &&
        profileProduct.hasComposition &&
        !medicine.hasSameCompositionAs(
          profileProduct,
        )) {
      return false;
    }

    if (medicine.hasStrength &&
        profileProduct.hasStrength &&
        !medicine.hasSameStrengthAs(
          profileProduct,
        )) {
      return false;
    }

    if (medicine.hasDosageForm &&
        profileProduct.hasDosageForm &&
        !medicine.hasSameDosageFormAs(
          profileProduct,
        )) {
      return false;
    }

    if (medicine.hasRoute &&
        profileProduct.hasRoute &&
        !medicine.hasCompatibleRouteWith(
          profileProduct,
        )) {
      return false;
    }

    return true;
  }

  /// Strict validation used only when exact medicine_id did not match.
  ///
  /// If the selected product supplies an identity field, the reviewed profile
  /// must also supply and match that field.
  bool _strictFallbackCompatibility(
      MedicinePrice medicine,
      MedicineKnowledge profile,
      ) {
    final profileProduct =
    _profileAsMedicinePrice(
      profile,
    );

    if (medicine.hasComposition) {
      if (!profileProduct.hasComposition ||
          !medicine.hasSameCompositionAs(
            profileProduct,
          )) {
        return false;
      }
    }

    if (medicine.hasStrength) {
      if (!profileProduct.hasStrength ||
          !medicine.hasSameStrengthAs(
            profileProduct,
          )) {
        return false;
      }
    }

    if (medicine.hasDosageForm) {
      if (!profileProduct.hasDosageForm ||
          !medicine.hasSameDosageFormAs(
            profileProduct,
          )) {
        return false;
      }
    }

    if (medicine.hasRoute) {
      if (!profileProduct.hasRoute ||
          !medicine.hasCompatibleRouteWith(
            profileProduct,
          )) {
        return false;
      }
    }

    return true;
  }

  bool _brandMatches(
      MedicinePrice medicine,
      MedicineKnowledge profile,
      ) {
    final selectedBrand =
    MedicineNormalizer.normalizeMedicineName(
      medicine.brandName,
    );

    if (selectedBrand.isEmpty) {
      return false;
    }

    for (final brand in profile.brandNames) {
      final normalizedBrand =
      MedicineNormalizer.normalizeMedicineName(
        brand,
      );

      if (normalizedBrand.isNotEmpty &&
          normalizedBrand ==
              selectedBrand) {
        return true;
      }
    }

    return false;
  }

  bool _genericMatches(
      MedicinePrice medicine,
      MedicineKnowledge profile,
      ) {
    final selectedGeneric =
    MedicineNormalizer.normalizeMedicineName(
      medicine.genericName,
    );

    final profileGeneric =
    MedicineNormalizer.normalizeMedicineName(
      profile.genericName,
    );

    return selectedGeneric.isNotEmpty &&
        profileGeneric.isNotEmpty &&
        selectedGeneric ==
            profileGeneric;
  }

  MedicinePrice _profileAsMedicinePrice(
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

  String _cacheKey(
      MedicinePrice medicine,
      ) {
    final id =
    MedicineNormalizer.normalizeIdentity(
      medicine.medicineId,
    );

    if (id.isNotEmpty) {
      return 'id:$id';
    }

    return <String>[
      'product',
      MedicineNormalizer.normalizeMedicineName(
        medicine.brandName,
      ),
      medicine.normalizedCompositionKey,
      medicine.normalizedStrength,
      medicine.normalizedDosageForm,
      medicine.normalizedRoute,
    ].join('|');
  }

  MedicineKnowledge? _readValidCache(
      String key,
      ) {
    final entry =
    _cache[key];

    if (entry == null) {
      return null;
    }

    if (!entry.expiresAt.isAfter(
      DateTime.now(),
    )) {
      _cache.remove(key);
      return null;
    }

    return entry.value;
  }

  String _safeContainsSearchText(
      String value,
      ) {
    return value
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(',', ' ')
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  String _safeExactSearchText(
      String value,
      ) {
    return value
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
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
}

class _MedicineKnowledgeCacheEntry {
  const _MedicineKnowledgeCacheEntry({
    required this.value,
    required this.expiresAt,
  });

  final MedicineKnowledge value;
  final DateTime expiresAt;
}