class MedicalDomainGuardDecision {
  final bool allowed;
  final String reason;
  final String userMessage;

  const MedicalDomainGuardDecision({
    required this.allowed,
    required this.reason,
    required this.userMessage,
  });
}

class MedicalDomainGuardService {
  const MedicalDomainGuardService();

  MedicalDomainGuardDecision evaluateText({
    required String input,
    required String responseLanguage,
    bool hasAttachedImage = false,
    bool catalogMatchFound = false,
  }) {
    if (hasAttachedImage) {
      return const MedicalDomainGuardDecision(
        allowed: true,
        reason: 'attached_medical_image',
        userMessage: '',
      );
    }

    final normalized = _normalize(input);

    if (normalized.isEmpty) {
      return MedicalDomainGuardDecision(
        allowed: false,
        reason: 'empty_input',
        userMessage: _refusal(responseLanguage),
      );
    }

    if (_containsAny(normalized, _dangerousMedicalActions)) {
      return MedicalDomainGuardDecision(
        allowed: false,
        reason: 'unsafe_medical_action',
        userMessage: _unsafeMedicalRefusal(responseLanguage),
      );
    }

    // Explicit non-medical topic rejection (e.g. "what is javascript and python", sports, politics, etc.)
    if (_containsAny(normalized, _blockedTopics) &&
        !_containsAny(normalized, _medicalTerms) &&
        !catalogMatchFound) {
      return MedicalDomainGuardDecision(
        allowed: false,
        reason: 'outside_medical_scope',
        userMessage: _refusal(responseLanguage),
      );
    }

    if (catalogMatchFound || _containsAny(normalized, _medicalTerms)) {
      return const MedicalDomainGuardDecision(
        allowed: true,
        reason: 'medical_or_pharmacy_scope',
        userMessage: '',
      );
    }

    if (_containsAny(normalized, _greetings)) {
      return const MedicalDomainGuardDecision(
        allowed: true,
        reason: 'greeting',
        userMessage: '',
      );
    }

    return MedicalDomainGuardDecision(
      allowed: false,
      reason: 'unclear_scope',
      userMessage: _refusal(responseLanguage),
    );
  }

  bool isAllowedMedicalText(String input) {
    return evaluateText(input: input, responseLanguage: 'English').allowed;
  }

  String refusalMessage(String responseLanguage) {
    return _refusal(responseLanguage);
  }

  static const List<String> _greetings = [
    'hello',
    'hi',
    'hey',
    'greetings',
    'good morning',
    'good afternoon',
    'good evening',
    'how are you',
    'who are you',
    'what can you do',
    'how can you help',
    'help me',
    'مرحبا',
    'اهلين',
    'اهلا',
    'أهلا',
    'سلام',
    'السلام عليكم',
    'صباح الخير',
    'مساء الخير',
    'كيفك',
    'من انت',
    'مين انت',
    'شو بتعمل',
    'كيف بتساعدني',
    'مساعدة',
  ];

