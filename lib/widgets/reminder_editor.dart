import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_text.dart';
import '../models/medicine_reminder.dart';
import '../services/health_profile_service.dart';
import '../services/moph_medicine_service.dart';
import '../services/reminder_service.dart';
import '../theme/pharmalens_theme.dart';
import '../utils/medicine_equivalence.dart';
import 'alarm_sound_tile.dart';
import 'reminder_setup_sheet.dart';

/// Opens the add/edit reminder dialog. Returns true when a reminder was saved.
Future<bool> showReminderEditor(
  BuildContext context, {
  String medicineName = '',
  String medicineId = '',
  String doseNote = '',
  MedicineReminder? existing,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _ReminderEditorDialog(
      medicineName: existing?.medicineName ?? medicineName,
      medicineId: existing?.medicineId ?? medicineId,
      doseNote: existing?.doseNote ?? doseNote,
      existing: existing,
    ),
  );
  return saved == true;
}

/// Course length written in the directions, e.g. "for 7 days", "x 10 days",
/// "لمدة 5 أيام" or "2 weeks". Null when none is written.
int? courseDaysFrom(String directions) {
  final text = directions.toLowerCase();
  final days = RegExp(r'(\d{1,3})\s*(?:days?|d\b|أيام|ايام|يوم|يومًا|يوما)').firstMatch(text);
  if (days != null) return int.tryParse(days.group(1)!);
  final weeks = RegExp(r'(\d{1,2})\s*(?:weeks?|wk|أسابيع|اسابيع|أسبوع|اسبوع)').firstMatch(text);
  if (weeks != null) {
    final count = int.tryParse(weeks.group(1)!);
    return count == null ? null : count * 7;
  }
  if (RegExp(r'\b(?:a|one) week\b|أسبوع واحد|لمدة أسبوع|لمدة اسبوع').hasMatch(text)) return 7;
  return null;
}

class _ReminderEditorDialog extends StatefulWidget {
  const _ReminderEditorDialog({
    required this.medicineName,
    required this.medicineId,
    required this.doseNote,
    this.existing,
  });

  final String medicineName;
  final String medicineId;
  final String doseNote;
  final MedicineReminder? existing;

  @override
  State<_ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<_ReminderEditorDialog> {
  late final TextEditingController _nameController = TextEditingController(text: widget.medicineName);
  late final TextEditingController _noteController = TextEditingController(text: widget.doseNote);
  late final TextEditingController _unitsController = TextEditingController(
    text: widget.existing?.packUnits?.toString() ?? _packUnitsOfProduct()?.toString() ?? '',
  );
  late final TextEditingController _perDoseController = TextEditingController(
    text: _formatAmount(widget.existing?.unitsPerDose ?? 1),
  );
  late List<int> _times = widget.existing?.times.toList() ?? <int>[8 * 60];
  late int? _durationDays = _initialDuration();
  late ReminderMode _mode = widget.existing?.mode ?? ReminderMode.notification;
  late bool _speakName = widget.existing?.speakName ?? true;
  late bool _trackSupply = widget.existing?.packUnits != null;
  bool _saving = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  static const List<int?> _presetDurations = <int?>[null, 3, 5, 7, 10, 14, 30, 60, 90];

  late final List<int?> _durations = <int?>{..._presetDurations, _durationDays}.toList()
    ..sort((a, b) => (a ?? -1).compareTo(b ?? -1));

  static String _formatAmount(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  int? _initialDuration() {
    final end = widget.existing?.endDate;
    if (end != null) {
      final now = DateTime.now();
      return DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays + 1;
    }
    if (widget.existing != null) return null;
    // A new reminder from a scan: take the course length from the directions.
    return courseDaysFrom(widget.doseNote);
  }

  /// Tablets or doses in one pack of the MOPH product, when countable.
  int? _packUnitsOfProduct() {
    if (widget.medicineId.isEmpty) return null;
    final product = MophMedicineService().findById(widget.medicineId);
    final quantity = MedicineEquivalence.packQuantity(product?.packSize);
    if (quantity == null || quantity.$2 != 'unit') return null;
    return quantity.$1.round();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _unitsController.dispose();
    _perDoseController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _times.isEmpty ? 8 : ((_times.last ~/ 60) + 8) % 24, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      _times = ({..._times, picked.hour * 60 + picked.minute}.toList()..sort());
    });
  }

