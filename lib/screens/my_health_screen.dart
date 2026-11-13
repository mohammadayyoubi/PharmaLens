import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../models/medicine_price.dart';
import '../models/medicine_reminder.dart';
import '../models/prescription_record.dart';
import '../services/health_profile_service.dart';
import '../services/medication_list_service.dart';
import '../services/medication_safety_service.dart';
import '../services/moph_medicine_service.dart';
import '../services/prescription_history_service.dart';
import '../services/dose_log_service.dart';
import '../services/reminder_service.dart';
import '../theme/pharmalens_theme.dart';
import '../widgets/ai_notice.dart';
import '../widgets/chatbot_view.dart';
import '../widgets/family_member_dialog.dart';
import '../widgets/reminder_editor.dart';
import '../widgets/reminder_setup_sheet.dart';
import '../widgets/safety_alert_card.dart';
import '../widgets/responsive.dart';
import 'medicine_details_screen.dart';

/// The user's own records: scanned prescriptions, medicine reminders and
/// allergies. Everything here stays on the device.
class MyHealthScreen extends StatefulWidget {
  const MyHealthScreen({super.key});

  /// Set before switching to My Health to open a tab on phones:
  /// 0 prescriptions, 1 reminders, 2 health.
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  @override
  State<MyHealthScreen> createState() => _MyHealthScreenState();
}

