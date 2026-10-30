// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'PharmaLens';

  @override
  String get home => 'الرئيسية';

  @override
  String get doctors => 'الأطباء';

  @override
  String get medicines => 'الأدوية';

  @override
  String get settings => 'الإعدادات';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get language => 'اللغة';

  @override
  String get chooseLanguage => 'اختر اللغة';

  @override
  String get useEnglish => 'استخدام PharmaLens باللغة الإنجليزية';

  @override
  String get useArabic => 'استخدام PharmaLens باللغة العربية';

  @override
  String get search => 'بحث';

  @override
  String get clear => 'مسح';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get close => 'إغلاق';

  @override
  String get doctorsDirectory => 'دليل الأطباء';

  @override
  String get doctorsDirectorySubtitle =>
      'ابحث عن الأطباء حسب الاسم أو الاختصاص أو المنطقة.';

  @override
  String get searchDoctorsHint =>
      'ابحث عن طبيب أو اختصاص أو مستشفى أو مرض أو منطقة';

  @override
  String get specialty => 'الاختصاص';

  @override
  String get area => 'المنطقة';

  @override
  String get choose => 'اختيار';

  @override
  String get allSpecialties => 'كل الاختصاصات';

  @override
  String get allAreas => 'كل المناطق';

  @override
  String get noMatchingDoctors => 'لا يوجد أطباء مطابقون';

  @override
  String get couldNotLoadDoctors => 'تعذر تحميل الأطباء';

  @override
  String get loadMoreDoctors => 'تحميل المزيد من الأطباء';

  @override
  String get endOfResults => 'نهاية النتائج';

  @override
  String get verified => 'موثّق';

  @override
  String get call => 'اتصال';

  @override
  String get email => 'بريد إلكتروني';

  @override
  String get directions => 'الاتجاهات';

  @override
  String get source => 'المصدر';

  @override
  String get lastVerified => 'آخر تحقق';

  @override
  String get medicineIdentityVerified => 'هوية الدواء مؤكدة';

  @override
  String get possibleDatabaseMatch => 'مطابقة محتملة في قاعدة البيانات';

  @override
  String get clinicalInformationLocked => 'المعلومات السريرية غير متاحة';

  @override
  String get professionalConfirmationRequired => 'يتطلب تأكيدًا من مختص';

  @override
  String get confirmExactMedicine => 'تأكيد الدواء الصحيح';

  @override
  String get openFullMedicineProfile => 'فتح الملف الكامل للدواء';

  @override
  String get medicinePrice => 'سعر الدواء';

  @override
  String get candidatePrice => 'سعر المنتج المرشح';

  @override
  String get prescriptionDirections => 'تعليمات الوصفة';

  @override
  String get databaseSource => 'مصدر قاعدة البيانات';

  @override
  String get medicineType => 'نوع الدواء';

  @override
  String get reviewedUses => 'الاستعمالات المراجعة';

  @override
  String get commonSideEffects => 'الأعراض الجانبية الشائعة';

  @override
  String get importantWarnings => 'تحذيرات مهمة';

  @override
  String get medicalDisclaimer =>
      'يوفر PharmaLens معلومات مساعدة ولا يحل محل الطبيب أو الصيدلي.';

  @override
  String get prescriptionAnalysis => 'تحليل الوصفة الطبية';

  @override
  String get tryAgain => 'إعادة المحاولة';

  @override
  String medicinePricesUpdatedToTheLatest(Object publishedDate) {
    return 'تم تحديث أسعار الأدوية إلى لائحة وزارة الصحة ($publishedDate).';
  }

  @override
  String get pharmacies => 'الصيدليات';

  @override
  String get myHealth => 'ملفي الصحي';

  @override
  String get medicineSafetyAssistant => 'مساعد سلامة الدواء';

  @override
  String mophListMedicines(Object publishedDate, Object totalMedicineCount) {
    return 'لائحة وزارة الصحة $publishedDate\n$totalMedicineCount دواء';
  }

  @override
  String get youAreOfflineMedicineSearchDoctors =>
      'أنت غير متصل. البحث عن الأدوية والأطباء والسجل يعمل، أما قراءة الوصفات والخريطة فتحتاج إلى الإنترنت.';

  @override
  String get privateClinic => 'عيادة خاصة';

  @override
  String get female => 'أنثى';

  @override
  String get male => 'ذكر';

  @override
  String get notSpecified => 'غير محدد';

  @override
  String get notAvailable => 'غير متوفر';

  @override
  String get whatsappVerified => 'WhatsApp موثّق';

  @override
  String get whatsappUnverified => 'WhatsApp غير موثّق';

  @override
  String get takeBeforeFood => 'يؤخذ قبل الطعام';

  @override
  String get takeAfterFood => 'يؤخذ بعد الطعام';

  @override
  String get takeWithFood => 'يؤخذ مع الطعام';

  @override
  String get takeOnAnEmptyStomach => 'يؤخذ على معدة فارغة';

  @override
  String get mayBeTakenWithOrWithout => 'يمكن تناوله مع الطعام أو بدونه';

  @override
  String get specificFoodsOrDrinksMustBe => 'توجد أطعمة أو مشروبات يجب تجنبها';

  @override
  String get verificationUnavailable => 'تعذر التحقق';

  @override
  String get categoryOnly => 'تم تحديد فئة فقط';

  @override
  String get unreadableMedicine => 'النص غير مقروء';

  @override
  String get noConfirmedProduct => 'لا يوجد منتج مؤكد';

  @override
  String get databaseProductSelected => 'منتج مختار يدويًا';

  @override
  String get prescriptionMatchVerified => 'مطابقة الوصفة مؤكدة';

  @override
  String get exactVariantNeedsConfirmation => 'يجب تحديد المنتج الدقيق';

  @override
  String get possiblePrescriptionMatch => 'مطابقة وصفة محتملة';

  @override
  String get requiresReview => 'يتطلب مراجعة';

  @override
  String get thePrescriptionWasReadButThe =>
      'تمت قراءة الوصفة، لكن تعذر الوصول إلى قاعدة الأدوية حاليًا.';

  @override
  String get onlyAMedicineCategoryWasDetected =>
      'تم اكتشاف فئة دوائية فقط. لا يمكن تحديد منتج دوائي أو عرض معلومات خاصة بمنتج.';

  @override
  String get theMedicineNameCouldNotBe =>
      'تعذر قراءة اسم الدواء بأمان. لا يجوز تخمين المنتج.';

  @override
  String get theTextWasReadButNo =>
      'تمت قراءة النص، لكن لم يتم العثور على منتج مطابق بأمان في قاعدة البيانات.';

  @override
  String get thisProductWasSelectedManuallyFrom =>
      'تم اختيار هذا المنتج يدويًا من قاعدة البيانات. هوية المنتج معروفة، لكن مطابقته مع الوصفة لم يتم تأكيدها تلقائيًا.';

  @override
  String get thePrescriptionTextWasMatchedTo =>
      'تمت مطابقة نص الوصفة مع هذا المنتج في قاعدة البيانات.';

  @override
  String get multipleProductVariantsRemainPossibleReview =>
      'تم العثور على أكثر من منتج محتمل. يجب مراجعة التركيز والشكل الدوائي لتحديد المنتج الدقيق.';

  @override
  String get thisIsOnlyAPossibleDatabase =>
      'هذا المنتج مرشح محتمل فقط ويحتاج إلى تأكيد قبل اعتماد مطابقته مع الوصفة.';

  @override
  String get theProductMustBeReviewedBefore =>
      'يجب مراجعة المنتج قبل المتابعة.';

  @override
  String get pickTheProductOnThePrescription => 'اختر المنتج المكتوب في الوصفة';

  @override
  String get compareTheStrengthAndFormWith =>
      'قارن التركيز والشكل مع ما كتبه الطبيب.';

  @override
  String get searchAllMedicines => 'البحث في كل الأدوية';

  @override
  String medicinesFound(Object count) {
    return '$count أدوية';
  }

  @override
  String get tapAnyMedicineToOpenIts => 'اضغط على أي دواء لعرض معلوماته.';

  @override
  String get remindMe => 'تذكير';

  @override
  String get noMedicinesWereIdentifiedSafely =>
      'لم يتم العثور على أدوية مقروءة بأمان.';

  @override
  String get prescriptionPhoto => 'صورة الوصفة';

  @override
  String get enlarge => 'تكبير';

  @override
  String get prescriptionPhoto2 => 'صورة الوصفة الطبية';

  @override
  String get couldNotLoadTheDoctorsDirectory => 'تعذر تحميل دليل الأطباء.';

  @override
  String get couldNotRefreshDoctors => 'تعذر تحديث الأطباء.';

  @override
  String get couldNotLoadDoctors2 => 'تعذر تحميل الأطباء.';

  @override
  String get couldNotOpenThisAction => 'تعذر فتح هذا الخيار.';

  @override
  String get searchDoctorSpecialtyOrHospital =>
      'ابحث عن طبيب أو اختصاص أو مستشفى';

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get doctorGender => 'جنس الطبيب';

  @override
  String get any => 'الكل';

  @override
  String get female2 => 'طبيبة';

  @override
  String get male2 => 'طبيب';

  @override
  String get theOfficialListHasNoGender =>
      'لا تتضمن اللائحة الرسمية الجنس، لذا يُقدَّر من الاسم الأول. حوالي طبيب من كل 10 لا يمكن تقديره ويظهر فقط ضمن \"الكل\".';

  @override
  String get clearFilters => 'مسح الفلاتر';

  @override
  String matchingDoctors(Object doctors, Object moreLabel) {
    return '$doctors$moreLabel طبيب/ة مطابقون';
  }

  @override
  String showingOf(Object doctors, Object moreLabel, Object totalDoctors) {
    return 'عرض $doctors$moreLabel من أصل $totalDoctors';
  }

  @override
  String get tryAnotherNameSpecialtyOrHospital =>
      'جرّب اسمًا أو اختصاصًا أو مستشفى مختلفًا.';

  @override
  String get estimatedFromName => 'مقدّر من الاسم';

  @override
  String get email2 => 'البريد';

  @override
  String get directions2 => 'الطريق';

  @override
  String get professionalInformation => 'المعلومات المهنية';

  @override
  String get subspecialty => 'الاختصاص الفرعي';

  @override
  String get hospitalClinic => 'المستشفى / العيادة';

  @override
  String get location => 'الموقع';

  @override
  String get contact => 'التواصل';

  @override
  String get phone => 'الهاتف';

  @override
  String get dataSource => 'مصدر البيانات';

  @override
  String get doctorId => 'رقم الطبيب';

  @override
  String get openSource => 'فتح المصدر';

  @override
  String get theOrderOfPhysiciansListDoes =>
      'لا تنشر لائحة نقابة الأطباء أرقام هواتف الأطباء أو عناوين العيادات. معلومات المستشفيات من خرائط Google وقد تتغير؛ تأكد قبل الزيارة.';

  @override
  String get doctor => 'الطبيب';

  @override
  String get lookingUpHospitalContact => 'جارٍ البحث عن معلومات المستشفى...';

  @override
  String get contactNotFoundSearchItOn =>
      'لم يتم العثور على المعلومات. ابحث على الخريطة.';

  @override
  String get theClinicAddressIsNotIn =>
      'عنوان العيادة غير موجود في اللائحة الرسمية. يمكنك البحث عنه:';

  @override
  String get contactLocation => 'التواصل والموقع';

  @override
  String get hospitalPhoneLookupNeedsAGoogle =>
      'البحث عن هاتف المستشفى يحتاج إلى مفتاح Google Places في إعدادات التطبيق.';

  @override
  String get doctors2 => 'دليل الأطباء';

  @override
  String doctorsRegisteredWithTheLebaneseOrder(Object total) {
    return '$total طبيب مسجل في نقابة الأطباء في لبنان';
  }

  @override
  String get selectSpecialty => 'اختيار الاختصاص';

  @override
  String get searchSpecialty => 'ابحث عن اختصاص';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get map => 'الخريطة';

  @override
  String get searchWeb => 'بحث';

  @override
  String get timeToTake => 'حان وقت تناول';

  @override
  String scheduledMinutesAgo(Object value) {
    return 'كان موعدها قبل $value دقيقة';
  }

  @override
  String get markedAsTaken => 'تم تسجيل الجرعة.';

  @override
  String get taken => 'تم التناول';

  @override
  String remindingYouAgainInMinutes(Object snoozeMinutes) {
    return 'سنذكرك مجددًا بعد $snoozeMinutes دقائق.';
  }

  @override
  String snoozeMin(Object snoozeMinutes) {
    return 'غفوة $snoozeMinutes دقائق';
  }

  @override
  String get doseSkipped => 'تم تخطي الجرعة.';

  @override
  String get skipThisDose => 'تخطي هذه الجرعة';

  @override
  String get mute => 'كتم الصوت';

  @override
  String itIsTimeToTake(Object time, Object medicineName, Object note) {
    return 'الساعة $time. حان وقت تناول $medicineName.$note';
  }

  @override
  String get theSelectedImageIsEmptyPlease =>
      'الصورة المختارة فارغة. يرجى اختيار صورة أخرى.';

  @override
  String get theSelectedImageIsTooLarge =>
      'حجم الصورة كبير جدًا. يرجى استخدام صورة أصغر.';

  @override
  String get theSelectedImageCouldNotBe => 'تعذر قراءة الصورة المختارة.';

  @override
  String get theImageCouldNotBeOpened =>
      'تعذر فتح الصورة. يرجى إعادة المحاولة.';

  @override
  String get checkedAgainstTheMophList => 'مطابقة مع وزارة الصحة';

  @override
  String get readYourPrescription => 'اقرأ وصفتك الطبية';

  @override
  String get takeAPhotoOrUploadOne =>
      'صوّر وصفتك أو ارفعها. نقرأ كل دواء ونعرض سعره الرسمي وبدائله الأرخص وطريقة استعماله، وننبهك إلى الحساسية.';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get opening => 'جارٍ الفتح...';

  @override
  String get uploadImage => 'رفع صورة';

  @override
  String get useAClearWellLitPhoto =>
      'صورة واضحة ومضاءة جيدًا تُظهر الوصفة كاملة.';

  @override
  String get aPhoneReadingAPrescription => 'هاتف يقرأ وصفة طبية';

  @override
  String get findAMedicine => 'ابحث عن دواء';

  @override
  String get officialPricesAndAlternatives => 'الأسعار والبدائل الرسمية';

  @override
  String get orderOfPhysiciansDirectory => 'دليل نقابة الأطباء';

  @override
  String get nearbyPharmacies => 'صيدليات قريبة';

  @override
  String get onTheMap => 'على الخريطة';

  @override
  String get historyRemindersAllergies => 'السجل والتذكيرات والحساسية';

  @override
  String get todaySDoses => 'جرعات اليوم';

  @override
  String get all => 'الكل';

  @override
  String get noRemindersYetAfterScanningA =>
      'لا تذكيرات بعد. بعد فحص وصفة، اضغط \"تذكير\" بجانب أي دواء.';

  @override
  String ofText(Object taken, Object doses) {
    return '$taken من $doses';
  }

  @override
  String mayRunOutOnTimeTo(Object medicineName, Object refillDate) {
    return 'قد ينفد $medicineName في $refillDate. فكّر بإعادة الشراء.';
  }

  @override
  String get taken2 => 'تم';

  @override
  String get recentPrescriptions => 'آخر الوصفات';

  @override
  String get prescriptionsYouScanWillAppearHere =>
      'ستظهر هنا الوصفات التي تفحصها.';

  @override
  String get noReadableMedicines => 'لا أدوية مقروءة';

  @override
  String verified2(Object verified) {
    return '$verified متحقق';
  }

  @override
  String get mophPriceList => 'لائحة أسعار وزارة الصحة';

  @override
  String get medicineListCouldNotBeLoaded => 'تعذر تحميل لائحة الأدوية';

  @override
  String get pricesMayBeOutOfDate => 'قد تكون الأسعار قديمة';

  @override
  String get restartTheAppIfItKeeps =>
      'أعد تشغيل التطبيق. إذا استمرت المشكلة، أعد تثبيته.';

  @override
  String get checkForANewerList => 'تحقق من لائحة أحدث';

  @override
  String get pharmalensHelpsYouReviewChangingOr =>
      'فارما لينس أداة مساعدة للمراجعة. تغيير الدواء أو استبداله يحتاج دائمًا إلى رأي الطبيب أو الصيدلي.';

  @override
  String get medicineInformation => 'معلومات الدواء';

  @override
  String get compositionUsesSafetyAndAlternatives =>
      'التركيبة والاستعمالات والتحذيرات والبدائل';

  @override
  String get noMedicineProductIsAvailable => 'لا يوجد منتج دوائي لعرضه.';

  @override
  String get noMedicinesFoundInTheDatabase =>
      'لم يتم العثور على أدوية في قاعدة البيانات.';

  @override
  String get noMatchingMedicinesWereFoundIn =>
      'لم يتم العثور على أدوية مطابقة في قاعدة بيانات وزارة الصحة.';

  @override
  String get searchServiceIsTemporarilyUnavailable =>
      'خدمة البحث غير متاحة حالياً.';

  @override
  String get selectMedicine => 'اختيار الدواء';

  @override
  String get confirmThatThisIsTheExact =>
      'تأكد أن هذا هو المنتج الدوائي الدقيق الذي تريد اختياره من قاعدة البيانات.';

  @override
  String get manualSelectionIdentifiesThisDatabaseProduct =>
      'الاختيار اليدوي يحدد هذا المنتج من قاعدة البيانات فقط. لا يؤكد أنه نفس الدواء المكتوب في الوصفة ولا يسمح بالاستبدال تلقائيًا.';

  @override
  String get select => 'اختيار';

  @override
  String get selectMedicine2 => 'اختيار الدواء';

  @override
  String get medicineSearch => 'البحث عن دواء';

  @override
  String get syncMophLebanonPrices => 'تحديث أسعار وزارة الصحة';

  @override
  String get searchTheDatabaseAndSelectThe =>
      'ابحث في قاعدة البيانات واختر المنتج الدقيق بعد التأكد من التركيز والشكل والعبوة والشركة المصنعة.';

  @override
  String get findTheExactProduct => 'ابحث عن المنتج الدقيق';

  @override
  String get lebaneseMedicineDatabase => 'الأدوية في لبنان';

  @override
  String get searchByBrandOrActiveIngredient =>
      'ابحث بالاسم أو المادة الفعالة · أسعار الوزارة الرسمية';

  @override
  String get exampleAugmentin625Mg => 'مثال: Augmentin 625 mg';

  @override
  String get searchMedicines => 'بحث عن الأدوية';

  @override
  String get checkTheSpellingOrTryA =>
      'تحقق من كتابة الاسم أو جرّب جزءًا أقصر من اسم الدواء.';

  @override
  String get enterABrandOrActiveIngredient =>
      'أدخل اسم العلامة التجارية أو المادة الفعالة.';

  @override
  String get searchAndSelectTheExactProduct => 'ابحث واختر المنتج الدقيق';

  @override
  String get findMedicineInformation => 'ابحث عن معلومات الدواء';

  @override
  String get reviewTheExactProductRecordBefore =>
      'راجع سجل المنتج الدقيق قبل اختياره.';

  @override
  String get searchProductRecordsPricesReviewedInformation =>
      'ابحث في سجلات المنتجات والأسعار والمعلومات المراجعة والبدائل ذات التركيبة المتحقّق منها.';

  @override
  String get searchingTheMedicineDatabase =>
      'جارٍ البحث في قاعدة بيانات الأدوية...';

  @override
  String get pleaseWaitAMoment => 'يرجى الانتظار قليلًا.';

  @override
  String get noMedicinesFound => 'لم يتم العثور على أدوية';

  @override
  String get tryUsingOnlyPartOfThe => 'جرّب استخدام جزء من اسم الدواء.';

  @override
  String medicinesInTheMophList(Object resultCount) {
    return '$resultCount دواء في لائحة وزارة الصحة';
  }

  @override
  String forText(Object query) {
    return 'البحث عن “$query”';
  }

  @override
  String get tapForDetails => 'اضغط للتفاصيل';

  @override
  String get officialSource => 'مصدر رسمي';

  @override
  String get manufacturer => 'الشركة';

  @override
  String get details => 'التفاصيل';

  @override
  String get selectMedicine3 => 'اختيار هذا الدواء';

  @override
  String get recordedPrice => 'السعر المسجل';

  @override
  String get strength => 'التركيز';

  @override
  String get form => 'الشكل';

  @override
  String get pack => 'العبوة';

  @override
  String get price => 'السعر';

  @override
  String get prescriptionsRemindersAllergiesAndConditionsSaved =>
      'الوصفات والتذكيرات والحساسية والحالات الصحية. محفوظة على هذا الجهاز فقط.';

  @override
  String get shareMedicineList => 'مشاركة لائحة الأدوية';

  @override
  String get medicineListCopied => 'تم نسخ لائحة الأدوية.';

  @override
  String get prescriptions => 'الوصفات';

  @override
  String get reminders => 'التذكيرات';

  @override
  String get health => 'الصحة';

  @override
  String get scannedPrescriptions => 'الوصفات المفحوصة';

  @override
  String saved(Object records) {
    return '$records محفوظة';
  }

  @override
  String get prescriptionsYouScanAppearHereSo =>
      'تظهر هنا الوصفات التي تفحصها لتعود إليها لاحقًا.';

  @override
  String get delete => 'حذف';

  @override
  String get deleteThisPrescription => 'حذف هذه الوصفة؟';

  @override
  String get thePhotoAndDetailsWillBe =>
      'ستُحذف الصورة والتفاصيل من هذا الجهاز.';

  @override
  String get noMedicinesWereReadFromThis => 'لم تُقرأ أدوية من هذه الوصفة.';

  @override
  String get medicineReminders => 'تذكيرات الأدوية';

  @override
  String get reminderSettings => 'إعدادات التذكير';

  @override
  String get add => 'إضافة';

  @override
  String get addAReminderFromAScanned =>
      'أضف تذكيرًا من وصفة مفحوصة أو صفحة دواء، أو اضغط إضافة.';

  @override
  String get ended => 'انتهى';

  @override
  String until(Object endDate) {
    return 'حتى $endDate';
  }

  @override
  String refillAround(Object refillDate) {
    return 'إعادة الشراء حوالي $refillDate';
  }

  @override
  String takenOfDosesInTheLast(Object rate) {
    return 'تم تناول $rate٪ من الجرعات في آخر 7 أيام';
  }

  @override
  String get deleteReminder => 'حذف التذكير';

  @override
  String get healthConditions => 'الحالات الصحية';

  @override
  String get medicinePagesHighlightTheWarningsThat =>
      'تُبرز صفحات الأدوية التحذيرات المناسبة.';

  @override
  String get allergies => 'الحساسية';

  @override
  String get scannedPrescriptionsAreCheckedAgainstThis =>
      'تُفحص الوصفات مقابل هذه اللائحة.';

  @override
  String get remove => 'إزالة';

  @override
  String get entriesMarkedWereNotFoundIn =>
      'العناصر المعلّمة بـ ? غير موجودة في لائحة المواد لدى وزارة الصحة، فلا يمكن فحصها. جرّب اسم المادة الفعالة بالإنجليزية، مثل \"Amoxicillin\".';

  @override
  String get medicineOrIngredientEGAmoxicillin =>
      'دواء أو مادة فعالة، مثل Amoxicillin';

  @override
  String get addAllergy => 'إضافة حساسية';

  @override
  String get thisCheckUsesMophIngredientAnd =>
      'يعتمد هذا الفحص على بيانات المواد والفئات من وزارة الصحة. لا يكشف كل التفاعلات؛ أخبر طبيبك والصيدلي دائمًا بالحساسية.';

  @override
  String ofVerified(Object verifiedCount, Object medicines) {
    return '$verifiedCount من $medicines متحقق منها';
  }

  @override
  String get notVerifiedCheckWithYourPharmacist =>
      'غير متحقق منه: راجع الصيدلي.';

  @override
  String get addAFamilyMember => 'إضافة فرد من العائلة';

  @override
  String get nameEGMom => 'الاسم (مثل: أمي)';

  @override
  String remove2(Object name) {
    return 'حذف $name؟';
  }

  @override
  String get theirAllergiesAndConditionsAreRemoved =>
      'تُحذف حساسيته وحالاته الصحية. تبقى وصفاته وتذكيراته محفوظة.';

  @override
  String get remove3 => 'حذف';

  @override
  String get familyMember => 'فرد من العائلة';

  @override
  String get welcomeToPharmalens => 'أهلًا بك في PharmaLens';

  @override
  String get yourMedicineSafetyAssistantForLebanon =>
      'مساعدك لسلامة الأدوية في لبنان.';

  @override
  String get readHandwrittenPrescriptions => 'قراءة الوصفات المكتوبة بخط اليد';

  @override
  String get officialMophPricesAndCheaperEquivalents =>
      'أسعار وزارة الصحة الرسمية وبدائل أرخص';

  @override
  String get allergyAndDuplicateChecks => 'فحص الحساسية والتكرار';

  @override
  String get remindersAndAlarmsForEveryDose => 'تذكيرات ومنبهات لكل جرعة';

  @override
  String get yourDataYourPhone => 'بياناتك على هاتفك';

  @override
  String get toReadAPrescriptionItsPhoto =>
      'لقراءة الوصفة تُرسل صورتها إلى Gemini، الذكاء الاصطناعي من Google. لا شيء آخر يغادر هاتفك: وصفاتك وحساسيتك وتذكيراتك محفوظة على هذا الجهاز فقط.';

  @override
  String get medicinesAreCheckedAgainstTheOfficial =>
      'تُطابق الأدوية مع لائحة وزارة الصحة الرسمية';

  @override
  String get aiCanMakeMistakesAlwaysConfirm =>
      'قد يخطئ الذكاء الاصطناعي: تأكد دائمًا مع الصيدلي';

  @override
  String get deleteAnyScanAtAnyTime => 'احذف أي وصفة في أي وقت';

  @override
  String get neverMissADose => 'لا تفوّت أي جرعة';

  @override
  String get remindersCanRingLikeAnAlarm =>
      'يمكن للتذكيرات أن ترنّ كالمنبه وتقول اسم الدواء. اسمح بالإشعارات والمنبهات لتصل في وقتها.';

  @override
  String get setUpReminders => 'إعداد التذكيرات';

  @override
  String get skip => 'تخطي';

  @override
  String get iUnderstand => 'فهمت';

  @override
  String get start => 'ابدأ';

  @override
  String get next => 'التالي';

  @override
  String get noPharmaciesWereFoundWithin5 =>
      'لم يتم العثور على صيدليات ضمن 5 كم.';

  @override
  String get nearbyHealthcareSearchIsTemporarilyUnavailable =>
      'البحث عن خدمات الرعاية الصحية القريبة غير متاح مؤقتًا. يرجى إعادة المحاولة.';

  @override
  String get yourLocationCouldNotBeAccessed => 'تعذر الوصول إلى موقعك.';

  @override
  String get locationServicesAreDisabledEnableGps =>
      'خدمات الموقع متوقفة. فعّل GPS للعثور على خدمات الرعاية الصحية القريبة.';

  @override
  String get locationPermissionCouldNotBeChecked =>
      'تعذر التحقق من صلاحية الموقع.';

  @override
  String get locationPermissionIsRequiredToFind =>
      'صلاحية الموقع مطلوبة للعثور على الصيدليات والمراكز الطبية القريبة.';

  @override
  String get locationPermissionIsBlockedEnableIt =>
      'صلاحية الموقع محظورة. فعّلها من إعدادات التطبيق.';

  @override
  String get yourCurrentLocationCouldNotBe =>
      'تعذر تحديد موقعك الحالي. تحقق من GPS وحاول مرة أخرى.';

  @override
  String get nearby => 'قريب';

  @override
  String get pharmacy => 'صيدلية';

  @override
  String get medicalCenter => 'مركز طبي';

  @override
  String get openNow => 'مفتوح الآن';

  @override
  String get closedNow => 'مغلق الآن';

  @override
  String get couldNotOpenDirections => 'تعذر فتح الطريق.';

  @override
  String get noPhoneNumberIsAvailableFor =>
      'لا يوجد رقم هاتف متاح لهذا المكان.';

  @override
  String get couldNotOpenThePhoneApplication => 'تعذر فتح تطبيق الهاتف.';

  @override
  String get enableLocation => 'تفعيل الموقع';

  @override
  String get enableGpsToFindTheClosest =>
      'فعّل GPS للعثور على أقرب الصيدليات والمراكز الطبية.';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get locationPermission => 'صلاحية الموقع';

  @override
  String get nearbyHealthcare => 'الرعاية الصحية القريبة';

  @override
  String get googleListing => 'بيانات من Google';

  @override
  String get retry2 => 'إعادة المحاولة';

  @override
  String get findingNearbyHealthcare =>
      'جارٍ البحث عن خدمات الرعاية الصحية القريبة...';

  @override
  String get closestToYou => 'الأقرب إليك';

  @override
  String get noNearbyResultsYet => 'لا توجد نتائج قريبة بعد.';

  @override
  String m(Object meters) {
    return '$meters م';
  }

  @override
  String km(Object kilometers) {
    return '$kilometers كم';
  }

  @override
  String get chooseAppearance => 'اختر المظهر';

  @override
  String get chooseLightDarkOrFollowThe =>
      'اختر الوضع الفاتح أو الداكن أو اتبع مظهر الجهاز.';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get brightMedicalInterface => 'واجهة طبية فاتحة وواضحة';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get comfortableDarkInterface => 'واجهة داكنة ومريحة';

  @override
  String get systemDefault => 'حسب النظام';

  @override
  String get followTheDeviceAutomatically => 'اتبع إعداد الجهاز تلقائيًا';

  @override
  String get couldNotOpenTheLink => 'تعذر فتح الرابط.';

  @override
  String get helloIAmContactingYouFrom =>
      'مرحبًا، أتواصل معك من خلال تطبيق PharmaLens.';

  @override
  String get couldNotOpenWhatsappOnThis => 'تعذر فتح واتساب على هذا الجهاز.';

  @override
  String get aboutPharmalens => 'حول PharmaLens';

  @override
  String get pharmalensIsAMedicineAndPrescription =>
      'PharmaLens هو تطبيق لدعم مراجعة الأدوية والوصفات، صُمم لمساعدة المستخدمين والصيادلة على مراجعة المعلومات الدوائية بشكل أكثر أمانًا.';

  @override
  String get done => 'تم';

  @override
  String get failedToSyncWithMophServer =>
      'تعذرت المزامنة مع خادم الوزارة. يجري استخدام القاعدة المحلية.';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get system => 'حسب النظام';

  @override
  String get auto => 'تلقائي';

  @override
  String get preferences => 'التفضيلات';

  @override
  String get appearance => 'المظهر';

  @override
  String get contact2 => 'تواصل معنا';

  @override
  String get contactOnWhatsapp => 'تواصل عبر واتساب';

  @override
  String get dataSync => 'البيانات والمزامنة';

  @override
  String get syncMophMedicineData => 'مزامنة بيانات أدوية وزارة الصحة';

  @override
  String get syncingInProgress => 'جارٍ التحديث…';

  @override
  String mophListOfMedicines(Object publishedDate, Object totalMedicineCount) {
    return 'لائحة وزارة الصحة بتاريخ $publishedDate · $totalMedicineCount دواء';
  }

  @override
  String get syncNow => 'زامن الآن';

  @override
  String get about => 'حول التطبيق';

  @override
  String version(Object appVersion, Object developerTeam) {
    return 'الإصدار $appVersion • $developerTeam';
  }

  @override
  String get languageAppearanceAndApplicationInformation =>
      'اللغة والمظهر ومعلومات التطبيق';

  @override
  String get medicineAndPrescriptionSupportWithSafety =>
      'دعم للأدوية والوصفات مع تحقق يعتمد السلامة أولًا.';

  @override
  String get medicalDisclaimer2 => 'تنبيه طبي';

  @override
  String developedBy(Object developer) {
    return 'تم التطوير بواسطة $developer';
  }

  @override
  String get madeInLebanonByLebaneseDevelopers =>
      'صُنع في لبنان 🇱🇧 بأيدي مبرمجين لبنانيين، لخدمة المرضى في لبنان.';

  @override
  String get asWrittenByYourDoctor => 'كما كتب الطبيب على الوصفة';

  @override
  String get thisInformationCouldNotBeLoaded =>
      'تعذر تحميل هذه المعلومات. اسحب الصفحة للأسفل لإعادة المحاولة.';

  @override
  String get loadingMedicineInformationAndAlternatives =>
      'جارٍ تحميل معلومات الدواء والبدائل...';

  @override
  String get doNotChangeTheDoseProduct =>
      'لا تغيّر الجرعة أو المنتج أو الشكل الدوائي أو طريق الإعطاء اعتمادًا على هذه الصفحة وحدها. يجب تأكيد الاستبدال مع الطبيب أو الصيدلي.';

  @override
  String get prescriptionMatch => 'مطابق للوصفة';

  @override
  String get selectedProduct => 'منتج مختار';

  @override
  String get medicineOverview => 'معلومات أساسية';

  @override
  String get drugFamily => 'العائلة الدوائية';

  @override
  String get composition => 'التركيبة';

  @override
  String get dosageForm => 'الشكل الدوائي';

  @override
  String get route => 'طريقة الإعطاء';

  @override
  String get whyIsThisMedicineUsed => 'لماذا يُستخدم هذا الدواء؟';

  @override
  String get howItIsUsuallyTaken => 'كيف يُستعمل عادةً';

  @override
  String get usualUse => 'الاستخدام المعتاد';

  @override
  String get foodInstructions => 'مع الطعام';

  @override
  String get noDirectionsAreWrittenOnThe =>
      'لم يتمكن PharmaLens من قراءة طريقة استعمال هذا الدواء على الوصفة. راجع الورقة، أو اسأل طبيبك أو الصيدلي كيف تأخذه.';

  @override
  String get howToUse => 'طريقة الاستخدام';

  @override
  String get sideEffects => 'الأعراض الجانبية';

  @override
  String get commonSideEffects2 => 'أعراض شائعة';

  @override
  String get seriousWarnings => 'تحذيرات مهمة';

  @override
  String get warningsSafety => 'التحذيرات والمعلومات المهمة';

  @override
  String get contraindications => 'موانع الاستعمال';

  @override
  String get interactions => 'التداخلات الدوائية';

  @override
  String get pregnancyBreastfeeding => 'الحمل والرضاعة';

  @override
  String get storage => 'التخزين';

  @override
  String alternatives(Object alternatives) {
    return 'البدائل ($alternatives)';
  }

  @override
  String get alternativesAreTemporarilyUnavailableTryRefreshing =>
      'تعذر تحميل البدائل حاليًا. حاول التحديث مرة أخرى.';

  @override
  String get noVerifiedAlternativesWereFoundIn =>
      'لم يتم العثور على بدائل مؤكدة في البيانات الحالية.';

  @override
  String get differentStrength => 'تركيز مختلف';

  @override
  String get differentForm => 'شكل مختلف';

  @override
  String get differentRoute => 'طريق إعطاء مختلف';

  @override
  String get productInformation => 'معلومات المنتج';

  @override
  String get brand => 'الاسم التجاري';

  @override
  String get activeIngredient => 'المادة الفعالة';

  @override
  String get manufacturer2 => 'الشركة المصنعة';

  @override
  String get registration => 'رقم التسجيل';

  @override
  String get priceDate => 'تاريخ السعر';

  @override
  String get productPriceSource => 'مصدر المنتج والسعر';

  @override
  String get clinicalSource => 'المصدر الطبي';

  @override
  String get lastReviewed => 'آخر مراجعة';

  @override
  String get reviewedBy => 'تمت المراجعة بواسطة';

  @override
  String get sourcesReview => 'المصادر والمراجعة';

  @override
  String get noAdditionalSourceInformationIsCurrently =>
      'لا توجد معلومات مصدر إضافية متاحة حاليًا.';

  @override
  String get activeIngredient2 => 'المادة الفعالة: ';

  @override
  String get usedFor => 'الاستعمال: ';

  @override
  String get howToTakeIt => 'طريقة الاستعمال: ';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get readAloudIsNotAvailableOn =>
      'القراءة الصوتية غير متاحة على هذا الجهاز.';

  @override
  String get resume => 'متابعة القراءة';

  @override
  String get readAloud => 'اقرأ بصوت عالٍ';

  @override
  String get stop => 'إيقاف';

  @override
  String get addReminder => 'تذكير بالدواء';

  @override
  String get loadingMedicineInformationUsesSideEffects =>
      'جارٍ تحميل معلومات الدواء (الاستعمال، الأعراض الجانبية، التحذيرات)…';

  @override
  String get couldNotLoadTheMedicineInformation =>
      'تعذر تحميل معلومات الدواء. تحقق من الاتصال بالإنترنت.';

  @override
  String get noFurtherInformationIsAvailableFor =>
      'لا تتوفر معلومات إضافية عن هذا الدواء حاليًا.';

  @override
  String aiSummaryOfTheUS(Object sourceTitle) {
    return 'ملخص بالذكاء الاصطناعي من نشرة إدارة الغذاء والدواء الأمريكية (FDA) لدواء بنفس المادة الفعالة$sourceTitle. قد يختلف المنتج اللبناني قليلًا، وقد يحتوي الملخص على أخطاء.';
  }

  @override
  String fromTheUSFdaLabel(Object sourceTitle) {
    return 'من نشرة إدارة الغذاء والدواء الأمريكية (FDA) لدواء بنفس المادة الفعالة$sourceTitle، باللغة الإنجليزية.';
  }

  @override
  String get writtenByAiBecauseNoOfficial =>
      'كُتبت هذه المعلومات بالذكاء الاصطناعي لعدم توفر نشرة رسمية. قد تحتوي على أخطاء، فتأكد منها مع الصيدلي أو من النشرة داخل العلبة.';

  @override
  String get openLabel => 'فتح النشرة';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get activeIngredients => 'المادة الفعالة';

  @override
  String get therapeuticGroup => 'الفئة العلاجية';

  @override
  String get officialPrice => 'السعر الرسمي';

  @override
  String get lbp => 'ل.ل.';

  @override
  String listOf(Object lastUpdatedDate) {
    return ' (لائحة $lastUpdatedDate)';
  }

  @override
  String get fromTheMophRegistry => 'من سجل وزارة الصحة';

  @override
  String get officialDataNotMedicalAdvice => 'بيانات رسمية، وليست نصيحة طبية';

  @override
  String get thisPriceMayBeOutOf =>
      'قد يكون هذا السعر قديمًا. تحقق منه في الصيدلية.';

  @override
  String get doNotSwitchBeforeAskingYour =>
      'لا تستبدل دواءك قبل استشارة الطبيب أو الصيدلي، حتى لو كانت المادة نفسها.';

  @override
  String lbpEach(Object perUnit) {
    return '$perUnit ل.ل. للوحدة';
  }

  @override
  String get pharmalensPrescriptionReading => 'قراءة الوصفة في التطبيق';

  @override
  String get generalAiKnowledge => 'معرفة عامة (ذكاء اصطناعي)';

  @override
  String get theAssistantIsBusyRightNow =>
      'المساعد مشغول حاليًا. حاول مجددًا بعد دقيقة.';

  @override
  String get theAssistantIsNotSetUp => 'المساعد غير مُعدّ على هذا الجهاز.';

  @override
  String get sorryICouldNotAnswerRight =>
      'عذرًا، لم أتمكن من الإجابة الآن. تأكد من الاتصال بالإنترنت وحاول مجددًا.';

  @override
  String mophPriceList2(Object publishedDate) {
    return 'لائحة وزارة الصحة $publishedDate';
  }

  @override
  String get pharmalensSafetyCheck => 'فحص السلامة في التطبيق';

  @override
  String get yourDataOnThisDevice => 'بياناتك على هذا الجهاز';

  @override
  String get fdaLabelAiSummary => 'نشرة FDA / ذكاء اصطناعي';

  @override
  String get lebaneseOrderOfPhysicians => 'نقابة الأطباء في لبنان';

  @override
  String get pregnant => 'حامل';

  @override
  String get breastfeeding => 'مرضعة';

  @override
  String get childUnder12 => 'طفل (أقل من 12 سنة)';

  @override
  String get kidneyDisease => 'مرض في الكلى';

  @override
  String get liverDisease => 'مرض في الكبد';

  @override
  String get me => 'أنا';

  @override
  String get medicineList => 'لائحة الأدوية';

  @override
  String ifThisLineIs(Object names) {
    return 'إذا كان الدواء المقصود هو $names: ';
  }

  @override
  String mayContainSomethingOnYourAllergy(Object prefix, Object names) {
    return '$prefix$names قد يحتوي على مادة سجلت أن لديك حساسية منها. لا تتناوله قبل التحدث مع طبيبك أو الصيدلي.';
  }

  @override
  String isInTheSameDrugClass(Object prefix, Object names) {
    return '$prefix$names من الفئة الدوائية نفسها لمادة على لائحة حساسيتك. قد تحدث حساسية متصالبة؛ اسأل طبيبك أو الصيدلي قبل تناوله.';
  }

  @override
  String theSameActiveIngredientIsIn(Object names) {
    return 'المادة نفسها موجودة في: $names. تناولها معًا قد يتجاوز الجرعة الآمنة. تأكد من الطبيب أو الصيدلي.';
  }

  @override
  String belongToTheSameTherapeuticClass(Object names) {
    return '$names من الفئة العلاجية نفسها. اسأل الطبيب أو الصيدلي إن كان المقصود تناولهما معًا.';
  }

  @override
  String get fromTheReviewedMedicineProfile => 'من الملف الطبي المراجع';

  @override
  String get basedOnTheAtcCodeIn => 'حسب تصنيف ATC الموجود في سجل الدواء';

  @override
  String get basedOnTheRegisteredActiveIngredient =>
      'حسب المادة الفعالة المسجلة';

  @override
  String get loadingTheMedicineList => 'جارٍ تحميل لائحة الأدوية…';

  @override
  String get checkingForNewData => 'جارٍ التحقق من بيانات جديدة…';

  @override
  String get downloadingTheNewList => 'جارٍ تنزيل اللائحة الجديدة…';

  @override
  String get verifyingTheList => 'جارٍ التحقق من اللائحة…';

  @override
  String get applyingTheUpdate => 'جارٍ تطبيق التحديث…';

  @override
  String get unknown => 'غير معروف';

  @override
  String revised(Object date, Object publishedDate) {
    return '$date، المعدّلة في $publishedDate';
  }

  @override
  String updatedToTheMophListOf(Object date, Object medicineCount) {
    return 'تم التحديث إلى لائحة وزارة الصحة بتاريخ $date ($medicineCount دواء).';
  }

  @override
  String youAlreadyHaveTheLatestMoph(Object date) {
    return 'لديك أحدث لائحة من وزارة الصحة ($date).';
  }

  @override
  String usingTheMophListOfNew(Object date) {
    return 'يتم استخدام لائحة وزارة الصحة بتاريخ $date. تصل اللوائح الجديدة مع تحديثات التطبيق.';
  }

  @override
  String couldNotCheckForANewer(Object date) {
    return 'تعذر التحقق من لائحة أحدث. يتم عرض لائحة $date.';
  }

  @override
  String timeFor(Object medicineName) {
    return 'موعد الدواء: $medicineName';
  }

  @override
  String get itIsTimeForYourDose => 'حان وقت جرعتك حسب وصفة الطبيب.';

  @override
  String get taken3 => 'تم التناول ✓';

  @override
  String snoozeMin2(Object snoozeMinutes) {
    return 'غفوة $snoozeMinutes د';
  }

  @override
  String get medicineAlarms => 'منبهات الدواء';

  @override
  String get medicineReminders2 => 'تذكيرات الدواء';

  @override
  String get hiIAmThePharmalensAssistant =>
      '### مرحبًا، أنا مساعد PharmaLens\nأجيب من **لائحة أسعار وزارة الصحة الرسمية** ومن البيانات المحفوظة في التطبيق. يمكنك أن تطلب مني:\n- البحث عن دواء وسعره الرسمي و**البدائل الأوفر**\n- قراءة **صورة وصفة** ومطابقتها مع لائحة الوزارة\n- فحص الأدوية مقابل **حساسيتك** ومع بعضها\n- شرح الاستعمال والآثار الجانبية وطريقة التناول\n- إيجاد **أطباء** و**صيدليات قريبة**';

  @override
  String get couldNotAttachImagePleaseTry =>
      'تعذر إرفاق الصورة. يرجى إعادة المحاولة.';

  @override
  String get pleaseAnalyzeThisPrescriptionImageFor =>
      'يرجى قراءة هذه الوصفة وتحليل الأدوية والأسعار والبدائل فيها.';

  @override
  String get pharmalensAi => 'مساعد PharmaLens';

  @override
  String get answersFromTheMophListAnd => 'إجابات من لائحة الوزارة وبياناتك';

  @override
  String get clearChat => 'مسح المحادثة';

  @override
  String get cheaperThanAugmentin1g => 'بديل أرخص لـ Augmentin 1g؟';

  @override
  String get whatIsTheOfficialPriceOf =>
      'ما السعر الرسمي لـ Augmentin 1g وما المنتجات المماثلة الأرخص؟';

  @override
  String get checkMyLastPrescription => 'افحص آخر وصفة';

  @override
  String get checkTheMedicinesOfMyLast =>
      'افحص أدوية آخر وصفة لدي مقابل حساسيتي ومع بعضها.';

  @override
  String get panadolSideEffects => 'آثار Panadol الجانبية';

  @override
  String get whatAreTheCommonSideEffects =>
      'ما الآثار الجانبية الشائعة لـ Panadol 500mg وكيف أتناوله؟';

  @override
  String get pharmaciesNearMe => 'صيدليات قريبة';

  @override
  String get whichPharmaciesAreNearMeAnd =>
      'ما الصيدليات القريبة مني والمفتوحة الآن؟';

  @override
  String get findACardiologist => 'طبيب قلب';

  @override
  String get findCardiologistsInBeirut => 'جد لي أطباء قلب في بيروت.';

  @override
  String get aiAnswerItCanBeWrong =>
      'إجابة ذكاء اصطناعي وقد تخطئ. راجع طبيبك أو الصيدلي.';

  @override
  String get readingThePrescription => 'أقرأ الوصفة…';

  @override
  String get searchingTheMophList => 'أبحث في لائحة الوزارة…';

  @override
  String get comparingEquivalentProducts => 'أقارن المنتجات المماثلة…';

  @override
  String get checkingAllergiesAndDuplicates => 'أفحص الحساسية والتكرار…';

  @override
  String get readingYourSavedData => 'أقرأ بياناتك المحفوظة…';

  @override
  String get lookingUpPatientInformation => 'أبحث عن معلومات الدواء…';

  @override
  String get searchingDoctors => 'أبحث عن أطباء…';

  @override
  String get findingNearbyPharmacies => 'أبحث عن صيدليات قريبة…';

  @override
  String get thinking => 'أفكر…';

  @override
  String get iAmAnAiAndCan =>
      'أنا ذكاء اصطناعي وقد أخطئ. راجع دائمًا قراراتك الطبية مع طبيبك أو الصيدلي.';

  @override
  String get prescriptionPhotoAttached => 'صورة الوصفة مرفقة';

  @override
  String get takePhoto2 => 'التقاط صورة';

  @override
  String get choosePhoto => 'اختيار صورة';

  @override
  String get askMedicinePriceOrPrescription => 'اسأل عن دواء، سعر، أو وصفة...';

  @override
  String get aiAssistant => 'المساعد الذكي';

  @override
  String get theLabelInformationHereSaysNothing =>
      'لا تذكر النشرة شيئًا خاصًا بهذه الحالة. اسأل طبيبك أو الصيدلي قبل تناوله.';

  @override
  String get basedOnTheHealthProfileSaved =>
      'من بيانات ملفك الصحي على هذا الجهاز. للمراجعة فقط، لا يغني عن رأي الطبيب.';

  @override
  String get checkWhatTheMedicineLabelsSay =>
      'تحقّق مما تقوله نشرات الأدوية عن تناول هذه الأدوية معًا.';

  @override
  String get check => 'تحقّق';

  @override
  String get readingTheMedicineLabels => 'أقرأ نشرات الأدوية…';

  @override
  String get theLabelsDoNotMentionEach => 'النشرات لا تذكر بعضها';

  @override
  String get theLabelsMentionEachOther => 'النشرات تذكر بعضها';

  @override
  String labelAbout(Object labelOf, Object mentions) {
    return 'نشرة $labelOf، عن $mentions:';
  }

  @override
  String get fromUSFdaLabelsFor =>
      'من نشرات FDA الأمريكية للمواد نفسها (ملخّصة بالذكاء الاصطناعي). ليس فحصًا كاملًا للتداخلات: اسأل الصيدلي.';

  @override
  String get newReminder => 'تذكير جديد';

  @override
  String get editReminder => 'تعديل التذكير';

  @override
  String get medicine => 'الدواء';

  @override
  String get doseAsPrescribedOptional => 'الجرعة حسب الوصفة (اختياري)';

  @override
  String get eG1TabletAfterFood => 'مثال: حبة واحدة بعد الأكل';

  @override
  String get howToRemindMe => 'طريقة التذكير';

  @override
  String get notification => 'إشعار';

  @override
  String get alarm => 'منبه';

  @override
  String get ringsWithThePharmalensToneUntil =>
      'يرنّ بصوت المنبه حتى تجيب، ويفتح شاشة فيها \"تم التناول\" و\"غفوة\"، حتى على شاشة القفل.';

  @override
  String get aNotificationWithTakenAndSnooze =>
      'إشعار فيه زرّا \"تم التناول\" و\"غفوة\".';

  @override
  String get sayTheMedicineNameAloud => 'قراءة اسم الدواء بصوت عالٍ';

  @override
  String get itIs800TimeTo => '\"الساعة 8:00. حان وقت تناول …\"';

  @override
  String get timesEachDay => 'الأوقات يوميًا';

  @override
  String get removeTime => 'حذف الوقت';

  @override
  String get addTime => 'إضافة وقت';

  @override
  String get onceADay => 'مرة يوميًا';

  @override
  String get twice => 'مرتين';

  @override
  String get n3Times => '3 مرات';

  @override
  String get every6H => 'كل 6 ساعات';

  @override
  String get forHowLong => 'المدة';

  @override
  String get takenFromThePrescriptionDirections => 'مأخوذة من تعليمات الوصفة';

  @override
  String get noEndDate => 'بدون تاريخ انتهاء';

  @override
  String days(Object days) {
    return '$days يومًا';
  }

  @override
  String get remindMeToRefill => 'ذكّرني بإعادة الشراء';

  @override
  String get estimatesWhenYourSupplyRunsOut => 'يقدّر متى تنفد الكمية لديك';

  @override
  String get unitsYouHave => 'الكمية لديك';

  @override
  String get perDose => 'لكل جرعة';

  @override
  String get notificationsAreNotAvailableInThe =>
      'الإشعارات غير متاحة في نسخة الويب. ثبّت التطبيق لتصلك التنبيهات.';

  @override
  String get followTheDoseAndDurationOn =>
      'اتبع الجرعة والمدة المذكورة في الوصفة. التذكيرات لا تغني عن تعليمات الطبيب.';

  @override
  String get save => 'حفظ';

  @override
  String get setUpMedicineReminders => 'إعداد تذكيرات الدواء';

  @override
  String get allowTheseSoRemindersAndAlarms =>
      'اسمح بهذه الإعدادات لتصل التذكيرات والمنبهات في وقتها حتى والهاتف مقفل.';

  @override
  String get thisDeviceNeedsNoExtraSettings =>
      'لا يحتاج هذا الجهاز إلى إعدادات إضافية. على الويب تظهر التذكيرات لكن لا يمكنها الرنين والصفحة مغلقة.';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get requiredForEveryReminder => 'ضرورية لكل تذكير.';

  @override
  String get allow => 'السماح';

  @override
  String get alarmsReminders => 'المنبهات والتذكيرات';

  @override
  String get ringsAtTheExactMinuteWithout =>
      'يرنّ في الدقيقة المحددة. بدونه قد يتأخر أندرويد بضع دقائق.';

  @override
  String get fullScreenAlarms => 'المنبه بملء الشاشة';

  @override
  String get letsAnAlarmShowTheDose =>
      'يسمح للمنبه بإظهار شاشة الجرعة فوق شاشة القفل، مع \"تم التناول\" و\"غفوة\".';

  @override
  String get batteryUnrestricted => 'البطارية: بلا قيود';

  @override
  String get somePhonesXiaomiHuaweiOppoSamsung =>
      'بعض الهواتف (شاومي، هواوي، أوبو، سامسونغ) توقف التذكيرات لتوفير البطارية. في إعدادات التطبيق افتح البطارية واختر \"بلا قيود\".';

  @override
  String get displayOverOtherAppsIsNot =>
      'لا حاجة إلى \"الظهور فوق التطبيقات الأخرى\": المنبه بملء الشاشة يظهر فوقها أصلًا.';

  @override
  String get skipForNow => 'تخطي الآن';

  @override
  String get continueText => 'متابعة';

  @override
  String get withoutNotificationsRemindersWillNotAlert =>
      'بدون الإشعارات لن تنبهك التذكيرات. يمكنك إكمال الإعداد لاحقًا من أي تذكير.';

  @override
  String get recommended => '(مستحسن)';

  @override
  String showMoreLeft(Object left) {
    return 'عرض المزيد ($left متبقية)';
  }

  @override
  String get body => 'الجسم';

  @override
  String get ageAndWeightHelpPharmalensPoint =>
      'العمر والطول والوزن تساعد صفحات الأدوية على تنبيهك عندما قد لا يناسبك دواء.';

  @override
  String get age => 'العمر';

  @override
  String get years => 'سنة';

  @override
  String get height => 'الطول';

  @override
  String get weight => 'الوزن';

  @override
  String bmiValue(Object bmi, Object category) {
    return 'مؤشر كتلة الجسم $bmi · $category';
  }

  @override
  String get bmiUnderweight => 'نقص في الوزن';

  @override
  String get bmiHealthy => 'وزن طبيعي';

  @override
  String get bmiOverweight => 'زيادة في الوزن';

  @override
  String get bmiObesity => 'سمنة';

  @override
  String get checkWithYourDoctorBeforeUsingIt => 'استشر طبيبك قبل استعماله.';

  @override
  String ageYearsOld(Object age) {
    return 'العمر $age سنة';
  }

  @override
  String get peopleOver65OftenNeedALower =>
      'من تجاوز 65 عامًا يكون غالبًا أكثر تأثرًا بالأدوية وقد يحتاج جرعة أقل. استشر طبيبك قبل استعماله.';

  @override
  String weightKgValue(Object weight) {
    return 'الوزن $weight كغ';
  }

  @override
  String theDoseDependsOnBodyWeight(Object weight) {
    return 'جرعة هذا الدواء تعتمد على وزن الجسم ($weight كغ). اسأل طبيبك أو الصيدلي عن الجرعة المناسبة قبل استعماله. تقول النشرة:';
  }

  @override
  String get atThisWeightAdultDosesMay =>
      'بهذا الوزن، قد تكون جرعة البالغين المعتادة مرتفعة. استشر طبيبك قبل استعماله.';

  @override
  String get thisIsAWeightLossMedicine =>
      'هذا دواء لإنقاص الوزن ومؤشر كتلة جسمك ليس مرتفعًا. استشر طبيبك قبل استعماله.';

  @override
  String showAllCount(Object count) {
    return 'عرض الكل ($count)';
  }

  @override
  String get yourMedicine => 'دواؤك';

  @override
  String sameDoseCount(Object count) {
    return 'الجرعة نفسها · $count';
  }

  @override
  String otherStrengthsFormsCount(Object count) {
    return 'تركيز أو شكل آخر · $count';
  }

  @override
  String cheapestSameDoseSaves(Object brand, Object saving) {
    return '$brand فيه المادة والتركيز والشكل نفسه وسعره أقل بـ$saving%.';
  }

  @override
  String get theseHaveTheSameIngredientBut =>
      'المادة نفسها، لكن التركيز أو الشكل أو طريقة الإعطاء مختلفة. الجرعة ليست نفسها.';

  @override
  String savePercent(Object percent) {
    return '−$percent%';
  }

  @override
  String morePercent(Object percent) {
    return '+$percent%';
  }

  @override
  String get alarmSound => 'صوت المنبه';

  @override
  String get pharmalensTone => 'نغمة PharmaLens';

  @override
  String get theAppSOwnShortTone => 'النغمة القصيرة الخاصة بالتطبيق';

  @override
  String get phoneAlarmTones => 'نغمات منبه الهاتف';

  @override
  String get theTonesYourPhoneUsesFor => 'النغمات التي يستعملها منبه هاتفك';

  @override
  String get musicOrAudioFile => 'موسيقى أو ملف صوتي';

  @override
  String get anySongOrRecordingOnThis => 'أي أغنية أو تسجيل على هذا الهاتف';

  @override
  String get customSound => 'الصوت المختار';

  @override
  String get listen => 'استماع';

  @override
  String get change => 'تغيير';
}