  static const List<String> _medicalTerms = [
    // Forms & delivery
    'medicine',
    'medication',
    'drug',
    'drugs',
    'pill',
    'pills',
    'dose',
    'dosage',
    'tablet',
    'tablets',
    'capsule',
    'capsules',
    'syrup',
    'injection',
    'injections',
    'ampoule',
    'vial',
    'cream',
    'ointment',
    'drops',
    'eye drops',
    'ear drops',
    'suppository',
    'spray',
    'inhaler',
    'patch',
    'solution',
    'suspension',
    'route',
    'prescription',
    'prescriptions',
    'rx',
    'otc',

    // Healthcare roles & facilities
    'pharmacy',
    'pharmacies',
    'pharmacist',
    'chemist',
    'doctor',
    'doctors',
    'physician',
    'nurse',
    'patient',
    'hospital',
    'hospitals',
    'clinic',
    'clinics',
    'dispensary',
    'moph',
    'tariff',

    // Clinical queries & pharmacology
    'side effect',
    'side effects',
    'adverse effect',
    'adverse effects',
    'contraindication',
    'contraindications',
    'interaction',
    'interactions',
    'warning',
    'warnings',
    'indication',
    'indications',
    'usage',
    'how to use',
    'how to take',
    'substitute',
    'generic',
    'alternative',
    'alternatives',
    'equivalent',
    'price',
    'cost',
    'how much',
    'price lbp',
    'brand',
    'active ingredient',
    'composition',
    'strength',
    'mg',
    'mcg',
    'ml',

    // Symptoms, conditions, & anatomy
    'headache',
    'migraine',
    'fever',
    'temperature',
    'cough',
    'coughing',
    'flu',
    'cold',
    'influenza',
    'sore throat',
    'pain',
    'painkiller',
    'analgesic',
    'anti inflammatory',
    'nsaid',
    'antibiotic',
    'infection',
    'allergy',
    'allergic',
    'antihistamine',
    'rash',
    'itch',
    'itching',
    'stomach',
    'stomachache',
    'nausea',
    'vomit',
    'vomiting',
    'diarrhea',
    'constipation',
    'reflux',
    'heartburn',
    'gerd',
    'ulcer',
    'cramp',
    'cramps',
    'dizziness',
    'vertigo',
    'insomnia',
    'sleep',
    'fatigue',
    'asthma',
    'bronchitis',
    'hypertension',
    'blood pressure',
    'hypotension',
    'diabetes',
    'blood sugar',
    'glucose',
    'insulin',
    'cholesterol',
    'triglycerides',
    'thyroid',
    'kidney',
    'renal',
    'liver',
    'hepatic',
    'heart',
    'cardiac',
    'pregnancy',
    'pregnant',
    'breastfeeding',
    'lactation',
    'pediatric',
    'child',
    'infant',
    'baby',
    'elderly',

    // Common brand & generic names in Lebanon / International
    'paracetamol',
    'acetaminophen',
    'panadol',
    'adol',
    'paramol',
    'ibuprofen',
    'advil',
    'brufen',
    'profid',
    'diclofenac',
    'voltaren',
    'cataflam',
    'aspirin',
    'amoxicillin',
    'augmentin',
    'curam',
    'klamentin',
    'azithromycin',
    'zithromax',
    'ciprofloxacin',
    'cipro',
    'metronidazole',
    'flagyl',
    'omeprazole',
    'losec',
    'nexium',
    'esomeprazole',
    'pantoprazole',
    'controloc',
    'concor',
    'bisoprolol',
    'lipitor',
    'atorvastatin',
    'crestor',
    'rosuvastatin',
    'metformin',
    'glucophage',
    'lasix',
    'furosemide',
    'ventolin',
    'salbutamol',
    'claritin',
    'loratadine',
    'zyrtec',
    'cetirizine',
    'aerius',
    'desloratadine',
    'solupred',
    'prednisolone',
    'decadron',
    'dexamethasone',
    'lexotanil',
    'bromazepam',
    'xanax',
    'alprazolam',
    'stilnox',
    'warfarin',

    // Arabic Medical terms
    'صيدلية',
    'صيدليات',
    'صيدلي',
    'صيدلاني',
    'طبيب',
    'اطباء',
    'دكتور',
    'حكيم',
    'ممرض',
    'مريض',
    'مرضى',
    'مستشفى',
    'مشفى',
    'عيادة',
    'وزارة الصحة',
    'دواء',
    'ادوية',
    'أدوية',
    'علاج',
    'علاجات',
    'جرعة',
    'جرعات',
    'حبوب',
    'حبه',
    'حبة',
    'كبسولة',
    'كبسولات',
    'شراب',
    'حقنة',
    'حقن',
    'ابرة',
    'إبرة',
    'قطرة',
    'قطرات',
    'مرهم',
    'كريم',
    'تحاميل',
    'تحميلة',
    'بخاخ',
    'وصفة',
    'روشتة',
    'سعر',
    'اسعار',
    'أسعار',
    'كم سعر',
    'بكم',
    'تكلفة',
    'بديل',
    'بدائل',
    'جنريك',
    'اعراض جانبية',
    'أعراض جانبية',
    'تاثيرات',
    'تأثيرات',
    'مضاعفات',
    'تداخلات',
    'تفاعل',
    'موانع استعمال',
    'محاذير',
    'طريقة الاستعمال',
    'كيفية الاستخدام',
    'صداع',
    'وجع راس',
    'وجع',
    'الم',
    'ألم',
    'حرارة',
    'سخونة',
    'حمى',
    'سعلة',
    'سعال',
    'بلغم',
    'رشح',
    'كريب',
    'انفلونزا',
    'زكام',
    'التهاب حلق',
    'حلق',
    'مغص',
    'وجع بطن',
    'غثيان',
    'لعيان',
    'استفراغ',
    'ترجيع',
    'تقيؤ',
    'اسهال',
    'إسهال',
    'امساك',
    'إمساك',
    'حموضة',
    'حرقة',
    'معدة',
    'قرحة',
    'دوخة',
    'دوار',
    'حساسية',
    'طفح',
    'حكة',
    'ربو',
    'ضيق تنفس',
    'ضغط',
    'ضغط دم',
    'سكري',
    'سكر',
    'انسولين',
    'كولسترول',
    'دهون',
    'كلى',
    'كبد',
    'قلب',
    'حمل',
    'حامل',
    'رضاعة',
    'مرضع',
    'اطفال',
    'طفل',
    'رضيع',
    'مضاد حيوي',
    'مسكن',
    'خافض حرارة',
    'باراسيتامول',
    'بنادول',
    'ادول',
    'بارامول',
    'بروفين',
    'ايبوبروفين',
    'ادفيل',
    'ديكلوفيناك',
    'فولتارين',
    'كاتافلام',
    'اسبرين',
    'اموكسيسيلين',
    'اوغمنتين',
    'كورام',
    'ازيثروميسين',
    'زيثروماكس',
    'فلاجيل',
    'اوميبرازول',
    'كونكور',
    'ليبيتور',
    'كريستور',
    'فنتولين',
  ];

