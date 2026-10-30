import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_shell.dart';
import '../l10n/app_text.dart';
import '../models/medicine_reminder.dart';
import '../models/prescription_record.dart';
import '../services/moph_medicine_service.dart';
import '../services/prescription_history_service.dart';
import '../services/dose_log_service.dart';
import '../services/health_profile_service.dart';
import '../services/reminder_service.dart';
import '../theme/pharmalens_theme.dart';
import '../utils/formatters.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/responsive.dart';
import '../widgets/sync_progress.dart';
import 'analysis_screen.dart';
import 'my_health_screen.dart';
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

  bool get _cameraAvailable {
    try {
      return _imagePicker.supportsImageSource(ImageSource.camera);
    } catch (_) {
      return false;
    }
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
        // Gemini downsamples larger images anyway; a smaller upload is
        // noticeably faster on slow connections.
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (pickedImage == null) {
        return;
      }

      final fileSize = await pickedImage.length();

      if (fileSize <= 0) {
        _showSafeError(
          appText(_isArabic).theSelectedImageIsEmptyPlease,
        );

        return;
      }

      if (fileSize > _maximumImageBytes) {
        _showSafeError(
          appText(_isArabic).theSelectedImageIsTooLarge,
        );

        return;
      }

      final imageBytes = await pickedImage.readAsBytes();

      if (imageBytes.isEmpty) {
        _showSafeError(
          appText(_isArabic).theSelectedImageCouldNotBe,
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
        appText(_isArabic).theImageCouldNotBeOpened,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  /// My Health, opened on the given tab on phones (see MyHealthScreen).
  void _openMyHealth(int tab) {
    MyHealthScreen.requestedTab.value = tab;
    _openTab(AppTab.myHealth);
  }

  void _openTab(AppTab tab) {
    final shell = AppShellScope.maybeOf(context);
    if (shell != null) {
      shell.selectTab(tab);
      return;
    }

    if (tab == AppTab.settings) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    }
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
    final compact = Breakpoints.isCompact(context);

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: const FloatingChatbotButton(),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 920;

              final primary = <Widget>[
                FadeSlideIn(
                  child: _ScanCard(
                    isArabic: _isArabic,
                    isLoading: _isPickingImage,
                    showCamera: _cameraAvailable,
                    onCamera: () => _pickPrescriptionImage(ImageSource.camera),
                    onUpload: () => _pickPrescriptionImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 90),
                  child: _QuickActions(isArabic: _isArabic, onOpen: _openTab),
                ),
              ];

              final secondary = <Widget>[
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: _TodayDoses(isArabic: _isArabic, onOpenAll: () => _openMyHealth(1)),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 220),
                  child: _RecentScans(isArabic: _isArabic, onOpenAll: () => _openMyHealth(0)),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 280),
                  child: _DataStatusCard(isArabic: _isArabic),
                ),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 96),
                child: PageFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Wider layouts show the logo and Settings in the sidebar.
                      if (compact) ...[
                        _TopBar(
                          isArabic: _isArabic,
                          onSettings: () => _openTab(AppTab.settings),
                        ),
                        const SizedBox(height: 18),
                      ] else ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: MophSyncChip(isArabic: _isArabic),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (twoColumns)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: primary)),
                            const SizedBox(width: 22),
                            Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: secondary)),
                          ],
                        )
                      else ...[
                        ...primary,
                        const SizedBox(height: 18),
                        ...secondary,
                      ],
                      const SizedBox(height: 18),
                      _SafetyFooter(isArabic: _isArabic),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Phone header: the logo, and Settings at the other end.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.isArabic, required this.onSettings});

  final bool isArabic;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/branding/app_icon.png', width: 40, height: 40),
        ),
        const SizedBox(width: 10),
        // The wordmark is part of the logo: it does not grow with large
        // text, and shrinks on very narrow screens.
        Flexible(
          flex: 3,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: palette.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                    children: const [
                      TextSpan(text: 'Pharma'),
                      TextSpan(text: 'Lens', style: TextStyle(color: PharmaLensColors.teal)),
                    ],
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Shows while the medicine list loads or checks for a newer one.
        Expanded(
          flex: 2,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: MophSyncChip(isArabic: isArabic),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: appText(isArabic).settings,
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
          style: IconButton.styleFrom(side: BorderSide(color: palette.border)),
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.isArabic,
    required this.isLoading,
    required this.showCamera,
    required this.onCamera,
    required this.onUpload,
  });

  final bool isArabic;
  final bool isLoading;
  final bool showCamera;
  final VoidCallback onCamera;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final isDark = PharmaLensTheme.isDark(context);

    return Container(
      decoration: PharmaLensDecorations.heroCard(borderRadius: BorderRadius.circular(28), isDark: isDark),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PositionedDirectional(
            end: -50,
            top: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
            ),
          ),
          PositionedDirectional(
            start: -70,
            bottom: -110,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(color: PharmaLensColors.cyan.withValues(alpha: 0.08), shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 540;
                final narrow = constraints.maxWidth < 360;

                final badge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined, color: PharmaLensColors.brightCyan, size: 15),
                      const SizedBox(width: 6),
                      // Always one line; very narrow screens shrink it.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            appText(isArabic).checkedAgainstTheMophList,
                            maxLines: 1,
                            style: const TextStyle(color: PharmaLensColors.brightCyan, fontSize: 10.8, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                final title = Semantics(
                  header: true,
                  child: Text(
                    appText(isArabic).readYourPrescription,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: narrow ? 24 : 29,
                      height: 1.1,
                      letterSpacing: isArabic ? 0 : -0.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );

                final body = Text(
                  appText(isArabic).takeAPhotoOrUploadOne,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 13.5,
                    height: isArabic ? 1.6 : 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                );

                final cameraButton = FilledButton.icon(
                  onPressed: isLoading ? null : onCamera,
                  style: FilledButton.styleFrom(
                    backgroundColor: PharmaLensColors.cyan,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.photo_camera_rounded, size: 20),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(appText(isArabic).takePhoto)),
                );

                final uploadButton = FilledButton.icon(
                  onPressed: isLoading ? null : onUpload,
                  style: FilledButton.styleFrom(
                    backgroundColor: showCamera ? Colors.white.withValues(alpha: 0.14) : PharmaLensColors.cyan,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: showCamera ? BorderSide(color: Colors.white.withValues(alpha: 0.25)) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.upload_file_rounded, size: 20),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isLoading ? appText(isArabic).opening : appText(isArabic).uploadImage,
                    ),
                  ),
                );

                // Side by side at every width; each takes half.
                final buttons = Row(
                  children: [
                    if (showCamera) ...[
                      Expanded(child: PressableScale(child: cameraButton)),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: PressableScale(child: uploadButton)),
                  ],
                );

                final tip = Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: Colors.white.withValues(alpha: 0.6), size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        appText(isArabic).useAClearWellLitPhoto,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );

                final illustration = Image.asset(
                  'assets/images/scan_illustration.png',
                  fit: BoxFit.contain,
                  semanticLabel: appText(isArabic).aPhoneReadingAPrescription,
                );

                if (wide) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [badge, const SizedBox(height: 16), title, const SizedBox(height: 10), body, const SizedBox(height: 20), buttons, const SizedBox(height: 12), tip],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: illustration),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [badge, const SizedBox(height: 14), title],
                          ),
                        ),
                        SizedBox(width: narrow ? 84 : 112, height: narrow ? 68 : 90, child: illustration),
                      ],
                    ),
                    const SizedBox(height: 10),
                    body,
                    const SizedBox(height: 18),
                    buttons,
                    const SizedBox(height: 12),
                    tip,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isArabic, required this.onOpen});

  final bool isArabic;
  final void Function(AppTab tab) onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final actions = <(IconData, String, String, AppTab, Color)>[
      (Icons.search_rounded, appText(isArabic).findAMedicine, appText(isArabic).officialPricesAndAlternatives, AppTab.medicines, PharmaLensColors.teal),
      (Icons.medical_services_outlined, appText(isArabic).doctors, appText(isArabic).orderOfPhysiciansDirectory, AppTab.doctors, PharmaLensColors.accentBlue),
      (Icons.local_pharmacy_outlined, appText(isArabic).nearbyPharmacies, appText(isArabic).onTheMap, AppTab.pharmacies, PharmaLensColors.accentCoral),
      (Icons.favorite_outline_rounded, appText(isArabic).myHealth, appText(isArabic).historyRemindersAllergies, AppTab.myHealth, PharmaLensColors.accentViolet),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        const spacing = 12.0;
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        Widget tile((IconData, String, String, AppTab, Color) action) {
          return SizedBox(
            width: tileWidth,
            child: PressableScale(
              child: SurfaceCard(
                padding: const EdgeInsets.all(14),
                onTap: () => onOpen(action.$4),
                semanticLabel: '${action.$2}. ${action.$3}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: action.$5.withValues(alpha: PharmaLensTheme.isDark(context) ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(action.$1, color: action.$5),
                          ),
                          const Spacer(),
                          Icon(
                            Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                            size: 18,
                            color: palette.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Two lines so "Nearby pharmacies" is never cut.
                      Text(
                        action.$2,
                        maxLines: 2,
                        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        action.$3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontSize: 11.8, height: 1.35, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final action in actions) tile(action)],
        );
      },
    );
  }
}

