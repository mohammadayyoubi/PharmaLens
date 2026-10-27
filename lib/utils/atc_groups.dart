/// WHO Anatomical Therapeutic Chemical (ATC) group names, levels 1 and 2.
///
/// Lets the app say what therapeutic group an MOPH product belongs to using
/// the official classification only, with no clinical claims of its own.
/// Source: WHO Collaborating Centre for Drug Statistics Methodology.
class AtcGroups {
  const AtcGroups._();

  static const String sourceUrl = 'https://atcddd.fhi.no/atc_ddd_index/';

  /// Level-2 group (e.g. "J01") or level-1 (e.g. "J") for [atcCode], or null.
  static AtcGroupName? describe(String? atcCode) {
    final code = (atcCode ?? '').trim().toUpperCase();
    if (code.length >= 3) {
      final level2 = _level2[code.substring(0, 3)];
      if (level2 != null) return AtcGroupName(code: code.substring(0, 3), en: level2.$1, ar: level2.$2);
    }
    if (code.isNotEmpty) {
      final level1 = _level1[code.substring(0, 1)];
      if (level1 != null) return AtcGroupName(code: code.substring(0, 1), en: level1.$1, ar: level1.$2);
    }
    return null;
  }

  static AtcGroupName? anatomicalGroup(String? atcCode) {
    final code = (atcCode ?? '').trim().toUpperCase();
    if (code.isEmpty) return null;
    final level1 = _level1[code.substring(0, 1)];
    return level1 == null ? null : AtcGroupName(code: code.substring(0, 1), en: level1.$1, ar: level1.$2);
  }

  static const Map<String, (String, String)> _level1 = {
    'A': ('Alimentary tract and metabolism', 'الجهاز الهضمي والاستقلاب'),
    'B': ('Blood and blood forming organs', 'الدم والأعضاء المكونة للدم'),
    'C': ('Cardiovascular system', 'القلب والأوعية الدموية'),
    'D': ('Dermatologicals', 'الأمراض الجلدية'),
    'G': ('Genito-urinary system and sex hormones', 'الجهاز البولي التناسلي والهرمونات الجنسية'),
    'H': ('Systemic hormonal preparations', 'المستحضرات الهرمونية الجهازية'),
    'J': ('Anti-infectives for systemic use', 'مضادات العدوى للاستخدام الجهازي'),
    'L': ('Antineoplastic and immunomodulating agents', 'مضادات الأورام ومعدلات المناعة'),
    'M': ('Musculo-skeletal system', 'الجهاز العضلي الهيكلي'),
    'N': ('Nervous system', 'الجهاز العصبي'),
    'P': ('Antiparasitic products, insecticides and repellents', 'مضادات الطفيليات والمبيدات والطاردات'),
    'R': ('Respiratory system', 'الجهاز التنفسي'),
    'S': ('Sensory organs', 'أعضاء الحس'),
    'V': ('Various', 'متفرقات'),
  };

