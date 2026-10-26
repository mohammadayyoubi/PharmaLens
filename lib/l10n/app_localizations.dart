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