class _TodayDoses extends StatelessWidget {
  const _TodayDoses({required this.isArabic, required this.onOpenAll});

  final bool isArabic;
  final VoidCallback onOpenAll;

  static const int _shownDoses = 4;

  static List<DueDose> _upcomingFirst(List<DueDose> doses, DoseLogService log) {
    bool answered(DueDose d) => log.statusOf(d.reminder.id, d.day, d.minutes) != null;
    return <DueDose>[...doses.where((d) => !answered(d)), ...doses.where(answered)];
  }

  @override
  Widget build(BuildContext context) {
    final service = ReminderService();
    final log = DoseLogService();
    final palette = PharmaLensTheme.paletteOf(context);

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[service, log]),
      builder: (context, _) {
        final now = DateTime.now();
        final nowMinutes = now.hour * 60 + now.minute;
        final doses = service.todaysDoses();
        final taken = doses.where((d) => log.statusOf(d.reminder.id, d.day, d.minutes) == DoseStatus.taken).length;
        final refills = service.reminders
            .where((r) => r.refillDate != null && r.refillDate!.difference(now).inDays <= 3 && !r.isExpired)
            .toList();

        return SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                icon: Icons.alarm_rounded,
                title: appText(isArabic).todaySDoses,
                trailing: service.reminders.isEmpty ? null : TextButton(onPressed: onOpenAll, child: Text(appText(isArabic).all)),
              ),
              const SizedBox(height: 10),
              if (doses.isEmpty)
                Row(
                  children: [
                    Image.asset('assets/images/reminder_illustration.png', width: 64, height: 64),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        appText(isArabic).noRemindersYetAfterScanningA,
                        style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.45),
                      ),
                    ),
                  ],
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: doses.isEmpty ? 0 : taken / doses.length,
                          minHeight: 8,
                          backgroundColor: palette.tealSurface,
                          color: PharmaLensColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      appText(isArabic).ofText(taken, doses.length),
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Doses still to answer first; taken or skipped ones after.
                for (final dose in _upcomingFirst(doses, log).take(_shownDoses))
                  _DoseRow(
                    dose: dose,
                    status: log.statusOf(dose.reminder.id, dose.day, dose.minutes),
                    isPast: dose.minutes <= nowMinutes,
                    isArabic: isArabic,
                  ),
                if (doses.length > _shownDoses)
                  _ShowAllButton(label: appText(isArabic).showAllCount(doses.length), onPressed: onOpenAll),
              ],
              for (final reminder in refills.take(2))
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: PharmaLensColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: PharmaLensColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          appText(isArabic).mayRunOutOnTimeTo(reminder.medicineName, MaterialLocalizations.of(context).formatMediumDate(reminder.refillDate!)),
                          style: TextStyle(color: palette.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A button at the bottom of a home card that opens the full list.
class _ShowAllButton extends StatelessWidget {
  const _ShowAllButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 6),
            Icon(rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose, required this.status, required this.isPast, required this.isArabic});

  final DueDose dose;
  final DoseStatus? status;
  final bool isPast;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final done = status == DoseStatus.taken;
    final skipped = status == DoseStatus.skipped;
    final owner = HealthProfileService().byId(dose.reminder.profileId);
    final person = owner == null || owner.isOwner ? '' : owner.name;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: done ? PharmaLensColors.success.withValues(alpha: 0.14) : palette.tealSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              MedicineReminder.formatTime(dose.minutes),
              style: TextStyle(
                color: done ? PharmaLensColors.success : PharmaLensColors.teal,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.reminder.medicineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (dose.reminder.isAlarm || skipped || person.isNotEmpty)
                  Text(
                    [
                      if (person.isNotEmpty) person,
                      if (skipped) isArabic ? 'تم التخطي' : 'Skipped' else if (dose.reminder.isAlarm) isArabic ? 'منبه' : 'Alarm',
                    ].join(' · '),
                    style: TextStyle(color: palette.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          if (done)
            const Icon(Icons.check_circle_rounded, color: PharmaLensColors.success)
          else
            TextButton.icon(
              onPressed: () => ReminderService().markTaken(dose),
              style: TextButton.styleFrom(
                foregroundColor: isPast ? PharmaLensColors.success : palette.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(appText(isArabic).taken2),
            ),
        ],
      ),
    );
  }
}

