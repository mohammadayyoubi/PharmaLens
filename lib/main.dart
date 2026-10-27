import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_settings_scope.dart';
import 'app/app_shell.dart';
import 'l10n/app_localizations.dart';
import 'services/connectivity_service.dart';
import 'services/doctors_service.dart';
import 'services/health_profile_service.dart';
import 'services/moph_medicine_service.dart';
import 'services/prescription_history_service.dart';
import 'services/reminder_service.dart';
import 'theme/pharmalens_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Both parse their CSV in a background isolate and never throw; a load
  // failure is reported through their loadError getters.
  await Future.wait<void>(<Future<void>>[
    MophMedicineService().initialize(),
    DoctorsService().initialize(),
  ]);

  unawaited(ConnectivityService().start());
  // New MOPH lists are published by .github/workflows/update-moph-prices.yml.
  MophMedicineService().startAutoUpdates();
  unawaited(PrescriptionHistoryService().load());
  unawaited(HealthProfileService().load());
  unawaited(ReminderService().load());

  runApp(
    const PharmaLensApp(),
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
            maxScaleFactor:
            1.30,
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
        _settingsLoaded
            ? const AppShell()
            : const _StartupScreen(),
      ),
    );
  }
}

class _StartupScreen
    extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Scaffold(
      backgroundColor:
      palette.background,
      body: DecoratedBox(
        decoration:
        BoxDecoration(
          gradient:
          palette.pageGradient,
        ),
        child:
        const SafeArea(
          child: Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child:
              CircularProgressIndicator(
                strokeWidth:
                3,
              ),
            ),
          ),
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