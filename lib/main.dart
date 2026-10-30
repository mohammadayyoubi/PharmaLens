import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_settings_scope.dart';
import 'app/app_shell.dart';
import 'l10n/app_localizations.dart';
import 'services/connectivity_service.dart';
import 'screens/onboarding_screen.dart';
import 'services/doctors_service.dart';
import 'services/dose_log_service.dart';
import 'services/health_profile_service.dart';
import 'services/moph_medicine_service.dart';
import 'services/prescription_history_service.dart';
import 'services/reminder_service.dart';
import 'theme/pharmalens_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw first; load data behind the splash. Screens that need the medicine
  // list await MophMedicineService().initialize() or listen to its
  // `changes`, so nothing waits for data it does not use.
  runApp(
    const PharmaLensApp(),
  );

  // Parses its CSV in a background isolate and never throws; a load failure
  // is reported through loadError. New MOPH lists are published by
  // .github/workflows/update-moph-prices.yml.
  unawaited(
    MophMedicineService().initialize().then(
          (_) => MophMedicineService().startAutoUpdates(),
    ),
  );
  unawaited(ConnectivityService().start());
  unawaited(PrescriptionHistoryService().load());
  // Reminder titles name the family member ("Mom · Time for ..."), so the
  // profiles load before the reminders are scheduled.
  ReminderService().personName = (profileId) {
    final person = HealthProfileService().byId(profileId);
    return person == null || person.isOwner ? '' : person.name;
  };
  unawaited(
    HealthProfileService().load().then(
          (_) => ReminderService().load(),
    ),
  );
  unawaited(DoseLogService().load());

  // The doctors list (18,000 rows) is only used by the Doctors tab and the
  // assistant; parse it once the first screens are up and the medicine list
  // has loaded.
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 5),
      DoctorsService().initialize,
    ),
  );
}

class PharmaLensApp
    extends StatefulWidget {
  const PharmaLensApp({
    super.key,
  });

  @override
  State<PharmaLensApp> createState() {
    return _PharmaLensAppState();
  }
}

