import 'package:flutter/material.dart';

class PharmaLensColors {
  const PharmaLensColors._();

  static const Color deepNavy = Color(0xFF0B2C3F);

  /// Native splash and startup screen background (android/.../colors.xml).
  static const Color splashBackground = Color(0xFF062B3A);
  static const Color navy = Color(0xFF123A4D);
  static const Color navyLight = Color(0xFF1F5D6F);

  static const Color cyan = Color(0xFF12A7A2);
  static const Color brightCyan = Color(0xFF6BDAD3);
  static const Color teal = Color(0xFF168F88);

  static const Color background = Color(0xFFF4F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFB);

  static const Color textPrimary = Color(0xFF183247);
  static const Color textSecondary = Color(0xFF6B7F8F);
  static const Color textMuted = Color(0xFF91A2AD);

  static const Color border = Color(0xFFDDE6EB);
  static const Color borderSoft = Color(0xFFEAF0F2);

  static const Color tealSurface = Color(0xFFE5F6F4);
  static const Color blueSurface = Color(0xFFEDF3FA);
  static const Color dangerSurface = Color(0xFFFFF5F5);

  static const Color darkBackground = Color(0xFF061B27);
  static const Color darkSurface = Color(0xFF0B2A3A);
  static const Color darkSurfaceSoft = Color(0xFF10384B);
  static const Color darkBorder = Color(0xFF1B4C60);
  static const Color darkBorderSoft = Color(0xFF133C4E);

  static const Color darkTextPrimary = Color(0xFFF2FBFC);
  static const Color darkTextSecondary = Color(0xFFB7CED8);
  static const Color darkTextMuted = Color(0xFF7FA0AE);

  static const Color darkTealSurface = Color(0xFF123E43);
  static const Color darkBlueSurface = Color(0xFF102E4D);
  static const Color darkDangerSurface = Color(0xFF3A161B);

  static const Color success = Color(0xFF168A67);
  static const Color warning = Color(0xFFE59B31);
  static const Color danger = Color(0xFFD64545);
  static const Color info = Color(0xFF4F79C9);

  /// Deep navy to teal, behind the onboarding and alarm screens.
  static const List<Color> brandGradient = <Color>[splashBackground, Color(0xFF0B4F63), Color(0xFF0E7C86)];

  // Accents that tell features apart (home tiles, female doctors, directions).
  static const Color accentBlue = Color(0xFF3B82C4);
  static const Color accentCoral = Color(0xFFE06A5A);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentPurple = Color(0xFF7457E8);
  static const Color accentPink = Color(0xFFD95A91);

  // Map placeholders and the selected pin.
  static const Color mapTileLight = Color(0xFFE8F1F5);
  static const Color mapTileDark = Color(0xFF0F1E28);
  static const Color mapBackgroundDark = Color(0xFF071D28);
  static const Color mapPinSelected = Color(0xFFFF6F59);

  // Other brands' colors, used only for their marks in About.
  static const Color instagram = Color(0xFFE1306C);
  static const Color lebanonRed = Color(0xFFED1C24);
  static const Color lebanonCedar = Color(0xFF00A651);
}

