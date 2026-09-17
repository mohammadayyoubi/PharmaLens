import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/pharmalens_theme.dart';
import '../widgets/chatbot_view.dart';
import 'analysis_screen.dart';
import 'doctors_screen.dart';
import 'medicine_search_screen.dart';
import 'pharmacies_map_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _maximumImageBytes = 15 * 1024 * 1024;

  final ImagePicker _imagePicker = ImagePicker();

  bool _isPickingImage = false;

  bool get _isArabic {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  }

  String _text({required String en, required String ar}) {
    return _isArabic ? ar : en;
  }

  Future<void> _pickPrescriptionImage(ImageSource source) async {
    if (_isPickingImage) {
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2200,
        maxHeight: 2200,
      );

      if (pickedImage == null) {
        return;
      }

      final fileSize = await pickedImage.length();

      if (fileSize <= 0) {
        _showSafeError(
          _text(
            en: 'The selected image is empty. Please choose another image.',
            ar: 'الصورة المختارة فارغة. يرجى اختيار صورة أخرى.',
          ),
        );

        return;
      }

      if (fileSize > _maximumImageBytes) {
        _showSafeError(
          _text(
            en: 'The selected image is too large. Please use a smaller image.',
            ar: 'حجم الصورة كبير جدًا. يرجى استخدام صورة أصغر.',
          ),
        );

        return;
      }

      final imageBytes = await pickedImage.readAsBytes();

      if (imageBytes.isEmpty) {
        _showSafeError(
          _text(
            en: 'The selected image could not be read.',
            ar: 'تعذر قراءة الصورة المختارة.',
          ),
        );

        return;
      }

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AnalysisScreen(
            imagePath: pickedImage.path,
            imageBytes: imageBytes,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _debugLog('Prescription image selection failed.', error, stackTrace);

      if (!mounted) {
        return;
      }

      _showSafeError(
        _text(
          en: 'The image could not be opened. Please try again.',
          ar: 'تعذر فتح الصورة. يرجى إعادة المحاولة.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _openImageSourceSheet() async {
    if (_isPickingImage) {
      return;
    }

    final palette = PharmaLensTheme.paletteOf(context);

    final isDark = PharmaLensTheme.isDark(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.64 : 0.34),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.tealSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.document_scanner_outlined,
                    color: PharmaLensColors.teal,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _text(en: 'Add prescription image', ar: 'إضافة صورة الوصفة'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _text(
                    en: 'Use a clear, well-lit image with the full prescription visible.',
                    ar: 'استخدم صورة واضحة ومضاءة جيدًا وتظهر الوصفة بالكامل.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textSecondary,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _ImageSourceTile(
                  icon: Icons.photo_camera_rounded,
                  title: _text(en: 'Take photo', ar: 'التقاط صورة'),
                  subtitle: _text(
                    en: 'Capture a new prescription.',
                    ar: 'صوّر وصفة جديدة.',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    _pickPrescriptionImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                _ImageSourceTile(
                  icon: Icons.photo_library_rounded,
                  title: _text(en: 'Upload image', ar: 'رفع صورة'),
                  subtitle: _text(
                    en: 'Choose an existing prescription image.',
                    ar: 'اختر صورة وصفة موجودة على الجهاز.',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    _pickPrescriptionImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMedicineSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MedicineSearchScreen()),
    );
  }

  void _openPharmaciesMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PharmaciesMapScreen()),
    );
  }

  void _openDoctorsDirectory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DoctorsScreen()));
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  void _showSafeError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _debugLog(String message, Object error, StackTrace stackTrace) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('$message\n$error');

    debugPrintStack(stackTrace: stackTrace);
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    final isDark = PharmaLensTheme.isDark(context);

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: const FloatingChatbotButton(),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720;

              final veryCompact = constraints.maxHeight < 640;

              final narrow = constraints.maxWidth < 390;

              final horizontalPadding = constraints.maxWidth >= 700
                  ? 22.0
                  : narrow
                  ? 12.0
                  : 14.0;

              final content = _buildHomeContent(
                compact: compact,
                veryCompact: veryCompact,
                narrow: narrow,
                horizontalPadding: horizontalPadding,
                isDark: isDark,
              );

              if (constraints.maxHeight < 560) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    12,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: content,
                  ),
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: content,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent({
    required bool compact,
    required bool veryCompact,
    required bool narrow,
    required double horizontalPadding,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? 8 : 14,
        horizontalPadding,
        compact ? 8 : 14,
      ),
      child: Column(
        children: [
          _buildTopBar(),
          SizedBox(height: compact ? 12 : 16),
          _buildHeroCard(
            compact: compact,
            veryCompact: veryCompact,
            narrow: narrow,
          ),
          SizedBox(height: compact ? 10 : 14),
          Expanded(
            child: _buildMainActions(
              compact: compact,
              veryCompact: veryCompact,
              narrow: narrow,
            ),
          ),
          SizedBox(height: compact ? 9 : 12),
          _buildSafetyFooter(compact: compact, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final palette = PharmaLensTheme.paletteOf(context);

    final isDark = PharmaLensTheme.isDark(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PharmaLensColors.teal,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: PharmaLensColors.teal.withValues(
                  alpha: isDark ? 0.28 : 0.18,
                ),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.medication_liquid_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
              children: const [
                TextSpan(text: 'Pharma'),
                TextSpan(
                  text: 'Lens',
                  style: TextStyle(color: PharmaLensColors.teal),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _openSettings,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Icon(Icons.settings_outlined, color: palette.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard({
    required bool compact,
    required bool veryCompact,
    required bool narrow,
  }) {
    final isDark = PharmaLensTheme.isDark(context);

    final height = veryCompact
        ? narrow
              ? 238.0
              : 220.0
        : compact
        ? narrow
              ? 250.0
              : 236.0
        : narrow
        ? 272.0
        : 270.0;

    return Container(
      width: double.infinity,
      height: height,
      decoration: PharmaLensDecorations.heroCard(
        borderRadius: BorderRadius.circular(24),
        isDark: isDark,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showArtwork = constraints.maxWidth >= 410;

          final horizontalPadding = narrow ? 18.0 : 23.0;

          final artworkSpace = showArtwork ? 108.0 : 0.0;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              PositionedDirectional(
                end: -44,
                top: -64,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.055),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              PositionedDirectional(
                start: -60,
                bottom: -90,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: PharmaLensColors.teal.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (showArtwork)
                PositionedDirectional(
                  end: 8,
                  bottom: 3,
                  child: _HeroArtwork(compact: compact),
                ),
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: horizontalPadding,
                  top: veryCompact ? 17 : 21,
                  end: horizontalPadding + artworkSpace,
                  bottom: veryCompact ? 16 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroBadge(
                      text: _text(
                        en: 'SMART MEDICINE SUPPORT',
                        ar: 'دعم دوائي ذكي',
                      ),
                    ),
                    SizedBox(height: veryCompact ? 12 : 17),
                    Text(
                      _text(
                        en: 'Understand the\nprescription safely.',
                        ar: 'افهم الوصفة\nبشكل أكثر أمانًا.',
                      ),
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: narrow
                            ? 27
                            : veryCompact
                            ? 26
                            : compact
                            ? 29
                            : 31,
                        height: _isArabic ? 1.18 : 1.05,
                        letterSpacing: _isArabic ? 0 : -0.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: narrow ? 9 : 10),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: Text(
                          _text(
                            en: 'Prescription reading, medicine records, verified-composition alternatives, doctors and nearby pharmacies.',
                            ar: 'قراءة الوصفات، سجلات الأدوية، بدائل بالتركيبة المتحقّق منها، أطباء وصيدليات قريبة.',
                          ),
                          maxLines: narrow ? 4 : 5,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: narrow
                                ? 11.3
                                : veryCompact
                                ? 11.5
                                : 12.3,
                            height: _isArabic ? 1.55 : 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainActions({
    required bool compact,
    required bool veryCompact,
    required bool narrow,
  }) {
    final spacing = narrow ? 6.0 : 9.0;

    return Column(
      children: [
        Expanded(
          flex: 11,
          child: _PrimaryActionCard(
            isLoading: _isPickingImage,
            compact: compact,
            title: _text(en: 'Scan prescription', ar: 'فحص وصفة طبية'),
            subtitle: _text(
              en: 'Capture or upload a clear prescription image.',
              ar: 'صوّر أو ارفع صورة واضحة للوصفة.',
            ),
            loadingText: _text(
              en: 'Opening image...',
              ar: 'جارٍ فتح الصورة...',
            ),
            onTap: _openImageSourceSheet,
          ),
        ),
        SizedBox(height: compact ? 9 : 11),
        Expanded(
          flex: 12,
          child: Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.search_rounded,
                  title: _text(en: 'Search', ar: 'بحث'),
                  subtitle: _text(en: 'Medicines', ar: 'الأدوية'),
                  compact: veryCompact,
                  narrow: narrow,
                  onTap: _openMedicineSearch,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.local_pharmacy_outlined,
                  title: _text(en: 'Pharmacies', ar: 'صيدليات'),
                  subtitle: _text(en: 'Nearby', ar: 'قريبة'),
                  compact: veryCompact,
                  narrow: narrow,
                  onTap: _openPharmaciesMap,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.medical_services_outlined,
                  title: _text(en: 'Doctors', ar: 'أطباء'),
                  subtitle: _text(en: 'Directory', ar: 'الدليل'),
                  compact: veryCompact,
                  narrow: narrow,
                  onTap: _openDoctorsDirectory,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyFooter({required bool compact, required bool isDark}) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: compact ? 10 : 13,
      ),
      decoration: BoxDecoration(
        color: palette.tealSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PharmaLensColors.teal.withValues(alpha: isDark ? 0.34 : 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: PharmaLensColors.teal.withValues(
                alpha: isDark ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: PharmaLensColors.teal,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _text(
                en: 'PharmaLens supports review. Medicine changes and substitutions still require professional judgment.',
                ar: 'PharmaLens يساعد بالمراجعة. تغيير الدواء أو استبداله يبقى بحاجة لتقييم مهني.',
              ),
              style: TextStyle(
                color: palette.textSecondary,
                height: _isArabic ? 1.5 : 1.38,
                fontSize: compact ? 11.3 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.isLoading,
    required this.compact,
    required this.title,
    required this.subtitle,
    required this.loadingText,
    required this.onTap,
  });

  final bool isLoading;
  final bool compact;

  final String title;
  final String subtitle;
  final String loadingText;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    final isDark = PharmaLensTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 15 : 18),
          decoration: PharmaLensDecorations.surfaceCard(
            borderRadius: BorderRadius.circular(21),
            isDark: isDark,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 52 : 58,
                height: compact ? 52 : 58,
                decoration: BoxDecoration(
                  color: palette.tealSurface,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(
                        Icons.document_scanner_outlined,
                        color: PharmaLensColors.teal,
                        size: 29,
                      ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading ? loadingText : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: compact ? 15 : 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        height: 1.35,
                        fontSize: 11.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.compact,
    required this.narrow,
    required this.onTap,
  });

  final IconData icon;

  final String title;
  final String subtitle;

  final bool compact;
  final bool narrow;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    final isDark = PharmaLensTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: narrow
                ? 7
                : compact
                ? 9
                : 11,
            vertical: compact ? 6 : 8,
          ),
          decoration: PharmaLensDecorations.surfaceCard(
            borderRadius: BorderRadius.circular(20),
            isDark: isDark,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: compact ? 39 : 45,
                height: compact ? 39 : 45,
                decoration: BoxDecoration(
                  color: palette.tealSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: PharmaLensColors.teal,
                  size: compact ? 20 : 23,
                ),
              ),
              SizedBox(height: compact ? 7 : 9),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: narrow
                          ? 12.5
                          : compact
                          ? 12
                          : 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: narrow
                          ? 10
                          : compact
                          ? 9.8
                          : 10.7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  const _ImageSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;

  final String title;
  final String subtitle;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Material(
      color: palette.surfaceSoft,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: palette.tealSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: PharmaLensColors.teal),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: PharmaLensColors.brightCyan,
            size: 15,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PharmaLensColors.brightCyan,
                fontSize: 10.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 78.0 : 90.0;

    return SizedBox(
      width: 108,
      height: 104,
      child: Stack(
        children: [
          PositionedDirectional(
            end: 16,
            bottom: 13,
            child: Container(
              width: size * 0.75,
              height: size * 0.88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: PharmaLensColors.brightCyan,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