  static const List<String> _blockedTopics = [
    // Programming & computer science
    'python',
    'javascript',
    'js',
    'typescript',
    'ts',
    'java',
    'c++',
    'cpp',
    'c#',
    'csharp',
    'golang',
    'rust',
    'php',
    'ruby',
    'swift',
    'kotlin',
    'html',
    'css',
    'sql',
    'nosql',
    'coding',
    'code',
    'programmer',
    'programming',
    'developer',
    'software',
    'flutter',
    'dart',
    'react',
    'angular',
    'vue',
    'node',
    'express',
    'django',
    'fastapi',
    'flask',
    'github',
    'git',
    'algorithm',
    'algorithms',
    'data structures',
    'backend',
    'frontend',
    'fullstack',
    'hack',
    'hacking',
    'cybersecurity',
    'linux',
    'ubuntu',
    'windows os',
    'terminal',
    'powershell',
    'chatgpt',
    'openai',
    'gemini model',
    'llm',

    // Sports & Entertainment
    'football',
    'soccer',
    'basketball',
    'fifa',
    'messi',
    'ronaldo',
    'real madrid',
    'barcelona',
    'champions league',
    'premier league',
    'world cup',
    'nba',
    'sports',
    'movie',
    'movies',
    'hollywood',
    'actor',
    'actress',
    'cinema',
    'music',
    'song',
    'songs',
    'album',
    'singer',
    'spotify',
    'game',
    'games',
    'gaming',
    'playstation',
    'xbox',
    'nintendo',
    'fortnite',
    'minecraft',

    // Politics & Finance
    'politics',
    'politician',
    'election',
    'parliament',
    'president',
    'minister',
    'crypto',
    'cryptocurrency',
    'bitcoin',
    'btc',
    'ethereum',
    'eth',
    'stock',
    'stocks',
    'shares',
    'nasdaq',
    'wall street',
    'forex',
    'trading',

    // Dating & Miscellaneous non-medical
    'dating',
    'tinder',
    'relationship',
    'girlfriend',
    'boyfriend',
    'love',
    'write cv',
    'job application',
    'resume',

    // Arabic non-medical terms
    'بايثون',
    'جافاسكريبت',
    'جافا',
    'برمجة',
    'كود',
    'مطور',
    'تطوير موقع',
    'رياكت',
    'فلاتر',
    'لغات البرمجة',
    'هاك',
    'اختراق',
    'امن سيبراني',
    'كرة قدم',
    'كرة السلة',
    'ميسي',
    'رونالدو',
    'ريال مدريد',
    'برشلونة',
    'كأس العالم',
    'رياضة',
    'فيلم',
    'افلام',
    'أفلام',
    'مسلسل',
    'ممثل',
    'سينما',
    'اغنية',
    'أغنية',
    'موسيقى',
    'لعبة',
    'العاب',
    'ألعاب',
    'بلايستيشن',
    'سياسة',
    'انتخابات',
    'رئيس',
    'وزير',
    'برلمان',
    'كريبتو',
    'عملات رقمية',
    'بيتكوين',
    'اسهم',
    'أسهم',
    'بورصة',
    'فوركس',
    'تداول',
    'حب',
    'علاقة',
    'غرام',
    'وظيفة',
    'سيرة ذاتية',
  ];

