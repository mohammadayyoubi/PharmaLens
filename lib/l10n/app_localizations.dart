import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'PharmaLens'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @doctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get doctors;

  /// No description provided for @medicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get medicines;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @useEnglish.
  ///
  /// In en, this message translates to:
  /// **'Use PharmaLens in English'**
  String get useEnglish;

  /// No description provided for @useArabic.
  ///
  /// In en, this message translates to:
  /// **'Use PharmaLens in Arabic'**
  String get useArabic;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @doctorsDirectory.
  ///
  /// In en, this message translates to:
  /// **'Doctors Directory'**
  String get doctorsDirectory;

  /// No description provided for @doctorsDirectorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find doctors by name, specialty, or area.'**
  String get doctorsDirectorySubtitle;

  /// No description provided for @searchDoctorsHint.
  ///
  /// In en, this message translates to:
  /// **'Search by doctor, specialty, hospital, disease, or area'**
  String get searchDoctorsHint;

  /// No description provided for @specialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get specialty;

  /// No description provided for @area.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get area;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @allSpecialties.
  ///
  /// In en, this message translates to:
  /// **'All specialties'**
  String get allSpecialties;

  /// No description provided for @allAreas.
  ///
  /// In en, this message translates to:
  /// **'All areas'**
  String get allAreas;

  /// No description provided for @noMatchingDoctors.
  ///
  /// In en, this message translates to:
  /// **'No matching doctors'**
  String get noMatchingDoctors;

  /// No description provided for @couldNotLoadDoctors.
  ///
  /// In en, this message translates to:
  /// **'Could not load doctors'**
  String get couldNotLoadDoctors;

  /// No description provided for @loadMoreDoctors.
  ///
  /// In en, this message translates to:
  /// **'Load more doctors'**
  String get loadMoreDoctors;

  /// No description provided for @endOfResults.
  ///
  /// In en, this message translates to:
  /// **'End of results'**
  String get endOfResults;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @lastVerified.
  ///
  /// In en, this message translates to:
  /// **'Last verified'**
  String get lastVerified;

  /// No description provided for @medicineIdentityVerified.
  ///
  /// In en, this message translates to:
  /// **'Medicine identity verified'**
  String get medicineIdentityVerified;

  /// No description provided for @possibleDatabaseMatch.
  ///
  /// In en, this message translates to:
  /// **'Possible database match'**
  String get possibleDatabaseMatch;

  /// No description provided for @clinicalInformationLocked.
  ///
  /// In en, this message translates to:
  /// **'Clinical information locked'**
  String get clinicalInformationLocked;

  /// No description provided for @professionalConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'Professional confirmation required'**
  String get professionalConfirmationRequired;

  /// No description provided for @confirmExactMedicine.
  ///
  /// In en, this message translates to:
  /// **'Confirm exact medicine'**
  String get confirmExactMedicine;

  /// No description provided for @openFullMedicineProfile.
  ///
  /// In en, this message translates to:
  /// **'Open full medicine profile'**
  String get openFullMedicineProfile;

  /// No description provided for @medicinePrice.
  ///
  /// In en, this message translates to:
  /// **'Medicine price'**
  String get medicinePrice;

  /// No description provided for @candidatePrice.
  ///
  /// In en, this message translates to:
  /// **'Candidate price'**
  String get candidatePrice;

  /// No description provided for @prescriptionDirections.
  ///
  /// In en, this message translates to:
  /// **'Prescription directions'**
  String get prescriptionDirections;

  /// No description provided for @databaseSource.
  ///
  /// In en, this message translates to:
  /// **'Database source'**
  String get databaseSource;

  /// No description provided for @medicineType.
  ///
  /// In en, this message translates to:
  /// **'Medicine type'**
  String get medicineType;

  /// No description provided for @reviewedUses.
  ///
  /// In en, this message translates to:
  /// **'Reviewed uses'**
  String get reviewedUses;

  /// No description provided for @commonSideEffects.
  ///
  /// In en, this message translates to:
  /// **'Common side effects'**
  String get commonSideEffects;

  /// No description provided for @importantWarnings.
  ///
  /// In en, this message translates to:
  /// **'Important warnings'**
  String get importantWarnings;

  /// No description provided for @medicalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'PharmaLens provides informational support and does not replace a doctor or pharmacist.'**
  String get medicalDisclaimer;

  /// No description provided for @prescriptionAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Prescription analysis'**
  String get prescriptionAnalysis;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @medicinePricesUpdatedToTheLatest.
  ///
  /// In en, this message translates to:
  /// **'Medicine prices updated to the latest MOPH list ({publishedDate}).'**
  String medicinePricesUpdatedToTheLatest(Object publishedDate);

  /// No description provided for @pharmacies.
  ///
  /// In en, this message translates to:
  /// **'Pharmacies'**
  String get pharmacies;

  /// No description provided for @myHealth.
  ///
  /// In en, this message translates to:
  /// **'My health'**
  String get myHealth;

  /// No description provided for @medicineSafetyAssistant.
  ///
  /// In en, this message translates to:
  /// **'Medicine safety assistant'**
  String get medicineSafetyAssistant;

  /// No description provided for @mophListMedicines.
  ///
  /// In en, this message translates to:
  /// **'MOPH list {publishedDate}\n{totalMedicineCount} medicines'**
  String mophListMedicines(Object publishedDate, Object totalMedicineCount);

  /// No description provided for @youAreOfflineMedicineSearchDoctors.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Medicine search, doctors and your history still work; reading prescriptions and the map need internet.'**
  String get youAreOfflineMedicineSearchDoctors;

  /// No description provided for @privateClinic.
  ///
  /// In en, this message translates to:
  /// **'Private clinic'**
  String get privateClinic;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @whatsappVerified.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp verified'**
  String get whatsappVerified;

  /// No description provided for @whatsappUnverified.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp unverified'**
  String get whatsappUnverified;

  /// No description provided for @takeBeforeFood.
  ///
  /// In en, this message translates to:
  /// **'Take before food'**
  String get takeBeforeFood;

  /// No description provided for @takeAfterFood.
  ///
  /// In en, this message translates to:
  /// **'Take after food'**
  String get takeAfterFood;

  /// No description provided for @takeWithFood.
  ///
  /// In en, this message translates to:
  /// **'Take with food'**
  String get takeWithFood;

  /// No description provided for @takeOnAnEmptyStomach.
  ///
  /// In en, this message translates to:
  /// **'Take on an empty stomach'**
  String get takeOnAnEmptyStomach;

  /// No description provided for @mayBeTakenWithOrWithout.
  ///
  /// In en, this message translates to:
  /// **'May be taken with or without food'**
  String get mayBeTakenWithOrWithout;

  /// No description provided for @specificFoodsOrDrinksMustBe.
  ///
  /// In en, this message translates to:
  /// **'Specific foods or drinks must be avoided'**
  String get specificFoodsOrDrinksMustBe;

  /// No description provided for @verificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Verification unavailable'**
  String get verificationUnavailable;

  /// No description provided for @categoryOnly.
  ///
  /// In en, this message translates to:
  /// **'Category only'**
  String get categoryOnly;

  /// No description provided for @unreadableMedicine.
  ///
  /// In en, this message translates to:
  /// **'Unreadable medicine'**
  String get unreadableMedicine;

  /// No description provided for @noConfirmedProduct.
  ///
  /// In en, this message translates to:
  /// **'No confirmed product'**
  String get noConfirmedProduct;

  /// No description provided for @databaseProductSelected.
  ///
  /// In en, this message translates to:
  /// **'Database product selected'**
  String get databaseProductSelected;

  /// No description provided for @prescriptionMatchVerified.
  ///
  /// In en, this message translates to:
  /// **'Prescription match verified'**
  String get prescriptionMatchVerified;

  /// No description provided for @exactVariantNeedsConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Exact variant needs confirmation'**
  String get exactVariantNeedsConfirmation;

  /// No description provided for @possiblePrescriptionMatch.
  ///
  /// In en, this message translates to:
  /// **'Possible prescription match'**
  String get possiblePrescriptionMatch;

  /// No description provided for @requiresReview.
  ///
  /// In en, this message translates to:
  /// **'Requires review'**
  String get requiresReview;

  /// No description provided for @thePrescriptionWasReadButThe.
  ///
  /// In en, this message translates to:
  /// **'The prescription was read, but the medicine database could not be checked.'**
  String get thePrescriptionWasReadButThe;

  /// No description provided for @onlyAMedicineCategoryWasDetected.
  ///
  /// In en, this message translates to:
  /// **'Only a medicine category was detected. An exact product cannot be selected safely.'**
  String get onlyAMedicineCategoryWasDetected;

  /// No description provided for @theMedicineNameCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'The medicine name could not be read safely. Do not guess the product.'**
  String get theMedicineNameCouldNotBe;

  /// No description provided for @theTextWasReadButNo.
  ///
  /// In en, this message translates to:
  /// **'The text was read, but no safe matching medicine product was confirmed in the database.'**
  String get theTextWasReadButNo;

  /// No description provided for @thisProductWasSelectedManuallyFrom.
  ///
  /// In en, this message translates to:
  /// **'This product was selected manually from the database. Its product identity is known, but its prescription match was not automatically verified.'**
  String get thisProductWasSelectedManuallyFrom;

  /// No description provided for @thePrescriptionTextWasMatchedTo.
  ///
  /// In en, this message translates to:
  /// **'The prescription text was matched to this database product.'**
  String get thePrescriptionTextWasMatchedTo;

  /// No description provided for @multipleProductVariantsRemainPossibleReview.
  ///
  /// In en, this message translates to:
  /// **'Multiple product variants remain possible. Review strength and dosage form before confirming the exact product.'**
  String get multipleProductVariantsRemainPossibleReview;

  /// No description provided for @thisIsOnlyAPossibleDatabase.
  ///
  /// In en, this message translates to:
  /// **'This is only a possible database candidate and requires confirmation before accepting the prescription match.'**
  String get thisIsOnlyAPossibleDatabase;

  /// No description provided for @theProductMustBeReviewedBefore.
  ///
  /// In en, this message translates to:
  /// **'The product must be reviewed before continuing.'**
  String get theProductMustBeReviewedBefore;

  /// No description provided for @pickTheProductOnThePrescription.
  ///
  /// In en, this message translates to:
  /// **'Pick the product on the prescription'**
  String get pickTheProductOnThePrescription;

  /// No description provided for @compareTheStrengthAndFormWith.
  ///
  /// In en, this message translates to:
  /// **'Compare the strength and form with what the doctor wrote.'**
  String get compareTheStrengthAndFormWith;

  /// No description provided for @searchAllMedicines.
  ///
  /// In en, this message translates to:
  /// **'Search all medicines'**
  String get searchAllMedicines;

  /// No description provided for @medicinesFound.
  ///
  /// In en, this message translates to:
  /// **'{count} medicines found'**
  String medicinesFound(Object count);

  /// No description provided for @tapAnyMedicineToOpenIts.
  ///
  /// In en, this message translates to:
  /// **'Tap any medicine to open its information.'**
  String get tapAnyMedicineToOpenIts;

  /// No description provided for @remindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remindMe;

  /// No description provided for @noMedicinesWereIdentifiedSafely.
  ///
  /// In en, this message translates to:
  /// **'No medicines were identified safely.'**
  String get noMedicinesWereIdentifiedSafely;

  /// No description provided for @prescriptionPhoto.
  ///
  /// In en, this message translates to:
  /// **'Prescription photo'**
  String get prescriptionPhoto;

  /// No description provided for @enlarge.
  ///
  /// In en, this message translates to:
  /// **'Enlarge'**
  String get enlarge;

  /// No description provided for @prescriptionPhoto2.
  ///
  /// In en, this message translates to:
  /// **'Prescription photo'**
  String get prescriptionPhoto2;

  /// No description provided for @couldNotLoadTheDoctorsDirectory.
  ///
  /// In en, this message translates to:
  /// **'Could not load the doctors directory.'**
  String get couldNotLoadTheDoctorsDirectory;

  /// No description provided for @couldNotRefreshDoctors.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh doctors.'**
  String get couldNotRefreshDoctors;

  /// No description provided for @couldNotLoadDoctors2.
  ///
  /// In en, this message translates to:
  /// **'Could not load doctors.'**
  String get couldNotLoadDoctors2;

  /// No description provided for @couldNotOpenThisAction.
  ///
  /// In en, this message translates to:
  /// **'Could not open this action.'**
  String get couldNotOpenThisAction;

  /// No description provided for @searchDoctorSpecialtyOrHospital.
  ///
  /// In en, this message translates to:
  /// **'Search doctor, specialty or hospital'**
  String get searchDoctorSpecialtyOrHospital;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @doctorGender.
  ///
  /// In en, this message translates to:
  /// **'Doctor gender'**
  String get doctorGender;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @female2.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female2;

  /// No description provided for @male2.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male2;

  /// No description provided for @theOfficialListHasNoGender.
  ///
  /// In en, this message translates to:
  /// **'The official list has no gender field, so it is estimated from the first name. About 1 in 10 doctors cannot be estimated and only appear under \"Any\".'**
  String get theOfficialListHasNoGender;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @matchingDoctors.
  ///
  /// In en, this message translates to:
  /// **'{doctors}{moreLabel} matching doctors'**
  String matchingDoctors(Object doctors, Object moreLabel);

  /// No description provided for @showingOf.
  ///
  /// In en, this message translates to:
  /// **'Showing {doctors}{moreLabel} of {totalDoctors}'**
  String showingOf(Object doctors, Object moreLabel, Object totalDoctors);

  /// No description provided for @tryAnotherNameSpecialtyOrHospital.
  ///
  /// In en, this message translates to:
  /// **'Try another name, specialty or hospital.'**
  String get tryAnotherNameSpecialtyOrHospital;

  /// No description provided for @estimatedFromName.
  ///
  /// In en, this message translates to:
  /// **'estimated from name'**
  String get estimatedFromName;

  /// No description provided for @email2.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email2;

  /// No description provided for @directions2.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions2;

  /// No description provided for @professionalInformation.
  ///
  /// In en, this message translates to:
  /// **'Professional information'**
  String get professionalInformation;

  /// No description provided for @subspecialty.
  ///
  /// In en, this message translates to:
  /// **'Subspecialty'**
  String get subspecialty;

  /// No description provided for @hospitalClinic.
  ///
  /// In en, this message translates to:
  /// **'Hospital / Clinic'**
  String get hospitalClinic;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @dataSource.
  ///
  /// In en, this message translates to:
  /// **'Data source'**
  String get dataSource;

  /// No description provided for @doctorId.
  ///
  /// In en, this message translates to:
  /// **'Doctor ID'**
  String get doctorId;

  /// No description provided for @openSource.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get openSource;

  /// No description provided for @theOrderOfPhysiciansListDoes.
  ///
  /// In en, this message translates to:
  /// **'The Order of Physicians list does not publish doctors\' phone numbers or clinic addresses. Hospital contacts come from Google Maps and can change; confirm before visiting.'**
  String get theOrderOfPhysiciansListDoes;

  /// No description provided for @doctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctor;

  /// No description provided for @lookingUpHospitalContact.
  ///
  /// In en, this message translates to:
  /// **'Looking up hospital contact...'**
  String get lookingUpHospitalContact;

  /// No description provided for @contactNotFoundSearchItOn.
  ///
  /// In en, this message translates to:
  /// **'Contact not found. Search it on the map.'**
  String get contactNotFoundSearchItOn;

  /// No description provided for @theClinicAddressIsNotIn.
  ///
  /// In en, this message translates to:
  /// **'The clinic address is not in the official list. You can search for it:'**
  String get theClinicAddressIsNotIn;

  /// No description provided for @contactLocation.
  ///
  /// In en, this message translates to:
  /// **'Contact & location'**
  String get contactLocation;

  /// No description provided for @hospitalPhoneLookupNeedsAGoogle.
  ///
  /// In en, this message translates to:
  /// **'Hospital phone lookup needs a Google Places key in the app configuration.'**
  String get hospitalPhoneLookupNeedsAGoogle;

  /// No description provided for @doctors2.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get doctors2;

  /// No description provided for @doctorsRegisteredWithTheLebaneseOrder.
  ///
  /// In en, this message translates to:
  /// **'{total} doctors registered with the Lebanese Order of Physicians'**
  String doctorsRegisteredWithTheLebaneseOrder(Object total);

  /// No description provided for @selectSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Select specialty'**
  String get selectSpecialty;

  /// No description provided for @searchSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Search specialty'**
  String get searchSpecialty;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @searchWeb.
  ///
  /// In en, this message translates to:
  /// **'Search web'**
  String get searchWeb;

  /// No description provided for @timeToTake.
  ///
  /// In en, this message translates to:
  /// **'Time to take'**
  String get timeToTake;

  /// No description provided for @scheduledMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Scheduled {value} minutes ago'**
  String scheduledMinutesAgo(Object value);

  /// No description provided for @markedAsTaken.
  ///
  /// In en, this message translates to:
  /// **'Marked as taken.'**
  String get markedAsTaken;

  /// No description provided for @taken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get taken;

  /// No description provided for @remindingYouAgainInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Reminding you again in {snoozeMinutes} minutes.'**
  String remindingYouAgainInMinutes(Object snoozeMinutes);

  /// No description provided for @snoozeMin.
  ///
  /// In en, this message translates to:
  /// **'Snooze {snoozeMinutes} min'**
  String snoozeMin(Object snoozeMinutes);

  /// No description provided for @doseSkipped.
  ///
  /// In en, this message translates to:
  /// **'Dose skipped.'**
  String get doseSkipped;

  /// No description provided for @skipThisDose.
  ///
  /// In en, this message translates to:
  /// **'Skip this dose'**
  String get skipThisDose;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @itIsTimeToTake.
  ///
  /// In en, this message translates to:
  /// **'It is {time}. Time to take {medicineName}.{note}'**
  String itIsTimeToTake(Object time, Object medicineName, Object note);

  /// No description provided for @theSelectedImageIsEmptyPlease.
  ///
  /// In en, this message translates to:
  /// **'The selected image is empty. Please choose another image.'**
  String get theSelectedImageIsEmptyPlease;

  /// No description provided for @theSelectedImageIsTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The selected image is too large. Please use a smaller image.'**
  String get theSelectedImageIsTooLarge;

  /// No description provided for @theSelectedImageCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'The selected image could not be read.'**
  String get theSelectedImageCouldNotBe;

  /// No description provided for @theImageCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'The image could not be opened. Please try again.'**
  String get theImageCouldNotBeOpened;

  /// No description provided for @checkedAgainstTheMophList.
  ///
  /// In en, this message translates to:
  /// **'CHECKED WITH MOPH'**
  String get checkedAgainstTheMophList;

  /// No description provided for @readYourPrescription.
  ///
  /// In en, this message translates to:
  /// **'Read your prescription'**
  String get readYourPrescription;

  /// No description provided for @takeAPhotoOrUploadOne.
  ///
  /// In en, this message translates to:
  /// **'Snap or upload a prescription. We read each medicine, show its official price, cheaper alternatives and how to take it, and warn you about allergies.'**
  String get takeAPhotoOrUploadOne;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @opening.
  ///
  /// In en, this message translates to:
  /// **'Opening...'**
  String get opening;

  /// No description provided for @uploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get uploadImage;

  /// No description provided for @useAClearWellLitPhoto.
  ///
  /// In en, this message translates to:
  /// **'Use a clear, well-lit photo of the whole prescription.'**
  String get useAClearWellLitPhoto;

  /// No description provided for @aPhoneReadingAPrescription.
  ///
  /// In en, this message translates to:
  /// **'A phone reading a prescription'**
  String get aPhoneReadingAPrescription;

  /// No description provided for @findAMedicine.
  ///
  /// In en, this message translates to:
  /// **'Find a medicine'**
  String get findAMedicine;

  /// No description provided for @officialPricesAndAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Official prices and alternatives'**
  String get officialPricesAndAlternatives;

  /// No description provided for @orderOfPhysiciansDirectory.
  ///
  /// In en, this message translates to:
  /// **'Order of Physicians directory'**
  String get orderOfPhysiciansDirectory;

  /// No description provided for @nearbyPharmacies.
  ///
  /// In en, this message translates to:
  /// **'Nearby pharmacies'**
  String get nearbyPharmacies;

  /// No description provided for @onTheMap.
  ///
  /// In en, this message translates to:
  /// **'On the map'**
  String get onTheMap;

  /// No description provided for @historyRemindersAllergies.
  ///
  /// In en, this message translates to:
  /// **'History, reminders, allergies'**
  String get historyRemindersAllergies;

  /// No description provided for @todaySDoses.
  ///
  /// In en, this message translates to:
  /// **'Today\'s doses'**
  String get todaySDoses;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noRemindersYetAfterScanningA.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet. After scanning a prescription, tap \"Remind me\" next to a medicine.'**
  String get noRemindersYetAfterScanningA;

  /// No description provided for @ofText.
  ///
  /// In en, this message translates to:
  /// **'{taken} of {doses}'**
  String ofText(Object taken, Object doses);

  /// No description provided for @mayRunOutOnTimeTo.
  ///
  /// In en, this message translates to:
  /// **'{medicineName} may run out on {refillDate}. Time to refill.'**
  String mayRunOutOnTimeTo(Object medicineName, Object refillDate);

  /// No description provided for @taken2.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get taken2;

  /// No description provided for @recentPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Recent prescriptions'**
  String get recentPrescriptions;

  /// No description provided for @prescriptionsYouScanWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions you scan will appear here.'**
  String get prescriptionsYouScanWillAppearHere;

  /// No description provided for @noReadableMedicines.
  ///
  /// In en, this message translates to:
  /// **'No readable medicines'**
  String get noReadableMedicines;

  /// No description provided for @verified2.
  ///
  /// In en, this message translates to:
  /// **'{verified} verified'**
  String verified2(Object verified);

  /// No description provided for @mophPriceList.
  ///
  /// In en, this message translates to:
  /// **'MOPH price list'**
  String get mophPriceList;

  /// No description provided for @medicineListCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Medicine list could not be loaded'**
  String get medicineListCouldNotBeLoaded;

  /// No description provided for @pricesMayBeOutOfDate.
  ///
  /// In en, this message translates to:
  /// **'Prices may be out of date'**
  String get pricesMayBeOutOfDate;

  /// No description provided for @restartTheAppIfItKeeps.
  ///
  /// In en, this message translates to:
  /// **'Restart the app. If it keeps happening, reinstall it.'**
  String get restartTheAppIfItKeeps;

  /// No description provided for @checkForANewerList.
  ///
  /// In en, this message translates to:
  /// **'Check for a newer list'**
  String get checkForANewerList;

  /// No description provided for @pharmalensHelpsYouReviewChangingOr.
  ///
  /// In en, this message translates to:
  /// **'PharmaLens helps you review. Changing or substituting a medicine always needs your doctor or pharmacist.'**
  String get pharmalensHelpsYouReviewChangingOr;

  /// No description provided for @medicineInformation.
  ///
  /// In en, this message translates to:
  /// **'Medicine information'**
  String get medicineInformation;

  /// No description provided for @compositionUsesSafetyAndAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Composition, uses, safety and alternatives'**
  String get compositionUsesSafetyAndAlternatives;

  /// No description provided for @noMedicineProductIsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No medicine product is available.'**
  String get noMedicineProductIsAvailable;

  /// No description provided for @noMedicinesFoundInTheDatabase.
  ///
  /// In en, this message translates to:
  /// **'No medicines found in the database.'**
  String get noMedicinesFoundInTheDatabase;

  /// No description provided for @noMatchingMedicinesWereFoundIn.
  ///
  /// In en, this message translates to:
  /// **'No matching medicines were found in the MOPH Lebanon database.'**
  String get noMatchingMedicinesWereFoundIn;

  /// No description provided for @searchServiceIsTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Search service is temporarily unavailable.'**
  String get searchServiceIsTemporarilyUnavailable;

  /// No description provided for @selectMedicine.
  ///
  /// In en, this message translates to:
  /// **'Select medicine'**
  String get selectMedicine;

  /// No description provided for @confirmThatThisIsTheExact.
  ///
  /// In en, this message translates to:
  /// **'Confirm that this is the exact database product you want to select.'**
  String get confirmThatThisIsTheExact;

  /// No description provided for @manualSelectionIdentifiesThisDatabaseProduct.
  ///
  /// In en, this message translates to:
  /// **'Manual selection identifies this database product only. It does not verify that it is the same medicine written on a prescription and does not authorize substitution.'**
  String get manualSelectionIdentifiesThisDatabaseProduct;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectMedicine2.
  ///
  /// In en, this message translates to:
  /// **'Select Medicine'**
  String get selectMedicine2;

  /// No description provided for @medicineSearch.
  ///
  /// In en, this message translates to:
  /// **'Medicine Search'**
  String get medicineSearch;

  /// No description provided for @syncMophLebanonPrices.
  ///
  /// In en, this message translates to:
  /// **'Sync MOPH Lebanon Prices'**
  String get syncMophLebanonPrices;

  /// No description provided for @searchTheDatabaseAndSelectThe.
  ///
  /// In en, this message translates to:
  /// **'Search the database and select the exact product after checking its strength, form, pack and manufacturer.'**
  String get searchTheDatabaseAndSelectThe;

  /// No description provided for @findTheExactProduct.
  ///
  /// In en, this message translates to:
  /// **'Find the exact product'**
  String get findTheExactProduct;

  /// No description provided for @lebaneseMedicineDatabase.
  ///
  /// In en, this message translates to:
  /// **'Medicines in Lebanon'**
  String get lebaneseMedicineDatabase;

  /// No description provided for @searchByBrandOrActiveIngredient.
  ///
  /// In en, this message translates to:
  /// **'Search by name or ingredient · official MOPH prices'**
  String get searchByBrandOrActiveIngredient;

  /// No description provided for @exampleAugmentin625Mg.
  ///
  /// In en, this message translates to:
  /// **'Example: Augmentin 625 mg'**
  String get exampleAugmentin625Mg;

  /// No description provided for @searchMedicines.
  ///
  /// In en, this message translates to:
  /// **'Search medicines'**
  String get searchMedicines;

  /// No description provided for @checkTheSpellingOrTryA.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling or try a shorter medicine name.'**
  String get checkTheSpellingOrTryA;

  /// No description provided for @enterABrandOrActiveIngredient.
  ///
  /// In en, this message translates to:
  /// **'Enter a brand or active ingredient.'**
  String get enterABrandOrActiveIngredient;

  /// No description provided for @searchAndSelectTheExactProduct.
  ///
  /// In en, this message translates to:
  /// **'Search and select the exact product'**
  String get searchAndSelectTheExactProduct;

  /// No description provided for @findMedicineInformation.
  ///
  /// In en, this message translates to:
  /// **'Find medicine information'**
  String get findMedicineInformation;

  /// No description provided for @reviewTheExactProductRecordBefore.
  ///
  /// In en, this message translates to:
  /// **'Review the exact product record before selecting it.'**
  String get reviewTheExactProductRecordBefore;

  /// No description provided for @searchProductRecordsPricesReviewedInformation.
  ///
  /// In en, this message translates to:
  /// **'Search product records, prices, reviewed information and verified-composition alternatives.'**
  String get searchProductRecordsPricesReviewedInformation;

  /// No description provided for @searchingTheMedicineDatabase.
  ///
  /// In en, this message translates to:
  /// **'Searching the medicine database...'**
  String get searchingTheMedicineDatabase;

  /// No description provided for @pleaseWaitAMoment.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment.'**
  String get pleaseWaitAMoment;

  /// No description provided for @noMedicinesFound.
  ///
  /// In en, this message translates to:
  /// **'No medicines found'**
  String get noMedicinesFound;

  /// No description provided for @tryUsingOnlyPartOfThe.
  ///
  /// In en, this message translates to:
  /// **'Try using only part of the medicine name.'**
  String get tryUsingOnlyPartOfThe;

  /// No description provided for @medicinesInTheMophList.
  ///
  /// In en, this message translates to:
  /// **'{resultCount} medicines in the MOPH list'**
  String medicinesInTheMophList(Object resultCount);

  /// No description provided for @forText.
  ///
  /// In en, this message translates to:
  /// **'For “{query}”'**
  String forText(Object query);

  /// No description provided for @tapForDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap for details'**
  String get tapForDetails;

  /// No description provided for @officialSource.
  ///
  /// In en, this message translates to:
  /// **'Official source'**
  String get officialSource;

  /// No description provided for @manufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get manufacturer;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @selectMedicine3.
  ///
  /// In en, this message translates to:
  /// **'Select medicine'**
  String get selectMedicine3;

  /// No description provided for @recordedPrice.
  ///
  /// In en, this message translates to:
  /// **'Recorded price'**
  String get recordedPrice;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strength;

  /// No description provided for @form.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get form;

  /// No description provided for @pack.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get pack;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @prescriptionsRemindersAllergiesAndConditionsSaved.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions, reminders, allergies and conditions. Saved on this device only.'**
  String get prescriptionsRemindersAllergiesAndConditionsSaved;

  /// No description provided for @shareMedicineList.
  ///
  /// In en, this message translates to:
  /// **'Share medicine list'**
  String get shareMedicineList;

  /// No description provided for @medicineListCopied.
  ///
  /// In en, this message translates to:
  /// **'Medicine list copied.'**
  String get medicineListCopied;

  /// No description provided for @prescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get prescriptions;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @scannedPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Scanned prescriptions'**
  String get scannedPrescriptions;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'{records} saved'**
  String saved(Object records);

  /// No description provided for @prescriptionsYouScanAppearHereSo.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions you scan appear here so you can review them later.'**
  String get prescriptionsYouScanAppearHereSo;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteThisPrescription.
  ///
  /// In en, this message translates to:
  /// **'Delete this prescription?'**
  String get deleteThisPrescription;

  /// No description provided for @thePhotoAndDetailsWillBe.
  ///
  /// In en, this message translates to:
  /// **'The photo and details will be removed from this device.'**
  String get thePhotoAndDetailsWillBe;

  /// No description provided for @noMedicinesWereReadFromThis.
  ///
  /// In en, this message translates to:
  /// **'No medicines were read from this prescription.'**
  String get noMedicinesWereReadFromThis;

  /// No description provided for @medicineReminders.
  ///
  /// In en, this message translates to:
  /// **'Medicine reminders'**
  String get medicineReminders;

  /// No description provided for @reminderSettings.
  ///
  /// In en, this message translates to:
  /// **'Reminder settings'**
  String get reminderSettings;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAReminderFromAScanned.
  ///
  /// In en, this message translates to:
  /// **'Add a reminder from a scanned prescription or a medicine page, or tap Add.'**
  String get addAReminderFromAScanned;

  /// No description provided for @ended.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get ended;

  /// No description provided for @until.
  ///
  /// In en, this message translates to:
  /// **'until {endDate}'**
  String until(Object endDate);

  /// No description provided for @refillAround.
  ///
  /// In en, this message translates to:
  /// **'Refill around {refillDate}'**
  String refillAround(Object refillDate);

  /// No description provided for @takenOfDosesInTheLast.
  ///
  /// In en, this message translates to:
  /// **'Taken {rate}% of doses in the last 7 days'**
  String takenOfDosesInTheLast(Object rate);

  /// No description provided for @deleteReminder.
  ///
  /// In en, this message translates to:
  /// **'Delete reminder'**
  String get deleteReminder;

  /// No description provided for @healthConditions.
  ///
  /// In en, this message translates to:
  /// **'Health conditions'**
  String get healthConditions;

  /// No description provided for @medicinePagesHighlightTheWarningsThat.
  ///
  /// In en, this message translates to:
  /// **'Medicine pages highlight the warnings that apply.'**
  String get medicinePagesHighlightTheWarningsThat;

  /// No description provided for @allergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergies;

  /// No description provided for @scannedPrescriptionsAreCheckedAgainstThis.
  ///
  /// In en, this message translates to:
  /// **'Scanned prescriptions are checked against this list.'**
  String get scannedPrescriptionsAreCheckedAgainstThis;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @entriesMarkedWereNotFoundIn.
  ///
  /// In en, this message translates to:
  /// **'Entries marked ? were not found in the MOPH ingredient list, so they cannot be checked. Try the ingredient name in English, e.g. \"Amoxicillin\".'**
  String get entriesMarkedWereNotFoundIn;

  /// No description provided for @medicineOrIngredientEGAmoxicillin.
  ///
  /// In en, this message translates to:
  /// **'Medicine or ingredient, e.g. Amoxicillin'**
  String get medicineOrIngredientEGAmoxicillin;

  /// No description provided for @addAllergy.
  ///
  /// In en, this message translates to:
  /// **'Add allergy'**
  String get addAllergy;

  /// No description provided for @thisCheckUsesMophIngredientAnd.
  ///
  /// In en, this message translates to:
  /// **'This check uses MOPH ingredient and class data. It cannot catch every reaction; always tell your doctor and pharmacist about allergies.'**
  String get thisCheckUsesMophIngredientAnd;

  /// No description provided for @ofVerified.
  ///
  /// In en, this message translates to:
  /// **'{verifiedCount} of {medicines} verified'**
  String ofVerified(Object verifiedCount, Object medicines);

  /// No description provided for @notVerifiedCheckWithYourPharmacist.
  ///
  /// In en, this message translates to:
  /// **'Not verified: check with your pharmacist.'**
  String get notVerifiedCheckWithYourPharmacist;

  /// No description provided for @addAFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'Add a family member'**
  String get addAFamilyMember;

  /// No description provided for @nameEGMom.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Mom)'**
  String get nameEGMom;

  /// No description provided for @remove2.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String remove2(Object name);

  /// No description provided for @theirAllergiesAndConditionsAreRemoved.
  ///
  /// In en, this message translates to:
  /// **'Their allergies and conditions are removed. Their prescriptions and reminders stay saved.'**
  String get theirAllergiesAndConditionsAreRemoved;

  /// No description provided for @remove3.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove3;

  /// No description provided for @familyMember.
  ///
  /// In en, this message translates to:
  /// **'Family member'**
  String get familyMember;

  /// No description provided for @welcomeToPharmalens.
  ///
  /// In en, this message translates to:
  /// **'Welcome to PharmaLens'**
  String get welcomeToPharmalens;

  /// No description provided for @yourMedicineSafetyAssistantForLebanon.
  ///
  /// In en, this message translates to:
  /// **'Your medicine safety assistant for Lebanon.'**
  String get yourMedicineSafetyAssistantForLebanon;

  /// No description provided for @readHandwrittenPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Read handwritten prescriptions'**
  String get readHandwrittenPrescriptions;

  /// No description provided for @officialMophPricesAndCheaperEquivalents.
  ///
  /// In en, this message translates to:
  /// **'Official MOPH prices and cheaper equivalents'**
  String get officialMophPricesAndCheaperEquivalents;

  /// No description provided for @allergyAndDuplicateChecks.
  ///
  /// In en, this message translates to:
  /// **'Allergy and duplicate checks'**
  String get allergyAndDuplicateChecks;

  /// No description provided for @remindersAndAlarmsForEveryDose.
  ///
  /// In en, this message translates to:
  /// **'Reminders and alarms for every dose'**
  String get remindersAndAlarmsForEveryDose;

  /// No description provided for @yourDataYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Your data, your phone'**
  String get yourDataYourPhone;

  /// No description provided for @toReadAPrescriptionItsPhoto.
  ///
  /// In en, this message translates to:
  /// **'To read a prescription, its photo is sent to Google\'s Gemini AI. Nothing else leaves your phone: your prescriptions, allergies and reminders are saved only on this device.'**
  String get toReadAPrescriptionItsPhoto;

  /// No description provided for @medicinesAreCheckedAgainstTheOfficial.
  ///
  /// In en, this message translates to:
  /// **'Medicines are checked against the official MOPH list'**
  String get medicinesAreCheckedAgainstTheOfficial;

  /// No description provided for @aiCanMakeMistakesAlwaysConfirm.
  ///
  /// In en, this message translates to:
  /// **'AI can make mistakes: always confirm with your pharmacist'**
  String get aiCanMakeMistakesAlwaysConfirm;

  /// No description provided for @deleteAnyScanAtAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Delete any scan at any time'**
  String get deleteAnyScanAtAnyTime;

  /// No description provided for @neverMissADose.
  ///
  /// In en, this message translates to:
  /// **'Never miss a dose'**
  String get neverMissADose;

  /// No description provided for @remindersCanRingLikeAnAlarm.
  ///
  /// In en, this message translates to:
  /// **'Reminders can ring like an alarm and say the medicine name. Allow notifications and alarms so they arrive on time.'**
  String get remindersCanRingLikeAnAlarm;

  /// No description provided for @setUpReminders.
  ///
  /// In en, this message translates to:
  /// **'Set up reminders'**
  String get setUpReminders;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @iUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get iUnderstand;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noPharmaciesWereFoundWithin5.
  ///
  /// In en, this message translates to:
  /// **'No pharmacies were found within 5 km.'**
  String get noPharmaciesWereFoundWithin5;

  /// No description provided for @nearbyHealthcareSearchIsTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Nearby healthcare search is temporarily unavailable. Please try again.'**
  String get nearbyHealthcareSearchIsTemporarilyUnavailable;

  /// No description provided for @yourLocationCouldNotBeAccessed.
  ///
  /// In en, this message translates to:
  /// **'Your location could not be accessed.'**
  String get yourLocationCouldNotBeAccessed;

  /// No description provided for @locationServicesAreDisabledEnableGps.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Enable GPS to find nearby healthcare services.'**
  String get locationServicesAreDisabledEnableGps;

  /// No description provided for @locationPermissionCouldNotBeChecked.
  ///
  /// In en, this message translates to:
  /// **'Location permission could not be checked.'**
  String get locationPermissionCouldNotBeChecked;

  /// No description provided for @locationPermissionIsRequiredToFind.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to find nearby pharmacies and medical centers.'**
  String get locationPermissionIsRequiredToFind;

  /// No description provided for @locationPermissionIsBlockedEnableIt.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked. Enable it from app settings.'**
  String get locationPermissionIsBlockedEnableIt;

  /// No description provided for @yourCurrentLocationCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'Your current location could not be determined. Check GPS and try again.'**
  String get yourCurrentLocationCouldNotBe;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @pharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get pharmacy;

  /// No description provided for @medicalCenter.
  ///
  /// In en, this message translates to:
  /// **'Medical center'**
  String get medicalCenter;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get openNow;

  /// No description provided for @closedNow.
  ///
  /// In en, this message translates to:
  /// **'Closed now'**
  String get closedNow;

  /// No description provided for @couldNotOpenDirections.
  ///
  /// In en, this message translates to:
  /// **'Could not open directions.'**
  String get couldNotOpenDirections;

  /// No description provided for @noPhoneNumberIsAvailableFor.
  ///
  /// In en, this message translates to:
  /// **'No phone number is available for this location.'**
  String get noPhoneNumberIsAvailableFor;

  /// No description provided for @couldNotOpenThePhoneApplication.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone application.'**
  String get couldNotOpenThePhoneApplication;

  /// No description provided for @enableLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable location'**
  String get enableLocation;

  /// No description provided for @enableGpsToFindTheClosest.
  ///
  /// In en, this message translates to:
  /// **'Enable GPS to find the closest pharmacies and medical centers.'**
  String get enableGpsToFindTheClosest;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @locationPermission.
  ///
  /// In en, this message translates to:
  /// **'Location permission'**
  String get locationPermission;

  /// No description provided for @nearbyHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Nearby healthcare'**
  String get nearbyHealthcare;

  /// No description provided for @googleListing.
  ///
  /// In en, this message translates to:
  /// **'Google listing'**
  String get googleListing;

  /// No description provided for @retry2.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry2;

  /// No description provided for @findingNearbyHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Finding nearby healthcare...'**
  String get findingNearbyHealthcare;

  /// No description provided for @closestToYou.
  ///
  /// In en, this message translates to:
  /// **'Closest to you'**
  String get closestToYou;

  /// No description provided for @noNearbyResultsYet.
  ///
  /// In en, this message translates to:
  /// **'No nearby results yet.'**
  String get noNearbyResultsYet;

  /// No description provided for @m.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String m(Object meters);

  /// No description provided for @km.
  ///
  /// In en, this message translates to:
  /// **'{kilometers} km'**
  String km(Object kilometers);

  /// No description provided for @chooseAppearance.
  ///
  /// In en, this message translates to:
  /// **'Choose appearance'**
  String get chooseAppearance;

  /// No description provided for @chooseLightDarkOrFollowThe.
  ///
  /// In en, this message translates to:
  /// **'Choose light, dark, or follow the device appearance.'**
  String get chooseLightDarkOrFollowThe;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// No description provided for @brightMedicalInterface.
  ///
  /// In en, this message translates to:
  /// **'Bright medical interface'**
  String get brightMedicalInterface;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @comfortableDarkInterface.
  ///
  /// In en, this message translates to:
  /// **'Comfortable dark interface'**
  String get comfortableDarkInterface;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @followTheDeviceAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Follow the device automatically'**
  String get followTheDeviceAutomatically;

  /// No description provided for @couldNotOpenTheLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get couldNotOpenTheLink;

  /// No description provided for @helloIAmContactingYouFrom.
  ///
  /// In en, this message translates to:
  /// **'Hello, I am contacting you from PharmaLens.'**
  String get helloIAmContactingYouFrom;

  /// No description provided for @couldNotOpenWhatsappOnThis.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp on this device.'**
  String get couldNotOpenWhatsappOnThis;

  /// No description provided for @aboutPharmalens.
  ///
  /// In en, this message translates to:
  /// **'About PharmaLens'**
  String get aboutPharmalens;

  /// No description provided for @pharmalensIsAMedicineAndPrescription.
  ///
  /// In en, this message translates to:
  /// **'PharmaLens is a medicine and prescription support application designed to help users and pharmacists review medicine information more safely.'**
  String get pharmalensIsAMedicineAndPrescription;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @failedToSyncWithMophServer.
  ///
  /// In en, this message translates to:
  /// **'Failed to sync with MOPH server. Using local dataset.'**
  String get failedToSyncWithMophServer;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @contact2.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact2;

  /// No description provided for @contactOnWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Contact on WhatsApp'**
  String get contactOnWhatsapp;

  /// No description provided for @dataSync.
  ///
  /// In en, this message translates to:
  /// **'Data & Sync'**
  String get dataSync;

  /// No description provided for @syncMophMedicineData.
  ///
  /// In en, this message translates to:
  /// **'Sync MOPH Medicine Data'**
  String get syncMophMedicineData;

  /// No description provided for @syncingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing in progress…'**
  String get syncingInProgress;

  /// No description provided for @mophListOfMedicines.
  ///
  /// In en, this message translates to:
  /// **'MOPH list of {publishedDate} · {totalMedicineCount} medicines'**
  String mophListOfMedicines(Object publishedDate, Object totalMedicineCount);

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {appVersion} • {developerTeam}'**
  String version(Object appVersion, Object developerTeam);

  /// No description provided for @languageAppearanceAndApplicationInformation.
  ///
  /// In en, this message translates to:
  /// **'Language, appearance and application information'**
  String get languageAppearanceAndApplicationInformation;

  /// No description provided for @medicineAndPrescriptionSupportWithSafety.
  ///
  /// In en, this message translates to:
  /// **'Medicine and prescription support with safety-first verification.'**
  String get medicineAndPrescriptionSupportWithSafety;

  /// No description provided for @medicalDisclaimer2.
  ///
  /// In en, this message translates to:
  /// **'Medical disclaimer'**
  String get medicalDisclaimer2;

  /// No description provided for @developedBy.
  ///
  /// In en, this message translates to:
  /// **'Developed by {developer}'**
  String developedBy(Object developer);

  /// No description provided for @madeInLebanonByLebaneseDevelopers.
  ///
  /// In en, this message translates to:
  /// **'Made in Lebanon 🇱🇧 by Lebanese developers, for patients in Lebanon.'**
  String get madeInLebanonByLebaneseDevelopers;

  /// No description provided for @asWrittenByYourDoctor.
  ///
  /// In en, this message translates to:
  /// **'As written by your doctor'**
  String get asWrittenByYourDoctor;

  /// No description provided for @thisInformationCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'This information could not be loaded. Pull down to try again.'**
  String get thisInformationCouldNotBeLoaded;

  /// No description provided for @loadingMedicineInformationAndAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Loading medicine information and alternatives...'**
  String get loadingMedicineInformationAndAlternatives;

  /// No description provided for @doNotChangeTheDoseProduct.
  ///
  /// In en, this message translates to:
  /// **'Do not change the dose, product, dosage form, or route based on this page alone. Any substitution should be confirmed with a doctor or pharmacist.'**
  String get doNotChangeTheDoseProduct;

  /// No description provided for @prescriptionMatch.
  ///
  /// In en, this message translates to:
  /// **'Prescription match'**
  String get prescriptionMatch;

  /// No description provided for @selectedProduct.
  ///
  /// In en, this message translates to:
  /// **'Selected product'**
  String get selectedProduct;

  /// No description provided for @medicineOverview.
  ///
  /// In en, this message translates to:
  /// **'Medicine overview'**
  String get medicineOverview;

  /// No description provided for @drugFamily.
  ///
  /// In en, this message translates to:
  /// **'Drug family'**
  String get drugFamily;

  /// No description provided for @composition.
  ///
  /// In en, this message translates to:
  /// **'Composition'**
  String get composition;

  /// No description provided for @dosageForm.
  ///
  /// In en, this message translates to:
  /// **'Dosage form'**
  String get dosageForm;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @whyIsThisMedicineUsed.
  ///
  /// In en, this message translates to:
  /// **'Why is this medicine used?'**
  String get whyIsThisMedicineUsed;

  /// No description provided for @howItIsUsuallyTaken.
  ///
  /// In en, this message translates to:
  /// **'How it is usually taken'**
  String get howItIsUsuallyTaken;

  /// No description provided for @usualUse.
  ///
  /// In en, this message translates to:
  /// **'Usual use'**
  String get usualUse;

  /// No description provided for @foodInstructions.
  ///
  /// In en, this message translates to:
  /// **'Food instructions'**
  String get foodInstructions;

  /// No description provided for @noDirectionsAreWrittenOnThe.
  ///
  /// In en, this message translates to:
  /// **'PharmaLens could not read directions for this medicine on the prescription. Check the paper, or ask your doctor or pharmacist how to take it.'**
  String get noDirectionsAreWrittenOnThe;

  /// No description provided for @howToUse.
  ///
  /// In en, this message translates to:
  /// **'How to use'**
  String get howToUse;

  /// No description provided for @sideEffects.
  ///
  /// In en, this message translates to:
  /// **'Side effects'**
  String get sideEffects;

  /// No description provided for @commonSideEffects2.
  ///
  /// In en, this message translates to:
  /// **'Common side effects'**
  String get commonSideEffects2;

  /// No description provided for @seriousWarnings.
  ///
  /// In en, this message translates to:
  /// **'Serious warnings'**
  String get seriousWarnings;

  /// No description provided for @warningsSafety.
  ///
  /// In en, this message translates to:
  /// **'Warnings & safety'**
  String get warningsSafety;

  /// No description provided for @contraindications.
  ///
  /// In en, this message translates to:
  /// **'Contraindications'**
  String get contraindications;

  /// No description provided for @interactions.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get interactions;

  /// No description provided for @pregnancyBreastfeeding.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy & breastfeeding'**
  String get pregnancyBreastfeeding;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @alternatives.
  ///
  /// In en, this message translates to:
  /// **'Alternatives ({alternatives})'**
  String alternatives(Object alternatives);

  /// No description provided for @alternativesAreTemporarilyUnavailableTryRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Alternatives are temporarily unavailable. Try refreshing again.'**
  String get alternativesAreTemporarilyUnavailableTryRefreshing;

  /// No description provided for @noVerifiedAlternativesWereFoundIn.
  ///
  /// In en, this message translates to:
  /// **'No verified alternatives were found in the current data.'**
  String get noVerifiedAlternativesWereFoundIn;

  /// No description provided for @differentStrength.
  ///
  /// In en, this message translates to:
  /// **'Different strength'**
  String get differentStrength;

  /// No description provided for @differentForm.
  ///
  /// In en, this message translates to:
  /// **'Different form'**
  String get differentForm;

  /// No description provided for @differentRoute.
  ///
  /// In en, this message translates to:
  /// **'Different route'**
  String get differentRoute;

  /// No description provided for @productInformation.
  ///
  /// In en, this message translates to:
  /// **'Product information'**
  String get productInformation;

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brand;

  /// No description provided for @activeIngredient.
  ///
  /// In en, this message translates to:
  /// **'Active ingredient'**
  String get activeIngredient;

  /// No description provided for @manufacturer2.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get manufacturer2;

  /// No description provided for @registration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registration;

  /// No description provided for @priceDate.
  ///
  /// In en, this message translates to:
  /// **'Price date'**
  String get priceDate;

  /// No description provided for @productPriceSource.
  ///
  /// In en, this message translates to:
  /// **'Product / price source'**
  String get productPriceSource;

  /// No description provided for @clinicalSource.
  ///
  /// In en, this message translates to:
  /// **'Clinical source'**
  String get clinicalSource;

  /// No description provided for @lastReviewed.
  ///
  /// In en, this message translates to:
  /// **'Last reviewed'**
  String get lastReviewed;

  /// No description provided for @reviewedBy.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by'**
  String get reviewedBy;

  /// No description provided for @sourcesReview.
  ///
  /// In en, this message translates to:
  /// **'Sources & review'**
  String get sourcesReview;

  /// No description provided for @noAdditionalSourceInformationIsCurrently.
  ///
  /// In en, this message translates to:
  /// **'No additional source information is currently available.'**
  String get noAdditionalSourceInformationIsCurrently;

  /// No description provided for @activeIngredient2.
  ///
  /// In en, this message translates to:
  /// **'Active ingredient: '**
  String get activeIngredient2;

  /// No description provided for @usedFor.
  ///
  /// In en, this message translates to:
  /// **'Used for: '**
  String get usedFor;

  /// No description provided for @howToTakeIt.
  ///
  /// In en, this message translates to:
  /// **'How to take it: '**
  String get howToTakeIt;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @readAloudIsNotAvailableOn.
  ///
  /// In en, this message translates to:
  /// **'Read aloud is not available on this device.'**
  String get readAloudIsNotAvailableOn;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @readAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get readAloud;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @addReminder.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get addReminder;

  /// No description provided for @loadingMedicineInformationUsesSideEffects.
  ///
  /// In en, this message translates to:
  /// **'Loading medicine information (uses, side effects, warnings)…'**
  String get loadingMedicineInformationUsesSideEffects;

  /// No description provided for @couldNotLoadTheMedicineInformation.
  ///
  /// In en, this message translates to:
  /// **'Could not load the medicine information. Check your internet connection.'**
  String get couldNotLoadTheMedicineInformation;

  /// No description provided for @noFurtherInformationIsAvailableFor.
  ///
  /// In en, this message translates to:
  /// **'No further information is available for this medicine yet.'**
  String get noFurtherInformationIsAvailableFor;

  /// No description provided for @aiSummaryOfTheUS.
  ///
  /// In en, this message translates to:
  /// **'AI summary of the U.S. FDA label for the same active ingredient{sourceTitle}. The Lebanese product can differ slightly, and the summary can contain mistakes.'**
  String aiSummaryOfTheUS(Object sourceTitle);

  /// No description provided for @fromTheUSFdaLabel.
  ///
  /// In en, this message translates to:
  /// **'From the U.S. FDA label for the same active ingredient{sourceTitle}.'**
  String fromTheUSFdaLabel(Object sourceTitle);

  /// No description provided for @writtenByAiBecauseNoOfficial.
  ///
  /// In en, this message translates to:
  /// **'Written by AI because no official leaflet was found. It can contain mistakes: check it with your pharmacist or the leaflet in the box.'**
  String get writtenByAiBecauseNoOfficial;

  /// No description provided for @openLabel.
  ///
  /// In en, this message translates to:
  /// **'Open label'**
  String get openLabel;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @activeIngredients.
  ///
  /// In en, this message translates to:
  /// **'Active ingredients'**
  String get activeIngredients;

  /// No description provided for @therapeuticGroup.
  ///
  /// In en, this message translates to:
  /// **'Therapeutic group'**
  String get therapeuticGroup;

  /// No description provided for @officialPrice.
  ///
  /// In en, this message translates to:
  /// **'Official price'**
  String get officialPrice;

  /// No description provided for @lbp.
  ///
  /// In en, this message translates to:
  /// **'LBP'**
  String get lbp;

  /// No description provided for @listOf.
  ///
  /// In en, this message translates to:
  /// **' (list of {lastUpdatedDate})'**
  String listOf(Object lastUpdatedDate);

  /// No description provided for @fromTheMophRegistry.
  ///
  /// In en, this message translates to:
  /// **'From the MOPH registry'**
  String get fromTheMophRegistry;

  /// No description provided for @officialDataNotMedicalAdvice.
  ///
  /// In en, this message translates to:
  /// **'Official data, not medical advice'**
  String get officialDataNotMedicalAdvice;

  /// No description provided for @thisPriceMayBeOutOf.
  ///
  /// In en, this message translates to:
  /// **'This price may be out of date. Confirm it at the pharmacy.'**
  String get thisPriceMayBeOutOf;

  /// No description provided for @doNotSwitchBeforeAskingYour.
  ///
  /// In en, this message translates to:
  /// **'Do not switch before asking your doctor or pharmacist, even when the ingredient is the same.'**
  String get doNotSwitchBeforeAskingYour;

  /// No description provided for @lbpEach.
  ///
  /// In en, this message translates to:
  /// **'{perUnit} LBP each'**
  String lbpEach(Object perUnit);

  /// No description provided for @pharmalensPrescriptionReading.
  ///
  /// In en, this message translates to:
  /// **'PharmaLens prescription reading'**
  String get pharmalensPrescriptionReading;

  /// No description provided for @generalAiKnowledge.
  ///
  /// In en, this message translates to:
  /// **'General AI knowledge'**
  String get generalAiKnowledge;

  /// No description provided for @theAssistantIsBusyRightNow.
  ///
  /// In en, this message translates to:
  /// **'The assistant is busy right now. Please try again in a minute.'**
  String get theAssistantIsBusyRightNow;

  /// No description provided for @theAssistantIsNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'The assistant is not set up on this device.'**
  String get theAssistantIsNotSetUp;

  /// No description provided for @sorryICouldNotAnswerRight.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I could not answer right now. Check your internet connection and try again.'**
  String get sorryICouldNotAnswerRight;

  /// No description provided for @mophPriceList2.
  ///
  /// In en, this message translates to:
  /// **'MOPH price list {publishedDate}'**
  String mophPriceList2(Object publishedDate);

  /// No description provided for @pharmalensSafetyCheck.
  ///
  /// In en, this message translates to:
  /// **'PharmaLens safety check'**
  String get pharmalensSafetyCheck;

  /// No description provided for @yourDataOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Your data on this device'**
  String get yourDataOnThisDevice;

  /// No description provided for @fdaLabelAiSummary.
  ///
  /// In en, this message translates to:
  /// **'FDA label / AI summary'**
  String get fdaLabelAiSummary;

  /// No description provided for @lebaneseOrderOfPhysicians.
  ///
  /// In en, this message translates to:
  /// **'Lebanese Order of Physicians'**
  String get lebaneseOrderOfPhysicians;

  /// No description provided for @pregnant.
  ///
  /// In en, this message translates to:
  /// **'Pregnant'**
  String get pregnant;

  /// No description provided for @breastfeeding.
  ///
  /// In en, this message translates to:
  /// **'Breastfeeding'**
  String get breastfeeding;

  /// No description provided for @childUnder12.
  ///
  /// In en, this message translates to:
  /// **'Child (under 12)'**
  String get childUnder12;

  /// No description provided for @kidneyDisease.
  ///
  /// In en, this message translates to:
  /// **'Kidney disease'**
  String get kidneyDisease;

  /// No description provided for @liverDisease.
  ///
  /// In en, this message translates to:
  /// **'Liver disease'**
  String get liverDisease;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @medicineList.
  ///
  /// In en, this message translates to:
  /// **'Medicine list'**
  String get medicineList;

  /// No description provided for @ifThisLineIs.
  ///
  /// In en, this message translates to:
  /// **'If this line is {names}: '**
  String ifThisLineIs(Object names);

  /// No description provided for @mayContainSomethingOnYourAllergy.
  ///
  /// In en, this message translates to:
  /// **'{prefix}{names} may contain something on your allergy list. Do not take it before talking to your doctor or pharmacist.'**
  String mayContainSomethingOnYourAllergy(Object prefix, Object names);

  /// No description provided for @isInTheSameDrugClass.
  ///
  /// In en, this message translates to:
  /// **'{prefix}{names} is in the same drug class as something on your allergy list. Cross-reactions are possible; ask your doctor or pharmacist before taking it.'**
  String isInTheSameDrugClass(Object prefix, Object names);

  /// No description provided for @theSameActiveIngredientIsIn.
  ///
  /// In en, this message translates to:
  /// **'The same active ingredient is in: {names}. Taking them together can exceed a safe dose. Check with your doctor or pharmacist.'**
  String theSameActiveIngredientIsIn(Object names);

  /// No description provided for @belongToTheSameTherapeuticClass.
  ///
  /// In en, this message translates to:
  /// **'{names} belong to the same therapeutic class. Ask your doctor or pharmacist whether both are intended.'**
  String belongToTheSameTherapeuticClass(Object names);

  /// No description provided for @fromTheReviewedMedicineProfile.
  ///
  /// In en, this message translates to:
  /// **'From the reviewed medicine profile'**
  String get fromTheReviewedMedicineProfile;

  /// No description provided for @basedOnTheAtcCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Based on the ATC code in the medicine record'**
  String get basedOnTheAtcCodeIn;

  /// No description provided for @basedOnTheRegisteredActiveIngredient.
  ///
  /// In en, this message translates to:
  /// **'Based on the registered active ingredient'**
  String get basedOnTheRegisteredActiveIngredient;

  /// No description provided for @loadingTheMedicineList.
  ///
  /// In en, this message translates to:
  /// **'Loading the medicine list…'**
  String get loadingTheMedicineList;

  /// No description provided for @checkingForNewData.
  ///
  /// In en, this message translates to:
  /// **'Checking for new data…'**
  String get checkingForNewData;

  /// No description provided for @downloadingTheNewList.
  ///
  /// In en, this message translates to:
  /// **'Downloading the new list…'**
  String get downloadingTheNewList;

  /// No description provided for @verifyingTheList.
  ///
  /// In en, this message translates to:
  /// **'Verifying the list…'**
  String get verifyingTheList;

  /// No description provided for @applyingTheUpdate.
  ///
  /// In en, this message translates to:
  /// **'Applying the update…'**
  String get applyingTheUpdate;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknown;

  /// No description provided for @revised.
  ///
  /// In en, this message translates to:
  /// **'{date}, revised {publishedDate}'**
  String revised(Object date, Object publishedDate);

  /// No description provided for @updatedToTheMophListOf.
  ///
  /// In en, this message translates to:
  /// **'Updated to the MOPH list of {date} ({medicineCount} medicines).'**
  String updatedToTheMophListOf(Object date, Object medicineCount);

  /// No description provided for @youAlreadyHaveTheLatestMoph.
  ///
  /// In en, this message translates to:
  /// **'You already have the latest MOPH list ({date}).'**
  String youAlreadyHaveTheLatestMoph(Object date);

  /// No description provided for @usingTheMophListOfNew.
  ///
  /// In en, this message translates to:
  /// **'Using the MOPH list of {date}. New lists arrive with app updates.'**
  String usingTheMophListOfNew(Object date);

  /// No description provided for @couldNotCheckForANewer.
  ///
  /// In en, this message translates to:
  /// **'Could not check for a newer MOPH list. Showing the list of {date}.'**
  String couldNotCheckForANewer(Object date);

  /// No description provided for @timeFor.
  ///
  /// In en, this message translates to:
  /// **'Time for {medicineName}'**
  String timeFor(Object medicineName);

  /// No description provided for @itIsTimeForYourDose.
  ///
  /// In en, this message translates to:
  /// **'It is time for your dose as prescribed.'**
  String get itIsTimeForYourDose;

  /// No description provided for @taken3.
  ///
  /// In en, this message translates to:
  /// **'Taken ✓'**
  String get taken3;

  /// No description provided for @snoozeMin2.
  ///
  /// In en, this message translates to:
  /// **'Snooze {snoozeMinutes} min'**
  String snoozeMin2(Object snoozeMinutes);

  /// No description provided for @medicineAlarms.
  ///
  /// In en, this message translates to:
  /// **'Medicine alarms'**
  String get medicineAlarms;

  /// No description provided for @medicineReminders2.
  ///
  /// In en, this message translates to:
  /// **'Medicine reminders'**
  String get medicineReminders2;

  /// No description provided for @hiIAmThePharmalensAssistant.
  ///
  /// In en, this message translates to:
  /// **'### Hi, I am the PharmaLens assistant\nI answer from the **official MOPH price list** and the data saved in this app. You can ask me to:\n- Find a medicine, its official price and **cheaper equivalents**\n- Read a **prescription photo** and check it against the MOPH list\n- Check medicines against **your allergies** and each other\n- Explain uses, side effects and how to take a medicine\n- Find **doctors** and **nearby pharmacies**'**
  String get hiIAmThePharmalensAssistant;

  /// No description provided for @couldNotAttachImagePleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Could not attach image. Please try again.'**
  String get couldNotAttachImagePleaseTry;

  /// No description provided for @pleaseAnalyzeThisPrescriptionImageFor.
  ///
  /// In en, this message translates to:
  /// **'Please analyze this prescription image for me.'**
  String get pleaseAnalyzeThisPrescriptionImageFor;

  /// No description provided for @pharmalensAi.
  ///
  /// In en, this message translates to:
  /// **'PharmaLens AI'**
  String get pharmalensAi;

  /// No description provided for @answersFromTheMophListAnd.
  ///
  /// In en, this message translates to:
  /// **'Answers from the MOPH list and your data'**
  String get answersFromTheMophListAnd;

  /// No description provided for @clearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get clearChat;

  /// No description provided for @cheaperThanAugmentin1g.
  ///
  /// In en, this message translates to:
  /// **'Cheaper than Augmentin 1g?'**
  String get cheaperThanAugmentin1g;

  /// No description provided for @whatIsTheOfficialPriceOf.
  ///
  /// In en, this message translates to:
  /// **'What is the official price of Augmentin 1g and which equivalent products are cheaper?'**
  String get whatIsTheOfficialPriceOf;

  /// No description provided for @checkMyLastPrescription.
  ///
  /// In en, this message translates to:
  /// **'Check my last prescription'**
  String get checkMyLastPrescription;

  /// No description provided for @checkTheMedicinesOfMyLast.
  ///
  /// In en, this message translates to:
  /// **'Check the medicines of my last prescription against my allergies and each other.'**
  String get checkTheMedicinesOfMyLast;

  /// No description provided for @panadolSideEffects.
  ///
  /// In en, this message translates to:
  /// **'Panadol side effects'**
  String get panadolSideEffects;

  /// No description provided for @whatAreTheCommonSideEffects.
  ///
  /// In en, this message translates to:
  /// **'What are the common side effects of Panadol 500mg and how should I take it?'**
  String get whatAreTheCommonSideEffects;

  /// No description provided for @pharmaciesNearMe.
  ///
  /// In en, this message translates to:
  /// **'Pharmacies near me'**
  String get pharmaciesNearMe;

  /// No description provided for @whichPharmaciesAreNearMeAnd.
  ///
  /// In en, this message translates to:
  /// **'Which pharmacies are near me and open now?'**
  String get whichPharmaciesAreNearMeAnd;

  /// No description provided for @findACardiologist.
  ///
  /// In en, this message translates to:
  /// **'Find a cardiologist'**
  String get findACardiologist;

  /// No description provided for @findCardiologistsInBeirut.
  ///
  /// In en, this message translates to:
  /// **'Find cardiologists in Beirut.'**
  String get findCardiologistsInBeirut;

  /// No description provided for @aiAnswerItCanBeWrong.
  ///
  /// In en, this message translates to:
  /// **'AI answer: it can be wrong. Review with your doctor or pharmacist.'**
  String get aiAnswerItCanBeWrong;

  /// No description provided for @readingThePrescription.
  ///
  /// In en, this message translates to:
  /// **'Reading the prescription…'**
  String get readingThePrescription;

  /// No description provided for @searchingTheMophList.
  ///
  /// In en, this message translates to:
  /// **'Searching the MOPH list…'**
  String get searchingTheMophList;

  /// No description provided for @comparingEquivalentProducts.
  ///
  /// In en, this message translates to:
  /// **'Comparing equivalent products…'**
  String get comparingEquivalentProducts;

  /// No description provided for @checkingAllergiesAndDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Checking allergies and duplicates…'**
  String get checkingAllergiesAndDuplicates;

  /// No description provided for @readingYourSavedData.
  ///
  /// In en, this message translates to:
  /// **'Reading your saved data…'**
  String get readingYourSavedData;

  /// No description provided for @lookingUpPatientInformation.
  ///
  /// In en, this message translates to:
  /// **'Looking up patient information…'**
  String get lookingUpPatientInformation;

  /// No description provided for @searchingDoctors.
  ///
  /// In en, this message translates to:
  /// **'Searching doctors…'**
  String get searchingDoctors;

  /// No description provided for @findingNearbyPharmacies.
  ///
  /// In en, this message translates to:
  /// **'Finding nearby pharmacies…'**
  String get findingNearbyPharmacies;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinking;

  /// No description provided for @iAmAnAiAndCan.
  ///
  /// In en, this message translates to:
  /// **'I am an AI and can make mistakes. Always review medical decisions with your doctor or pharmacist.'**
  String get iAmAnAiAndCan;

  /// No description provided for @prescriptionPhotoAttached.
  ///
  /// In en, this message translates to:
  /// **'Prescription photo attached'**
  String get prescriptionPhotoAttached;

  /// No description provided for @takePhoto2.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto2;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose Photo'**
  String get choosePhoto;

  /// No description provided for @askMedicinePriceOrPrescription.
  ///
  /// In en, this message translates to:
  /// **'Ask medicine, price, or prescription...'**
  String get askMedicinePriceOrPrescription;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get aiAssistant;

  /// No description provided for @theLabelInformationHereSaysNothing.
  ///
  /// In en, this message translates to:
  /// **'The label information here says nothing specific about this. Ask your doctor or pharmacist before taking it.'**
  String get theLabelInformationHereSaysNothing;

  /// No description provided for @basedOnTheHealthProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Based on the health profile saved on this device. For review only; it does not replace your doctor.'**
  String get basedOnTheHealthProfileSaved;

  /// No description provided for @checkWhatTheMedicineLabelsSay.
  ///
  /// In en, this message translates to:
  /// **'Check what the medicine labels say about taking these together.'**
  String get checkWhatTheMedicineLabelsSay;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @readingTheMedicineLabels.
  ///
  /// In en, this message translates to:
  /// **'Reading the medicine labels…'**
  String get readingTheMedicineLabels;

  /// No description provided for @theLabelsDoNotMentionEach.
  ///
  /// In en, this message translates to:
  /// **'The labels do not mention each other'**
  String get theLabelsDoNotMentionEach;

  /// No description provided for @theLabelsMentionEachOther.
  ///
  /// In en, this message translates to:
  /// **'The labels mention each other'**
  String get theLabelsMentionEachOther;

  /// No description provided for @labelAbout.
  ///
  /// In en, this message translates to:
  /// **'{labelOf} label, about {mentions}:'**
  String labelAbout(Object labelOf, Object mentions);

  /// No description provided for @fromUSFdaLabelsFor.
  ///
  /// In en, this message translates to:
  /// **'From U.S. FDA labels for the same ingredients (summarized by AI). Not a full interaction check: ask your pharmacist.'**
  String get fromUSFdaLabelsFor;

  /// No description provided for @newReminder.
  ///
  /// In en, this message translates to:
  /// **'New reminder'**
  String get newReminder;

  /// No description provided for @editReminder.
  ///
  /// In en, this message translates to:
  /// **'Edit reminder'**
  String get editReminder;

  /// No description provided for @medicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get medicine;

  /// No description provided for @doseAsPrescribedOptional.
  ///
  /// In en, this message translates to:
  /// **'Dose as prescribed (optional)'**
  String get doseAsPrescribedOptional;

  /// No description provided for @eG1TabletAfterFood.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1 tablet after food'**
  String get eG1TabletAfterFood;

  /// No description provided for @howToRemindMe.
  ///
  /// In en, this message translates to:
  /// **'How to remind me'**
  String get howToRemindMe;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @alarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get alarm;

  /// No description provided for @ringsWithThePharmalensToneUntil.
  ///
  /// In en, this message translates to:
  /// **'Rings with the alarm sound until you answer, and opens a screen with Taken and Snooze, even on the lock screen.'**
  String get ringsWithThePharmalensToneUntil;

  /// No description provided for @aNotificationWithTakenAndSnooze.
  ///
  /// In en, this message translates to:
  /// **'A notification with Taken and Snooze buttons.'**
  String get aNotificationWithTakenAndSnooze;

  /// No description provided for @sayTheMedicineNameAloud.
  ///
  /// In en, this message translates to:
  /// **'Say the medicine name aloud'**
  String get sayTheMedicineNameAloud;

  /// No description provided for @itIs800TimeTo.
  ///
  /// In en, this message translates to:
  /// **'\"It is 8:00. Time to take …\"'**
  String get itIs800TimeTo;

  /// No description provided for @timesEachDay.
  ///
  /// In en, this message translates to:
  /// **'Times each day'**
  String get timesEachDay;

  /// No description provided for @removeTime.
  ///
  /// In en, this message translates to:
  /// **'Remove time'**
  String get removeTime;

  /// No description provided for @addTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get addTime;

  /// No description provided for @onceADay.
  ///
  /// In en, this message translates to:
  /// **'Once a day'**
  String get onceADay;

  /// No description provided for @twice.
  ///
  /// In en, this message translates to:
  /// **'Twice'**
  String get twice;

  /// No description provided for @n3Times.
  ///
  /// In en, this message translates to:
  /// **'3 times'**
  String get n3Times;

  /// No description provided for @every6H.
  ///
  /// In en, this message translates to:
  /// **'Every 6 h'**
  String get every6H;

  /// No description provided for @forHowLong.
  ///
  /// In en, this message translates to:
  /// **'For how long'**
  String get forHowLong;

  /// No description provided for @takenFromThePrescriptionDirections.
  ///
  /// In en, this message translates to:
  /// **'Taken from the prescription directions'**
  String get takenFromThePrescriptionDirections;

  /// No description provided for @noEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get noEndDate;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String days(Object days);

  /// No description provided for @remindMeToRefill.
  ///
  /// In en, this message translates to:
  /// **'Remind me to refill'**
  String get remindMeToRefill;

  /// No description provided for @estimatesWhenYourSupplyRunsOut.
  ///
  /// In en, this message translates to:
  /// **'Estimates when your supply runs out'**
  String get estimatesWhenYourSupplyRunsOut;

  /// No description provided for @unitsYouHave.
  ///
  /// In en, this message translates to:
  /// **'Units you have'**
  String get unitsYouHave;

  /// No description provided for @perDose.
  ///
  /// In en, this message translates to:
  /// **'Per dose'**
  String get perDose;

  /// No description provided for @notificationsAreNotAvailableInThe.
  ///
  /// In en, this message translates to:
  /// **'Notifications are not available in the web version. Install the app to get alerts.'**
  String get notificationsAreNotAvailableInThe;

  /// No description provided for @followTheDoseAndDurationOn.
  ///
  /// In en, this message translates to:
  /// **'Follow the dose and duration on your prescription. Reminders do not replace your doctor\'s instructions.'**
  String get followTheDoseAndDurationOn;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @setUpMedicineReminders.
  ///
  /// In en, this message translates to:
  /// **'Set up medicine reminders'**
  String get setUpMedicineReminders;

  /// No description provided for @allowTheseSoRemindersAndAlarms.
  ///
  /// In en, this message translates to:
  /// **'Allow these so reminders and alarms arrive on time, even when the phone is locked.'**
  String get allowTheseSoRemindersAndAlarms;

  /// No description provided for @thisDeviceNeedsNoExtraSettings.
  ///
  /// In en, this message translates to:
  /// **'This device needs no extra settings. On the web, reminders are listed but cannot ring while the page is closed.'**
  String get thisDeviceNeedsNoExtraSettings;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @requiredForEveryReminder.
  ///
  /// In en, this message translates to:
  /// **'Required for every reminder.'**
  String get requiredForEveryReminder;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @alarmsReminders.
  ///
  /// In en, this message translates to:
  /// **'Alarms & reminders'**
  String get alarmsReminders;

  /// No description provided for @ringsAtTheExactMinuteWithout.
  ///
  /// In en, this message translates to:
  /// **'Rings at the exact minute. Without it Android may be a few minutes late.'**
  String get ringsAtTheExactMinuteWithout;

  /// No description provided for @fullScreenAlarms.
  ///
  /// In en, this message translates to:
  /// **'Full-screen alarms'**
  String get fullScreenAlarms;

  /// No description provided for @letsAnAlarmShowTheDose.
  ///
  /// In en, this message translates to:
  /// **'Lets an alarm show the dose screen over the lock screen, with Taken and Snooze.'**
  String get letsAnAlarmShowTheDose;

  /// No description provided for @batteryUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'Battery: Unrestricted'**
  String get batteryUnrestricted;

  /// No description provided for @somePhonesXiaomiHuaweiOppoSamsung.
  ///
  /// In en, this message translates to:
  /// **'Some phones (Xiaomi, Huawei, Oppo, Samsung) stop reminders to save battery. In the app settings, open Battery and choose \"Unrestricted\".'**
  String get somePhonesXiaomiHuaweiOppoSamsung;

  /// No description provided for @displayOverOtherAppsIsNot.
  ///
  /// In en, this message translates to:
  /// **'\"Display over other apps\" is not needed: full-screen alarms already appear over other apps.'**
  String get displayOverOtherAppsIsNot;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @withoutNotificationsRemindersWillNotAlert.
  ///
  /// In en, this message translates to:
  /// **'Without notifications, reminders will not alert you. You can finish this later from any reminder.'**
  String get withoutNotificationsRemindersWillNotAlert;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'(recommended)'**
  String get recommended;

  /// No description provided for @showMoreLeft.
  ///
  /// In en, this message translates to:
  /// **'Show more ({left} left)'**
  String showMoreLeft(Object left);

  /// No description provided for @body.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get body;

  /// No description provided for @ageAndWeightHelpPharmalensPoint.
  ///
  /// In en, this message translates to:
  /// **'Age, height and weight let medicine pages warn you when a medicine may not suit you.'**
  String get ageAndWeightHelpPharmalensPoint;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @bmiValue.
  ///
  /// In en, this message translates to:
  /// **'BMI {bmi} · {category}'**
  String bmiValue(Object bmi, Object category);

  /// No description provided for @bmiUnderweight.
  ///
  /// In en, this message translates to:
  /// **'Underweight'**
  String get bmiUnderweight;

  /// No description provided for @bmiHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy weight'**
  String get bmiHealthy;

  /// No description provided for @bmiOverweight.
  ///
  /// In en, this message translates to:
  /// **'Overweight'**
  String get bmiOverweight;

  /// No description provided for @bmiObesity.
  ///
  /// In en, this message translates to:
  /// **'Obesity'**
  String get bmiObesity;

  /// No description provided for @checkWithYourDoctorBeforeUsingIt.
  ///
  /// In en, this message translates to:
  /// **'Check with your doctor before using it.'**
  String get checkWithYourDoctorBeforeUsingIt;

  /// No description provided for @ageYearsOld.
  ///
  /// In en, this message translates to:
  /// **'Age {age}'**
  String ageYearsOld(Object age);

  /// No description provided for @peopleOver65OftenNeedALower.
  ///
  /// In en, this message translates to:
  /// **'People over 65 are often more sensitive to medicines and may need a lower dose. Check with your doctor before using it.'**
  String get peopleOver65OftenNeedALower;

  /// No description provided for @weightKgValue.
  ///
  /// In en, this message translates to:
  /// **'Weight {weight} kg'**
  String weightKgValue(Object weight);

  /// No description provided for @theDoseDependsOnBodyWeight.
  ///
  /// In en, this message translates to:
  /// **'The dose of this medicine depends on body weight ({weight} kg). Ask your doctor or pharmacist for the right dose before using it. The label says:'**
  String theDoseDependsOnBodyWeight(Object weight);

  /// No description provided for @atThisWeightAdultDosesMay.
  ///
  /// In en, this message translates to:
  /// **'At this weight, a usual adult dose may be too high. Check with your doctor before using it.'**
  String get atThisWeightAdultDosesMay;

  /// No description provided for @thisIsAWeightLossMedicine.
  ///
  /// In en, this message translates to:
  /// **'This is a weight-loss medicine and your BMI is not high. Check with your doctor before using it.'**
  String get thisIsAWeightLossMedicine;

  /// No description provided for @showAllCount.
  ///
  /// In en, this message translates to:
  /// **'Show all ({count})'**
  String showAllCount(Object count);

  /// No description provided for @yourMedicine.
  ///
  /// In en, this message translates to:
  /// **'Your medicine'**
  String get yourMedicine;

  /// No description provided for @sameDoseCount.
  ///
  /// In en, this message translates to:
  /// **'Same dose · {count}'**
  String sameDoseCount(Object count);

  /// No description provided for @otherStrengthsFormsCount.
  ///
  /// In en, this message translates to:
  /// **'Other strengths & forms · {count}'**
  String otherStrengthsFormsCount(Object count);

  /// No description provided for @cheapestSameDoseSaves.
  ///
  /// In en, this message translates to:
  /// **'{brand} has the same ingredient, strength and form and costs {saving}% less.'**
  String cheapestSameDoseSaves(Object brand, Object saving);

  /// No description provided for @theseHaveTheSameIngredientBut.
  ///
  /// In en, this message translates to:
  /// **'Same ingredient, but the strength, form or route differs. The dose is not the same.'**
  String get theseHaveTheSameIngredientBut;

  /// No description provided for @savePercent.
  ///
  /// In en, this message translates to:
  /// **'−{percent}%'**
  String savePercent(Object percent);

  /// No description provided for @morePercent.
  ///
  /// In en, this message translates to:
  /// **'+{percent}%'**
  String morePercent(Object percent);

  /// No description provided for @alarmSound.
  ///
  /// In en, this message translates to:
  /// **'Alarm sound'**
  String get alarmSound;

  /// No description provided for @pharmalensTone.
  ///
  /// In en, this message translates to:
  /// **'PharmaLens tone'**
  String get pharmalensTone;

  /// No description provided for @theAppSOwnShortTone.
  ///
  /// In en, this message translates to:
  /// **'The app\'s own short tone'**
  String get theAppSOwnShortTone;

  /// No description provided for @phoneAlarmTones.
  ///
  /// In en, this message translates to:
  /// **'Phone alarm tones'**
  String get phoneAlarmTones;

  /// No description provided for @theTonesYourPhoneUsesFor.
  ///
  /// In en, this message translates to:
  /// **'The tones your phone uses for its alarm clock'**
  String get theTonesYourPhoneUsesFor;

  /// No description provided for @musicOrAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Music or audio file'**
  String get musicOrAudioFile;

  /// No description provided for @anySongOrRecordingOnThis.
  ///
  /// In en, this message translates to:
  /// **'Any song or recording on this phone'**
  String get anySongOrRecordingOnThis;

  /// No description provided for @customSound.
  ///
  /// In en, this message translates to:
  /// **'Chosen sound'**
  String get customSound;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