class PharmaLensPalette {
  const PharmaLensPalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderSoft,
    required this.tealSurface,
    required this.blueSurface,
    required this.dangerSurface,
    required this.heroGradient,
    required this.pageGradient,
    required this.cardShadow,
  });

  final bool isDark;

  final Color background;
  final Color surface;
  final Color surfaceSoft;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color border;
  final Color borderSoft;

  final Color tealSurface;
  final Color blueSurface;
  final Color dangerSurface;

  final LinearGradient heroGradient;
  final LinearGradient pageGradient;
  final List<BoxShadow> cardShadow;

  static const PharmaLensPalette light = PharmaLensPalette(
    isDark: false,
    background: PharmaLensColors.background,
    surface: PharmaLensColors.surface,
    surfaceSoft: PharmaLensColors.surfaceSoft,
    textPrimary: PharmaLensColors.textPrimary,
    textSecondary: PharmaLensColors.textSecondary,
    textMuted: PharmaLensColors.textMuted,
    border: PharmaLensColors.border,
    borderSoft: PharmaLensColors.borderSoft,
    tealSurface: PharmaLensColors.tealSurface,
    blueSurface: PharmaLensColors.blueSurface,
    dangerSurface: PharmaLensColors.dangerSurface,
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        PharmaLensColors.deepNavy,
        PharmaLensColors.navy,
        PharmaLensColors.navyLight,
      ],
    ),
    pageGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF9FBFC), PharmaLensColors.background],
    ),
    cardShadow: [
      BoxShadow(color: Color(0x0C183247), blurRadius: 20, offset: Offset(0, 8)),
    ],
  );

  static const PharmaLensPalette dark = PharmaLensPalette(
    isDark: true,
    background: PharmaLensColors.darkBackground,
    surface: PharmaLensColors.darkSurface,
    surfaceSoft: PharmaLensColors.darkSurfaceSoft,
    textPrimary: PharmaLensColors.darkTextPrimary,
    textSecondary: PharmaLensColors.darkTextSecondary,
    textMuted: PharmaLensColors.darkTextMuted,
    border: PharmaLensColors.darkBorder,
    borderSoft: PharmaLensColors.darkBorderSoft,
    tealSurface: PharmaLensColors.darkTealSurface,
    blueSurface: PharmaLensColors.darkBlueSurface,
    dangerSurface: PharmaLensColors.darkDangerSurface,
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF061B27), Color(0xFF0A3243), Color(0xFF0E4A56)],
    ),
    pageGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF061B27), Color(0xFF082230)],
    ),
    cardShadow: [
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
  );
}

class PharmaLensGradients {
  const PharmaLensGradients._();

  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF9FBFC), PharmaLensColors.background],
  );

  static const LinearGradient pageBackgroundDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [PharmaLensColors.darkBackground, Color(0xFF082230)],
  );

  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      PharmaLensColors.deepNavy,
      PharmaLensColors.navy,
      PharmaLensColors.navyLight,
    ],
  );

  static const LinearGradient heroDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF061B27), Color(0xFF0A3243), Color(0xFF0E4A56)],
  );

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PharmaLensColors.cyan, PharmaLensColors.teal],
  );

  static const LinearGradient cyanGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1812A7A2), Color(0x0A168F88)],
  );

  static const LinearGradient cyanGlassDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2412A7A2), Color(0x10168F88)],
  );
}

