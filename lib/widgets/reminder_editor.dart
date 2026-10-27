import 'package:flutter/material.dart';

import '../models/medicine_reminder.dart';
import '../services/reminder_service.dart';
import '../theme/pharmalens_theme.dart';

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
  late List<int> _times = widget.existing?.times.toList() ?? <int>[8 * 60];
  late int? _durationDays = _initialDuration();
  bool _saving = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  String _t({required String en, required String ar}) => _isArabic ? ar : en;

  static const List<int?> _durations = <int?>[null, 3, 5, 7, 10, 14, 30];

  int? _initialDuration() {
    final end = widget.existing?.endDate;
    if (end == null) return null;
    final days = end.difference(DateTime.now()).inDays + 1;
    return _durations.contains(days) ? days : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
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

  void _applyPreset(List<int> hours) {
    setState(() => _times = hours.map((h) => h * 60).toList());
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _times.isEmpty || _saving) return;

    setState(() => _saving = true);

    final service = ReminderService()..languageCode = _isArabic ? 'ar' : 'en';
    final endDate = _durationDays == null ? null : DateTime.now().add(Duration(days: _durationDays! - 1));

    if (service.supportsNotifications) {
      await service.requestPermission();
    }

    final existing = widget.existing;
    if (existing == null) {
      await service.add(
        medicineName: name,
        medicineId: widget.medicineId,
        doseNote: _noteController.text,
        times: _times,
        endDate: endDate,
      );
    } else {
      await service.update(existing.copyWith(
        medicineName: name,
        doseNote: _noteController.text,
        times: _times,
        endDate: endDate,
        clearEndDate: endDate == null,
      ));
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return AlertDialog(
      title: Text(widget.existing == null ? _t(en: 'New reminder', ar: 'تذكير جديد') : _t(en: 'Edit reminder', ar: 'تعديل التذكير')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _t(en: 'Medicine', ar: 'الدواء'),
                  prefixIcon: const Icon(Icons.medication_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: _t(en: 'Dose as prescribed (optional)', ar: 'الجرعة حسب الوصفة (اختياري)'),
                  hintText: _t(en: 'e.g. 1 tablet after food', ar: 'مثال: حبة واحدة بعد الأكل'),
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t(en: 'Times each day', ar: 'الأوقات يوميًا'),
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in _times)
                    InputChip(
                      label: Text(MedicineReminder.formatTime(time)),
                      onDeleted: _times.length > 1 ? () => setState(() => _times = _times.where((t) => t != time).toList()) : null,
                      deleteButtonTooltipMessage: _t(en: 'Remove time', ar: 'حذف الوقت'),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: Text(_t(en: 'Add time', ar: 'إضافة وقت')),
                    onPressed: _addTime,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  TextButton(onPressed: () => _applyPreset(<int>[8]), child: Text(_t(en: 'Once a day', ar: 'مرة يوميًا'))),
                  TextButton(onPressed: () => _applyPreset(<int>[8, 20]), child: Text(_t(en: 'Twice', ar: 'مرتين'))),
                  TextButton(onPressed: () => _applyPreset(<int>[8, 14, 20]), child: Text(_t(en: '3 times', ar: '3 مرات'))),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _durationDays,
                decoration: InputDecoration(
                  labelText: _t(en: 'For how long', ar: 'المدة'),
                  prefixIcon: const Icon(Icons.event_outlined),
                ),
                items: [
                  for (final days in _durations)
                    DropdownMenuItem<int?>(
                      value: days,
                      child: Text(
                        days == null ? _t(en: 'No end date', ar: 'بدون تاريخ انتهاء') : _t(en: '$days days', ar: '$days أيام'),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _durationDays = value),
              ),
              if (!ReminderService().supportsNotifications) ...[
                const SizedBox(height: 12),
                Text(
                  _t(
                    en: 'Notifications are not available in the web version. Install the app to get alerts.',
                    ar: 'الإشعارات غير متاحة في نسخة الويب. ثبّت التطبيق لتصلك التنبيهات.',
                  ),
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _t(
                  en: 'Follow the dose and duration on your prescription. Reminders do not replace your doctor\'s instructions.',
                  ar: 'اتبع الجرعة والمدة المذكورة في الوصفة. التذكيرات لا تغني عن تعليمات الطبيب.',
                ),
                style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(_t(en: 'Cancel', ar: 'إلغاء')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_t(en: 'Save', ar: 'حفظ')),
        ),
      ],
    );
  }
}
