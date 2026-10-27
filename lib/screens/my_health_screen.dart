import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/medicine_price.dart';
import '../models/medicine_reminder.dart';
import '../models/prescription_record.dart';
import '../services/health_profile_service.dart';
import '../services/medication_safety_service.dart';
import '../services/moph_medicine_service.dart';
import '../services/prescription_history_service.dart';
import '../services/reminder_service.dart';
import '../theme/pharmalens_theme.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/reminder_editor.dart';
import '../widgets/safety_alert_card.dart';
import '../widgets/responsive.dart';
import 'medicine_details_screen.dart';

/// The user's own records: scanned prescriptions, medicine reminders and
/// allergies. Everything here stays on the device.
class MyHealthScreen extends StatefulWidget {
  const MyHealthScreen({super.key});

  @override
  State<MyHealthScreen> createState() => _MyHealthScreenState();
}

class _MyHealthScreenState extends State<MyHealthScreen> {
  final PrescriptionHistoryService _history = PrescriptionHistoryService();
  final ReminderService _reminders = ReminderService();
  final HealthProfileService _profile = HealthProfileService();

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  String _t({required String en, required String ar}) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _history.load();
    _reminders.load();
    _profile.load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: const FloatingChatbotButton(),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= Breakpoints.expanded - 264;

              final header = Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 14),
                child: Row(
                  children: [
                    const AdaptiveBackButton(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              _t(en: 'My health', ar: 'ملفي الصحي'),
                              style: TextStyle(color: palette.textPrimary, fontSize: 26, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _t(
                              en: 'Your prescriptions, reminders and allergies. Saved on this device only.',
                              ar: 'وصفاتك وتذكيراتك وحساسيتك. محفوظة على هذا الجهاز فقط.',
                            ),
                            style: TextStyle(color: palette.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              if (wide) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 96),
                  child: PageFrame(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _HistorySection(isArabic: _isArabic)),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _RemindersSection(isArabic: _isArabic),
                                  const SizedBox(height: 20),
                                  _AllergiesSection(isArabic: _isArabic),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              return DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    PageFrame(child: header),
                    PageFrame(
                      padTop: false,
                      child: TabBar(
                        labelColor: PharmaLensColors.teal,
                        unselectedLabelColor: palette.textSecondary,
                        indicatorColor: PharmaLensColors.teal,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                        tabs: [
                          Tab(text: _t(en: 'Prescriptions', ar: 'الوصفات')),
                          Tab(text: _t(en: 'Reminders', ar: 'التذكيرات')),
                          Tab(text: _t(en: 'Allergies', ar: 'الحساسية')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final section in <Widget>[
                            _HistorySection(isArabic: _isArabic),
                            _RemindersSection(isArabic: _isArabic),
                            _AllergiesSection(isArabic: _isArabic),
                          ])
                            SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 96),
                              child: PageFrame(child: Padding(padding: const EdgeInsets.only(top: 8), child: section)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Prescription history
// -----------------------------------------------------------------------------

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.isArabic});

  final bool isArabic;

  String _t({required String en, required String ar}) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final history = PrescriptionHistoryService();

    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final records = history.records;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: _t(en: 'Scanned prescriptions', ar: 'الوصفات المفحوصة'),
              subtitle: records.isEmpty
                  ? null
                  : _t(en: '${records.length} saved', ar: '${records.length} محفوظة'),
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              _EmptyState(
                icon: Icons.document_scanner_outlined,
                text: _t(
                  en: 'Prescriptions you scan appear here so you can review them later.',
                  ar: 'تظهر هنا الوصفات التي تفحصها لتعود إليها لاحقًا.',
                ),
              )
            else
              AdaptiveGrid(
                minItemWidth: 300,
                maxColumns: 2,
                children: [
                  for (final record in records)
                    _HistoryCard(
                      record: record,
                      isArabic: isArabic,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => PrescriptionRecordScreen(record: record)),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record, required this.isArabic, required this.onTap});

  final PrescriptionRecord record;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final localizations = MaterialLocalizations.of(context);
    final date = '${localizations.formatMediumDate(record.createdAt)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(record.createdAt))}';
    final names = record.medicines.map((m) => m.displayName).where((n) => n.isNotEmpty).toList();

    return SurfaceCard(
      onTap: onTap,
      semanticLabel: '$date, ${names.join(', ')}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumbnail(path: record.imagePath, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14.5)),
                if (record.doctorName.isNotEmpty || record.specialty.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [record.doctorName, record.specialty].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  names.isEmpty ? (isArabic ? 'لا أدوية مقروءة' : 'No readable medicines') : names.join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                      ? '${record.verifiedCount} من ${record.medicines.length} متحقق منها'
                      : '${record.verifiedCount} of ${record.medicines.length} verified',
                  style: const TextStyle(color: PharmaLensColors.teal, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: palette.tealSurface, borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.receipt_long_rounded, color: PharmaLensColors.teal),
    );

    if (kIsWeb || path.isEmpty || !File(path).existsSync()) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

/// A saved prescription: photo, medicines, safety notes and reminder shortcuts.
class PrescriptionRecordScreen extends StatelessWidget {
  const PrescriptionRecordScreen({super.key, required this.record});

  final PrescriptionRecord record;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String t({required String en, required String ar}) => isArabic ? ar : en;

    final moph = MophMedicineService();
    final products = record.medicines
        .map((m) => moph.findById(m.medicineId))
        .whereType<MedicinePrice>()
        .toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(MaterialLocalizations.of(context).formatMediumDate(record.createdAt)),
        actions: [
          IconButton(
            tooltip: t(en: 'Delete', ar: 'حذف'),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(t(en: 'Delete this prescription?', ar: 'حذف هذه الوصفة؟')),
                  content: Text(t(en: 'The photo and details will be removed from this device.', ar: 'ستُحذف الصورة والتفاصيل من هذا الجهاز.')),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(t(en: 'Cancel', ar: 'إلغاء'))),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: PharmaLensColors.danger),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(t(en: 'Delete', ar: 'حذف')),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await PrescriptionHistoryService().remove(record.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: HealthProfileService(),
        builder: (context, _) {
          final alerts = const MedicationSafetyService().check(products, allergies: HealthProfileService().allergies);

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: PageFrame(
              maxWidth: 1000,
              child: Flex(
                direction: Breakpoints.isCompact(context) ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!kIsWeb && record.imagePath.isNotEmpty && File(record.imagePath).existsSync())
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 20, bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 480),
                          child: Image.file(File(record.imagePath), fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  Flexible(
                    fit: Breakpoints.isCompact(context) ? FlexFit.loose : FlexFit.tight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (record.doctorName.isNotEmpty || record.specialty.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              [record.doctorName, record.specialty].where((s) => s.isNotEmpty).join(' · '),
                              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        for (final alert in alerts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SafetyAlertCard(alert: alert, isArabic: isArabic),
                          ),
                        for (final entry in record.medicines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecordMedicineTile(entry: entry, isArabic: isArabic),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecordMedicineTile extends StatelessWidget {
  const _RecordMedicineTile({required this.entry, required this.isArabic});

  final PrescriptionMedicineEntry entry;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final product = MophMedicineService().findById(entry.medicineId);
    final details = [entry.strength, entry.dosageForm].where((s) => s.isNotEmpty).join(' · ');

    return SurfaceCard(
      onTap: product == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => MedicineDetailsScreen(medicine: product)),
              ),
      child: Row(
        children: [
          Icon(
            entry.verified ? Icons.verified_rounded : Icons.help_outline_rounded,
            color: entry.verified ? PharmaLensColors.success : PharmaLensColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayName, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                if (details.isNotEmpty)
                  Text(details, style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                if (entry.instructions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(entry.instructions, style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                  ),
                if (!entry.verified)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isArabic ? 'غير متحقق منه: راجع الصيدلي.' : 'Not verified: check with your pharmacist.',
                      style: const TextStyle(color: PharmaLensColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: isArabic ? 'تذكير' : 'Remind me',
            icon: const Icon(Icons.alarm_add_rounded, color: PharmaLensColors.teal),
            onPressed: () => showReminderEditor(
              context,
              medicineName: entry.displayName,
              medicineId: entry.medicineId,
              doseNote: entry.instructions,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Reminders
// -----------------------------------------------------------------------------

class _RemindersSection extends StatelessWidget {
  const _RemindersSection({required this.isArabic});

  final bool isArabic;

  String _t({required String en, required String ar}) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final service = ReminderService();
    final palette = PharmaLensTheme.paletteOf(context);

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final reminders = service.reminders;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              icon: Icons.alarm_rounded,
              title: _t(en: 'Medicine reminders', ar: 'تذكيرات الأدوية'),
              trailing: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => showReminderEditor(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(_t(en: 'Add', ar: 'إضافة')),
              ),
            ),
            const SizedBox(height: 12),
            if (reminders.isEmpty)
              _EmptyState(
                icon: Icons.alarm_add_outlined,
                text: _t(
                  en: 'Add a reminder from a scanned prescription or a medicine page, or tap Add.',
                  ar: 'أضف تذكيرًا من وصفة مفحوصة أو صفحة دواء، أو اضغط إضافة.',
                ),
              )
            else
              for (final reminder in reminders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SurfaceCard(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    onTap: () => showReminderEditor(context, existing: reminder),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reminder.medicineName,
                                style: TextStyle(
                                  color: reminder.isExpired ? palette.textMuted : palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  reminder.times.map(MedicineReminder.formatTime).join('  ·  '),
                                  if (reminder.doseNote.isNotEmpty) reminder.doseNote,
                                  if (reminder.endDate != null)
                                    reminder.isExpired
                                        ? _t(en: 'Ended', ar: 'انتهى')
                                        : _t(
                                            en: 'until ${MaterialLocalizations.of(context).formatShortDate(reminder.endDate!)}',
                                            ar: 'حتى ${MaterialLocalizations.of(context).formatShortDate(reminder.endDate!)}',
                                          ),
                                ].join('\n'),
                                style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: reminder.enabled && !reminder.isExpired,
                          onChanged: reminder.isExpired ? null : (value) => service.update(reminder.copyWith(enabled: value)),
                        ),
                        IconButton(
                          tooltip: _t(en: 'Delete reminder', ar: 'حذف التذكير'),
                          icon: Icon(Icons.delete_outline_rounded, color: palette.textMuted),
                          onPressed: () => service.remove(reminder.id),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Allergies
// -----------------------------------------------------------------------------

class _AllergiesSection extends StatefulWidget {
  const _AllergiesSection({required this.isArabic});

  final bool isArabic;

  @override
  State<_AllergiesSection> createState() => _AllergiesSectionState();
}

class _AllergiesSectionState extends State<_AllergiesSection> {
  final TextEditingController _controller = TextEditingController();

  String _t({required String en, required String ar}) => widget.isArabic ? ar : en;

  static const List<(String, String)> _suggestions = [
    ('Penicillin', 'بنسلين'),
    ('Cephalosporin', 'سيفالوسبورين'),
    ('Sulfa', 'سلفا'),
    ('NSAID', 'NSAID'),
    ('Aspirin', 'أسبرين'),
    ('Codeine', 'Codeine'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add(String value) async {
    await HealthProfileService().addAllergy(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final profile = HealthProfileService();

    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) {
        final allergies = profile.allergies;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              icon: Icons.no_food_outlined,
              title: _t(en: 'Allergies', ar: 'الحساسية'),
              subtitle: _t(
                en: 'Scanned prescriptions are checked against this list.',
                ar: 'تُفحص الوصفات مقابل هذه اللائحة.',
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (allergies.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final allergy in allergies)
                          InputChip(
                            label: Text(allergy),
                            onDeleted: () => profile.removeAllergy(allergy),
                            deleteButtonTooltipMessage: _t(en: 'Remove', ar: 'إزالة'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _add,
                    decoration: InputDecoration(
                      hintText: _t(en: 'Medicine or ingredient, e.g. Amoxicillin', ar: 'دواء أو مادة فعالة، مثل Amoxicillin'),
                      prefixIcon: const Icon(Icons.add_circle_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _t(en: 'Add allergy', ar: 'إضافة حساسية'),
                        icon: const Icon(Icons.check_rounded),
                        onPressed: () => _add(_controller.text),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final suggestion in _suggestions)
                        if (!allergies.contains(suggestion.$1) && !allergies.contains(suggestion.$2))
                          ActionChip(
                            label: Text(widget.isArabic ? suggestion.$2 : suggestion.$1),
                            onPressed: () => _add(suggestion.$1),
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t(
                      en: 'This check uses MOPH ingredient and class data. It cannot catch every reaction; always tell your doctor and pharmacist about allergies.',
                      ar: 'يعتمد هذا الفحص على بيانات المواد والفئات من وزارة الصحة. لا يكشف كل التفاعلات؛ أخبر طبيبك والصيدلي دائمًا بالحساسية.',
                    ),
                    style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Column(
        children: [
          Icon(icon, color: palette.textMuted, size: 34),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, height: 1.45)),
        ],
      ),
    );
  }
}
