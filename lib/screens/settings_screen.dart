import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_settings_scope.dart';
import '../l10n/app_localizations.dart';
import '../services/moph_medicine_service.dart';
import '../theme/pharmalens_theme.dart';
import '../utils/formatters.dart';
import '../widgets/chatbot_view.dart';

class SettingsScreen
    extends StatefulWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  State<SettingsScreen> createState() {
    return _SettingsScreenState();
  }
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  static const String _whatsAppNumber =
      '96170080214';

  static const String
  _displayWhatsAppNumber =
      '+961 70 080 214';

  static const String _developerTeam =
      'TechWrap Development Team';

  static const String _appVersion =
      '1.0.0';

  bool _isSyncingMoph = false;

  AppLocalizations get _l10n {
    return AppLocalizations.of(
      context,
    );
  }

  bool get _isArabic {
    return Localizations.localeOf(
      context,
    ).languageCode.toLowerCase() ==
        'ar';
  }

  String _text({
    required String en,
    required String ar,
  }) {
    return _isArabic ? ar : en;
  }

  PharmaLensAppScope get _appScope {
    return PharmaLensAppScope.of(
      context,
    );
  }

  Future<void> _changeLanguage(
      BuildContext sheetContext,
      Locale locale,
      ) async {
    final scope =
        _appScope;

    final languageCode =
    locale.languageCode
        .trim()
        .toLowerCase();

    if (scope.selectedLocale.languageCode ==
        languageCode) {
      Navigator.of(
        sheetContext,
      ).pop();

      return;
    }

    Navigator.of(
      sheetContext,
    ).pop();

    await scope.onLocaleChanged(
      Locale(
        languageCode,
      ),
    );
  }

  Future<void> _changeTheme(
      BuildContext sheetContext,
      ThemeMode themeMode,
      ) async {
    final scope =
        _appScope;

    Navigator.of(
      sheetContext,
    ).pop();

    await scope.onThemeModeChanged(
      themeMode,
    );
  }

  Future<void> _openLanguageSheet() async {
    final currentLocale =
        _appScope.selectedLocale;

    await showModalBottomSheet<void>(
      context:
      context,
      useSafeArea:
      true,
      isScrollControlled:
      true,
      backgroundColor:
      Colors.transparent,
      builder:
          (sheetContext) {
        return _SettingsSheet(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const _SheetHandle(),

              const SizedBox(
                height: 20,
              ),

              _SheetIcon(
                icon:
                Icons
                    .language_rounded,
              ),

              const SizedBox(
                height: 14,
              ),

              Text(
                _l10n.chooseLanguage,
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  PharmaLensTheme
                      .paletteOf(
                    sheetContext,
                  )
                      .textPrimary,
                  fontSize:
                  20,
                  fontWeight:
                  FontWeight
                      .w900,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              _ChoiceTile(
                icon:
                Icons
                    .language_rounded,
                title:
                'English',
                subtitle:
                _l10n.useEnglish,
                selected:
                currentLocale
                    .languageCode ==
                    'en',
                onTap: () {
                  _changeLanguage(
                    sheetContext,
                    const Locale(
                      'en',
                    ),
                  );
                },
              ),

              const SizedBox(
                height: 10,
              ),

              _ChoiceTile(
                icon:
                Icons
                    .translate_rounded,
                title:
                'العربية',
                subtitle:
                _l10n.useArabic,
                selected:
                currentLocale
                    .languageCode ==
                    'ar',
                onTap: () {
                  _changeLanguage(
                    sheetContext,
                    const Locale(
                      'ar',
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAppearanceSheet() async {
    final currentTheme =
        _appScope.themeMode;

    await showModalBottomSheet<void>(
      context:
      context,
      useSafeArea:
      true,
      isScrollControlled:
      true,
      backgroundColor:
      Colors.transparent,
      builder:
          (sheetContext) {
        final palette =
        PharmaLensTheme.paletteOf(
          sheetContext,
        );

        return _SettingsSheet(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const _SheetHandle(),

              const SizedBox(
                height: 20,
              ),

              const _SheetIcon(
                icon:
                Icons
                    .contrast_rounded,
              ),

              const SizedBox(
                height: 14,
              ),

              Text(
                _text(
                  en:
                  'Choose appearance',
                  ar:
                  'اختر المظهر',
                ),
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
                height: 6,
              ),

              Text(
                _text(
                  en:
                  'Choose light, dark, or follow the device appearance.',
                  ar:
                  'اختر الوضع الفاتح أو الداكن أو اتبع مظهر الجهاز.',
                ),
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  palette
                      .textSecondary,
                  height:
                  1.45,
                  fontSize:
                  12,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              _ChoiceTile(
                icon:
                Icons
                    .light_mode_outlined,
                title:
                _text(
                  en:
                  'Light mode',
                  ar:
                  'الوضع الفاتح',
                ),
                subtitle:
                _text(
                  en:
                  'Bright medical interface',
                  ar:
                  'واجهة طبية فاتحة وواضحة',
                ),
                selected:
                currentTheme ==
                    ThemeMode.light,
                onTap: () {
                  _changeTheme(
                    sheetContext,
                    ThemeMode.light,
                  );
                },
              ),

              const SizedBox(
                height: 10,
              ),

              _ChoiceTile(
                icon:
                Icons
                    .dark_mode_outlined,
                title:
                _text(
                  en:
                  'Dark mode',
                  ar:
                  'الوضع الداكن',
                ),
                subtitle:
                _text(
                  en:
                  'Comfortable dark interface',
                  ar:
                  'واجهة داكنة ومريحة',
                ),
                selected:
                currentTheme ==
                    ThemeMode.dark,
                onTap: () {
                  _changeTheme(
                    sheetContext,
                    ThemeMode.dark,
                  );
                },
              ),

              const SizedBox(
                height: 10,
              ),

              _ChoiceTile(
                icon:
                Icons
                    .brightness_auto_outlined,
                title:
                _text(
                  en:
                  'System default',
                  ar:
                  'حسب النظام',
                ),
                subtitle:
                _text(
                  en:
                  'Follow the device automatically',
                  ar:
                  'اتبع إعداد الجهاز تلقائيًا',
                ),
                selected:
                currentTheme ==
                    ThemeMode.system,
                onTap: () {
                  _changeTheme(
                    sheetContext,
                    ThemeMode.system,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openWhatsApp() async {
    final message =
    _text(
      en:
      'Hello, I am contacting you from PharmaLens.',
      ar:
      'مرحبًا، أتواصل معك من خلال تطبيق PharmaLens.',
    );

    final uri =
    Uri.https(
      'wa.me',
      '/$_whatsAppNumber',
      <String, String>{
        'text':
        message,
      },
    );

    try {
      final opened =
      await launchUrl(
        uri,
        mode:
        LaunchMode.platformDefault,
      );

      if (!opened) {
        _showSafeMessage(
          _text(
            en:
            'Could not open WhatsApp on this device.',
            ar:
            'تعذر فتح واتساب على هذا الجهاز.',
          ),
        );
      }
    } catch (
    error,
    stackTrace
    ) {
      _debugLog(
        'Could not open WhatsApp.',
        error,
        stackTrace,
      );

      _showSafeMessage(
        _text(
          en:
          'Could not open WhatsApp on this device.',
          ar:
          'تعذر فتح واتساب على هذا الجهاز.',
        ),
      );
    }
  }

  Future<void> _openAbout() async {
    await showModalBottomSheet<void>(
      context:
      context,
      useSafeArea:
      true,
      isScrollControlled:
      true,
      backgroundColor:
      Colors.transparent,
      builder:
          (sheetContext) {
        final palette =
        PharmaLensTheme.paletteOf(
          sheetContext,
        );

        return _SettingsSheet(
          child:
          SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const _SheetHandle(),

                const SizedBox(
                  height: 20,
                ),

                const _SheetIcon(
                  icon:
                  Icons
                      .info_outline_rounded,
                ),

                const SizedBox(
                  height: 14,
                ),

                Text(
                  _text(
                    en:
                    'About PharmaLens',
                    ar:
                    'حول PharmaLens',
                  ),
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
                  height: 10,
                ),

                Text(
                  _text(
                    en:
                    'PharmaLens is a medicine and prescription support application designed to help users and pharmacists review medicine information more safely.',
                    ar:
                    'PharmaLens هو تطبيق لدعم مراجعة الأدوية والوصفات، صُمم لمساعدة المستخدمين والصيادلة على مراجعة المعلومات الدوائية بشكل أكثر أمانًا.',
                  ),
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    color:
                    palette
                        .textSecondary,
                    height:
                    1.6,
                    fontSize:
                    13,
                    fontWeight:
                    FontWeight
                        .w500,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                const SizedBox(
                  height: 10,
                ),

                _ValuePill(
                  value:
                  'v$_appVersion',
                ),

                const SizedBox(
                  height: 14,
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _text(
                          en: 'Developed by $_developerTeam',
                          ar: 'تم التطوير بواسطة فريق تطوير TechWrap',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _displayWhatsAppNumber,
                        style: const TextStyle(
                          color: PharmaLensColors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  child:
                  FilledButton(
                    onPressed: () {
                      Navigator.of(
                        sheetContext,
                      ).pop();
                    },
                    child:
                    Text(
                      _text(
                        en:
                        'Done',
                        ar:
                        'تم',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _manualSyncMoph() async {
    if (_isSyncingMoph) return;

    setState(() {
      _isSyncingMoph = true;
    });

    _showSafeMessage(
      _text(
        en: 'Checking MOPH Lebanon official dataset...',
        ar: 'جارٍ التحقق من قاعدة بيانات وزارة الصحة العامة...',
      ),
    );

    try {
      final result = await MophMedicineService().checkAndUpdateIfStale(force: true);

      if (!mounted) return;

      setState(() {
        _isSyncingMoph = false;
      });

      _showSafeMessage(
        result.describe(
          isArabic: _isArabic,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSyncingMoph = false;
      });

      _showSafeMessage(
        _text(
          en: 'Failed to sync with MOPH server. Using local dataset.',
          ar: 'تعذرت المزامنة مع خادم الوزارة. يجري استخدام القاعدة المحلية.',
        ),
      );
    }
  }

  void _showSafeMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(
            message,
          ),
        ),
      );
  }

  String _appearanceLabel(
      ThemeMode themeMode,
      ) {
    switch (themeMode) {
      case ThemeMode.light:
        return _text(
          en:
          'Light',
          ar:
          'فاتح',
        );

      case ThemeMode.dark:
        return _text(
          en:
          'Dark',
          ar:
          'داكن',
        );

      case ThemeMode.system:
        return _text(
          en:
          'System',
          ar:
          'حسب النظام',
        );
    }
  }

  String _appearanceCode(
      ThemeMode themeMode,
      ) {
    switch (themeMode) {
      case ThemeMode.light:
        return _text(
          en:
          'Light',
          ar:
          'فاتح',
        );

      case ThemeMode.dark:
        return _text(
          en:
          'Dark',
          ar:
          'داكن',
        );

      case ThemeMode.system:
        return _text(
          en:
          'Auto',
          ar:
          'تلقائي',
        );
    }
  }

  IconData _appearanceIcon(
      ThemeMode themeMode,
      ) {
    switch (themeMode) {
      case ThemeMode.light:
        return Icons
            .light_mode_outlined;

      case ThemeMode.dark:
        return Icons
            .dark_mode_outlined;

      case ThemeMode.system:
        return Icons
            .brightness_auto_outlined;
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

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final appScope =
        _appScope;

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: const FloatingChatbotButton(),
      body: DecoratedBox(
        decoration:
        BoxDecoration(
          gradient:
          palette.pageGradient,
        ),
        child: SafeArea(
          child: Center(
            child:
            ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth:
                760,
              ),
              child:
              ListView(
                physics:
                const BouncingScrollPhysics(),
                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  32,
                ),
                children: [
                  _buildHeader(),

                  const SizedBox(
                    height: 22,
                  ),

                  _buildBrandCard(),

                  const SizedBox(
                    height: 22,
                  ),

                  _SettingsSection(
                    title:
                    _text(
                      en:
                      'Preferences',
                      ar:
                      'التفضيلات',
                    ),
                    children: [
                      _SettingsTile(
                        icon:
                        Icons
                            .language_rounded,
                        title:
                        _l10n.language,
                        subtitle:
                        _isArabic
                            ? _l10n.arabic
                            : _l10n.english,
                        trailing:
                        _ValuePill(
                          value:
                          _isArabic
                              ? 'AR'
                              : 'EN',
                        ),
                        onTap:
                        _openLanguageSheet,
                      ),

                      _SettingsTile(
                        icon:
                        _appearanceIcon(
                          appScope.themeMode,
                        ),
                        title:
                        _text(
                          en:
                          'Appearance',
                          ar:
                          'المظهر',
                        ),
                        subtitle:
                        _appearanceLabel(
                          appScope.themeMode,
                        ),
                        trailing:
                        _ValuePill(
                          value:
                          _appearanceCode(
                            appScope.themeMode,
                          ),
                        ),
                        onTap:
                        _openAppearanceSheet,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _SettingsSection(
                    title:
                    _text(
                      en:
                      'Contact',
                      ar:
                      'تواصل معنا',
                    ),
                    children: [
                      _SettingsTile(
                        icon:
                        Icons
                            .chat_rounded,
                        title:
                        _text(
                          en:
                          'Contact on WhatsApp',
                          ar:
                          'تواصل عبر واتساب',
                        ),
                        subtitle:
                        _displayWhatsAppNumber,
                        forceLtrSubtitle:
                        true,
                        trailing:
                        const _WhatsAppBadge(),
                        onTap:
                        _openWhatsApp,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _SettingsSection(
                    title:
                    _text(
                      en:
                      'Data & Sync',
                      ar:
                      'البيانات والمزامنة',
                    ),
                    children: [
                      _SettingsTile(
                        icon:
                        Icons.sync_rounded,
                        title:
                        _text(
                          en:
                          'Sync MOPH Medicine Data',
                          ar:
                          'مزامنة بيانات أدوية وزارة الصحة',
                        ),
                        subtitle:
                        _isSyncingMoph
                            ? _text(
                                en: 'Syncing in progress...',
                                ar: 'جارٍ التحديث...',
                              )
                            : _text(
                                en: 'MOPH list of ${MophMedicineService().publishedDate} · ${formatCount(MophMedicineService().totalMedicineCount)} medicines',
                                ar: 'لائحة وزارة الصحة بتاريخ ${MophMedicineService().publishedDate} · ${formatCount(MophMedicineService().totalMedicineCount)} دواء',
                              ),
                        trailing: _isSyncingMoph
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.refresh_rounded,
                                color: PharmaLensColors.teal,
                                size: 20,
                              ),
                        onTap: _isSyncingMoph ? null : _manualSyncMoph,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _SettingsSection(
                    title:
                    _text(
                      en:
                      'About',
                      ar:
                      'حول التطبيق',
                    ),
                    children: [
                      _SettingsTile(
                        icon:
                        Icons
                            .info_outline_rounded,
                        title:
                        _text(
                          en:
                          'About PharmaLens',
                          ar:
                          'حول PharmaLens',
                        ),
                        subtitle:
                        _text(
                          en:
                          'Version $_appVersion • $_developerTeam',
                          ar:
                          'الإصدار $_appVersion • فريق $_developerTeam',
                        ),
                        onTap:
                        _openAbout,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildMedicalDisclaimer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final canPop =
    Navigator.of(
      context,
    ).canPop();

    return Row(
      children: [
        if (canPop)
        Material(
          color:
          palette.surface,
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          child:
          InkWell(
            onTap: () {
              Navigator.maybePop(
                context,
              );
            },
            borderRadius:
            BorderRadius.circular(
              14,
            ),
            child:
            Container(
              width:
              46,
              height:
              46,
              decoration:
              BoxDecoration(
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                border:
                Border.all(
                  color:
                  palette.border,
                ),
                boxShadow:
                palette
                    .cardShadow,
              ),
              child:
              Icon(
                Icons.arrow_back_rounded,
                color:
                palette
                    .textPrimary,
                size:
                22,
              ),
            ),
          ),
        ),

        if (canPop)
        const SizedBox(
          width: 13,
        ),

        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.settings,
                style:
                TextStyle(
                  color:
                  palette
                      .textPrimary,
                  fontSize:
                  24,
                  fontWeight:
                  FontWeight
                      .w900,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                _text(
                  en:
                  'Language, appearance and application information',
                  ar:
                  'اللغة والمظهر ومعلومات التطبيق',
                ),
                style:
                TextStyle(
                  color:
                  palette
                      .textSecondary,
                  fontSize:
                  11.5,
                  fontWeight:
                  FontWeight
                      .w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrandCard() {
    final isDark =
    PharmaLensTheme.isDark(
      context,
    );

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration:
      PharmaLensDecorations
          .heroCard(
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        isDark:
        isDark,
      ),
      child:
      Row(
        children: [
          Container(
            width:
            58,
            height:
            58,
            decoration:
            BoxDecoration(
              color:
              Colors.white
                  .withValues(
                alpha:
                0.10,
              ),
              borderRadius:
              BorderRadius.circular(
                18,
              ),
              border:
              Border.all(
                color:
                Colors.white
                    .withValues(
                  alpha:
                  0.13,
                ),
              ),
            ),
            child:
            const Icon(
              Icons
                  .health_and_safety_outlined,
              color:
              PharmaLensColors
                  .brightCyan,
              size:
              29,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'PharmaLens',
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                    fontSize:
                    20,
                    fontWeight:
                    FontWeight
                        .w900,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  _text(
                    en:
                    'Medicine and prescription support with safety-first verification.',
                    ar:
                    'دعم للأدوية والوصفات مع تحقق يعتمد السلامة أولًا.',
                  ),
                  style:
                  TextStyle(
                    color:
                    Colors.white
                        .withValues(
                      alpha:
                      0.74,
                    ),
                    height:
                    1.45,
                    fontSize:
                    12,
                    fontWeight:
                    FontWeight
                        .w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalDisclaimer() {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        15,
      ),
      decoration:
      BoxDecoration(
        color:
        palette.dangerSurface,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border:
        Border.all(
          color:
          PharmaLensColors
              .danger
              .withValues(
            alpha:
            0.34,
          ),
        ),
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width:
            39,
            height:
            39,
            decoration:
            BoxDecoration(
              color:
              PharmaLensColors
                  .danger
                  .withValues(
                alpha:
                0.11,
              ),
              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),
            child:
            const Icon(
              Icons
                  .warning_amber_rounded,
              color:
              PharmaLensColors
                  .danger,
              size:
              21,
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _text(
                    en:
                    'Medical disclaimer',
                    ar:
                    'تنبيه طبي',
                  ),
                  style:
                  const TextStyle(
                    color:
                    PharmaLensColors
                        .danger,
                    fontSize:
                    13.5,
                    fontWeight:
                    FontWeight
                        .w900,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  _l10n
                      .medicalDisclaimer,
                  style:
                  TextStyle(
                    color:
                    PharmaLensTheme
                        .isDark(
                      context,
                    )
                        ? const Color(
                      0xFFFFB9B9,
                    )
                        : const Color(
                      0xFF765E61,
                    ),
                    height:
                    1.45,
                    fontSize:
                    11.5,
                    fontWeight:
                    FontWeight
                        .w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection
    extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

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

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
          const EdgeInsetsDirectional.only(
            start: 4,
            end: 4,
            bottom: 9,
          ),
          child:
          Text(
            title,
            style:
            const TextStyle(
              color:
              PharmaLensColors
                  .teal,
              fontSize:
              12,
              fontWeight:
              FontWeight
                  .w900,
            ),
          ),
        ),

        Container(
          decoration:
          PharmaLensDecorations
              .surfaceCard(
            borderRadius:
            BorderRadius.circular(
              19,
            ),
            isDark:
            isDark,
          ),
          clipBehavior:
          Clip.antiAlias,
          child:
          Column(
            children: [
              for (
              var index = 0;
              index < children.length;
              index++
              ) ...[
                children[index],

                if (index !=
                    children.length -
                        1)
                  Divider(
                    height:
                    1,
                    color:
                    palette
                        .borderSoft,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile
    extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.forceLtrSubtitle = false,
  });

  final IconData icon;

  final String title;
  final String subtitle;

  final Widget? trailing;
  final VoidCallback? onTap;

  final bool forceLtrSubtitle;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    return Material(
      color:
      Colors.transparent,
      child:
      InkWell(
        onTap:
        onTap,
        child:
        Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal:
            14,
            vertical:
            13,
          ),
          child:
          Row(
            children: [
              Container(
                width:
                41,
                height:
                41,
                decoration:
                BoxDecoration(
                  color:
                  palette
                      .tealSurface,
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child:
                Icon(
                  icon,
                  color:
                  PharmaLensColors
                      .teal,
                  size:
                  21,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      title,
                      style:
                      TextStyle(
                        color:
                        palette
                            .textPrimary,
                        fontSize:
                        14,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),

                    if (subtitle
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        subtitle,
                        textDirection:
                        forceLtrSubtitle
                            ? TextDirection
                            .ltr
                            : null,
                        style:
                        TextStyle(
                          color:
                          palette
                              .textSecondary,
                          fontSize:
                          10.8,
                          height:
                          1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color:
                    palette
                        .textMuted,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSheet
    extends StatelessWidget {
  const _SettingsSheet({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(
      BuildContext context,
      ) {
    final palette =
    PharmaLensTheme.paletteOf(
      context,
    );

    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration:
          BoxDecoration(
            color:
            palette.surface,
            borderRadius:
            const BorderRadius.vertical(
              top:
              Radius.circular(
                26,
              ),
            ),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              18,
              10,
              18,
              22 +
                  MediaQuery.paddingOf(
                    context,
                  ).bottom,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SheetHandle
    extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      44,
      height:
      5,
      decoration:
      BoxDecoration(
        color:
        PharmaLensTheme
            .paletteOf(
          context,
        )
            .border,
        borderRadius:
        BorderRadius.circular(
          999,
        ),
      ),
    );
  }
}

class _SheetIcon
    extends StatelessWidget {
  const _SheetIcon({
    required this.icon,
  });

  final IconData icon;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      58,
      height:
      58,
      decoration:
      BoxDecoration(
        color:
        PharmaLensTheme
            .paletteOf(
          context,
        )
            .tealSurface,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
      ),
      child:
      Icon(
        icon,
        color:
        PharmaLensColors
            .teal,
        size:
        29,
      ),
    );
  }
}

class _ChoiceTile
    extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;

  final String title;
  final String subtitle;

  final bool selected;

  final VoidCallback onTap;

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

    return Material(
      color:
      selected
          ? palette.tealSurface
          : palette.surfaceSoft,
      borderRadius:
      BorderRadius.circular(
        17,
      ),
      child:
      InkWell(
        onTap:
        onTap,
        borderRadius:
        BorderRadius.circular(
          17,
        ),
        child:
        Container(
          padding:
          const EdgeInsets.all(
            13,
          ),
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              17,
            ),
            border:
            Border.all(
              color:
              selected
                  ? PharmaLensColors
                  .teal
                  .withValues(
                alpha:
                isDark
                    ? 0.55
                    : 0.70,
              )
                  : palette
                  .border,
            ),
          ),
          child:
          Row(
            children: [
              Icon(
                icon,
                color:
                selected
                    ? PharmaLensColors
                    .teal
                    : palette
                    .textSecondary,
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      title,
                      style:
                      TextStyle(
                        color:
                        palette
                            .textPrimary,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      subtitle,
                      style:
                      TextStyle(
                        color:
                        palette
                            .textSecondary,
                        fontSize:
                        11,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                selected
                    ? Icons
                    .check_circle_rounded
                    : Icons
                    .circle_outlined,
                color:
                selected
                    ? PharmaLensColors
                    .teal
                    : palette
                    .textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValuePill
    extends StatelessWidget {
  const _ValuePill({
    required this.value,
  });

  final String value;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      constraints:
      const BoxConstraints(
        maxWidth:
        90,
      ),
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        9,
        vertical:
        6,
      ),
      decoration:
      BoxDecoration(
        color:
        PharmaLensTheme
            .paletteOf(
          context,
        )
            .tealSurface,
        borderRadius:
        BorderRadius.circular(
          999,
        ),
      ),
      child:
      Text(
        value,
        maxLines:
        1,
        overflow:
        TextOverflow.ellipsis,
        style:
        const TextStyle(
          color:
          PharmaLensColors
              .teal,
          fontSize:
          10.8,
          fontWeight:
          FontWeight
              .w900,
        ),
      ),
    );
  }
}

class _WhatsAppBadge
    extends StatelessWidget {
  const _WhatsAppBadge();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        9,
        vertical:
        6,
      ),
      decoration:
      BoxDecoration(
        color:
        PharmaLensTheme
            .paletteOf(
          context,
        )
            .tealSurface,
        borderRadius:
        BorderRadius.circular(
          999,
        ),
      ),
      child:
      const Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            Icons
                .chat_rounded,
            color:
            PharmaLensColors
                .teal,
            size:
            14,
          ),
          SizedBox(
            width: 5,
          ),
          Text(
            'WhatsApp',
            style:
            TextStyle(
              color:
              PharmaLensColors
                  .teal,
              fontSize:
              10.5,
              fontWeight:
              FontWeight
                  .w900,
            ),
          ),
        ],
      ),
    );
  }
}