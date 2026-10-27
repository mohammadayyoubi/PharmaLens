import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_shell.dart';
import '../models/medicine_reminder.dart';
import '../models/prescription_record.dart';
import '../services/moph_medicine_service.dart';
import '../services/prescription_history_service.dart';
import '../services/reminder_service.dart';
import '../theme/pharmalens_theme.dart';
import '../utils/formatters.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/responsive.dart';
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

  String _text({required String en, required String ar}) {
    return _isArabic ? ar : en;
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
                _ScanCard(
                  isArabic: _isArabic,
                  isLoading: _isPickingImage,
                  showCamera: _cameraAvailable,
                  onCamera: () => _pickPrescriptionImage(ImageSource.camera),
                  onUpload: () => _pickPrescriptionImage(ImageSource.gallery),
                ),
                const SizedBox(height: 18),
                _QuickActions(isArabic: _isArabic, onOpen: _openTab),
              ];

              final secondary = <Widget>[
                _TodayReminders(isArabic: _isArabic, onOpenAll: () => _openTab(AppTab.myHealth)),
                const SizedBox(height: 18),
                _RecentScans(isArabic: _isArabic, onOpenAll: () => _openTab(AppTab.myHealth)),
                const SizedBox(height: 18),
                _DataStatusCard(isArabic: _isArabic),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 96),
                child: PageFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        isArabic: _isArabic,
                        showBrand: compact,
                        onSettings: () => _openTab(AppTab.settings),
                      ),
                      const SizedBox(height: 18),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isArabic, required this.showBrand, required this.onSettings});

  final bool isArabic;
  final bool showBrand;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? (isArabic ? 'صباح الخير' : 'Good morning')
        : hour < 18
            ? (isArabic ? 'مساء الخير' : 'Good afternoon')
            : (isArabic ? 'مساء الخير' : 'Good evening');

    return Row(
      children: [
        if (showBrand) ...[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: PharmaLensGradients.primary,
              borderRadius: BorderRadius.circular(13),
              boxShadow: PharmaLensShadows.cyanGlow,
            ),
            child: const Icon(Icons.medication_liquid_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 11),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBrand)
                Text.rich(
                  TextSpan(
                    style: TextStyle(color: palette.textPrimary, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                    children: const [
                      TextSpan(text: 'Pharma'),
                      TextSpan(text: 'Lens', style: TextStyle(color: PharmaLensColors.teal)),
                    ],
                  ),
                )
              else
                Semantics(
                  header: true,
                  child: Text(
                    greeting,
                    style: TextStyle(color: palette.textPrimary, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                ),
              Text(
                isArabic ? 'افهم وصفتك وتأكد من أدويتك بأمان.' : 'Understand your prescription and check your medicines safely.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (showBrand)
          IconButton(
            tooltip: isArabic ? 'الإعدادات' : 'Settings',
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
      decoration: PharmaLensDecorations.heroCard(borderRadius: BorderRadius.circular(26), isDark: isDark),
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
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showArt = constraints.maxWidth >= 520;

                final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
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
                          Flexible(
                            child: Text(
                              isArabic ? 'مطابقة مع لائحة وزارة الصحة' : 'CHECKED AGAINST THE MOPH LIST',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: PharmaLensColors.brightCyan, fontSize: 10.8, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        isArabic ? 'اقرأ وصفتك الطبية' : 'Read your prescription',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: constraints.maxWidth < 380 ? 25 : 30,
                          height: 1.1,
                          letterSpacing: isArabic ? 0 : -0.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isArabic
                          ? 'صوّر الوصفة أو ارفع صورتها. نقرأ أسماء الأدوية ونطابقها مع الأدوية المسجلة وأسعارها الرسمية، وننبهك عند تكرار المادة أو وجود حساسية.'
                          : 'Take a photo or upload one. We read the medicine names, match them to registered products and official prices, and flag duplicates or allergies.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13.5,
                        height: isArabic ? 1.6 : 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (showCamera)
                          FilledButton.icon(
                            onPressed: isLoading ? null : onCamera,
                            style: FilledButton.styleFrom(
                              backgroundColor: PharmaLensColors.cyan,
                              minimumSize: const Size(0, 50),
                            ),
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: Text(isArabic ? 'التقاط صورة' : 'Take photo'),
                          ),
                        FilledButton.icon(
                          onPressed: isLoading ? null : onUpload,
                          style: FilledButton.styleFrom(
                            backgroundColor: showCamera ? Colors.white.withValues(alpha: 0.14) : PharmaLensColors.cyan,
                            minimumSize: const Size(0, 50),
                          ),
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                )
                              : const Icon(Icons.upload_file_rounded),
                          label: Text(
                            isLoading
                                ? (isArabic ? 'جارٍ فتح الصورة...' : 'Opening image...')
                                : (isArabic ? 'رفع صورة' : 'Upload image'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic
                          ? 'نصيحة: صورة واضحة ومضاءة جيدًا تُظهر الوصفة كاملة.'
                          : 'Tip: use a clear, well-lit photo that shows the whole prescription.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                );

                if (!showArt) return text;

                return Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: 20),
                    Container(
                      width: 128,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      child: const Icon(Icons.document_scanner_outlined, color: PharmaLensColors.brightCyan, size: 58),
                    ),
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
    final actions = <(IconData, String, String, AppTab)>[
      (Icons.search_rounded, isArabic ? 'ابحث عن دواء' : 'Find a medicine', isArabic ? 'الأسعار والبدائل الرسمية' : 'Official prices and alternatives', AppTab.medicines),
      (Icons.medical_services_outlined, isArabic ? 'الأطباء' : 'Doctors', isArabic ? 'دليل نقابة الأطباء' : 'Order of Physicians directory', AppTab.doctors),
      (Icons.local_pharmacy_outlined, isArabic ? 'صيدليات قريبة' : 'Nearby pharmacies', isArabic ? 'على الخريطة' : 'On the map', AppTab.pharmacies),
      (Icons.favorite_outline_rounded, isArabic ? 'ملفي الصحي' : 'My health', isArabic ? 'السجل والتذكيرات والحساسية' : 'History, reminders, allergies', AppTab.myHealth),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        final spacing = 12.0;

        Widget tile((IconData, String, String, AppTab) action) {
          return SurfaceCard(
            padding: const EdgeInsets.all(16),
            onTap: () => onOpen(action.$4),
            semanticLabel: '${action.$2}. ${action.$3}',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PharmaLensTheme.paletteOf(context).tealSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action.$1, color: PharmaLensColors.teal),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    action.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PharmaLensTheme.paletteOf(context).textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    action.$3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PharmaLensTheme.paletteOf(context).textSecondary,
                      fontSize: 11.8,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final rows = <Widget>[];
        for (var start = 0; start < actions.length; start += columns) {
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns && i < actions.length; i++) ...[
                    if (i > start) SizedBox(width: spacing),
                    Expanded(child: tile(actions[i])),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(children: rows);
      },
    );
  }
}

class _TodayReminders extends StatelessWidget {
  const _TodayReminders({required this.isArabic, required this.onOpenAll});

  final bool isArabic;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final service = ReminderService();
    final palette = PharmaLensTheme.paletteOf(context);

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final now = DateTime.now();
        final nowMinutes = now.hour * 60 + now.minute;
        final doses = <(int, MedicineReminder)>[
          for (final reminder in service.reminders.where((r) => r.enabled && !r.isExpired))
            for (final time in reminder.times) (time, reminder),
        ]..sort((a, b) => a.$1.compareTo(b.$1));
        final upcoming = doses.where((d) => d.$1 >= nowMinutes).take(3).toList();

        return SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                icon: Icons.alarm_rounded,
                title: isArabic ? 'جرعات اليوم' : "Today's doses",
                trailing: TextButton(onPressed: onOpenAll, child: Text(isArabic ? 'الكل' : 'All')),
              ),
              const SizedBox(height: 10),
              if (doses.isEmpty)
                Text(
                  isArabic
                      ? 'لا تذكيرات بعد. بعد فحص وصفة، اضغط "تذكير" بجانب أي دواء.'
                      : 'No reminders yet. After scanning a prescription, tap "Remind me" next to a medicine.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.45),
                )
              else if (upcoming.isEmpty)
                Text(
                  isArabic ? 'انتهت جرعات اليوم.' : 'All of today\'s doses are done.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                )
              else
                for (final dose in upcoming)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: palette.tealSurface, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            MedicineReminder.formatTime(dose.$1),
                            style: const TextStyle(color: PharmaLensColors.teal, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dose.$2.medicineName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
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
        final recent = history.records.take(3).toList();

        return SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                icon: Icons.receipt_long_outlined,
                title: isArabic ? 'آخر الوصفات' : 'Recent prescriptions',
                trailing: recent.isEmpty ? null : TextButton(onPressed: onOpenAll, child: Text(isArabic ? 'الكل' : 'All')),
              ),
              const SizedBox(height: 6),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    isArabic ? 'ستظهر هنا الوصفات التي تفحصها.' : 'Prescriptions you scan will appear here.',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                  ),
                )
              else
                for (final record in recent) _RecentScanTile(record: record, isArabic: isArabic),
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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PrescriptionRecordScreen(record: record)),
      ),
      leading: const Icon(Icons.description_outlined, color: PharmaLensColors.teal),
      title: Text(
        MaterialLocalizations.of(context).formatMediumDate(record.createdAt),
        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
      ),
      subtitle: Text(
        names.isEmpty ? (isArabic ? 'لا أدوية مقروءة' : 'No readable medicines') : names,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: palette.textMuted,
      ),
    );
  }
}

class _DataStatusCard extends StatelessWidget {
  const _DataStatusCard({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final moph = MophMedicineService();
    final stale = moph.isDataStale;
    final failed = moph.loadError != null;

    final title = failed
        ? (isArabic ? 'تعذر تحميل لائحة الأدوية' : 'Medicine list could not be loaded')
        : stale
            ? (isArabic ? 'قد تكون الأسعار قديمة' : 'Prices may be out of date')
            : (isArabic ? 'لائحة أسعار وزارة الصحة' : 'MOPH price list');

    final body = failed
        ? (isArabic ? 'أعد تشغيل التطبيق. إذا استمرت المشكلة، أعد تثبيته.' : 'Restart the app. If it keeps happening, reinstall it.')
        : isArabic
            ? 'لائحة ${moph.lastUpdatedDate} · ${formatCount(moph.totalMedicineCount)} دواء مسجل.${stale ? ' تحقق من السعر في الصيدلية.' : ''}'
            : 'List of ${moph.lastUpdatedDate} · ${formatCount(moph.totalMedicineCount)} registered medicines.${stale ? ' Confirm the price at the pharmacy.' : ''}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: failed || stale ? palette.dangerSurface : palette.tealSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (failed || stale ? PharmaLensColors.warning : PharmaLensColors.teal).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            failed ? Icons.error_outline_rounded : stale ? Icons.history_toggle_off_rounded : Icons.fact_check_outlined,
            color: failed || stale ? PharmaLensColors.warning : PharmaLensColors.teal,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
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
            isArabic
                ? 'فارما لينس أداة مساعدة للمراجعة. تغيير الدواء أو استبداله يحتاج دائمًا إلى رأي الطبيب أو الصيدلي.'
                : 'PharmaLens helps you review. Changing or substituting a medicine always needs your doctor or pharmacist.',
            style: TextStyle(color: palette.textMuted, fontSize: 12, height: 1.45, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
