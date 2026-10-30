// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'PharmaLens';

  @override
  String get home => 'Home';

  @override
  String get doctors => 'Doctors';

  @override
  String get medicines => 'Medicines';

  @override
  String get settings => 'Settings';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get language => 'Language';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get useEnglish => 'Use PharmaLens in English';

  @override
  String get useArabic => 'Use PharmaLens in Arabic';

  @override
  String get search => 'Search';

  @override
  String get clear => 'Clear';

  @override
  String get clearAll => 'Clear all';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Try again';

  @override
  String get close => 'Close';

  @override
  String get doctorsDirectory => 'Doctors Directory';

  @override
  String get doctorsDirectorySubtitle =>
      'Find doctors by name, specialty, or area.';

  @override
  String get searchDoctorsHint =>
      'Search by doctor, specialty, hospital, disease, or area';

  @override
  String get specialty => 'Specialty';

  @override
  String get area => 'Area';

  @override
  String get choose => 'Choose';

  @override
  String get allSpecialties => 'All specialties';

  @override
  String get allAreas => 'All areas';

  @override
  String get noMatchingDoctors => 'No matching doctors';

  @override
  String get couldNotLoadDoctors => 'Could not load doctors';

  @override
  String get loadMoreDoctors => 'Load more doctors';

  @override
  String get endOfResults => 'End of results';

  @override
  String get verified => 'Verified';

  @override
  String get call => 'Call';

  @override
  String get email => 'Email';

  @override
  String get directions => 'Directions';

  @override
  String get source => 'Source';

  @override
  String get lastVerified => 'Last verified';

  @override
  String get medicineIdentityVerified => 'Medicine identity verified';

  @override
  String get possibleDatabaseMatch => 'Possible database match';

  @override
  String get clinicalInformationLocked => 'Clinical information locked';

  @override
  String get professionalConfirmationRequired =>
      'Professional confirmation required';

  @override
  String get confirmExactMedicine => 'Confirm exact medicine';

  @override
  String get openFullMedicineProfile => 'Open full medicine profile';

  @override
  String get medicinePrice => 'Medicine price';

  @override
  String get candidatePrice => 'Candidate price';

  @override
  String get prescriptionDirections => 'Prescription directions';

  @override
  String get databaseSource => 'Database source';

  @override
  String get medicineType => 'Medicine type';

  @override
  String get reviewedUses => 'Reviewed uses';

  @override
  String get commonSideEffects => 'Common side effects';

  @override
  String get importantWarnings => 'Important warnings';

  @override
  String get medicalDisclaimer =>
      'PharmaLens provides informational support and does not replace a doctor or pharmacist.';

  @override
  String get prescriptionAnalysis => 'Prescription analysis';

  @override
  String get tryAgain => 'Try again';

  @override
  String medicinePricesUpdatedToTheLatest(Object publishedDate) {
    return 'Medicine prices updated to the latest MOPH list ($publishedDate).';
  }

  @override
  String get pharmacies => 'Pharmacies';

  @override
  String get myHealth => 'My health';

  @override
  String get medicineSafetyAssistant => 'Medicine safety assistant';

  @override
  String mophListMedicines(Object publishedDate, Object totalMedicineCount) {
    return 'MOPH list $publishedDate\n$totalMedicineCount medicines';
  }

  @override
  String get youAreOfflineMedicineSearchDoctors =>
      'You are offline. Medicine search, doctors and your history still work; reading prescriptions and the map need internet.';

  @override
  String get privateClinic => 'Private clinic';

  @override
  String get female => 'Female';

  @override
  String get male => 'Male';

  @override
  String get notSpecified => 'Not specified';

  @override
  String get notAvailable => 'Not available';

  @override
  String get whatsappVerified => 'WhatsApp verified';

  @override
  String get whatsappUnverified => 'WhatsApp unverified';

  @override
  String get takeBeforeFood => 'Take before food';

  @override
  String get takeAfterFood => 'Take after food';

  @override
  String get takeWithFood => 'Take with food';

  @override
  String get takeOnAnEmptyStomach => 'Take on an empty stomach';

  @override
  String get mayBeTakenWithOrWithout => 'May be taken with or without food';

  @override
  String get specificFoodsOrDrinksMustBe =>
      'Specific foods or drinks must be avoided';

  @override
  String get verificationUnavailable => 'Verification unavailable';

  @override
  String get categoryOnly => 'Category only';

  @override
  String get unreadableMedicine => 'Unreadable medicine';

  @override
  String get noConfirmedProduct => 'No confirmed product';

  @override
  String get databaseProductSelected => 'Database product selected';

  @override
  String get prescriptionMatchVerified => 'Prescription match verified';

  @override
  String get exactVariantNeedsConfirmation =>
      'Exact variant needs confirmation';

  @override
  String get possiblePrescriptionMatch => 'Possible prescription match';

  @override
  String get requiresReview => 'Requires review';

  @override
  String get thePrescriptionWasReadButThe =>
      'The prescription was read, but the medicine database could not be checked.';

  @override
  String get onlyAMedicineCategoryWasDetected =>
      'Only a medicine category was detected. An exact product cannot be selected safely.';

  @override
  String get theMedicineNameCouldNotBe =>
      'The medicine name could not be read safely. Do not guess the product.';

  @override
  String get theTextWasReadButNo =>
      'The text was read, but no safe matching medicine product was confirmed in the database.';

  @override
  String get thisProductWasSelectedManuallyFrom =>
      'This product was selected manually from the database. Its product identity is known, but its prescription match was not automatically verified.';

  @override
  String get thePrescriptionTextWasMatchedTo =>
      'The prescription text was matched to this database product.';

  @override
  String get multipleProductVariantsRemainPossibleReview =>
      'Multiple product variants remain possible. Review strength and dosage form before confirming the exact product.';

  @override
  String get thisIsOnlyAPossibleDatabase =>
      'This is only a possible database candidate and requires confirmation before accepting the prescription match.';

  @override
  String get theProductMustBeReviewedBefore =>
      'The product must be reviewed before continuing.';

  @override
  String get pickTheProductOnThePrescription =>
      'Pick the product on the prescription';

  @override
  String get compareTheStrengthAndFormWith =>
      'Compare the strength and form with what the doctor wrote.';

  @override
  String get searchAllMedicines => 'Search all medicines';

  @override
  String medicinesFound(Object count) {
    return '$count medicines found';
  }

  @override
  String get tapAnyMedicineToOpenIts =>
      'Tap any medicine to open its information.';

  @override
  String get remindMe => 'Remind me';

  @override
  String get noMedicinesWereIdentifiedSafely =>
      'No medicines were identified safely.';

  @override
  String get prescriptionPhoto => 'Prescription photo';

  @override
  String get enlarge => 'Enlarge';

  @override
  String get prescriptionPhoto2 => 'Prescription photo';

  @override
  String get couldNotLoadTheDoctorsDirectory =>
      'Could not load the doctors directory.';

  @override
  String get couldNotRefreshDoctors => 'Could not refresh doctors.';

  @override
  String get couldNotLoadDoctors2 => 'Could not load doctors.';

  @override
  String get couldNotOpenThisAction => 'Could not open this action.';

  @override
  String get searchDoctorSpecialtyOrHospital =>
      'Search doctor, specialty or hospital';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get doctorGender => 'Doctor gender';

  @override
  String get any => 'Any';

  @override
  String get female2 => 'Female';

  @override
  String get male2 => 'Male';

  @override
  String get theOfficialListHasNoGender =>
      'The official list has no gender field, so it is estimated from the first name. About 1 in 10 doctors cannot be estimated and only appear under \"Any\".';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String matchingDoctors(Object doctors, Object moreLabel) {
    return '$doctors$moreLabel matching doctors';
  }

  @override
  String showingOf(Object doctors, Object moreLabel, Object totalDoctors) {
    return 'Showing $doctors$moreLabel of $totalDoctors';
  }

  @override
  String get tryAnotherNameSpecialtyOrHospital =>
      'Try another name, specialty or hospital.';

  @override
  String get estimatedFromName => 'estimated from name';

  @override
  String get email2 => 'Email';

  @override
  String get directions2 => 'Directions';

  @override
  String get professionalInformation => 'Professional information';

  @override
  String get subspecialty => 'Subspecialty';

  @override
  String get hospitalClinic => 'Hospital / Clinic';

  @override
  String get location => 'Location';

  @override
  String get contact => 'Contact';

  @override
  String get phone => 'Phone';

  @override
  String get dataSource => 'Data source';

  @override
  String get doctorId => 'Doctor ID';

  @override
  String get openSource => 'Open source';

  @override
  String get theOrderOfPhysiciansListDoes =>
      'The Order of Physicians list does not publish doctors\' phone numbers or clinic addresses. Hospital contacts come from Google Maps and can change; confirm before visiting.';

  @override
  String get doctor => 'Doctor';

  @override
  String get lookingUpHospitalContact => 'Looking up hospital contact...';

  @override
  String get contactNotFoundSearchItOn =>
      'Contact not found. Search it on the map.';

  @override
  String get theClinicAddressIsNotIn =>
      'The clinic address is not in the official list. You can search for it:';

  @override
  String get contactLocation => 'Contact & location';

  @override
  String get hospitalPhoneLookupNeedsAGoogle =>
      'Hospital phone lookup needs a Google Places key in the app configuration.';

  @override
  String get doctors2 => 'Doctors';

  @override
  String doctorsRegisteredWithTheLebaneseOrder(Object total) {
    return '$total doctors registered with the Lebanese Order of Physicians';
  }

  @override
  String get selectSpecialty => 'Select specialty';

  @override
  String get searchSpecialty => 'Search specialty';

  @override
  String get loadMore => 'Load more';

  @override
  String get map => 'Map';

  @override
  String get searchWeb => 'Search web';

  @override
  String get timeToTake => 'Time to take';

  @override
  String scheduledMinutesAgo(Object value) {
    return 'Scheduled $value minutes ago';
  }

  @override
  String get markedAsTaken => 'Marked as taken.';

  @override
  String get taken => 'Taken';

  @override
  String remindingYouAgainInMinutes(Object snoozeMinutes) {
    return 'Reminding you again in $snoozeMinutes minutes.';
  }

  @override
  String snoozeMin(Object snoozeMinutes) {
    return 'Snooze $snoozeMinutes min';
  }

  @override
  String get doseSkipped => 'Dose skipped.';

  @override
  String get skipThisDose => 'Skip this dose';

  @override
  String get mute => 'Mute';

  @override
  String itIsTimeToTake(Object time, Object medicineName, Object note) {
    return 'It is $time. Time to take $medicineName.$note';
  }

  @override
  String get theSelectedImageIsEmptyPlease =>
      'The selected image is empty. Please choose another image.';

  @override
  String get theSelectedImageIsTooLarge =>
      'The selected image is too large. Please use a smaller image.';

  @override
  String get theSelectedImageCouldNotBe =>
      'The selected image could not be read.';

  @override
  String get theImageCouldNotBeOpened =>
      'The image could not be opened. Please try again.';

  @override
  String get checkedAgainstTheMophList => 'CHECKED WITH MOPH';

  @override
  String get readYourPrescription => 'Read your prescription';

  @override
  String get takeAPhotoOrUploadOne =>
      'Snap or upload a prescription. We read each medicine, show its official price, cheaper alternatives and how to take it, and warn you about allergies.';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get opening => 'Opening...';

  @override
  String get uploadImage => 'Upload image';

  @override
  String get useAClearWellLitPhoto =>
      'Use a clear, well-lit photo of the whole prescription.';

  @override
  String get aPhoneReadingAPrescription => 'A phone reading a prescription';

  @override
  String get findAMedicine => 'Find a medicine';

  @override
  String get officialPricesAndAlternatives =>
      'Official prices and alternatives';

  @override
  String get orderOfPhysiciansDirectory => 'Order of Physicians directory';

  @override
  String get nearbyPharmacies => 'Nearby pharmacies';

  @override
  String get onTheMap => 'On the map';

  @override
  String get historyRemindersAllergies => 'History, reminders, allergies';

  @override
  String get todaySDoses => 'Today\'s doses';

  @override
  String get all => 'All';

  @override
  String get noRemindersYetAfterScanningA =>
      'No reminders yet. After scanning a prescription, tap \"Remind me\" next to a medicine.';

  @override
  String ofText(Object taken, Object doses) {
    return '$taken of $doses';
  }

  @override
  String mayRunOutOnTimeTo(Object medicineName, Object refillDate) {
    return '$medicineName may run out on $refillDate. Time to refill.';
  }

  @override
  String get taken2 => 'Taken';

  @override
  String get recentPrescriptions => 'Recent prescriptions';

  @override
  String get prescriptionsYouScanWillAppearHere =>
      'Prescriptions you scan will appear here.';

  @override
  String get noReadableMedicines => 'No readable medicines';

  @override
  String verified2(Object verified) {
    return '$verified verified';
  }

  @override
  String get mophPriceList => 'MOPH price list';

  @override
  String get medicineListCouldNotBeLoaded =>
      'Medicine list could not be loaded';

  @override
  String get pricesMayBeOutOfDate => 'Prices may be out of date';

  @override
  String get restartTheAppIfItKeeps =>
      'Restart the app. If it keeps happening, reinstall it.';

  @override
  String get checkForANewerList => 'Check for a newer list';

  @override
  String get pharmalensHelpsYouReviewChangingOr =>
      'PharmaLens helps you review. Changing or substituting a medicine always needs your doctor or pharmacist.';

  @override
  String get medicineInformation => 'Medicine information';

  @override
  String get compositionUsesSafetyAndAlternatives =>
      'Composition, uses, safety and alternatives';

  @override
  String get noMedicineProductIsAvailable =>
      'No medicine product is available.';

  @override
  String get noMedicinesFoundInTheDatabase =>
      'No medicines found in the database.';

  @override
  String get noMatchingMedicinesWereFoundIn =>
      'No matching medicines were found in the MOPH Lebanon database.';

  @override
  String get searchServiceIsTemporarilyUnavailable =>
      'Search service is temporarily unavailable.';

  @override
  String get selectMedicine => 'Select medicine';

  @override
  String get confirmThatThisIsTheExact =>
      'Confirm that this is the exact database product you want to select.';

  @override
  String get manualSelectionIdentifiesThisDatabaseProduct =>
      'Manual selection identifies this database product only. It does not verify that it is the same medicine written on a prescription and does not authorize substitution.';

  @override
  String get select => 'Select';

  @override
  String get selectMedicine2 => 'Select Medicine';

  @override
  String get medicineSearch => 'Medicine Search';

  @override
  String get syncMophLebanonPrices => 'Sync MOPH Lebanon Prices';

  @override
  String get searchTheDatabaseAndSelectThe =>
      'Search the database and select the exact product after checking its strength, form, pack and manufacturer.';

  @override
  String get findTheExactProduct => 'Find the exact product';

  @override
  String get lebaneseMedicineDatabase => 'Medicines in Lebanon';

  @override
  String get searchByBrandOrActiveIngredient =>
      'Search by name or ingredient · official MOPH prices';

  @override
  String get exampleAugmentin625Mg => 'Example: Augmentin 625 mg';

  @override
  String get searchMedicines => 'Search medicines';

  @override
  String get checkTheSpellingOrTryA =>
      'Check the spelling or try a shorter medicine name.';

  @override
  String get enterABrandOrActiveIngredient =>
      'Enter a brand or active ingredient.';

  @override
  String get searchAndSelectTheExactProduct =>
      'Search and select the exact product';

  @override
  String get findMedicineInformation => 'Find medicine information';

  @override
  String get reviewTheExactProductRecordBefore =>
      'Review the exact product record before selecting it.';

  @override
  String get searchProductRecordsPricesReviewedInformation =>
      'Search product records, prices, reviewed information and verified-composition alternatives.';

  @override
  String get searchingTheMedicineDatabase =>
      'Searching the medicine database...';

  @override
  String get pleaseWaitAMoment => 'Please wait a moment.';

  @override
  String get noMedicinesFound => 'No medicines found';

  @override
  String get tryUsingOnlyPartOfThe =>
      'Try using only part of the medicine name.';

  @override
  String medicinesInTheMophList(Object resultCount) {
    return '$resultCount medicines in the MOPH list';
  }

  @override
  String forText(Object query) {
    return 'For “$query”';
  }

  @override
  String get tapForDetails => 'Tap for details';

  @override
  String get officialSource => 'Official source';

  @override
  String get manufacturer => 'Manufacturer';

  @override
  String get details => 'Details';

  @override
  String get selectMedicine3 => 'Select medicine';

  @override
  String get recordedPrice => 'Recorded price';

  @override
  String get strength => 'Strength';

  @override
  String get form => 'Form';

  @override
  String get pack => 'Pack';

  @override
  String get price => 'Price';

  @override
  String get prescriptionsRemindersAllergiesAndConditionsSaved =>
      'Prescriptions, reminders, allergies and conditions. Saved on this device only.';

  @override
  String get shareMedicineList => 'Share medicine list';

  @override
  String get medicineListCopied => 'Medicine list copied.';

  @override
  String get prescriptions => 'Prescriptions';

  @override
  String get reminders => 'Reminders';

  @override
  String get health => 'Health';

  @override
  String get scannedPrescriptions => 'Scanned prescriptions';

  @override
  String saved(Object records) {
    return '$records saved';
  }

  @override
  String get prescriptionsYouScanAppearHereSo =>
      'Prescriptions you scan appear here so you can review them later.';

  @override
  String get delete => 'Delete';

  @override
  String get deleteThisPrescription => 'Delete this prescription?';

  @override
  String get thePhotoAndDetailsWillBe =>
      'The photo and details will be removed from this device.';

  @override
  String get noMedicinesWereReadFromThis =>
      'No medicines were read from this prescription.';

  @override
  String get medicineReminders => 'Medicine reminders';

  @override
  String get reminderSettings => 'Reminder settings';

  @override
  String get add => 'Add';

  @override
  String get addAReminderFromAScanned =>
      'Add a reminder from a scanned prescription or a medicine page, or tap Add.';

  @override
  String get ended => 'Ended';

  @override
  String until(Object endDate) {
    return 'until $endDate';
  }

  @override
  String refillAround(Object refillDate) {
    return 'Refill around $refillDate';
  }

  @override
  String takenOfDosesInTheLast(Object rate) {
    return 'Taken $rate% of doses in the last 7 days';
  }

  @override
  String get deleteReminder => 'Delete reminder';

  @override
  String get healthConditions => 'Health conditions';

  @override
  String get medicinePagesHighlightTheWarningsThat =>
      'Medicine pages highlight the warnings that apply.';

  @override
  String get allergies => 'Allergies';

  @override
  String get scannedPrescriptionsAreCheckedAgainstThis =>
      'Scanned prescriptions are checked against this list.';

  @override
  String get remove => 'Remove';

  @override
  String get entriesMarkedWereNotFoundIn =>
      'Entries marked ? were not found in the MOPH ingredient list, so they cannot be checked. Try the ingredient name in English, e.g. \"Amoxicillin\".';

  @override
  String get medicineOrIngredientEGAmoxicillin =>
      'Medicine or ingredient, e.g. Amoxicillin';

  @override
  String get addAllergy => 'Add allergy';

  @override
  String get thisCheckUsesMophIngredientAnd =>
      'This check uses MOPH ingredient and class data. It cannot catch every reaction; always tell your doctor and pharmacist about allergies.';

  @override
  String ofVerified(Object verifiedCount, Object medicines) {
    return '$verifiedCount of $medicines verified';
  }

  @override
  String get notVerifiedCheckWithYourPharmacist =>
      'Not verified: check with your pharmacist.';

  @override
  String get addAFamilyMember => 'Add a family member';

  @override
  String get nameEGMom => 'Name (e.g. Mom)';

  @override
  String remove2(Object name) {
    return 'Remove $name?';
  }

  @override
  String get theirAllergiesAndConditionsAreRemoved =>
      'Their allergies and conditions are removed. Their prescriptions and reminders stay saved.';

  @override
  String get remove3 => 'Remove';

  @override
  String get familyMember => 'Family member';

  @override
  String get welcomeToPharmalens => 'Welcome to PharmaLens';

  @override
  String get yourMedicineSafetyAssistantForLebanon =>
      'Your medicine safety assistant for Lebanon.';

  @override
  String get readHandwrittenPrescriptions => 'Read handwritten prescriptions';

  @override
  String get officialMophPricesAndCheaperEquivalents =>
      'Official MOPH prices and cheaper equivalents';

  @override
  String get allergyAndDuplicateChecks => 'Allergy and duplicate checks';

  @override
  String get remindersAndAlarmsForEveryDose =>
      'Reminders and alarms for every dose';

  @override
  String get yourDataYourPhone => 'Your data, your phone';

  @override
  String get toReadAPrescriptionItsPhoto =>
      'To read a prescription, its photo is sent to Google\'s Gemini AI. Nothing else leaves your phone: your prescriptions, allergies and reminders are saved only on this device.';

  @override
  String get medicinesAreCheckedAgainstTheOfficial =>
      'Medicines are checked against the official MOPH list';

  @override
  String get aiCanMakeMistakesAlwaysConfirm =>
      'AI can make mistakes: always confirm with your pharmacist';

  @override
  String get deleteAnyScanAtAnyTime => 'Delete any scan at any time';

  @override
  String get neverMissADose => 'Never miss a dose';

  @override
  String get remindersCanRingLikeAnAlarm =>
      'Reminders can ring like an alarm and say the medicine name. Allow notifications and alarms so they arrive on time.';

  @override
  String get setUpReminders => 'Set up reminders';

  @override
  String get skip => 'Skip';

  @override
  String get iUnderstand => 'I understand';

  @override
  String get start => 'Start';

  @override
  String get next => 'Next';

  @override
  String get noPharmaciesWereFoundWithin5 =>
      'No pharmacies were found within 5 km.';

  @override
  String get nearbyHealthcareSearchIsTemporarilyUnavailable =>
      'Nearby healthcare search is temporarily unavailable. Please try again.';

  @override
  String get yourLocationCouldNotBeAccessed =>
      'Your location could not be accessed.';

  @override
  String get locationServicesAreDisabledEnableGps =>
      'Location services are disabled. Enable GPS to find nearby healthcare services.';

  @override
  String get locationPermissionCouldNotBeChecked =>
      'Location permission could not be checked.';

  @override
  String get locationPermissionIsRequiredToFind =>
      'Location permission is required to find nearby pharmacies and medical centers.';

  @override
  String get locationPermissionIsBlockedEnableIt =>
      'Location permission is blocked. Enable it from app settings.';

  @override
  String get yourCurrentLocationCouldNotBe =>
      'Your current location could not be determined. Check GPS and try again.';

  @override
  String get nearby => 'Nearby';

  @override
  String get pharmacy => 'Pharmacy';

  @override
  String get medicalCenter => 'Medical center';

  @override
  String get openNow => 'Open now';

  @override
  String get closedNow => 'Closed now';

  @override
  String get couldNotOpenDirections => 'Could not open directions.';

  @override
  String get noPhoneNumberIsAvailableFor =>
      'No phone number is available for this location.';

  @override
  String get couldNotOpenThePhoneApplication =>
      'Could not open the phone application.';

  @override
  String get enableLocation => 'Enable location';

  @override
  String get enableGpsToFindTheClosest =>
      'Enable GPS to find the closest pharmacies and medical centers.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get locationPermission => 'Location permission';

  @override
  String get nearbyHealthcare => 'Nearby healthcare';

  @override
  String get googleListing => 'Google listing';

  @override
  String get retry2 => 'Retry';

  @override
  String get findingNearbyHealthcare => 'Finding nearby healthcare...';

  @override
  String get closestToYou => 'Closest to you';

  @override
  String get noNearbyResultsYet => 'No nearby results yet.';

  @override
  String m(Object meters) {
    return '$meters m';
  }

  @override
  String km(Object kilometers) {
    return '$kilometers km';
  }

  @override
  String get chooseAppearance => 'Choose appearance';

  @override
  String get chooseLightDarkOrFollowThe =>
      'Choose light, dark, or follow the device appearance.';

  @override
  String get lightMode => 'Light mode';

  @override
  String get brightMedicalInterface => 'Bright medical interface';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get comfortableDarkInterface => 'Comfortable dark interface';

  @override
  String get systemDefault => 'System default';

  @override
  String get followTheDeviceAutomatically => 'Follow the device automatically';

  @override
  String get couldNotOpenTheLink => 'Could not open the link.';

  @override
  String get helloIAmContactingYouFrom =>
      'Hello, I am contacting you from PharmaLens.';

  @override
  String get couldNotOpenWhatsappOnThis =>
      'Could not open WhatsApp on this device.';

  @override
  String get aboutPharmalens => 'About PharmaLens';

  @override
  String get pharmalensIsAMedicineAndPrescription =>
      'PharmaLens is a medicine and prescription support application designed to help users and pharmacists review medicine information more safely.';

  @override
  String get done => 'Done';

  @override
  String get failedToSyncWithMophServer =>
      'Failed to sync with MOPH server. Using local dataset.';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get auto => 'Auto';

  @override
  String get preferences => 'Preferences';

  @override
  String get appearance => 'Appearance';

  @override
  String get contact2 => 'Contact';

  @override
  String get contactOnWhatsapp => 'Contact on WhatsApp';

  @override
  String get dataSync => 'Data & Sync';

  @override
  String get syncMophMedicineData => 'Sync MOPH Medicine Data';

  @override
  String get syncingInProgress => 'Syncing in progress…';

  @override
  String mophListOfMedicines(Object publishedDate, Object totalMedicineCount) {
    return 'MOPH list of $publishedDate · $totalMedicineCount medicines';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get about => 'About';

  @override
  String version(Object appVersion, Object developerTeam) {
    return 'Version $appVersion • $developerTeam';
  }

  @override
  String get languageAppearanceAndApplicationInformation =>
      'Language, appearance and application information';

  @override
  String get medicineAndPrescriptionSupportWithSafety =>
      'Medicine and prescription support with safety-first verification.';

  @override
  String get medicalDisclaimer2 => 'Medical disclaimer';

  @override
  String developedBy(Object developer) {
    return 'Developed by $developer';
  }

  @override
  String get madeInLebanonByLebaneseDevelopers =>
      'Made in Lebanon 🇱🇧 by Lebanese developers, for patients in Lebanon.';

  @override
  String get asWrittenByYourDoctor => 'As written by your doctor';

  @override
  String get thisInformationCouldNotBeLoaded =>
      'This information could not be loaded. Pull down to try again.';

  @override
  String get loadingMedicineInformationAndAlternatives =>
      'Loading medicine information and alternatives...';

  @override
  String get doNotChangeTheDoseProduct =>
      'Do not change the dose, product, dosage form, or route based on this page alone. Any substitution should be confirmed with a doctor or pharmacist.';

  @override
  String get prescriptionMatch => 'Prescription match';

  @override
  String get selectedProduct => 'Selected product';

  @override
  String get medicineOverview => 'Medicine overview';

  @override
  String get drugFamily => 'Drug family';

  @override
  String get composition => 'Composition';

  @override
  String get dosageForm => 'Dosage form';

  @override
  String get route => 'Route';

  @override
  String get whyIsThisMedicineUsed => 'Why is this medicine used?';

  @override
  String get howItIsUsuallyTaken => 'How it is usually taken';

  @override
  String get usualUse => 'Usual use';

  @override
  String get foodInstructions => 'Food instructions';

  @override
  String get noDirectionsAreWrittenOnThe =>
      'PharmaLens could not read directions for this medicine on the prescription. Check the paper, or ask your doctor or pharmacist how to take it.';

  @override
  String get howToUse => 'How to use';

  @override
  String get sideEffects => 'Side effects';

  @override
  String get commonSideEffects2 => 'Common side effects';

  @override
  String get seriousWarnings => 'Serious warnings';

  @override
  String get warningsSafety => 'Warnings & safety';

  @override
  String get contraindications => 'Contraindications';

  @override
  String get interactions => 'Interactions';

  @override
  String get pregnancyBreastfeeding => 'Pregnancy & breastfeeding';

  @override
  String get storage => 'Storage';

  @override
  String alternatives(Object alternatives) {
    return 'Alternatives ($alternatives)';
  }

  @override
  String get alternativesAreTemporarilyUnavailableTryRefreshing =>
      'Alternatives are temporarily unavailable. Try refreshing again.';

  @override
  String get noVerifiedAlternativesWereFoundIn =>
      'No verified alternatives were found in the current data.';

  @override
  String get differentStrength => 'Different strength';

  @override
  String get differentForm => 'Different form';

  @override
  String get differentRoute => 'Different route';

  @override
  String get productInformation => 'Product information';

  @override
  String get brand => 'Brand';

  @override
  String get activeIngredient => 'Active ingredient';

  @override
  String get manufacturer2 => 'Manufacturer';

  @override
  String get registration => 'Registration';

  @override
  String get priceDate => 'Price date';

  @override
  String get productPriceSource => 'Product / price source';

  @override
  String get clinicalSource => 'Clinical source';

  @override
  String get lastReviewed => 'Last reviewed';

  @override
  String get reviewedBy => 'Reviewed by';

  @override
  String get sourcesReview => 'Sources & review';

  @override
  String get noAdditionalSourceInformationIsCurrently =>
      'No additional source information is currently available.';

  @override
  String get activeIngredient2 => 'Active ingredient: ';

  @override
  String get usedFor => 'Used for: ';

  @override
  String get howToTakeIt => 'How to take it: ';

  @override
  String get pause => 'Pause';

  @override
  String get readAloudIsNotAvailableOn =>
      'Read aloud is not available on this device.';

  @override
  String get resume => 'Resume';

  @override
  String get readAloud => 'Read aloud';

  @override
  String get stop => 'Stop';

  @override
  String get addReminder => 'Add reminder';

  @override
  String get loadingMedicineInformationUsesSideEffects =>
      'Loading medicine information (uses, side effects, warnings)…';

  @override
  String get couldNotLoadTheMedicineInformation =>
      'Could not load the medicine information. Check your internet connection.';

  @override
  String get noFurtherInformationIsAvailableFor =>
      'No further information is available for this medicine yet.';

  @override
  String aiSummaryOfTheUS(Object sourceTitle) {
    return 'AI summary of the U.S. FDA label for the same active ingredient$sourceTitle. The Lebanese product can differ slightly, and the summary can contain mistakes.';
  }

  @override
  String fromTheUSFdaLabel(Object sourceTitle) {
    return 'From the U.S. FDA label for the same active ingredient$sourceTitle.';
  }

  @override
  String get writtenByAiBecauseNoOfficial =>
      'Written by AI because no official leaflet was found. It can contain mistakes: check it with your pharmacist or the leaflet in the box.';

  @override
  String get openLabel => 'Open label';

  @override
  String get loading => 'Loading…';

  @override
  String get activeIngredients => 'Active ingredients';

  @override
  String get therapeuticGroup => 'Therapeutic group';

  @override
  String get officialPrice => 'Official price';

  @override
  String get lbp => 'LBP';

  @override
  String listOf(Object lastUpdatedDate) {
    return ' (list of $lastUpdatedDate)';
  }

  @override
  String get fromTheMophRegistry => 'From the MOPH registry';

  @override
  String get officialDataNotMedicalAdvice =>
      'Official data, not medical advice';

  @override
  String get thisPriceMayBeOutOf =>
      'This price may be out of date. Confirm it at the pharmacy.';

  @override
  String get doNotSwitchBeforeAskingYour =>
      'Do not switch before asking your doctor or pharmacist, even when the ingredient is the same.';

  @override
  String lbpEach(Object perUnit) {
    return '$perUnit LBP each';
  }

  @override
  String get pharmalensPrescriptionReading => 'PharmaLens prescription reading';

  @override
  String get generalAiKnowledge => 'General AI knowledge';

  @override
  String get theAssistantIsBusyRightNow =>
      'The assistant is busy right now. Please try again in a minute.';

  @override
  String get theAssistantIsNotSetUp =>
      'The assistant is not set up on this device.';

  @override
  String get sorryICouldNotAnswerRight =>
      'Sorry, I could not answer right now. Check your internet connection and try again.';

  @override
  String mophPriceList2(Object publishedDate) {
    return 'MOPH price list $publishedDate';
  }

  @override
  String get pharmalensSafetyCheck => 'PharmaLens safety check';

  @override
  String get yourDataOnThisDevice => 'Your data on this device';

  @override
  String get fdaLabelAiSummary => 'FDA label / AI summary';

  @override
  String get lebaneseOrderOfPhysicians => 'Lebanese Order of Physicians';

  @override
  String get pregnant => 'Pregnant';

  @override
  String get breastfeeding => 'Breastfeeding';

  @override
  String get childUnder12 => 'Child (under 12)';

  @override
  String get kidneyDisease => 'Kidney disease';

  @override
  String get liverDisease => 'Liver disease';

  @override
  String get me => 'Me';

  @override
  String get medicineList => 'Medicine list';

  @override
  String ifThisLineIs(Object names) {
    return 'If this line is $names: ';
  }

  @override
  String mayContainSomethingOnYourAllergy(Object prefix, Object names) {
    return '$prefix$names may contain something on your allergy list. Do not take it before talking to your doctor or pharmacist.';
  }

  @override
  String isInTheSameDrugClass(Object prefix, Object names) {
    return '$prefix$names is in the same drug class as something on your allergy list. Cross-reactions are possible; ask your doctor or pharmacist before taking it.';
  }

  @override
  String theSameActiveIngredientIsIn(Object names) {
    return 'The same active ingredient is in: $names. Taking them together can exceed a safe dose. Check with your doctor or pharmacist.';
  }

  @override
  String belongToTheSameTherapeuticClass(Object names) {
    return '$names belong to the same therapeutic class. Ask your doctor or pharmacist whether both are intended.';
  }

  @override
  String get fromTheReviewedMedicineProfile =>
      'From the reviewed medicine profile';

  @override
  String get basedOnTheAtcCodeIn =>
      'Based on the ATC code in the medicine record';

  @override
  String get basedOnTheRegisteredActiveIngredient =>
      'Based on the registered active ingredient';

  @override
  String get loadingTheMedicineList => 'Loading the medicine list…';

  @override
  String get checkingForNewData => 'Checking for new data…';

  @override
  String get downloadingTheNewList => 'Downloading the new list…';

  @override
  String get verifyingTheList => 'Verifying the list…';

  @override
  String get applyingTheUpdate => 'Applying the update…';

  @override
  String get unknown => 'unknown';

  @override
  String revised(Object date, Object publishedDate) {
    return '$date, revised $publishedDate';
  }

  @override
  String updatedToTheMophListOf(Object date, Object medicineCount) {
    return 'Updated to the MOPH list of $date ($medicineCount medicines).';
  }

  @override
  String youAlreadyHaveTheLatestMoph(Object date) {
    return 'You already have the latest MOPH list ($date).';
  }

  @override
  String usingTheMophListOfNew(Object date) {
    return 'Using the MOPH list of $date. New lists arrive with app updates.';
  }

  @override
  String couldNotCheckForANewer(Object date) {
    return 'Could not check for a newer MOPH list. Showing the list of $date.';
  }

  @override
  String timeFor(Object medicineName) {
    return 'Time for $medicineName';
  }

  @override
  String get itIsTimeForYourDose => 'It is time for your dose as prescribed.';

  @override
  String get taken3 => 'Taken ✓';

  @override
  String snoozeMin2(Object snoozeMinutes) {
    return 'Snooze $snoozeMinutes min';
  }

  @override
  String get medicineAlarms => 'Medicine alarms';

  @override
  String get medicineReminders2 => 'Medicine reminders';

  @override
  String get hiIAmThePharmalensAssistant =>
      '### Hi, I am the PharmaLens assistant\nI answer from the **official MOPH price list** and the data saved in this app. You can ask me to:\n- Find a medicine, its official price and **cheaper equivalents**\n- Read a **prescription photo** and check it against the MOPH list\n- Check medicines against **your allergies** and each other\n- Explain uses, side effects and how to take a medicine\n- Find **doctors** and **nearby pharmacies**';

  @override
  String get couldNotAttachImagePleaseTry =>
      'Could not attach image. Please try again.';

  @override
  String get pleaseAnalyzeThisPrescriptionImageFor =>
      'Please analyze this prescription image for me.';

  @override
  String get pharmalensAi => 'PharmaLens AI';

  @override
  String get answersFromTheMophListAnd =>
      'Answers from the MOPH list and your data';

  @override
  String get clearChat => 'Clear chat';

  @override
  String get cheaperThanAugmentin1g => 'Cheaper than Augmentin 1g?';

  @override
  String get whatIsTheOfficialPriceOf =>
      'What is the official price of Augmentin 1g and which equivalent products are cheaper?';

  @override
  String get checkMyLastPrescription => 'Check my last prescription';

  @override
  String get checkTheMedicinesOfMyLast =>
      'Check the medicines of my last prescription against my allergies and each other.';

  @override
  String get panadolSideEffects => 'Panadol side effects';

  @override
  String get whatAreTheCommonSideEffects =>
      'What are the common side effects of Panadol 500mg and how should I take it?';

  @override
  String get pharmaciesNearMe => 'Pharmacies near me';

  @override
  String get whichPharmaciesAreNearMeAnd =>
      'Which pharmacies are near me and open now?';

  @override
  String get findACardiologist => 'Find a cardiologist';

  @override
  String get findCardiologistsInBeirut => 'Find cardiologists in Beirut.';

  @override
  String get aiAnswerItCanBeWrong =>
      'AI answer: it can be wrong. Review with your doctor or pharmacist.';

  @override
  String get readingThePrescription => 'Reading the prescription…';

  @override
  String get searchingTheMophList => 'Searching the MOPH list…';

  @override
  String get comparingEquivalentProducts => 'Comparing equivalent products…';

  @override
  String get checkingAllergiesAndDuplicates =>
      'Checking allergies and duplicates…';

  @override
  String get readingYourSavedData => 'Reading your saved data…';

  @override
  String get lookingUpPatientInformation => 'Looking up patient information…';

  @override
  String get searchingDoctors => 'Searching doctors…';

  @override
  String get findingNearbyPharmacies => 'Finding nearby pharmacies…';

  @override
  String get thinking => 'Thinking…';

  @override
  String get iAmAnAiAndCan =>
      'I am an AI and can make mistakes. Always review medical decisions with your doctor or pharmacist.';

  @override
  String get prescriptionPhotoAttached => 'Prescription photo attached';

  @override
  String get takePhoto2 => 'Take Photo';

  @override
  String get choosePhoto => 'Choose Photo';

  @override
  String get askMedicinePriceOrPrescription =>
      'Ask medicine, price, or prescription...';

  @override
  String get aiAssistant => 'AI assistant';

  @override
  String get theLabelInformationHereSaysNothing =>
      'The label information here says nothing specific about this. Ask your doctor or pharmacist before taking it.';

  @override
  String get basedOnTheHealthProfileSaved =>
      'Based on the health profile saved on this device. For review only; it does not replace your doctor.';

  @override
  String get checkWhatTheMedicineLabelsSay =>
      'Check what the medicine labels say about taking these together.';

  @override
  String get check => 'Check';

  @override
  String get readingTheMedicineLabels => 'Reading the medicine labels…';

  @override
  String get theLabelsDoNotMentionEach =>
      'The labels do not mention each other';

  @override
  String get theLabelsMentionEachOther => 'The labels mention each other';

  @override
  String labelAbout(Object labelOf, Object mentions) {
    return '$labelOf label, about $mentions:';
  }

  @override
  String get fromUSFdaLabelsFor =>
      'From U.S. FDA labels for the same ingredients (summarized by AI). Not a full interaction check: ask your pharmacist.';

  @override
  String get newReminder => 'New reminder';

  @override
  String get editReminder => 'Edit reminder';

  @override
  String get medicine => 'Medicine';

  @override
  String get doseAsPrescribedOptional => 'Dose as prescribed (optional)';

  @override
  String get eG1TabletAfterFood => 'e.g. 1 tablet after food';

  @override
  String get howToRemindMe => 'How to remind me';

  @override
  String get notification => 'Notification';

  @override
  String get alarm => 'Alarm';

  @override
  String get ringsWithThePharmalensToneUntil =>
      'Rings with the alarm sound until you answer, and opens a screen with Taken and Snooze, even on the lock screen.';

  @override
  String get aNotificationWithTakenAndSnooze =>
      'A notification with Taken and Snooze buttons.';

  @override
  String get sayTheMedicineNameAloud => 'Say the medicine name aloud';

  @override
  String get itIs800TimeTo => '\"It is 8:00. Time to take …\"';

  @override
  String get timesEachDay => 'Times each day';

  @override
  String get removeTime => 'Remove time';

  @override
  String get addTime => 'Add time';

  @override
  String get onceADay => 'Once a day';

  @override
  String get twice => 'Twice';

  @override
  String get n3Times => '3 times';

  @override
  String get every6H => 'Every 6 h';

  @override
  String get forHowLong => 'For how long';

  @override
  String get takenFromThePrescriptionDirections =>
      'Taken from the prescription directions';

  @override
  String get noEndDate => 'No end date';

  @override
  String days(Object days) {
    return '$days days';
  }

  @override
  String get remindMeToRefill => 'Remind me to refill';

  @override
  String get estimatesWhenYourSupplyRunsOut =>
      'Estimates when your supply runs out';

  @override
  String get unitsYouHave => 'Units you have';

  @override
  String get perDose => 'Per dose';

  @override
  String get notificationsAreNotAvailableInThe =>
      'Notifications are not available in the web version. Install the app to get alerts.';

  @override
  String get followTheDoseAndDurationOn =>
      'Follow the dose and duration on your prescription. Reminders do not replace your doctor\'s instructions.';

  @override
  String get save => 'Save';

  @override
  String get setUpMedicineReminders => 'Set up medicine reminders';

  @override
  String get allowTheseSoRemindersAndAlarms =>
      'Allow these so reminders and alarms arrive on time, even when the phone is locked.';

  @override
  String get thisDeviceNeedsNoExtraSettings =>
      'This device needs no extra settings. On the web, reminders are listed but cannot ring while the page is closed.';

  @override
  String get notifications => 'Notifications';

  @override
  String get requiredForEveryReminder => 'Required for every reminder.';

  @override
  String get allow => 'Allow';

  @override
  String get alarmsReminders => 'Alarms & reminders';

  @override
  String get ringsAtTheExactMinuteWithout =>
      'Rings at the exact minute. Without it Android may be a few minutes late.';

  @override
  String get fullScreenAlarms => 'Full-screen alarms';

  @override
  String get letsAnAlarmShowTheDose =>
      'Lets an alarm show the dose screen over the lock screen, with Taken and Snooze.';

  @override
  String get batteryUnrestricted => 'Battery: Unrestricted';

  @override
  String get somePhonesXiaomiHuaweiOppoSamsung =>
      'Some phones (Xiaomi, Huawei, Oppo, Samsung) stop reminders to save battery. In the app settings, open Battery and choose \"Unrestricted\".';

  @override
  String get displayOverOtherAppsIsNot =>
      '\"Display over other apps\" is not needed: full-screen alarms already appear over other apps.';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get continueText => 'Continue';

  @override
  String get withoutNotificationsRemindersWillNotAlert =>
      'Without notifications, reminders will not alert you. You can finish this later from any reminder.';

  @override
  String get recommended => '(recommended)';

  @override
  String showMoreLeft(Object left) {
    return 'Show more ($left left)';
  }

  @override
  String get body => 'Body';

  @override
  String get ageAndWeightHelpPharmalensPoint =>
      'Age, height and weight let medicine pages warn you when a medicine may not suit you.';

  @override
  String get age => 'Age';

  @override
  String get years => 'years';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

  @override
  String bmiValue(Object bmi, Object category) {
    return 'BMI $bmi · $category';
  }

  @override
  String get bmiUnderweight => 'Underweight';

  @override
  String get bmiHealthy => 'Healthy weight';

  @override
  String get bmiOverweight => 'Overweight';

  @override
  String get bmiObesity => 'Obesity';

  @override
  String get checkWithYourDoctorBeforeUsingIt =>
      'Check with your doctor before using it.';

  @override
  String ageYearsOld(Object age) {
    return 'Age $age';
  }

  @override
  String get peopleOver65OftenNeedALower =>
      'People over 65 are often more sensitive to medicines and may need a lower dose. Check with your doctor before using it.';

  @override
  String weightKgValue(Object weight) {
    return 'Weight $weight kg';
  }

  @override
  String theDoseDependsOnBodyWeight(Object weight) {
    return 'The dose of this medicine depends on body weight ($weight kg). Ask your doctor or pharmacist for the right dose before using it. The label says:';
  }

  @override
  String get atThisWeightAdultDosesMay =>
      'At this weight, a usual adult dose may be too high. Check with your doctor before using it.';

  @override
  String get thisIsAWeightLossMedicine =>
      'This is a weight-loss medicine and your BMI is not high. Check with your doctor before using it.';

  @override
  String showAllCount(Object count) {
    return 'Show all ($count)';
  }

  @override
  String get yourMedicine => 'Your medicine';

  @override
  String sameDoseCount(Object count) {
    return 'Same dose · $count';
  }

  @override
  String otherStrengthsFormsCount(Object count) {
    return 'Other strengths & forms · $count';
  }

  @override
  String cheapestSameDoseSaves(Object brand, Object saving) {
    return '$brand has the same ingredient, strength and form and costs $saving% less.';
  }

  @override
  String get theseHaveTheSameIngredientBut =>
      'Same ingredient, but the strength, form or route differs. The dose is not the same.';

  @override
  String savePercent(Object percent) {
    return '−$percent%';
  }

  @override
  String morePercent(Object percent) {
    return '+$percent%';
  }

  @override
  String get alarmSound => 'Alarm sound';

  @override
  String get pharmalensTone => 'PharmaLens tone';

  @override
  String get theAppSOwnShortTone => 'The app\'s own short tone';

  @override
  String get phoneAlarmTones => 'Phone alarm tones';

  @override
  String get theTonesYourPhoneUsesFor =>
      'The tones your phone uses for its alarm clock';

  @override
  String get musicOrAudioFile => 'Music or audio file';

  @override
  String get anySongOrRecordingOnThis => 'Any song or recording on this phone';

  @override
  String get customSound => 'Chosen sound';

  @override
  String get listen => 'Listen';

  @override
  String get change => 'Change';
}
