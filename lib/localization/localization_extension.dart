import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n {
    return AppLocalizations.of(this);
  }

  bool get isArabic {
    return Localizations.localeOf(this)
        .languageCode
        .toLowerCase() ==
        'ar';
  }

  bool get isRtl {
    return Directionality.of(this) == TextDirection.rtl;
  }
}

/// Temporary compatibility layer for screens that still use:
///
/// tr.isArabic
/// tr.t('translationKey')
/// tr.translateConfidence(...)
/// tr.translateRoute(...)
///
/// New screens should use direct generated getters such as:
///
/// context.l10n.settings
extension AppLocalizationsCompatibility on AppLocalizations {
  bool get isArabic {
    return localeName.toLowerCase().startsWith('ar');
  }

  String t(String key) {
    final translations = isArabic
        ? _legacyArabicTranslations
        : _legacyEnglishTranslations;

    return translations[key] ?? _humanizeKey(key);
  }

  String translateConfidence(String value) {
    final normalizedValue = value.trim().toLowerCase();

    switch (normalizedValue) {
      case 'high':
        return isArabic ? 'مرتفعة' : 'High';

      case 'medium':
      case 'moderate':
        return isArabic ? 'متوسطة' : 'Medium';

      case 'low':
        return isArabic ? 'منخفضة' : 'Low';

      case 'unknown':
      case '':
        return isArabic ? 'غير معروفة' : 'Unknown';

      default:
        return value;
    }
  }

  String translateRoute(String value) {
    final normalizedValue = value
        .trim()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    switch (normalizedValue) {
      case 'ORAL':
      case 'PO':
        return isArabic ? 'عن طريق الفم' : 'Oral';

      case 'TOPICAL':
        return isArabic ? 'موضعي' : 'Topical';

      case 'INHALATION':
      case 'INHALED':
        return isArabic ? 'عن طريق الاستنشاق' : 'Inhalation';

      case 'INJECTION':
      case 'INJECTABLE':
        return isArabic ? 'عن طريق الحقن' : 'Injection';

      case 'INTRAVENOUS':
      case 'IV':
        return isArabic ? 'وريدي' : 'Intravenous';

      case 'INTRAMUSCULAR':
      case 'IM':
        return isArabic ? 'عضلي' : 'Intramuscular';

      case 'SUBCUTANEOUS':
      case 'SC':
      case 'SQ':
        return isArabic ? 'تحت الجلد' : 'Subcutaneous';

      case 'SUBLINGUAL':
        return isArabic ? 'تحت اللسان' : 'Sublingual';

      case 'NASAL':
        return isArabic ? 'عن طريق الأنف' : 'Nasal';

      case 'OPHTHALMIC':
      case 'EYE':
        return isArabic ? 'للعين' : 'Ophthalmic';

      case 'OTIC':
      case 'EAR':
        return isArabic ? 'للأذن' : 'Otic';

      case 'RECTAL':
        return isArabic ? 'عن طريق المستقيم' : 'Rectal';

      case 'VAGINAL':
        return isArabic ? 'مهبلي' : 'Vaginal';

      case 'TRANSDERMAL':
        return isArabic ? 'عبر الجلد' : 'Transdermal';

      case 'UNKNOWN':
      case '':
        return isArabic ? 'غير مؤكدة' : 'Not verified';

      default:
        return value;
    }
  }

  String _humanizeKey(String key) {
    if (key.trim().isEmpty) {
      return '';
    }

    final spacedKey = key
        .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
    )
        .replaceAll('_', ' ')
        .trim();

    if (spacedKey.isEmpty) {
      return key;
    }

    return '${spacedKey[0].toUpperCase()}${spacedKey.substring(1)}';
  }
}