class _RecentScans extends StatelessWidget {
  const _RecentScans({required this.isArabic, required this.onOpenAll});

  final bool isArabic;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final history = PrescriptionHistoryService();
    final palette = PharmaLensTheme.paletteOf(context);

    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final all = history.records;
        final recent = all.take(3).toList();

        return SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                icon: Icons.receipt_long_outlined,
                title: appText(isArabic).recentPrescriptions,
                trailing: recent.isEmpty ? null : TextButton(onPressed: onOpenAll, child: Text(appText(isArabic).all)),
              ),
              const SizedBox(height: 6),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    appText(isArabic).prescriptionsYouScanWillAppearHere,
                    style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                  ),
                )
              else ...[
                for (final record in recent) _RecentScanTile(record: record, isArabic: isArabic),
                if (all.length > recent.length)
                  _ShowAllButton(label: appText(isArabic).showAllCount(all.length), onPressed: onOpenAll),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  const _RecentScanTile({required this.record, required this.isArabic});

  final PrescriptionRecord record;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final names = record.medicines.map((m) => m.displayName).where((n) => n.isNotEmpty).join(', ');
    final verified = record.medicines.where((m) => m.verified).length;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PrescriptionRecordScreen(record: record)),
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: palette.tealSurface, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.description_outlined, color: PharmaLensColors.teal),
      ),
      title: Text(
        MaterialLocalizations.of(context).formatMediumDate(record.createdAt),
        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
      ),
      subtitle: Text(
        names.isEmpty
            ? appText(isArabic).noReadableMedicines
            : '$names · ${appText(isArabic).verified2(verified)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
      ),
      trailing: Icon(
        Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        color: palette.textMuted,
      ),
    );
  }
}