  Future<void> _editTime(int time) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: time ~/ 60, minute: time % 60));
    if (picked == null) return;
    setState(() {
      _times = ({..._times.where((t) => t != time), picked.hour * 60 + picked.minute}.toList()..sort());
    });
  }

  void _applyPreset(List<int> hours) {
    setState(() => _times = hours.map((h) => h * 60).toList());
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _times.isEmpty || _saving) return;

    setState(() => _saving = true);

    final service = ReminderService()..languageCode = _isArabic ? 'ar' : 'en';
    final today = DateTime.now();
    final endDate = _durationDays == null ? null : DateTime(today.year, today.month, today.day).add(Duration(days: _durationDays! - 1));
    final packUnits = _trackSupply ? int.tryParse(_unitsController.text.trim()) : null;
    final perDose = double.tryParse(_perDoseController.text.trim().replaceAll(',', '.')) ?? 1;

    // Ask for what this kind of reminder needs; a skipped step is offered
    // again the next time a reminder is saved.
    if (service.supportsNotifications) {
      await ensureReminderSetup(context, forAlarms: _mode == ReminderMode.alarm);
    }

    final existing = widget.existing;
    if (existing == null) {
      await service.add(
        medicineName: name,
        medicineId: widget.medicineId,
        doseNote: _noteController.text,
        times: _times,
        endDate: endDate,
        mode: _mode,
        speakName: _speakName,
        packUnits: packUnits,
        unitsPerDose: perDose,
        profileId: HealthProfileService().active.id,
      );
    } else {
      await service.update(existing.copyWith(
        medicineName: name,
        doseNote: _noteController.text,
        times: _times,
        endDate: endDate,
        clearEndDate: endDate == null,
        mode: _mode,
        speakName: _speakName,
        packUnits: packUnits,
        clearPackUnits: packUnits == null,
        unitsPerDose: perDose,
        startDate: packUnits != existing.packUnits ? DateTime.now() : null,
      ));
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final width = MediaQuery.sizeOf(context).width;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: width < 420 ? 12 : 40, vertical: 24),
      title: Text(widget.existing == null ? appText(_isArabic).newReminder : appText(_isArabic).editReminder),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: appText(_isArabic).medicine,
                  prefixIcon: const Icon(Icons.medication_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: appText(_isArabic).doseAsPrescribedOptional,
                  hintText: appText(_isArabic).eG1TabletAfterFood,
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              _Label(appText(_isArabic).howToRemindMe),
              const SizedBox(height: 8),
              SegmentedButton<ReminderMode>(
                segments: [
                  ButtonSegment(
                    value: ReminderMode.notification,
                    icon: const Icon(Icons.notifications_outlined),
                    label: Text(appText(_isArabic).notification),
                  ),
                  ButtonSegment(
                    value: ReminderMode.alarm,
                    icon: const Icon(Icons.alarm_rounded),
                    label: Text(appText(_isArabic).alarm),
                  ),
                ],
                selected: <ReminderMode>{_mode},
                onSelectionChanged: (value) => setState(() => _mode = value.first),
              ),
              const SizedBox(height: 6),
              Text(
                _mode == ReminderMode.alarm
                    ? appText(_isArabic).ringsWithThePharmalensToneUntil
                    : appText(_isArabic).aNotificationWithTakenAndSnooze,
                style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.4),
              ),
              if (_mode == ReminderMode.alarm) ...[
                const SizedBox(height: 10),
                AlarmSoundTile(isArabic: _isArabic),
              ],
              if (_mode == ReminderMode.alarm)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _speakName,
                  onChanged: (value) => setState(() => _speakName = value),
                  title: Text(appText(_isArabic).sayTheMedicineNameAloud, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    appText(_isArabic).itIs800TimeTo,
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              _Label(appText(_isArabic).timesEachDay),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in _times)
                    InputChip(
                      label: Text(MedicineReminder.formatTime(time)),
                      onPressed: () => _editTime(time),
                      onDeleted: _times.length > 1 ? () => setState(() => _times = _times.where((t) => t != time).toList()) : null,
                      deleteButtonTooltipMessage: appText(_isArabic).removeTime,
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: Text(appText(_isArabic).addTime),
                    onPressed: _addTime,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  TextButton(onPressed: () => _applyPreset(<int>[8]), child: Text(appText(_isArabic).onceADay)),
                  TextButton(onPressed: () => _applyPreset(<int>[8, 20]), child: Text(appText(_isArabic).twice)),
                  TextButton(onPressed: () => _applyPreset(<int>[8, 14, 20]), child: Text(appText(_isArabic).n3Times)),
                  TextButton(onPressed: () => _applyPreset(<int>[0, 6, 12, 18]), child: Text(appText(_isArabic).every6H)),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: _durationDays,
                decoration: InputDecoration(
                  labelText: appText(_isArabic).forHowLong,
                  prefixIcon: const Icon(Icons.event_outlined),
                  helperText: widget.existing == null && courseDaysFrom(widget.doseNote) != null
                      ? appText(_isArabic).takenFromThePrescriptionDirections
                      : null,
                ),
                items: [
                  for (final days in _durations)
                    DropdownMenuItem<int?>(
                      value: days,
                      child: Text(
                        days == null ? appText(_isArabic).noEndDate : appText(_isArabic).days(days),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _durationDays = value),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _trackSupply,
                onChanged: (value) => setState(() => _trackSupply = value),
                title: Text(appText(_isArabic).remindMeToRefill, style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  appText(_isArabic).estimatesWhenYourSupplyRunsOut,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ),
              if (_trackSupply)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _unitsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(labelText: appText(_isArabic).unitsYouHave),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _perDoseController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: appText(_isArabic).perDose),
                      ),
                    ),
                  ],
                ),
              if (!ReminderService().supportsNotifications) ...[
                const SizedBox(height: 12),
                Text(
                  appText(_isArabic).notificationsAreNotAvailableInThe,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                appText(_isArabic).followTheDoseAndDurationOn,
                style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(appText(_isArabic).cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(appText(_isArabic).save),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: PharmaLensTheme.paletteOf(context).textPrimary, fontWeight: FontWeight.w800));
  }
}