class _PharmaLensAppState
    extends State<PharmaLensApp> {
  static const String _themeModeKey =
      'pharmalens_theme_mode';

  static const String _localeKey =
      'pharmalens_locale';

  static const Set<String>
  _supportedLanguageCodes =
  <String>{
    'en',
    'ar',
  };

  ThemeMode _themeMode =
      ThemeMode.light;

  Locale _selectedLocale =
  const Locale(
    'en',
  );

  bool _settingsLoaded =
  false;

  bool _onboarded =
  true;

  @override
  void initState() {
    super.initState();

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var nextThemeMode =
        ThemeMode.light;

    var nextLocale =
    _deviceLocale();

    var onboarded =
    true;

    try {
      final preferences =
      await SharedPreferences
          .getInstance();

      nextThemeMode =
          _themeModeFromStorage(
            preferences.getString(
              _themeModeKey,
            ),
          );

      final savedLanguageCode =
      preferences
          .getString(
        _localeKey,
      )
          ?.trim()
          .toLowerCase();

      if (savedLanguageCode !=
          null &&
          _supportedLanguageCodes
              .contains(
            savedLanguageCode,
          )) {
        nextLocale =
            Locale(
              savedLanguageCode,
            );
      }

      onboarded =
          preferences.getBool(
            OnboardingScreen.seenKey,
          ) ??
              false;
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Could not load PharmaLens settings.',
        error,
        stackTrace,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _themeMode =
          nextThemeMode;

      _selectedLocale =
          nextLocale;

      _settingsLoaded =
      true;

      _onboarded =
          onboarded;
    });
  }

  Locale _deviceLocale() {
    final languageCode =
    WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .languageCode
        .trim()
        .toLowerCase();

    if (_supportedLanguageCodes
        .contains(
      languageCode,
    )) {
      return Locale(
        languageCode,
      );
    }

    return const Locale(
      'en',
    );
  }

  Future<void> _changeThemeMode(
      ThemeMode themeMode,
      ) async {
    if (_themeMode ==
        themeMode) {
      return;
    }

    setState(() {
      _themeMode =
          themeMode;
    });

    try {
      final preferences =
      await SharedPreferences
          .getInstance();

      await preferences.setString(
        _themeModeKey,
        _themeModeToStorage(
          themeMode,
        ),
      );
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Could not save PharmaLens theme.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _changeLocale(
      Locale locale,
      ) async {
    final languageCode =
    locale.languageCode
        .trim()
        .toLowerCase();

    if (!_supportedLanguageCodes
        .contains(
      languageCode,
    )) {
      return;
    }

    if (_selectedLocale
        .languageCode ==
        languageCode) {
      return;
    }

    final nextLocale =
    Locale(
      languageCode,
    );

    setState(() {
      _selectedLocale =
          nextLocale;
    });

    try {
      final preferences =
      await SharedPreferences
          .getInstance();

      await preferences.setString(
        _localeKey,
        languageCode,
      );
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Could not save PharmaLens language.',
        error,
        stackTrace,
      );
    }
  }

  ThemeMode _themeModeFromStorage(
      String? value,
      ) {
    switch (
    value
        ?.trim()
        .toLowerCase()
    ) {
      case 'dark':
        return ThemeMode.dark;

      case 'system':
        return ThemeMode.system;

      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  String _themeModeToStorage(
      ThemeMode themeMode,
      ) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'light';

      case ThemeMode.dark:
        return 'dark';

      case ThemeMode.system:
        return 'system';
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    // Scheduled reminder text follows the app language.
    ReminderService().languageCode =
        _selectedLocale.languageCode;

    return PharmaLensAppScope(
      themeMode:
      _themeMode,
      selectedLocale:
      _selectedLocale,
      settingsLoaded:
      _settingsLoaded,
      onThemeModeChanged:
      _changeThemeMode,
      onLocaleChanged:
      _changeLocale,
      child: MaterialApp(
        debugShowCheckedModeBanner:
        false,

        theme:
        PharmaLensTheme.light,

        darkTheme:
        PharmaLensTheme.dark,

        themeMode:
        _themeMode,

        locale:
        _selectedLocale,

        supportedLocales:
        AppLocalizations
            .supportedLocales,

        localizationsDelegates:
        AppLocalizations
            .localizationsDelegates,

        onGenerateTitle: (
            context,
            ) {
          return AppLocalizations.of(
            context,
          ).appName;
        },

        builder: (
            context,
            child,
            ) {
          final mediaQuery =
          MediaQuery.of(
            context,
          );

          final textScaler =
          mediaQuery
              .textScaler
              .clamp(
            minScaleFactor:
            0.85,
            // Large text for low-vision users; layouts wrap instead of
            // clipping (see test/app_shell_test.dart).
            maxScaleFactor:
            1.60,
          );

          return MediaQuery(
            data:
            mediaQuery.copyWith(
              textScaler:
              textScaler,
            ),
            child:
            child ??
                const SizedBox.shrink(),
          );
        },

        home:
        !_settingsLoaded
            ? const _StartupScreen()
            : _onboarded
            ? const AppShell()
            : OnboardingScreen(
          onDone: () {
            setState(() {
              _onboarded =
              true;
            });
          },
        ),
      ),
    );
  }
}

class _StartupScreen
    extends StatelessWidget {
  const _StartupScreen();

  /// Matches the native splash (logo on deep navy) so the hand-over from
  /// the platform splash to Flutter is invisible.
  @override
  Widget build(
      BuildContext context,
      ) {
    return const Scaffold(
      backgroundColor:
      PharmaLensColors.splashBackground,
      body: Center(
        child: Image(
          image: AssetImage(
            'assets/branding/app_icon.png',
          ),
          width: 96,
          height: 96,
        ),
      ),
    );
  }
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
    stackTrace:
    stackTrace,
  );
}