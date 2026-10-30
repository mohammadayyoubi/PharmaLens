import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_settings_scope.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_text.dart';
import '../services/moph_medicine_service.dart';
import '../theme/pharmalens_theme.dart';
import '../utils/formatters.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/sync_progress.dart';

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

/// Who made the app: TechWrap LB, a Lebanese team, with its contacts.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({
    required this.isArabic,
    required this.developer,
    required this.whatsApp,
    required this.instagramHandle,
    required this.onInstagram,
  });

  final bool isArabic;
  final String developer;
  final String whatsApp;
  final String instagramHandle;
  final VoidCallback onInstagram;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          const _LebanonFlag(width: 42),
          const SizedBox(height: 10),
          Text(
            appText(isArabic).developedBy(developer),
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            appText(isArabic).madeInLebanonByLebaneseDevelopers,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.camera_alt_outlined, size: 18, color: PharmaLensColors.instagram),
                label: Text('@$instagramHandle'),
                onPressed: onInstagram,
                tooltip: 'Instagram',
              ),
              Chip(
                avatar: const Icon(Icons.chat_outlined, size: 18, color: PharmaLensColors.teal),
                label: Text(whatsApp, textDirection: TextDirection.ltr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The Lebanese flag: red bands, white middle, green cedar.
class _LebanonFlag extends StatelessWidget {
  const _LebanonFlag({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: width * 2 / 3,
        child: Column(
          children: [
            Expanded(child: Container(color: PharmaLensColors.lebanonRed)),
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Icon(Icons.park_rounded, color: PharmaLensColors.lebanonCedar, size: width * 0.38),
              ),
            ),
            Expanded(child: Container(color: PharmaLensColors.lebanonRed)),
          ],
        ),
      ),
    );
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
      'TechWrap LB';

  static const String _instagramHandle =
      'techwrap.lb';

  static const String _instagramUrl =
      'https://www.instagram.com/techwrap.lb/';

  static const String _appVersion =
      '1.1.0';


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
                appText(_isArabic).chooseAppearance,
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
                appText(_isArabic).chooseLightDarkOrFollowThe,
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
                appText(_isArabic).lightMode,
                subtitle:
                appText(_isArabic).brightMedicalInterface,
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
                appText(_isArabic).darkMode,
                subtitle:
                appText(_isArabic).comfortableDarkInterface,
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
                appText(_isArabic).systemDefault,
                subtitle:
                appText(_isArabic).followTheDeviceAutomatically,
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

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(_isArabic).couldNotOpenTheLink)),
        );
      }
    } catch (error) {
      debugPrint('Settings: could not open $url: $error');
    }
  }

  Future<void> _openWhatsApp() async {
    final message =
    appText(_isArabic).helloIAmContactingYouFrom;

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
          appText(_isArabic).couldNotOpenWhatsappOnThis,
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
        appText(_isArabic).couldNotOpenWhatsappOnThis,
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

                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                  child:
                  Image.asset(
                    'assets/branding/app_icon.png',
                    width: 64,
                    height: 64,
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                Text(
                  appText(_isArabic).aboutPharmalens,
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
                  appText(_isArabic).pharmalensIsAMedicineAndPrescription,
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

                _DeveloperCard(
                  isArabic: _isArabic,
                  developer: _developerTeam,
                  whatsApp: _displayWhatsAppNumber,
                  instagramHandle: _instagramHandle,
                  onInstagram: () => _openExternal(_instagramUrl),
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
                      appText(_isArabic).done,
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
    // The tile shows the progress and stays disabled until the check ends.
    if (MophMedicineService().isSyncing) return;

    try {
      final result = await MophMedicineService().checkAndUpdateIfStale(force: true);

      if (!mounted) return;

      _showSafeMessage(
        result.describe(
          isArabic: _isArabic,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showSafeMessage(
        appText(_isArabic).failedToSyncWithMophServer,
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
        return appText(_isArabic).light;

      case ThemeMode.dark:
        return appText(_isArabic).dark;

      case ThemeMode.system:
        return appText(_isArabic).system;
    }
  }

  String _appearanceCode(
      ThemeMode themeMode,
      ) {
    switch (themeMode) {
      case ThemeMode.light:
        return appText(_isArabic).light;

      case ThemeMode.dark:
        return appText(_isArabic).dark;

      case ThemeMode.system:
        return appText(_isArabic).auto;
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
                    appText(_isArabic).preferences,
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
                        appText(_isArabic).appearance,
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
                    appText(_isArabic).contact2,
                    children: [
                      _SettingsTile(
                        icon:
                        Icons
                            .chat_rounded,
                        title:
                        appText(_isArabic).contactOnWhatsapp,
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
                    appText(_isArabic).dataSync,
                    children: [
                      ValueListenableBuilder<MophSyncProgress>(
                        valueListenable: MophMedicineService().progress,
                        builder: (context, progress, _) {
                          final busy = progress.busy || MophMedicineService().isSyncing;
                          return _SettingsTile(
                            icon: Icons.sync_rounded,
                            title: appText(_isArabic).syncMophMedicineData,
                            subtitle: busy
                                ? '${progress.busy ? progress.label(isArabic: _isArabic) : appText(_isArabic).syncingInProgress} ${progress.percent}%'
                                : appText(_isArabic).mophListOfMedicines(MophMedicineService().publishedDate, formatCount(MophMedicineService().totalMedicineCount)),
                            trailing: MophSyncButton(
                              tooltip: appText(_isArabic).syncNow,
                              onPressed: _manualSyncMoph,
                            ),
                            onTap: busy ? null : _manualSyncMoph,
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _SettingsSection(
                    title:
                    appText(_isArabic).about,
                    children: [
                      _SettingsTile(
                        icon:
                        Icons
                            .info_outline_rounded,
                        title:
                        appText(_isArabic).aboutPharmalens,
                        subtitle:
                        appText(_isArabic).version(_appVersion, _developerTeam),
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
                appText(_isArabic).languageAppearanceAndApplicationInformation,
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
                  appText(_isArabic).medicineAndPrescriptionSupportWithSafety,
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
                  appText(_isArabic).medicalDisclaimer2,
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