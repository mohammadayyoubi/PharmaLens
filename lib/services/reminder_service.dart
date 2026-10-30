import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener, AppLifecycleState, WidgetsBinding;
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_text.dart';
import '../models/medicine_reminder.dart';
import 'alarm_sound_service.dart';
import 'dose_log_service.dart';

/// Runs when a notification button (Taken / Snooze) is pressed while the
/// app is not in the foreground. It runs in its own isolate.
@pragma('vm:entry-point')
void reminderBackgroundResponse(NotificationResponse response) {
  DartPluginRegistrant.ensureInitialized();
  unawaited(ReminderService().handleResponse(response, inBackground: true));
}

/// Stores medicine reminders and schedules their notifications.
///
/// - A reminder with an end date that is less than [_oneShotDays] away gets
///   one notification per dose, so it stops exactly after the last day.
///   Longer courses repeat daily and switch to one-shots as the end comes
///   near (the schedule is rebuilt each time the app opens).
/// - Alarm-mode reminders use their own channel: the PharmaLens alarm tone
///   repeats until answered and the dose screen opens over the lock screen.
/// - Notification buttons record Taken or Snooze without opening the app.
///
/// On the web reminders are saved and listed, but the browser cannot deliver
/// them while the page is closed, so [supportsNotifications] is false there.
class ReminderService extends ChangeNotifier {
  ReminderService._internal();

  static final ReminderService _instance = ReminderService._internal();

  factory ReminderService() => _instance;

  static const String _storageKey = 'pharmalens_reminders_v1';
  static const int _maxTimesPerReminder = 8;
  static const int _oneShotDays = 14;
  static const int snoozeMinutes = 10;

  static const String _notificationChannel = 'medicine_reminders';
  // Android fixes a channel's sound when it is created; a new sound needs a
  // new channel id.
  static const String _alarmChannel = 'medicine_alarms_v1';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  List<MedicineReminder> _reminders = <MedicineReminder>[];
  bool _loaded = false;
  bool _pluginReady = false;
  String _languageCode = 'en';
  Timer? _foregroundTimer;
  Timer? _rescheduleDebounce;
  AppLifecycleListener? _lifecycle;

  /// A dose to show on the dose screen: set when a reminder notification is
  /// tapped, when an alarm opens the app, or when an alarm is due while the
  /// app is open. The app shell listens and opens the screen.
  final ValueNotifier<DueDose?> pendingDose = ValueNotifier<DueDose?>(null);

  List<MedicineReminder> get reminders => List<MedicineReminder>.unmodifiable(_reminders);
  bool get isLoaded => _loaded;
  bool get supportsNotifications => !kIsWeb;

  /// Language used for notification text. Changing it reschedules the
  /// notifications so their text follows.
  set languageCode(String value) {
    final code = value == 'ar' ? 'ar' : 'en';
    if (code == _languageCode) return;
    _languageCode = code;
    if (_loaded && _reminders.isNotEmpty) {
      _rescheduleDebounce?.cancel();
      _rescheduleDebounce = Timer(const Duration(seconds: 2), () => unawaited(_rescheduleAll()));
    }
  }

  bool get _isArabic => _languageCode == 'ar';

  String _alarmChannelInUse = _alarmChannel;

  /// Android fixes a channel's sound when it is created, so each chosen
  /// alarm sound gets its own channel.
  static String _alarmChannelFor(AlarmSound sound) =>
      sound.isDefault ? _alarmChannel : 'medicine_alarms_${md5.convert(utf8.encode(sound.uri)).toString().substring(0, 10)}';

