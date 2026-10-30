import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../services/reminder_permissions.dart';
import '../theme/pharmalens_theme.dart';
import 'alarm_sound_tile.dart';

/// Asks for what reminders need, one step at a time, with a reason for each.
/// Shown once on first launch (skippable) and again from the reminder editor
/// while something is still missing.
///
/// Returns the status after the user closes the sheet.
Future<ReminderSetupStatus> showReminderSetupSheet(BuildContext context, {bool forAlarms = true}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ReminderSetupSheet(forAlarms: forAlarms),
  );
  await ReminderPermissions.markSetupSeen();
  return ReminderPermissions.check();
}

/// Opens the setup sheet only when something needed is missing.
Future<ReminderSetupStatus> ensureReminderSetup(BuildContext context, {required bool forAlarms}) async {
  final status = await ReminderPermissions.check();
  final ready = forAlarms ? status.readyForAlarms : status.readyForNotifications;
  if (ready || !context.mounted) return status;
  return showReminderSetupSheet(context, forAlarms: forAlarms);
}

class _ReminderSetupSheet extends StatefulWidget {
  const _ReminderSetupSheet({required this.forAlarms});

  final bool forAlarms;

  @override
  State<_ReminderSetupSheet> createState() => _ReminderSetupSheetState();
}

class _ReminderSetupSheetState extends State<_ReminderSetupSheet> with WidgetsBindingObserver {
  ReminderSetupStatus? _status;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from a system settings page: show the new state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await ReminderPermissions.check();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _run(Future<Object?> Function() request) async {
    await request();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final status = _status;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(gradient: PharmaLensGradients.primary, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.alarm_on_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText(_isArabic).setUpMedicineReminders,
                      style: TextStyle(color: palette.textPrimary, fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appText(_isArabic).allowTheseSoRemindersAndAlarms,
                      style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (status == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (!status.applies)
            Text(
              appText(_isArabic).thisDeviceNeedsNoExtraSettings,
              style: TextStyle(color: palette.textSecondary, height: 1.45),
            )
          else ...[
            _Step(
              icon: Icons.notifications_active_outlined,
              title: appText(_isArabic).notifications,
              reason: appText(_isArabic).requiredForEveryReminder,
              granted: status.notifications,
              required: true,
              actionLabel: appText(_isArabic).allow,
              onPressed: () => _run(ReminderPermissions.requestNotifications),
            ),
            _Step(
              icon: Icons.schedule_rounded,
              title: appText(_isArabic).alarmsReminders,
              reason: appText(_isArabic).ringsAtTheExactMinuteWithout,
              granted: status.exactAlarms,
              required: widget.forAlarms,
              actionLabel: appText(_isArabic).openSettings,
              onPressed: () => _run(ReminderPermissions.requestExactAlarms),
            ),
            _Step(
              icon: Icons.fullscreen_rounded,
              title: appText(_isArabic).fullScreenAlarms,
              reason: appText(_isArabic).letsAnAlarmShowTheDose,
              granted: status.fullScreen,
              required: widget.forAlarms,
              actionLabel: appText(_isArabic).allow,
              onPressed: () => _run(ReminderPermissions.requestFullScreen),
            ),
            _Step(
              icon: Icons.battery_charging_full_rounded,
              title: appText(_isArabic).batteryUnrestricted,
              reason: appText(_isArabic).somePhonesXiaomiHuaweiOppoSamsung,
              granted: status.batteryUnrestricted,
              required: false,
              actionLabel: appText(_isArabic).openSettings,
              onPressed: () => _run(() async {
                await ReminderPermissions.openBatterySettings();
                return null;
              }),
            ),
            if (widget.forAlarms) ...[
              const SizedBox(height: 4),
              AlarmSoundTile(isArabic: _isArabic),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Text(
              appText(_isArabic).displayOverOtherAppsIsNot,
              style: TextStyle(color: palette.textMuted, fontSize: 11.5, height: 1.4),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(appText(_isArabic).skipForNow),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    status != null && (widget.forAlarms ? status.readyForAlarms : status.readyForNotifications)
                        ? appText(_isArabic).done
                        : appText(_isArabic).continueText,
                  ),
                ),
              ),
            ],
          ),
          if (status != null && status.applies && !status.readyForNotifications)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                appText(_isArabic).withoutNotificationsRemindersWillNotAlert,
                textAlign: TextAlign.center,
                style: const TextStyle(color: PharmaLensColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.title,
    required this.reason,
    required this.granted,
    required this.required,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String reason;
  final bool granted;
  final bool required;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: granted ? palette.tealSurface : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: granted ? PharmaLensColors.teal.withValues(alpha: 0.35) : palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: granted ? PharmaLensColors.teal : palette.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    if (!required && !granted)
                      Text(
                        appText(isArabic).recommended,
                        style: TextStyle(color: palette.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(reason, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          granted
              ? const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.check_circle_rounded, color: PharmaLensColors.success),
                )
              : FilledButton.tonal(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