  static const List<String> _dangerousMedicalActions = [
    'increase my dose',
    'decrease my dose',
    'stop my medicine',
    'replace my medicine',
    'prescribe me',
    'give me antibiotic',
    'what should i take',
    'which medicine should i take',
    'what drug should i take',
    'what should i take for chest pain',
    'overdose',
    'suicide',
    'kill myself',
    'زود الجرعة',
    'زيد الجرعة',
    'خفف الجرعة',
    'وقف الدواء',
    'اوقف الدواء',
    'بدل الدواء',
    'غير الدواء',
    'اعطيني مضاد',
    'اكتبلي دواء',
    'شو اخد',
    'شو آخد',
    'شو اخذ',
    'ماذا اخذ',
    'اي دواء اخد',
    'جرعة قاتلة',
    'انتحار',
  ];

  static bool _containsAny(String text, List<String> values) {
    final normText = _normalize(text);
    if (normText.isEmpty) return false;
    final paddedText = ' $normText ';
    final tokens = normText.split(' ');

    for (final value in values) {
      final normVal = _normalize(value);
      if (normVal.isEmpty) continue;

      // Multi-word phrase matching with space boundaries
      if (normVal.contains(' ')) {
        if (paddedText.contains(' $normVal ')) {
          return true;
        }
        continue;
      }

      // Single-word matching with token boundaries and Arabic prefix handling
      for (final token in tokens) {
        if (token == normVal) return true;

        // Common Arabic prefixes: 'ال' (the), 'و' (and), 'وال' (and the), 'ب' (with), 'بال' (with the), 'لل' (for the)
        if (token.startsWith('ال') && token.substring(2) == normVal) return true;
        if (token.startsWith('وال') && token.substring(3) == normVal) return true;
        if (token.startsWith('و') && token.substring(1) == normVal) return true;
        if (token.startsWith('بال') && token.substring(3) == normVal) return true;
        if (token.startsWith('لل') && token.substring(2) == normVal) return true;
      }
    }

    return false;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u0652\u061F\u060C\u061B\u06D4؟،؛]'), ' ')
        .replaceAll(RegExp(r'[إأآا]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _refusal(String responseLanguage) {
    return responseLanguage.toLowerCase() == 'arabic'
        ? 'أنا PharmaLens، مساعد ذكي مخصص حصريًا للرعاية الصحية، الأدوية، والوصفات الطبية. يمكنني مساعدتك بمعلومات الأدوية، الجرعات والتحذيرات، الأسعار الرسمية والبدائل، وإرشادات الوصفات. لا يمكنني الإجابة على أسئلة خارج المجال الطبي أو الصيدلي (مثل البرمجة أو المواضيع العامة).'
        : 'I am PharmaLens, an AI assistant dedicated exclusively to healthcare, pharmaceuticals, and prescriptions. I can help with medicine information, usage instructions, side effects, official prices, generic alternatives, and prescription verification. I cannot answer questions outside the medical or pharmacy scope (such as programming, coding, or general trivia).';
  }

  static String _unsafeMedicalRefusal(String responseLanguage) {
    return responseLanguage.toLowerCase() == 'arabic'
        ? 'لا أستطيع تغيير جرعة، إيقاف دواء، أو وصف علاج جديد. راجع طبيبًا أو صيدليًا، وفي الحالات الخطيرة أو الطارئة اتصل بالطوارئ فورًا.'
        : 'I cannot change a dose, stop a medicine, or prescribe a new treatment. Please consult a qualified doctor or pharmacist, and for urgent symptoms contact emergency services immediately.';
  }
}
