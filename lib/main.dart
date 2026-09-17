import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_settings_scope.dart';
import 'l10n/app_localizations.dart';
import 'private/supabase_private_config.dart';
import 'screens/home_screen.dart';
import 'services/doctors_service.dart';
import 'services/moph_medicine_service.dart';
import 'theme/pharmalens_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize MOPH Lebanon official medicine database and Doctors dataset
    await MophMedicineService().initialize();
    await DoctorsService().initialize();

    // Optional Supabase setup attempt (non-blocking)
    try {
      if (SupabasePrivateConfig.projectUrl.isNotEmpty) {
        await Supabase.initialize(
          url: SupabasePrivateConfig.projectUrl,
          publishableKey: SupabasePrivateConfig.publishableKey,
        );
      }
    } catch (_) {
      // Supabase is optional; MOPH Lebanon dataset operates standalone
    }

    runApp(
      const PharmaLensApp(),
    );
  } catch (error, stackTrace) {
    _debugLog(
      'MOPH Lebanon dataset initialization failed.',
      error,
      stackTrace,
    );

    runApp(
      const PharmaLensApp(),
    );
  }
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
            ? const HomeScreen()
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

class _StartupFailureApp
    extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(
      BuildContext context,
      ) {
    return MaterialApp(
      debugShowCheckedModeBanner:
      false,
      theme:
      PharmaLensTheme.light,
      darkTheme:
      PharmaLensTheme.dark,
      home:
      const _StartupFailureScreen(),
    );
  }
}

class _StartupFailureScreen
    extends StatelessWidget {
  const _StartupFailureScreen();

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final isDark =
    PharmaLensTheme.isDark(
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
        child: SafeArea(
          child: Center(
            child:
            SingleChildScrollView(
              padding:
              const EdgeInsets.all(
                28,
              ),
              child:
              ConstrainedBox(
                constraints:
                const BoxConstraints(
                  maxWidth:
                  460,
                ),
                child: Container(
                  width:
                  double.infinity,
                  padding:
                  const EdgeInsets.all(
                    22,
                  ),
                  decoration:
                  PharmaLensDecorations
                      .surfaceCard(
                    borderRadius:
                    BorderRadius.circular(
                      22,
                    ),
                    isDark:
                    isDark,
                  ),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Container(
                        width:
                        72,
                        height:
                        72,
                        decoration:
                        BoxDecoration(
                          color:
                          palette
                              .dangerSurface,
                          borderRadius:
                          BorderRadius.circular(
                            22,
                          ),
                        ),
                        child:
                        const Icon(
                          Icons
                              .cloud_off_outlined,
                          color:
                          PharmaLensColors
                              .danger,
                          size:
                          34,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      Text(
                        'PharmaLens could not start',
                        textAlign:
                        TextAlign.center,
                        style:
                        TextStyle(
                          color:
                          palette
                              .textPrimary,
                          fontSize:
                          20,
                          fontWeight:
                          FontWeight
                              .w900,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        'The application services are temporarily unavailable. Close the app and try again.',
                        textAlign:
                        TextAlign.center,
                        style:
                        TextStyle(
                          color:
                          palette
                              .textSecondary,
                          height:
                          1.5,
                          fontWeight:
                          FontWeight
                              .w600,
                        ),
                      ),
                    ],
                  ),
                ),
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