const Map<String, String> _legacyEnglishTranslations = <String, String>{
  'localOcrWeb':
  'Local OCR is unavailable on the web. AI image analysis will be used.',
  'errorWhileAnalyzing': 'Error while analyzing',
  'prescriptionAnalysis': 'Prescription analysis',
  'changeLanguage': 'Change language',
  'readingSafely': 'Reading the prescription safely...',
  'tryAgain': 'Try again',
  'runLocalAgain': 'Run local analysis again',
  'aiReading': 'AI is analyzing the prescription...',
  'aiHandwritingAnalysis': 'Analyze prescription with AI',
  'aiResult': 'AI analysis result',
  'noAiResult': 'No AI result yet',
  'pressAi': 'Press the AI analysis button to begin.',
  'noSafeSuggestion':
  'No medicine could be identified safely from this prescription.',
  'detectedPatientProblem': 'Detected patient problem',
  'doctorContext': 'Doctor information',
  'safetyStatus': 'Safety status',
  'beginnerGuidance': 'Recommended next steps',
  'confirmReview': 'Confirm review',
  'whatShouldIDo': 'What should I do?',
  'aiCouldNotDetect':
  'The AI could not safely identify medicine information.',
  'aiHasUnclearDetails':
  'Some prescription details are unclear and require professional review.',
  'noVerifiedMatch':
  'No exact medicine match was confirmed in the official database.',
  'noTextToAnalyze': 'There is no text to analyze.',
  'reviewRecorded': 'The review was recorded.',
  'contactDoctor': 'Contact the prescribing doctor for confirmation.',
  'askSenior': 'Ask a senior pharmacist to review the prescription.',
  'verifyDetails':
  'Verify the medicine name, strength, dosage form and directions.',
  'medicineConfidence': 'Reading confidence',
  'route': 'Route',
  'whyRoute': 'Why this route was detected',
  'pharmacistMustVerify': 'The pharmacist must verify',
  'confirmationRequired': 'Professional confirmation required',
  'confirmationMessage':
  'Do not dispense until the unclear medicine details are confirmed.',
  'catalog': 'Medicine catalog',
  'commonUse': 'Possible general use',
  'possibleMedicine': 'Possible medicine',
  'identifiedMedicine': 'Identified medicine',
  'unreadableMedicine': 'Unreadable medicine',
  'manualReviewRequired': 'Manual review required',
  'noMatches': 'No local medicine matches',
  'localMatches': 'Local medicine matches',
  'aiAnalysis': 'AI analysis',
  'databaseVerification': 'Database verification',
};

const Map<String, String> _legacyArabicTranslations = <String, String>{
  'localOcrWeb':
  'التعرّف المحلي على النص غير متاح على الويب. سيتم استخدام تحليل الصورة بالذكاء الاصطناعي.',
  'errorWhileAnalyzing': 'حدث خطأ أثناء التحليل',
  'prescriptionAnalysis': 'تحليل الوصفة الطبية',
  'changeLanguage': 'تغيير اللغة',
  'readingSafely': 'جارٍ قراءة الوصفة بأمان...',
  'tryAgain': 'إعادة المحاولة',
  'runLocalAgain': 'إعادة التحليل المحلي',
  'aiReading': 'يحلل الذكاء الاصطناعي الوصفة...',
  'aiHandwritingAnalysis': 'تحليل الوصفة بالذكاء الاصطناعي',
  'aiResult': 'نتيجة تحليل الذكاء الاصطناعي',
  'noAiResult': 'لا توجد نتيجة تحليل بعد',
  'pressAi': 'اضغط على زر التحليل للبدء.',
  'noSafeSuggestion':
  'لم يتمكن النظام من تحديد أي دواء بأمان من هذه الوصفة.',
  'detectedPatientProblem': 'المشكلة الصحية المكتشفة',
  'doctorContext': 'معلومات الطبيب',
  'safetyStatus': 'حالة السلامة',
  'beginnerGuidance': 'الخطوات التالية المقترحة',
  'confirmReview': 'تأكيد المراجعة',
  'whatShouldIDo': 'ماذا يجب أن أفعل؟',
  'aiCouldNotDetect':
  'لم يتمكن الذكاء الاصطناعي من تحديد معلومات الدواء بأمان.',
  'aiHasUnclearDetails':
  'توجد تفاصيل غير واضحة في الوصفة وتحتاج إلى مراجعة مختص.',
  'noVerifiedMatch':
  'لم يتم تأكيد مطابقة دقيقة للدواء في قاعدة البيانات الرسمية.',
  'noTextToAnalyze': 'لا يوجد نص لتحليله.',
  'reviewRecorded': 'تم تسجيل المراجعة.',
  'contactDoctor': 'تواصل مع الطبيب الذي كتب الوصفة للتأكيد.',
  'askSenior': 'اطلب من صيدلي خبير مراجعة الوصفة.',
  'verifyDetails':
  'تحقق من اسم الدواء والعيار والشكل الدوائي وتعليمات الاستخدام.',
  'medicineConfidence': 'دقة القراءة',
  'route': 'طريقة الإعطاء',
  'whyRoute': 'سبب تحديد طريقة الإعطاء',
  'pharmacistMustVerify': 'يجب على الصيدلي التحقق من',
  'confirmationRequired': 'يلزم تأكيد من مختص',
  'confirmationMessage':
  'لا يتم صرف الدواء قبل تأكيد التفاصيل غير الواضحة.',
  'catalog': 'قاعدة بيانات الأدوية',
  'commonUse': 'الاستخدام العام المحتمل',
  'possibleMedicine': 'دواء محتمل',
  'identifiedMedicine': 'دواء محدد',
  'unreadableMedicine': 'دواء غير مقروء',
  'manualReviewRequired': 'يلزم التحقق اليدوي',
  'noMatches': 'لا توجد مطابقات محلية للأدوية',
  'localMatches': 'مطابقات الأدوية المحلية',
  'aiAnalysis': 'تحليل الذكاء الاصطناعي',
  'databaseVerification': 'التحقق من قاعدة البيانات',
};