class _MyHealthScreenState extends State<MyHealthScreen> {
  final PrescriptionHistoryService _history = PrescriptionHistoryService();
  final ReminderService _reminders = ReminderService();
  final HealthProfileService _profile = HealthProfileService();

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

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
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GradientPageHeader(
                      icon: Icons.favorite_rounded,
                      title: appText(_isArabic).myHealth,
                      subtitle: appText(_isArabic).prescriptionsRemindersAllergiesAndConditionsSaved,
                      actions: [
                        GradientPageHeader.action(
                          icon: Icons.ios_share_rounded,
                          tooltip: appText(_isArabic).shareMedicineList,
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final shared = await const MedicationListService().share(isArabic: _isArabic);
                            if (!shared) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(appText(_isArabic).medicineListCopied)),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ProfileSwitcher(isArabic: _isArabic),
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
                child: _TabRequests(
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
                        // One line each: long labels shrink instead of wrapping.
                        tabs: [
                          for (final label in <String>[
                            appText(_isArabic).prescriptions,
                            appText(_isArabic).reminders,
                            appText(_isArabic).health,
                          ])
                            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1))),
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

  @override
  Widget build(BuildContext context) {
    final history = PrescriptionHistoryService();
    final profile = HealthProfileService();

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[history, profile]),
      builder: (context, _) {
        final records = history.records.where((r) => r.profileId == profile.active.id).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: appText(isArabic).scannedPrescriptions,
              subtitle: records.isEmpty
                  ? null
                  : appText(isArabic).saved(records.length),
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              _EmptyState(
                icon: Icons.document_scanner_outlined,
                text: appText(isArabic).prescriptionsYouScanAppearHereSo,
              )
            else
              _Paged(
                key: ValueKey<String>('history-${profile.active.id}'),
                itemCount: records.length,
                isArabic: isArabic,
                builder: (context, shown) => AdaptiveGrid(
                  minItemWidth: 300,
                  maxColumns: 2,
                  children: [
                    for (final record in records.take(shown))
                      _HistoryCard(
                        record: record,
                        isArabic: isArabic,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => PrescriptionRecordScreen(record: record)),
                        ),
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
                  names.isEmpty ? appText(isArabic).noReadableMedicines : names.join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  appText(isArabic).ofVerified(record.verifiedCount, record.medicines.length),
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

  /// Moves the scan to another family member (it was saved under the
  /// wrong person).
  Future<void> _changePerson(BuildContext context, PrescriptionRecord current, bool isArabic) async {
    final service = HealthProfileService();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        final palette = PharmaLensTheme.paletteOf(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                appText(isArabic).whoIsThisPrescriptionFor,
                style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final profile in service.profiles)
                    ChoiceChip(
                      avatar: Icon(profile.isOwner ? Icons.person_rounded : Icons.family_restroom_rounded, size: 18),
                      label: Text(profile.displayName(isArabic: isArabic)),
                      selected: profile.id == current.profileId,
                      onSelected: (_) => Navigator.of(sheetContext).pop(profile.id),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (chosen != null) await PrescriptionHistoryService().updateProfile(current.id, chosen);
  }

  void _openPhoto(BuildContext context, String path) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
            tooltip: appText(isArabic).delete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(appText(isArabic).deleteThisPrescription),
                  content: Text(appText(isArabic).thePhotoAndDetailsWillBe),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(appText(isArabic).cancel)),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: PharmaLensColors.danger),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(appText(isArabic).delete),
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
        listenable: Listenable.merge(<Listenable>[HealthProfileService(), PrescriptionHistoryService()]),
        builder: (context, _) {
          // The record may have been moved to someone else since it opened.
          final current = PrescriptionHistoryService().records.where((r) => r.id == record.id).firstOrNull ?? record;
          final profiles = HealthProfileService();
          final person = profiles.byId(current.profileId) ?? profiles.byId(HealthProfileService.ownerId) ?? profiles.active;
          final alerts = const MedicationSafetyService().check(
            products,
            allergies: person.allergies,
            conditions: person.effectiveConditions,
            catalog: MophMedicineService().catalog,
          );

          final compact = Breakpoints.isCompact(context);
          final hasImage = !kIsWeb && record.imagePath.isNotEmpty && File(record.imagePath).existsSync();

          final photo = !hasImage
              ? null
              : GestureDetector(
                  onTap: () => _openPhoto(context, record.imagePath),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 360, maxHeight: compact ? 260 : 480),
                      child: Image.file(
                        File(record.imagePath),
                        fit: compact ? BoxFit.cover : BoxFit.contain,
                        width: compact ? double.infinity : null,
                        // Decode at display size, not the full photo.
                        cacheWidth: 900,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SurfaceCard(
                            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                            child: Row(
                              children: [
                                Icon(
                                  person.isOwner ? Icons.person_rounded : Icons.family_restroom_rounded,
                                  color: PharmaLensColors.teal,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    person.isOwner ? appText(isArabic).forYou : appText(isArabic).forPerson(person.name),
                                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (profiles.hasFamily)
                                  TextButton(
                                    onPressed: () => _changePerson(context, current, isArabic),
                                    child: Text(appText(isArabic).change),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AiNotice(isArabic: isArabic, message: appText(isArabic).aiReadingNotice),
                        ),
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
                            child: _RecordMedicineTile(entry: entry, isArabic: isArabic, profileId: person.id),
                          ),
                        if (record.medicines.isEmpty)
                          _EmptyState(
                            icon: Icons.receipt_long_outlined,
                            text: appText(isArabic).noMedicinesWereReadFromThis,
                          ),
            ],
          );

          // On phones the photo sits above the list. A Flexible inside a
          // vertical scroll view has no height to share and paints nothing,
          // which is why this page used to open blank.
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: PageFrame(
              maxWidth: 1000,
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (photo != null) ...[photo, const SizedBox(height: 16)],
                        details,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (photo != null) ...[photo, const SizedBox(width: 20)],
                        Expanded(child: details),
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
  const _RecordMedicineTile({required this.entry, required this.isArabic, required this.profileId});

  final PrescriptionMedicineEntry entry;
  final bool isArabic;

  /// The person the prescription is for.
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final product = MophMedicineService().findById(entry.medicineId);
    final details = [entry.strength, entry.dosageForm].where((s) => s.isNotEmpty).join(' · ');

    return SurfaceCard(
      onTap: product == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => MedicineDetailsScreen(medicine: product, profileId: profileId)),
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
                      appText(isArabic).notVerifiedCheckWithYourPharmacist,
                      style: const TextStyle(color: PharmaLensColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: appText(isArabic).remindMe,
            icon: const Icon(Icons.alarm_add_rounded, color: PharmaLensColors.teal),
            onPressed: () => showReminderEditor(
              context,
              medicineName: entry.displayName,
              medicineId: entry.medicineId,
              doseNote: entry.instructions,
              profileId: profileId,
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

  @override
  Widget build(BuildContext context) {
    final service = ReminderService();
    final log = DoseLogService();
    final palette = PharmaLensTheme.paletteOf(context);

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[service, log, HealthProfileService()]),
      builder: (context, _) {
        final activeId = HealthProfileService().active.id;
        final reminders = service.reminders.where((r) => r.profileId == activeId).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              icon: Icons.alarm_rounded,
              title: appText(isArabic).medicineReminders,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: appText(isArabic).reminderSettings,
                    onPressed: () => showReminderSetupSheet(context),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () => showReminderEditor(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(appText(isArabic).add),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (reminders.isEmpty)
              _EmptyState(
                icon: Icons.alarm_add_outlined,
                text: appText(isArabic).addAReminderFromAScanned,
              )
            else
              _Paged(
                key: ValueKey<String>('reminders-$activeId'),
                itemCount: reminders.length,
                pageSize: 15,
                isArabic: isArabic,
                builder: (context, shown) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              for (final reminder in reminders.take(shown))
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
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      reminder.medicineName,
                                      style: TextStyle(
                                        color: reminder.isExpired ? palette.textMuted : palette.textPrimary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    reminder.isAlarm ? Icons.alarm_rounded : Icons.notifications_none_rounded,
                                    size: 16,
                                    color: reminder.isAlarm ? PharmaLensColors.warning : palette.textMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  reminder.times.map(MedicineReminder.formatTime).join('  ·  '),
                                  if (reminder.doseNote.isNotEmpty) reminder.doseNote,
                                  if (reminder.endDate != null)
                                    reminder.isExpired
                                        ? appText(isArabic).ended
                                        : appText(isArabic).until(MaterialLocalizations.of(context).formatShortDate(reminder.endDate!)),
                                  if (reminder.refillDate != null && !reminder.isExpired)
                                    appText(isArabic).refillAround(MaterialLocalizations.of(context).formatShortDate(reminder.refillDate!)),
                                  if (log.adherence(reminderId: reminder.id) case final rate?)
                                    appText(isArabic).takenOfDosesInTheLast((rate * 100).round()),
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
                          tooltip: appText(isArabic).deleteReminder,
                          icon: Icon(Icons.delete_outline_rounded, color: palette.textMuted),
                          onPressed: () => service.remove(reminder.id),
                        ),
                      ],
                    ),
                  ),
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
            _BodySection(key: ValueKey<String>('body-${profile.active.id}'), isArabic: widget.isArabic),
            const SizedBox(height: 20),
            SectionTitle(
              icon: Icons.monitor_heart_outlined,
              title: appText(widget.isArabic).healthConditions,
              subtitle: appText(widget.isArabic).medicinePagesHighlightTheWarningsThat,
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final condition in HealthCondition.values)
                    FilterChip(
                      label: Text(condition.label(isArabic: widget.isArabic)),
                      selected: profile.conditions.contains(condition),
                      onSelected: (_) => profile.toggleCondition(condition),
                    ),
                  // Typed by the user ("Other…").
                  for (final other in profile.active.otherConditions)
                    InputChip(
                      label: Text(other),
                      selected: true,
                      showCheckmark: false,
                      avatar: const Icon(Icons.check_rounded, size: 18, color: PharmaLensColors.teal),
                      onDeleted: () => profile.removeOtherCondition(other),
                      deleteButtonTooltipMessage: appText(widget.isArabic).remove,
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: Text(appText(widget.isArabic).otherCondition),
                    tooltip: appText(widget.isArabic).addAHealthCondition,
                    onPressed: () async {
                      final value = await showOtherConditionDialog(context, isArabic: widget.isArabic);
                      if (value != null) await profile.addOtherCondition(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionTitle(
              icon: Icons.no_food_outlined,
              title: appText(widget.isArabic).allergies,
              subtitle: appText(widget.isArabic).scannedPrescriptionsAreCheckedAgainstThis,
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
                            avatar: MedicationSafetyService.isRecognizedAllergy(allergy, MophMedicineService().catalog)
                                ? const Icon(Icons.check_circle_rounded, color: PharmaLensColors.success, size: 18)
                                : const Icon(Icons.help_outline_rounded, color: PharmaLensColors.warning, size: 18),
                            label: Text(allergy),
                            onDeleted: () => profile.removeAllergy(allergy),
                            deleteButtonTooltipMessage: appText(widget.isArabic).remove,
                          ),
                      ],
                    ),
                    if (allergies.any((a) => !MedicationSafetyService.isRecognizedAllergy(a, MophMedicineService().catalog)))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          appText(widget.isArabic).entriesMarkedWereNotFoundIn,
                          style: const TextStyle(color: PharmaLensColors.warning, fontSize: 12, height: 1.4, fontWeight: FontWeight.w700),
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _add,
                    decoration: InputDecoration(
                      hintText: appText(widget.isArabic).medicineOrIngredientEGAmoxicillin,
                      prefixIcon: const Icon(Icons.add_circle_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: appText(widget.isArabic).addAllergy,
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
                    appText(widget.isArabic).thisCheckUsesMophIngredientAnd,
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

/// Chips for each person whose medicines are managed here, plus "Add".
class _ProfileSwitcher extends StatelessWidget {
  const _ProfileSwitcher({required this.isArabic});

  final bool isArabic;

  Future<void> _addPerson(BuildContext context) => showAddFamilyMemberDialog(context, isArabic: isArabic);

  Future<void> _confirmRemove(BuildContext context, HealthProfile person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appText(isArabic).remove2(person.name)),
        content: Text(
          appText(isArabic).theirAllergiesAndConditionsAreRemoved,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(appText(isArabic).cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PharmaLensColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(appText(isArabic).remove3),
          ),
        ],
      ),
    );
    if (confirmed == true) await HealthProfileService().removeProfile(person.id);
  }

  @override
  Widget build(BuildContext context) {
    final service = HealthProfileService();

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final active = service.active;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final person in service.profiles)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: GestureDetector(
                    onLongPress: person.isOwner ? null : () => _confirmRemove(context, person),
                    child: ChoiceChip(
                      avatar: Icon(person.isOwner ? Icons.person_rounded : Icons.family_restroom_rounded, size: 18),
                      label: Text(person.displayName(isArabic: isArabic)),
                      selected: person.id == active.id,
                      onSelected: (_) => service.setActive(person.id),
                    ),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(appText(isArabic).familyMember),
                onPressed: () => _addPerson(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Opens the tab asked for through [MyHealthScreen.requestedTab].
class _TabRequests extends StatefulWidget {
  const _TabRequests({required this.child});

  final Widget child;

  @override
  State<_TabRequests> createState() => _TabRequestsState();
}

class _TabRequestsState extends State<_TabRequests> {
  @override
  void initState() {
    super.initState();
    MyHealthScreen.requestedTab.addListener(_open);
    // Asked for before this page was first built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    MyHealthScreen.requestedTab.removeListener(_open);
    super.dispose();
  }

  void _open() {
    final tab = MyHealthScreen.requestedTab.value;
    if (tab == null || !mounted) return;
    MyHealthScreen.requestedTab.value = null;
    DefaultTabController.of(context).animateTo(tab);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows a long list a page at a time: the next page is added as the
/// surrounding scroll view nears its end, and a button covers lists too
/// short to scroll.
class _Paged extends StatefulWidget {
  const _Paged({super.key, required this.itemCount, required this.builder, required this.isArabic, this.pageSize = 10});

  final int itemCount;
  final int pageSize;
  final bool isArabic;

  /// Builds the first `shown` items.
  final Widget Function(BuildContext context, int shown) builder;

  @override
  State<_Paged> createState() => _PagedState();
}

class _PagedState extends State<_Paged> {
  late int _visible = widget.pageSize;
  ScrollPosition? _position;

  int get _shown => _visible < widget.itemCount ? _visible : widget.itemCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position == _position) return;
    _position?.removeListener(_onScroll);
    _position = position?..addListener(_onScroll);
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final position = _position;
    if (position == null || !position.hasContentDimensions) return;
    if (_shown < widget.itemCount && position.pixels >= position.maxScrollExtent - 400) _more();
  }

  void _more() => setState(() => _visible += widget.pageSize);

  @override
  Widget build(BuildContext context) {
    final left = widget.itemCount - _shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.builder(context, _shown),
        if (left > 0)
          Center(
            child: TextButton.icon(
              onPressed: _more,
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(appText(widget.isArabic).showMoreLeft(left)),
            ),
          ),
      ],
    );
  }
}

/// Age, sex, height and weight, so medicine pages can point at label
/// warnings that depend on them. Saved as the user types.
class _BodySection extends StatefulWidget {
  const _BodySection({super.key, required this.isArabic});

  final bool isArabic;

  @override
  State<_BodySection> createState() => _BodySectionState();
}

class _BodySectionState extends State<_BodySection> {
  final HealthProfileService _profile = HealthProfileService();
  late final HealthProfile _person = _profile.active;
  late final TextEditingController _age = TextEditingController(text: _person.age?.toString() ?? '');
  late final TextEditingController _height = TextEditingController(text: _format(_person.heightCm));
  late final TextEditingController _weight = TextEditingController(text: _format(_person.weightKg));
  late BiologicalSex? _sex = _person.sex;
  Timer? _save;

  static String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
  }

  static double? _number(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  // Values outside these ranges are typing mistakes and are not saved.
  int? get _ageValue {
    final value = int.tryParse(_age.text.trim());
    return value == null || value < 0 || value > 120 ? null : value;
  }

  double? get _heightValue {
    final value = _number(_height.text);
    return value == null || value < 40 || value > 250 ? null : value;
  }

  double? get _weightValue {
    final value = _number(_weight.text);
    return value == null || value < 2 || value > 350 ? null : value;
  }

  @override
  void dispose() {
    // Typed just before leaving the page.
    if (_save?.isActive ?? false) {
      _save!.cancel();
      _persist();
    }
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 700), _persist);
  }

  void _persist() {
    unawaited(_profile.setBody(age: _ageValue, sex: _sex, heightCm: _heightValue, weightKg: _weightValue));
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(widget.isArabic);
    final height = _heightValue, weight = _weightValue;
    final bmi = height == null || weight == null ? null : weight / ((height / 100) * (height / 100));

    // The name and unit sit above the box, so a third of a narrow phone is
    // enough for the number itself (a suffix inside the box covered it).
    Widget field(TextEditingController controller, String label, String unit, {bool decimal = true}) {
      return MergeSemantics(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '$label · $unit',
              maxLines: 1,
              style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            textInputAction: TextInputAction.next,
            textAlign: TextAlign.center,
            onChanged: (_) => _changed(),
            style: TextStyle(color: palette.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '—',
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            ),
          ),
        ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          icon: Icons.accessibility_new_rounded,
          title: text.body,
          subtitle: text.ageAndWeightHelpPharmalensPoint,
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Full width, one line per label: in half a row "Female"
              // wrapped onto two lines on narrow phones.
              SegmentedButton<BiologicalSex>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: BiologicalSex.female,
                    icon: const Icon(Icons.female_rounded),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(text.female, maxLines: 1)),
                  ),
                  ButtonSegment(
                    value: BiologicalSex.male,
                    icon: const Icon(Icons.male_rounded),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(text.male, maxLines: 1)),
                  ),
                ],
                selected: <BiologicalSex>{if (_sex != null) _sex!},
                onSelectionChanged: (value) {
                  _sex = value.isEmpty ? null : value.first;
                  _changed();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: field(_age, text.age, text.years, decimal: false)),
                  const SizedBox(width: 8),
                  Expanded(child: field(_height, text.height, 'cm')),
                  const SizedBox(width: 8),
                  Expanded(child: field(_weight, text.weight, 'kg')),
                ],
              ),
              if (bmi != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.speed_rounded, size: 18, color: bmiColor(bmi)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text.bmiValue(bmi.toStringAsFixed(1), bmiCategory(bmi, isArabic: widget.isArabic)),
                        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _BmiScale(bmi: bmi, isArabic: widget.isArabic),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Color of a BMI band: underweight, healthy, overweight, then obesity
/// class I, II and III.
Color bmiColor(double bmi) {
  if (bmi < 18.5) return PharmaLensColors.bmiUnderweight;
  if (bmi < 25) return PharmaLensColors.bmiHealthy;
  if (bmi < 30) return PharmaLensColors.bmiOverweight;
  if (bmi < 35) return PharmaLensColors.bmiObesity1;
  if (bmi < 40) return PharmaLensColors.bmiObesity2;
  return PharmaLensColors.bmiObesity3;
}

/// A colored bar from BMI 15 to 45 in the WHO bands, with a pointer and the
/// value above [bmi], and the band limits underneath.
class _BmiScale extends StatelessWidget {
  const _BmiScale({required this.bmi, required this.isArabic});

  final double bmi;
  final bool isArabic;

  static const double _min = 15;
  static const double _max = 45;
  static const List<double> _limits = <double>[18.5, 25, 30, 35, 40];
  static const List<(double, double)> _bands = <(double, double)>[
    (_min, 18.5),
    (18.5, 25),
    (25, 30),
    (30, 35),
    (35, 40),
    (40, _max),
  ];

  static const double _bubbleHeight = 22;
  static const double _pointerHeight = 9;
  static const double _barHeight = 16;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final value = bmi.toStringAsFixed(1);

    return Semantics(
      container: true,
      label: appText(isArabic).bmiScale,
      value: appText(isArabic).bmiValue(value, bmiCategory(bmi, isArabic: isArabic)),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            double at(double v) => ((v - _min) / (_max - _min)).clamp(0.0, 1.0) * width;
            final x = at(bmi);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _bubbleHeight + _pointerHeight + _barHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The bands: full color, lighter on the top half.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _bubbleHeight + _pointerHeight,
                        height: _barHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          // Stretch: a DecoratedBox with no child in a Row
                          // is 0 px tall otherwise, and the bar showed white.
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final band in _bands)
                                Expanded(
                                  key: ValueKey<String>('bmi-band-${band.$1}'),
                                  flex: ((band.$2 - band.$1) * 10).round(),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: const [0.5, 0.5],
                                        colors: [
                                          Color.lerp(bmiColor((band.$1 + band.$2) / 2), Colors.white, 0.22)!,
                                          bmiColor((band.$1 + band.$2) / 2),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Value bubble and pointer.
                      PositionedDirectional(
                        start: (x - 26).clamp(0.0, width - 52),
                        top: 0,
                        width: 52,
                        height: _bubbleHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.textPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              value,
                              maxLines: 1,
                              style: TextStyle(color: palette.surface, fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: (x - 8).clamp(0.0, width - 16),
                        top: _bubbleHeight - 1,
                        width: 16,
                        height: _pointerHeight + 4,
                        child: CustomPaint(painter: _PointerPainter(palette.textPrimary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final limit in _limits)
                        PositionedDirectional(
                          start: at(limit) - 16,
                          width: 32,
                          top: 0,
                          child: Text(
                            limit == limit.roundToDouble() ? limit.round().toString() : limit.toString(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(color: palette.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A downward triangle with a rounded tip.
class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2 + 2, size.height - 2)
      ..quadraticBezierTo(size.width / 2, size.height, size.width / 2 - 2, size.height - 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => oldDelegate.color != color;
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