  /// A new alarm sound: drop the old channel and move scheduled alarms to
  /// one that rings with the new sound.
  Future<void> _onAlarmSoundChanged() async {
    final next = _alarmChannelFor(AlarmSoundService().sound);
    final previous = _alarmChannelInUse;
    if (next == previous) return;
    _alarmChannelInUse = next;
    if (previous != _alarmChannel && await _ensurePlugin()) {
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.deleteNotificationChannel(channelId: previous);
      } catch (_) {}
    }
    if (_reminders.any((r) => r.isAlarm)) await _rescheduleAll();
  }

  Future<void> load() async {
    if (_loaded) return;

    _reminders = await _readReminders();
    _loaded = true;
    notifyListeners();

    if (!supportsNotifications) return;

    final sounds = AlarmSoundService();
    await sounds.load();
    _alarmChannelInUse = _alarmChannelFor(sounds.sound);
    sounds.addListener(_onAlarmSoundChanged);

    _armForegroundTimer();
    if (!await _ensurePlugin()) return;

    // A tapped reminder opens its dose screen right away.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
        await handleResponse(response);
      }
    } catch (error) {
      debugPrint('ReminderService: no launch details: $error');
    }

    // Rebuilding the whole schedule is slow: every notification is a call
    // into Android on the UI thread, which froze the first screen for
    // seconds. So it waits until the app is up, and runs only when
    // something it depends on changed (see _scheduleSignature).
    unawaited(Future<void>.delayed(const Duration(seconds: 3), _rescheduleIfNeeded));

    _lifecycle ??= AppLifecycleListener(onResume: () {
      unawaited(_rescheduleIfNeeded());
      unawaited(DoseLogService().load(force: true));
    });
  }

  static const String _scheduleSignatureKey = 'pharmalens_reminder_schedule_v1';

  /// Everything the scheduled notifications depend on: the reminders, their
  /// language and alarm sound, the exact-alarm permission, the time zone,
  /// and the day (courses switch to one-off notifications as their end
  /// comes near).
  Future<String> _scheduleSignature() async {
    var zone = '';
    try {
      zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    var exact = false;
    try {
      exact = await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.canScheduleExactNotifications() ??
          false;
    } catch (_) {}
    final now = DateTime.now();
    final source = jsonEncode(<Object>[
      _reminders.map((r) => r.toJson()).toList(),
      _languageCode,
      _alarmChannelInUse,
      exact,
      zone,
      _date(now),
    ]);
    return md5.convert(utf8.encode(source)).toString();
  }

  Future<void> _rescheduleIfNeeded() async {
    if (!await _ensurePlugin()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final signature = await _scheduleSignature();
      if (prefs.getString(_scheduleSignatureKey) == signature) {
        _armForegroundTimer();
        return;
      }
      await _rescheduleAll();
      await prefs.setString(_scheduleSignatureKey, signature);
    } catch (error) {
      debugPrint('ReminderService: could not check the schedule: $error');
    }
  }

  static Future<List<MedicineReminder>> _readReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => MedicineReminder.fromJson(Map<String, dynamic>.from(m)))
              .where((r) => r.id > 0 && r.medicineName.isNotEmpty)
              .toList();
        }
      }
    } catch (error) {
      debugPrint('ReminderService: could not load reminders: $error');
    }
    return <MedicineReminder>[];
  }

  MedicineReminder? byId(int id) => _reminders.where((r) => r.id == id).firstOrNull;

  Future<MedicineReminder> add({
    required String medicineName,
    required List<int> times,
    String medicineId = '',
    String doseNote = '',
    DateTime? endDate,
    ReminderMode mode = ReminderMode.notification,
    bool speakName = true,
    int? packUnits,
    double unitsPerDose = 1,
    String profileId = 'me',
  }) async {
    await load();

    final nextId = _reminders.fold<int>(0, (max, r) => r.id > max ? r.id : max) + 1;
    final reminder = MedicineReminder(
      id: nextId,
      medicineName: medicineName.trim(),
      medicineId: medicineId,
      doseNote: doseNote.trim(),
      times: _cleanTimes(times),
      endDate: endDate,
      mode: mode,
      speakName: speakName,
      startDate: DateTime.now(),
      packUnits: packUnits,
      unitsPerDose: unitsPerDose,
      profileId: profileId,
    );

    _reminders = <MedicineReminder>[..._reminders, reminder];
    await _persist();
    await _schedule(reminder);
    _armForegroundTimer();
    notifyListeners();
    return reminder;
  }

  Future<void> update(MedicineReminder reminder) async {
    await load();

    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index < 0) return;

    final cleaned = reminder.copyWith(times: _cleanTimes(reminder.times));
    await _cancel(_reminders[index]);
    _reminders = List<MedicineReminder>.of(_reminders)..[index] = cleaned;
    await _persist();
    await _schedule(cleaned);
    _armForegroundTimer();
    notifyListeners();
  }

  Future<void> remove(int id) async {
    await load();

    final index = _reminders.indexWhere((r) => r.id == id);
    if (index < 0) return;

    await _cancel(_reminders[index]);
    _reminders = List<MedicineReminder>.of(_reminders)..removeAt(index);
    await _persist();
    _armForegroundTimer();
    notifyListeners();
  }

  List<int> _cleanTimes(List<int> times) {
    final cleaned = times.where((t) => t >= 0 && t < 24 * 60).toSet().toList()..sort();
    return cleaned.take(_maxTimesPerReminder).toList();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_reminders.map((r) => r.toJson()).toList()));
    } catch (error) {
      debugPrint('ReminderService: could not save reminders: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Answers: Taken, Snooze, Skip
  // ---------------------------------------------------------------------------

  Future<void> markTaken(DueDose dose) => _answer(dose, DoseStatus.taken);

  Future<void> markSkipped(DueDose dose) => _answer(dose, DoseStatus.skipped);

  /// Records the snooze and reminds again in [snoozeMinutes] minutes.
  Future<void> snooze(DueDose dose) async {
    await _answer(dose, DoseStatus.snoozed);
    if (!await _ensurePlugin()) return;
    // Snooze can run in the background isolate, before anything loaded it.
    await AlarmSoundService().load();
    await _ensureTimeZones();

    try {
      await _plugin.zonedSchedule(
        id: _snoozeId(dose.reminder),
        title: _title(dose.reminder),
        body: _body(dose.reminder),
        scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: snoozeMinutes)),
        notificationDetails: _details(dose.reminder),
        androidScheduleMode: await _scheduleMode(dose.reminder),
        payload: _payload(dose.reminder, dose.minutes, dose.day),
      );
    } catch (error) {
      debugPrint('ReminderService: could not snooze: $error');
    }
  }

  Future<void> _answer(DueDose dose, DoseStatus status) async {
    await DoseLogService.record(DoseLogEntry(
      reminderId: dose.reminder.id,
      medicineName: dose.reminder.medicineName,
      day: DateTime(dose.day.year, dose.day.month, dose.day.day),
      minutes: dose.minutes,
      status: status,
      at: DateTime.now(),
    ));
    await dismiss(dose);
  }

  /// Stops a ringing alarm for [dose]. The schedule is rebuilt because on
  /// Android cancelling a repeating notification also cancels its repeats.
  Future<void> dismiss(DueDose dose) async {
    if (!await _ensurePlugin()) return;
    final reminder = byId(dose.reminder.id) ?? dose.reminder;
    await _cancel(reminder);
    await _schedule(reminder);
  }

  /// Handles a tap on a reminder notification or one of its buttons.
  Future<void> handleResponse(NotificationResponse response, {bool inBackground = false}) async {
    final parsed = _parsePayload(response.payload);
    if (parsed == null) return;

    if (inBackground || !_loaded) {
      _reminders = await _readReminders();
      try {
        // Same key as the app's language setting in main.dart.
        final prefs = await SharedPreferences.getInstance();
        languageCode = prefs.getString('pharmalens_locale') ?? _languageCode;
      } catch (_) {}
    }
    final reminder = byId(parsed.$1);
    if (reminder == null) return;

    final dose = DueDose(reminder: reminder, minutes: parsed.$2, day: parsed.$3);
    switch (response.actionId) {
      case 'taken':
        await markTaken(dose);
      case 'snooze':
        await snooze(dose);
      default:
        // A tap on the notification itself opens the dose screen.
        if (!inBackground) pendingDose.value = dose;
    }
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<bool> _ensurePlugin() async {
    if (!supportsNotifications) return false;
    if (_pluginReady) return true;

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher_monochrome'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          linux: LinuxInitializationSettings(defaultActionName: 'Open PharmaLens'),
          windows: WindowsInitializationSettings(
            appName: 'PharmaLens',
            appUserModelId: 'com.codepeakstudio.pharmalens',
            guid: '7b3c5f0e-4f4b-4d36-9a52-1c1f8a6a2d71',
          ),
        ),
        onDidReceiveNotificationResponse: (response) => unawaited(handleResponse(response)),
        onDidReceiveBackgroundNotificationResponse: reminderBackgroundResponse,
      );

      _pluginReady = true;
    } catch (error) {
      debugPrint('ReminderService: notifications unavailable: $error');
    }

    return _pluginReady;
  }

  bool _timeZonesReady = false;

  /// Loads the time-zone database (large, parsed on the UI thread) the
  /// first time something is scheduled.
  Future<void> _ensureTimeZones() async {
    if (_timeZonesReady) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Most users are in Lebanon; better than silently using UTC.
      tz.setLocalLocation(tz.getLocation('Asia/Beirut'));
    }
    _timeZonesReady = true;
  }

  /// Asks for notification permission only. The full setup (exact alarms,
  /// full-screen, battery) is in ReminderSetupSheet.
  Future<bool> requestPermission() async {
    if (!await _ensurePlugin()) return false;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true, badge: true) ?? false;
      }

      final macos = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) {
        return await macos.requestPermissions(alert: true, sound: true, badge: true) ?? false;
      }
    } catch (error) {
      debugPrint('ReminderService: permission request failed: $error');
      return false;
    }

    return true;
  }

  // Ids: reminder.id * 1000 + offset. One-shots use day * 10 + time index
  // (days 0-14), repeats 900 + time index, the snooze 999.
  int _oneShotId(MedicineReminder r, int day, int timeIndex) => r.id * 1000 + day * 10 + timeIndex;
  int _repeatId(MedicineReminder r, int timeIndex) => r.id * 1000 + 900 + timeIndex;
  int _snoozeId(MedicineReminder r) => r.id * 1000 + 999;

  static String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _payload(MedicineReminder r, int minutes, DateTime? day) =>
      'dose:${r.id}:$minutes${day == null ? '' : ':${_date(day)}'}';

  static (int, int, DateTime)? _parsePayload(String? payload) {
    final parts = (payload ?? '').split(':');
    if (parts.length < 3 || parts.first != 'dose') return null;
    final id = int.tryParse(parts[1]);
    final minutes = int.tryParse(parts[2]);
    if (id == null || minutes == null) return null;
    final now = DateTime.now();
    final day = parts.length > 3 ? DateTime.tryParse(parts[3]) : null;
    return (id, minutes, day ?? DateTime(now.year, now.month, now.day));
  }

  /// Name of a family member to put in front of the title, or ''.
  String Function(String profileId) personName = (_) => '';

  String _title(MedicineReminder r) {
    final person = personName(r.profileId);
    final title = appText(_isArabic).timeFor(r.medicineName);
    return person.isEmpty ? title : '$person · $title';
  }

  String _body(MedicineReminder r) => r.doseNote.isNotEmpty
      ? r.doseNote
      : appText(_isArabic).itIsTimeForYourDose;

  NotificationDetails _details(MedicineReminder r) {
    final actions = <AndroidNotificationAction>[
      AndroidNotificationAction('taken', appText(_isArabic).taken3, cancelNotification: true),
      AndroidNotificationAction('snooze', appText(_isArabic).snoozeMin2(snoozeMinutes), cancelNotification: true),
    ];

    if (r.isAlarm) {
      final chosen = AlarmSoundService().sound;
      return NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannelFor(chosen),
          appText(_isArabic).medicineAlarms,
          channelDescription: 'Alarm-style medicine reminders with sound',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          sound: chosen.isDefault
              ? const RawResourceAndroidNotificationSound('pharmalens_alarm')
              : UriAndroidNotificationSound(chosen.uri),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          // FLAG_INSISTENT: the tone repeats until the alarm is answered.
          additionalFlags: Int32List.fromList(<int>[4]),
          timeoutAfter: 10 * 60 * 1000,
          visibility: NotificationVisibility.public,
          actions: actions,
        ),
        // ios/Runner/pharmalens_alarm.wav, bundled with the app (iOS plays
        // custom sounds up to 30 s; this one is 3 s).
        iOS: const DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
          presentSound: true,
          sound: 'pharmalens_alarm.wav',
        ),
        macOS: const DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      );
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannel,
        appText(_isArabic).medicineReminders2,
        channelDescription: 'Daily reminders to take your medicines',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
  }

  Future<AndroidScheduleMode> _scheduleMode(MedicineReminder r) async {
    var exact = false;
    try {
      exact = await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.canScheduleExactNotifications() ??
          false;
    } catch (_) {}
    // Without the exact-alarm permission Android may deliver a reminder a
    // few minutes late; it is asked for in the reminder setup.
    if (!exact) return AndroidScheduleMode.inexactAllowWhileIdle;
    return r.isAlarm ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.exactAllowWhileIdle;
  }

  Future<void> _schedule(MedicineReminder reminder) async {
    if (!reminder.enabled || reminder.isExpired) return;
    if (!await _ensurePlugin()) return;
    await _ensureTimeZones();

    final details = _details(reminder);
    final mode = await _scheduleMode(reminder);
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    final end = reminder.endDate;
    final daysLeft = end == null ? null : DateTime(end.year, end.month, end.day).difference(today).inDays;
    final oneShots = daysLeft != null && daysLeft < _oneShotDays;

    for (var i = 0; i < reminder.times.length; i++) {
      final minutes = reminder.times[i];
      try {
        if (!oneShots) {
          await _plugin.zonedSchedule(
            id: _repeatId(reminder, i),
            title: _title(reminder),
            body: _body(reminder),
            scheduledDate: _nextInstance(minutes),
            notificationDetails: details,
            androidScheduleMode: mode,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: _payload(reminder, minutes, null),
          );
          continue;
        }

        for (var day = 0; day <= daysLeft; day++) {
          final date = today.add(Duration(days: day));
          final at = tz.TZDateTime(tz.local, date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
          if (!at.isAfter(now)) continue;
          await _plugin.zonedSchedule(
            id: _oneShotId(reminder, day, i),
            title: _title(reminder),
            body: _body(reminder),
            scheduledDate: at,
            notificationDetails: details,
            androidScheduleMode: mode,
            payload: _payload(reminder, minutes, date),
          );
        }
      } catch (error) {
        debugPrint('ReminderService: could not schedule reminder ${reminder.id}: $error');
      }
    }
  }

  Future<void> _cancel(MedicineReminder reminder) async {
    if (!await _ensurePlugin()) return;

    try {
      final pending = await _plugin.pendingNotificationRequests();
      final prefix = 'dose:${reminder.id}:';
      for (final request in pending) {
        if ((request.payload ?? '').startsWith(prefix)) {
          await _plugin.cancel(id: request.id);
        }
      }
      // Shown notifications are not pending any more.
      for (var i = 0; i < _maxTimesPerReminder; i++) {
        await _plugin.cancel(id: _repeatId(reminder, i));
      }
      await _plugin.cancel(id: _snoozeId(reminder));
      // Ids used before version 1.1 (reminder.id * 10 + time index).
      for (var i = 0; i < _maxTimesPerReminder; i++) {
        await _plugin.cancel(id: reminder.id * 10 + i);
      }
    } catch (error) {
      debugPrint('ReminderService: could not cancel reminder ${reminder.id}: $error');
    }
  }

  Future<void> _rescheduleAll() async {
    if (!await _ensurePlugin()) return;

    try {
      // Only reminders use notifications in this app, so a clean slate is
      // the simplest way to drop ids from older versions.
      await _plugin.cancelAllPendingNotifications();
    } catch (_) {
      for (final reminder in _reminders) {
        await _cancel(reminder);
      }
    }
    for (final reminder in _reminders) {
      await _schedule(reminder);
    }
    _armForegroundTimer();
  }

  /// While the app is open, an alarm-mode dose opens the dose screen at its
  /// time (the system notification alone would only show a banner).
  void _armForegroundTimer() {
    _foregroundTimer?.cancel();
    final next = nextDose(alarmsOnly: true);
    if (next == null) return;

    final wait = next.scheduledAt.difference(DateTime.now());
    if (wait.isNegative || wait > const Duration(hours: 24)) return;

    _foregroundTimer = Timer(wait, () {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) {
        pendingDose.value = next;
      }
      _armForegroundTimer();
    });
  }

  /// The next scheduled dose after now, or null.
  DueDose? nextDose({bool alarmsOnly = false}) {
    final now = DateTime.now();
    DueDose? best;
    for (final reminder in _reminders) {
      if (!reminder.enabled || reminder.isExpired) continue;
      if (alarmsOnly && !reminder.isAlarm) continue;
      for (var dayOffset = 0; dayOffset < 2; dayOffset++) {
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
        final end = reminder.endDate;
        if (end != null && day.isAfter(DateTime(end.year, end.month, end.day))) continue;
        for (final minutes in reminder.times) {
          final dose = DueDose(reminder: reminder, minutes: minutes, day: day);
          if (!dose.scheduledAt.isAfter(now)) continue;
          if (best == null || dose.scheduledAt.isBefore(best.scheduledAt)) best = dose;
        }
      }
    }
    return best;
  }

  /// Today's doses in time order, for the home screen.
  List<DueDose> todaysDoses() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final doses = <DueDose>[
      for (final reminder in _reminders.where((r) => r.enabled && !r.isExpired))
        for (final minutes in reminder.times) DueDose(reminder: reminder, minutes: minutes, day: today),
    ]..sort((a, b) => a.minutes.compareTo(b.minutes));
    return doses;
  }

  tz.TZDateTime _nextInstance(int minutesAfterMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesAfterMidnight ~/ 60,
      minutesAfterMidnight % 60,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
