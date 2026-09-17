import 'package:flutter/material.dart';

class PharmaLensAppScope extends InheritedWidget {
  const PharmaLensAppScope({
    super.key,
    required this.themeMode,
    required this.selectedLocale,
    required this.settingsLoaded,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required super.child,
  });

  final ThemeMode themeMode;
  final Locale selectedLocale;
  final bool settingsLoaded;

  final Future<void> Function(
      ThemeMode themeMode,
      ) onThemeModeChanged;

  final Future<void> Function(
      Locale locale,
      ) onLocaleChanged;

  bool get isArabic {
    return selectedLocale.languageCode
        .trim()
        .toLowerCase() ==
        'ar';
  }

  bool get isEnglish {
    return !isArabic;
  }

  bool get isLightMode {
    return themeMode ==
        ThemeMode.light;
  }

  bool get isDarkMode {
    return themeMode ==
        ThemeMode.dark;
  }

  bool get isSystemMode {
    return themeMode ==
        ThemeMode.system;
  }

  static PharmaLensAppScope of(
      BuildContext context,
      ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<
        PharmaLensAppScope
    >();

    assert(
    scope != null,
    'PharmaLensAppScope was not found above this context.',
    );

    return scope!;
  }

  static PharmaLensAppScope? maybeOf(
      BuildContext context,
      ) {
    return context
        .dependOnInheritedWidgetOfExactType<
        PharmaLensAppScope
    >();
  }

  @override
  bool updateShouldNotify(
      covariant PharmaLensAppScope oldWidget,
      ) {
    return themeMode !=
        oldWidget.themeMode ||
        selectedLocale !=
            oldWidget.selectedLocale ||
        settingsLoaded !=
            oldWidget.settingsLoaded;
  }
}