class PharmaLensShadows {
  const PharmaLensShadows._();

  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0C183247), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> softDark = [
    BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(color: Color(0x15183247), blurRadius: 26, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> mediumDark = [
    BoxShadow(color: Color(0x42000000), blurRadius: 28, offset: Offset(0, 14)),
  ];

  static const List<BoxShadow> cyanGlow = [
    BoxShadow(color: Color(0x3012A7A2), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

class PharmaLensTheme {
  const PharmaLensTheme._();

  static ThemeData get light {
    return _buildTheme(
      palette: PharmaLensPalette.light,
      brightness: Brightness.light,
    );
  }

  static ThemeData get dark {
    return _buildTheme(
      palette: PharmaLensPalette.dark,
      brightness: Brightness.dark,
    );
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static PharmaLensPalette paletteOf(BuildContext context) {
    return isDark(context) ? PharmaLensPalette.dark : PharmaLensPalette.light;
  }

  static ThemeData _buildTheme({
    required PharmaLensPalette palette,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: PharmaLensColors.teal,
          brightness: brightness,
        ).copyWith(
          primary: PharmaLensColors.teal,
          secondary: PharmaLensColors.cyan,
          surface: palette.surface,
          error: PharmaLensColors.danger,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: palette.textPrimary,
          onError: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      splashColor: PharmaLensColors.teal.withValues(alpha: isDark ? 0.12 : 0.07),
      highlightColor: PharmaLensColors.teal.withValues(alpha: isDark ? 0.07 : 0.035),

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary, size: 23),
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 30,
          height: 1.18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        headlineMedium: TextStyle(
          color: palette.textPrimary,
          fontSize: 25,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        headlineSmall: TextStyle(
          color: palette.textPrimary,
          fontSize: 21,
          height: 1.25,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 19,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: palette.textSecondary,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: palette.textSecondary,
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: TextStyle(
          color: palette.textMuted,
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        labelMedium: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: palette.borderSoft,
        thickness: 1,
        space: 1,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PharmaLensColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? const Color(0xFF395460)
              : const Color(0xFFB6C7CD),
          disabledForegroundColor: isDark
              ? const Color(0xFF9CB4BE)
              : Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          side: BorderSide(color: palette.border, width: 1.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PharmaLensColors.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textPrimary,
          backgroundColor: palette.surface,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 15,
        ),
        hintStyle: TextStyle(
          color: palette.textMuted,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: PharmaLensColors.teal,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: PharmaLensColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: PharmaLensColors.danger,
            width: 1.5,
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }

          return isDark ? const Color(0xFFD6E4E9) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PharmaLensColors.teal;
          }

          return isDark ? const Color(0xFF42606B) : const Color(0xFFB7C5CC);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF0E3445)
            : PharmaLensColors.deepNavy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: PharmaLensColors.teal,
        linearTrackColor: palette.borderSoft,
        circularTrackColor: palette.borderSoft,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: palette.tealSurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? PharmaLensColors.teal : palette.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? palette.textPrimary : palette.textSecondary,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.tealSurface,
        selectedIconTheme: const IconThemeData(color: PharmaLensColors.teal),
        unselectedIconTheme: IconThemeData(color: palette.textSecondary),
        selectedLabelTextStyle: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: PharmaLensColors.teal,
        unselectedLabelColor: palette.textSecondary,
        indicatorColor: PharmaLensColors.teal,
        dividerColor: palette.borderSoft,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceSoft,
        selectedColor: palette.tealSurface,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        labelStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

extension PharmaLensThemeContext on BuildContext {
  bool get isPharmaDark {
    return Theme.of(this).brightness == Brightness.dark;
  }

  PharmaLensPalette get pharmaPalette {
    return PharmaLensTheme.paletteOf(this);
  }
}

class PharmaLensDecorations {
  const PharmaLensDecorations._();

  static BoxDecoration heroCard({
    BorderRadius? borderRadius,
    bool isDark = false,
  }) {
    return BoxDecoration(
      gradient: isDark
          ? PharmaLensGradients.heroDark
          : PharmaLensGradients.hero,
      borderRadius: borderRadius ?? BorderRadius.circular(22),
      boxShadow: isDark
          ? PharmaLensShadows.mediumDark
          : PharmaLensShadows.medium,
    );
  }

  static BoxDecoration cyanGlowCard({BorderRadius? borderRadius}) {
    return BoxDecoration(
      gradient: PharmaLensGradients.primary,
      borderRadius: borderRadius ?? BorderRadius.circular(18),
      boxShadow: PharmaLensShadows.cyanGlow,
    );
  }

  static BoxDecoration surfaceCard({
    BorderRadius? borderRadius,
    bool isDark = false,
  }) {
    final palette = isDark ? PharmaLensPalette.dark : PharmaLensPalette.light;

    return BoxDecoration(
      color: palette.surface,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(color: palette.border),
      boxShadow: palette.cardShadow,
    );
  }

  static BoxDecoration glassCard({
    BorderRadius? borderRadius,
    bool isDark = false,
  }) {
    final palette = isDark ? PharmaLensPalette.dark : PharmaLensPalette.light;

    return BoxDecoration(
      gradient: isDark
          ? PharmaLensGradients.cyanGlassDark
          : PharmaLensGradients.cyanGlass,
      borderRadius: borderRadius ?? BorderRadius.circular(18),
      border: Border.all(color: palette.borderSoft),
    );
  }
}
