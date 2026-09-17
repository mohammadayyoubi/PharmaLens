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
  }) {
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

    if (_containsAny(normalized, _blockedTopics) &&
        !_containsAny(normalized, _medicalTerms)) {
      return MedicalDomainGuardDecision(
        allowed: false,
        reason: 'outside_medical_scope',
        userMessage: _refusal(responseLanguage),
      );
    }

    if (_containsAny(normalized, _medicalTerms)) {
      return const MedicalDomainGuardDecision(
        allowed: true,
        reason: 'medical_or_pharmacy_scope',
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

  static const List<String> _medicalTerms = [
    'medicine',
    'medication',
    'drug',
    'dose',
    'dosage',
    'tablet',
    'capsule',
    'syrup',
    'injection',
    'ampoule',
    'vial',
    'cream',
    'ointment',
    'drops',
    'eye drops',
    'ear drops',
    'suppository',
    'oral',
    'iv',
    'im',
    'route',
    'prescription',
    'rx',
    'otc',
    'pharmacy',
    'pharmacist',
    'doctor',
    'patient',
    'allergy',
    'pregnancy',
    'breastfeeding',
    'diabetes',
    'blood pressure',
    'hypertension',
    'side effect',
    'contraindication',
    'interaction',
    'antibiotic',
    'analgesic',
    'painkiller',
    'anti inflammatory',
    'nsaid',
    'insulin',
    'warfarin',
    'paracetamol',
    'acetaminophen',
    'ibuprofen',
    'diclofenac',
    'amoxicillin',
    'صيدلية',
    'صيدلي',
    'صيدلاني',
    'طبيب',
    'دكتور',
    'مريض',
    'دواء',
    'ادوية',
    'أدوية',
    'علاج',
    'جرعة',
    'حبوب',
    'كبسولة',
    'شراب',
    'حقنة',
    'ابرة',
    'إبرة',
    'قطرة',
    'مرهم',
    'كريم',
    'تحاميل',
    'وصفة',
    'روشتة',
    'حساسية',
    'حمل',
    'رضاعة',
    'سكري',
    'ضغط',
    'اعراض جانبية',
    'أعراض جانبية',
    'تداخل',
    'مضاد حيوي',
    'مسكن',
    'باراسيتامول',
    'بروفين',
    'ديكلوفيناك',
    'اموكسيسيلين',
  ];

  static const List<String> _blockedTopics = [
    'code',
    'coding',
    'programming',
    'flutter',
    'dart',
    'python',
    'javascript',
    'html',
    'css',
    'sql',
    'hack',
    'hacking',
    'cybersecurity',
    'football',
    'basketball',
    'sports',
    'movie',
    'music',
    'game',
    'politics',
    'election',
    'crypto',
    'stock',
    'forex',
    'dating',
    'relationship',
    'love',
    'write cv',
    'job application',
    'برمجة',
    'كود',
    'فلاتر',
    'بايثون',
    'اختراق',
    'امن سيبراني',
    'سياسة',
    'انتخابات',
    'رياضة',
    'كرة',
    'فيلم',
    'اغنية',
    'لعبة',
    'حب',
    'علاقة',
    'وظيفة',
    'سيرة ذاتية',
    'كريبتو',
    'اسهم',
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
    for (final value in values) {
      if (text.contains(_normalize(value))) {
        return true;
      }
    }

    return false;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[إأآا]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _refusal(String responseLanguage) {
    return responseLanguage.toLowerCase() == 'arabic'
        ? 'أنا PharmaLens، مساعد طبي وصيدلي فقط. أقدر أساعدك بفهم الوصفة، معلومات الدواء، طريقة الاستخدام، والتحذيرات. لا أستطيع الإجابة على أسئلة خارج المجال الطبي أو الصيدلي.'
        : 'I am PharmaLens, a medical and pharmacy assistant only. I can help with prescriptions, medicine information, usage instructions, and safety checks. I cannot answer questions outside the medical or pharmacy scope.';
  }

  static String _unsafeMedicalRefusal(String responseLanguage) {
    return responseLanguage.toLowerCase() == 'arabic'
        ? 'لا أستطيع تغيير جرعة، إيقاف دواء، أو وصف علاج جديد. راجع طبيبًا أو صيدليًا، وفي الحالات الخطيرة اتصل بالطوارئ فورًا.'
        : 'I cannot change a dose, stop a medicine, or prescribe a new treatment. Contact a doctor or pharmacist, and for urgent symptoms contact emergency services immediately.';
  }
}