class _DataStatusCard extends StatelessWidget {
  const _DataStatusCard({required this.isArabic});

  final bool isArabic;

  Future<void> _sync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await MophMedicineService().checkAndUpdateIfStale(force: true);
    messenger.showSnackBar(SnackBar(content: Text(result.describe(isArabic: isArabic))));
  }

  @override
  Widget build(BuildContext context) {
    final moph = MophMedicineService();

    // The list loads after the first frame; show it once it is in.
    return ListenableBuilder(
      listenable: moph.changes,
      builder: (context, _) {
        final palette = PharmaLensTheme.paletteOf(context);
        final loading = !moph.isInitialized;
        final stale = moph.isDataStale;
        final failed = moph.loadError != null;

        final title = loading
            ? appText(isArabic).mophPriceList
            : failed
                ? appText(isArabic).medicineListCouldNotBeLoaded
                : stale
                    ? appText(isArabic).pricesMayBeOutOfDate
                    : appText(isArabic).mophPriceList;

        final body = loading
            ? ''
            : failed
                ? appText(isArabic).restartTheAppIfItKeeps
                : isArabic
                    ? 'لائحة ${moph.publishedDate} · ${formatCount(moph.totalMedicineCount)} دواء مسجل.${stale ? ' تحقق من السعر في الصيدلية.' : ''}'
                    : 'List of ${moph.publishedDate} · ${formatCount(moph.totalMedicineCount)} registered medicines.${stale ? ' Confirm the price at the pharmacy.' : ''}';

        final warn = failed || stale;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: warn ? palette.dangerSurface : palette.tealSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: (warn ? PharmaLensColors.warning : PharmaLensColors.teal).withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              // A still icon: loading takes a moment, and an endless spinner
              // here would also keep the page from ever settling in tests.
              if (loading)
                const Icon(Icons.hourglass_top_rounded, color: PharmaLensColors.teal)
              else
                Icon(
                  failed ? Icons.error_outline_rounded : stale ? Icons.history_toggle_off_rounded : Icons.fact_check_outlined,
                  color: warn ? PharmaLensColors.warning : PharmaLensColors.teal,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(body, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.4)),
                    ],
                    MophSyncProgressLine(isArabic: isArabic),
                  ],
                ),
              ),
              if (moph.canCheckForUpdates && !failed)
                MophSyncButton(
                  tooltip: appText(isArabic).checkForANewerList,
                  onPressed: () => _sync(context),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SafetyFooter extends StatelessWidget {
  const _SafetyFooter({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: palette.textMuted, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            appText(isArabic).pharmalensHelpsYouReviewChangingOr,
            style: TextStyle(color: palette.textMuted, fontSize: 12, height: 1.45, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