  static const Map<String, (String, String)> _level2 = {
    'A01': ('Stomatological preparations', 'مستحضرات الفم والأسنان'),
    'A02': ('Drugs for acid related disorders', 'أدوية اضطرابات الحموضة'),
    'A03': ('Drugs for functional gastrointestinal disorders', 'أدوية الاضطرابات الهضمية الوظيفية'),
    'A04': ('Antiemetics and antinauseants', 'مضادات القيء والغثيان'),
    'A05': ('Bile and liver therapy', 'علاجات الصفراء والكبد'),
    'A06': ('Drugs for constipation', 'أدوية الإمساك'),
    'A07': ('Antidiarrheals, intestinal anti-inflammatory and anti-infective agents', 'مضادات الإسهال ومضادات الالتهاب والعدوى المعوية'),
    'A08': ('Antiobesity preparations', 'مستحضرات علاج السمنة'),
    'A09': ('Digestives, including enzymes', 'مساعدات الهضم والإنزيمات'),
    'A10': ('Drugs used in diabetes', 'أدوية السكري'),
    'A11': ('Vitamins', 'الفيتامينات'),
    'A12': ('Mineral supplements', 'المكملات المعدنية'),
    'A13': ('Tonics', 'المقويات'),
    'A14': ('Anabolic agents for systemic use', 'العوامل البنائية الجهازية'),
    'A15': ('Appetite stimulants', 'فاتحات الشهية'),
    'A16': ('Other alimentary tract and metabolism products', 'منتجات أخرى للجهاز الهضمي والاستقلاب'),
    'B01': ('Antithrombotic agents', 'مضادات التخثر'),
    'B02': ('Antihemorrhagics', 'مضادات النزيف'),
    'B03': ('Antianemic preparations', 'مستحضرات علاج فقر الدم'),
    'B05': ('Blood substitutes and perfusion solutions', 'بدائل الدم ومحاليل التسريب'),
    'B06': ('Other hematological agents', 'عوامل دموية أخرى'),
    'C01': ('Cardiac therapy', 'علاجات القلب'),
    'C02': ('Antihypertensives', 'خافضات ضغط الدم'),
    'C03': ('Diuretics', 'مدرات البول'),
    'C04': ('Peripheral vasodilators', 'موسعات الأوعية المحيطية'),
    'C05': ('Vasoprotectives', 'واقيات الأوعية'),
    'C07': ('Beta blocking agents', 'حاصرات بيتا'),
    'C08': ('Calcium channel blockers', 'حاصرات قنوات الكالسيوم'),
    'C09': ('Agents acting on the renin-angiotensin system', 'أدوية نظام الرينين-أنجيوتنسين'),
    'C10': ('Lipid modifying agents', 'أدوية تعديل الدهون'),
    'D01': ('Antifungals for dermatological use', 'مضادات الفطريات الجلدية'),
    'D02': ('Emollients and protectives', 'المطريات والواقيات الجلدية'),
    'D03': ('Preparations for treatment of wounds and ulcers', 'مستحضرات علاج الجروح والقرح'),
    'D04': ('Antipruritics', 'مضادات الحكة'),
    'D05': ('Antipsoriatics', 'أدوية الصدفية'),
    'D06': ('Antibiotics and chemotherapeutics for dermatological use', 'المضادات الحيوية الجلدية'),
    'D07': ('Corticosteroids, dermatological preparations', 'الكورتيكوستيرويدات الجلدية'),
    'D08': ('Antiseptics and disinfectants', 'المطهرات'),
    'D09': ('Medicated dressings', 'الضمادات الدوائية'),
    'D10': ('Anti-acne preparations', 'مستحضرات حب الشباب'),
    'D11': ('Other dermatological preparations', 'مستحضرات جلدية أخرى'),
    'G01': ('Gynecological anti-infectives and antiseptics', 'مضادات العدوى والمطهرات النسائية'),
    'G02': ('Other gynecologicals', 'مستحضرات نسائية أخرى'),
    'G03': ('Sex hormones and modulators of the genital system', 'الهرمونات الجنسية ومعدلات الجهاز التناسلي'),
    'G04': ('Urologicals', 'أدوية المسالك البولية'),
    'H01': ('Pituitary and hypothalamic hormones and analogues', 'هرمونات الغدة النخامية وتحت المهاد'),
    'H02': ('Corticosteroids for systemic use', 'الكورتيكوستيرويدات الجهازية'),
    'H03': ('Thyroid therapy', 'علاجات الغدة الدرقية'),
    'H04': ('Pancreatic hormones', 'هرمونات البنكرياس'),
    'H05': ('Calcium homeostasis', 'توازن الكالسيوم'),
    'J01': ('Antibacterials for systemic use', 'المضادات الحيوية للاستخدام الجهازي'),
    'J02': ('Antimycotics for systemic use', 'مضادات الفطريات الجهازية'),
    'J04': ('Antimycobacterials', 'مضادات المتفطرات'),
    'J05': ('Antivirals for systemic use', 'مضادات الفيروسات الجهازية'),
    'J06': ('Immune sera and immunoglobulins', 'الأمصال والغلوبولينات المناعية'),
    'J07': ('Vaccines', 'اللقاحات'),
    'L01': ('Antineoplastic agents', 'الأدوية المضادة للأورام'),
    'L02': ('Endocrine therapy', 'العلاج الهرموني'),
    'L03': ('Immunostimulants', 'منشطات المناعة'),
    'L04': ('Immunosuppressants', 'مثبطات المناعة'),
    'M01': ('Anti-inflammatory and antirheumatic products', 'مضادات الالتهاب والروماتيزم'),
    'M02': ('Topical products for joint and muscular pain', 'مستحضرات موضعية لآلام المفاصل والعضلات'),
    'M03': ('Muscle relaxants', 'مرخيات العضلات'),
    'M04': ('Antigout preparations', 'أدوية النقرس'),
    'M05': ('Drugs for treatment of bone diseases', 'أدوية أمراض العظام'),
    'M09': ('Other drugs for disorders of the musculo-skeletal system', 'أدوية أخرى للجهاز العضلي الهيكلي'),
    'N01': ('Anesthetics', 'أدوية التخدير'),
    'N02': ('Analgesics', 'المسكنات'),
    'N03': ('Antiepileptics', 'مضادات الصرع'),
    'N04': ('Anti-parkinson drugs', 'أدوية باركنسون'),
    'N05': ('Psycholeptics', 'المهدئات النفسية'),
    'N06': ('Psychoanaleptics', 'المنشطات النفسية'),
    'N07': ('Other nervous system drugs', 'أدوية أخرى للجهاز العصبي'),
    'P01': ('Antiprotozoals', 'مضادات الأوالي'),
    'P02': ('Anthelmintics', 'طاردات الديدان'),
    'P03': ('Ectoparasiticides, including scabicides, insecticides and repellents', 'مضادات الطفيليات الخارجية'),
    'R01': ('Nasal preparations', 'مستحضرات الأنف'),
    'R02': ('Throat preparations', 'مستحضرات الحلق'),
    'R03': ('Drugs for obstructive airway diseases', 'أدوية أمراض انسداد المجاري التنفسية'),
    'R05': ('Cough and cold preparations', 'أدوية السعال والزكام'),
    'R06': ('Antihistamines for systemic use', 'مضادات الهيستامين الجهازية'),
    'R07': ('Other respiratory system products', 'منتجات أخرى للجهاز التنفسي'),
    'S01': ('Ophthalmologicals', 'مستحضرات العين'),
    'S02': ('Otologicals', 'مستحضرات الأذن'),
    'S03': ('Ophthalmological and otological preparations', 'مستحضرات العين والأذن'),
    'V01': ('Allergens', 'مسببات الحساسية'),
    'V03': ('All other therapeutic products', 'منتجات علاجية أخرى'),
    'V04': ('Diagnostic agents', 'عوامل تشخيصية'),
    'V06': ('General nutrients', 'المغذيات العامة'),
    'V07': ('All other non-therapeutic products', 'منتجات أخرى غير علاجية'),
    'V08': ('Contrast media', 'مواد التباين'),
    'V09': ('Diagnostic radiopharmaceuticals', 'مستحضرات مشعة تشخيصية'),
    'V10': ('Therapeutic radiopharmaceuticals', 'مستحضرات مشعة علاجية'),
    'V20': ('Surgical dressings', 'الضمادات الجراحية'),
  };
}

class AtcGroupName {
  const AtcGroupName({required this.code, required this.en, required this.ar});

  final String code;
  final String en;
  final String ar;

  String localized({required bool isArabic}) => isArabic ? ar : en;
}
