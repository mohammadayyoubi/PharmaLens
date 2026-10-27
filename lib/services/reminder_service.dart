import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicine_reminder.dart';

/// Stores medicine reminders and schedules one daily notification per time.
///
/// Notifications are scheduled on Android, iOS, macOS, Windows and Linux.
/// On the web reminders are saved and listed, but the browser cannot deliver
/// them while the page is closed, so [supportsNotifications] is false there.
class ReminderService extends ChangeNotifier {
  ReminderService._internal();

  static final ReminderService _instance = ReminderService._internal();

  factory ReminderService() => _instance;

  static const String _storageKey = 'pharmalens_reminders_v1';
  static const int _maxTimesPerReminder = 8;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  List<MedicineReminder> _reminders = <MedicineReminder>[];
  bool _loaded = false;
  bool _pluginReady = false;
  String _languageCode = 'en';

  List<MedicineReminder> get reminders => List<MedicineReminder>.unmodifiable(_reminders);
  bool get isLoaded => _loaded;
  bool get supportsNotifications => !kIsWeb;

  /// Language used for notification text.
  set languageCode(String value) {
    _languageCode = value == 'ar' ? 'ar' : 'en';
  }

  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _reminders = decoded
              .whereType<Map>()
              .map((m) => MedicineReminder.fromJson(Map<String, dynamic>.from(m)))
              .where((r) => r.id > 0 && r.medicineName.isNotEmpty)
              .toList();
        }
      }
    } catch (error) {
      debugPrint('ReminderService: could not load reminders: $error');
    }

    _loaded = true;
    notifyListeners();

    // Re-schedule after app updates or time-zone changes.
    await _rescheduleAll();
  }

  Future<MedicineReminder> add({
    required String medicineName,
    required List<int> times,
    String medicineId = '',
    String doseNote = '',
    DateTime? endDate,
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
    );

    _reminders = <MedicineReminder>[..._reminders, reminder];
    await _persist();
    await _schedule(reminder);
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
    notifyListeners();
  }

  Future<void> remove(int id) async {
    await load();

    final index = _reminders.indexWhere((r) => r.id == id);
    if (index < 0) return;

    await _cancel(_reminders[index]);
    _reminders = List<MedicineReminder>.of(_reminders)..removeAt(index);
    await _persist();
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
  // Notifications
  // ---------------------------------------------------------------------------

  Future<bool> _ensurePlugin() async {
    if (!supportsNotifications) return false;
    if (_pluginReady) return true;

    try {
      tz_data.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        // Most users are in Lebanon; better than silently using UTC.
        tz.setLocalLocation(tz.getLocation('Asia/Beirut'));
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
      );

      _pluginReady = true;
    } catch (error) {
      debugPrint('ReminderService: notifications unavailable: $error');
    }

    return _pluginReady;
  }

  /// Asks the OS for permission to show notifications. Returns false if denied.
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

  int _notificationId(MedicineReminder reminder, int timeIndex) => reminder.id * 10 + timeIndex;

  Future<void> _schedule(MedicineReminder reminder) async {
    if (!reminder.enabled || reminder.isExpired) return;
    if (!await _ensurePlugin()) return;

    final isArabic = _languageCode == 'ar';
    final title = isArabic ? 'موعد الدواء: ${reminder.medicineName}' : 'Time for ${reminder.medicineName}';
    final body = reminder.doseNote.isNotEmpty
        ? reminder.doseNote
        : (isArabic ? 'حان وقت جرعتك حسب وصفة الطبيب.' : 'It is time for your dose as prescribed.');

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medicine_reminders',
        'Medicine reminders',
        channelDescription: 'Daily reminders to take your medicines',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    for (var i = 0; i < reminder.times.length; i++) {
      try {
        await _plugin.zonedSchedule(
          id: _notificationId(reminder, i),
          title: title,
          body: body,
          scheduledDate: _nextInstance(reminder.times[i]),
          notificationDetails: details,
          // Inexact keeps us clear of the exact-alarm permission; a reminder
          // may arrive a few minutes late on some Android devices.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'reminder:${reminder.id}',
        );
      } catch (error) {
        debugPrint('ReminderService: could not schedule reminder ${reminder.id}: $error');
      }
    }
  }

  Future<void> _cancel(MedicineReminder reminder) async {
    if (!await _ensurePlugin()) return;

    for (var i = 0; i < _maxTimesPerReminder; i++) {
      try {
        await _plugin.cancel(id: _notificationId(reminder, i));
      } catch (_) {}
    }
  }

  Future<void> _rescheduleAll() async {
    if (_reminders.isEmpty || !await _ensurePlugin()) return;

    for (final reminder in _reminders) {
      await _cancel(reminder);
      await _schedule(reminder);
    }
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
