import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What reminders need from the operating system, and whether the user
/// granted it.
///
/// - Notifications: required for any reminder (Android 13+, iOS).
/// - Exact alarms: without it Android may deliver a reminder minutes late
///   (Android 12+; off by default on Android 14+).
/// - Full-screen alarms: lets an alarm open the dose screen over the lock
///   screen (Android 14+ may ask the user).
/// - Battery "Unrestricted": some phones (Xiaomi, Huawei, Oppo, Samsung)
///   stop alarms of apps they optimize. Optional but recommended.
///
/// "Display over other apps" is not needed: full-screen notifications are
/// the Android way for alarms to appear over other apps.
class ReminderSetupStatus {
  const ReminderSetupStatus({
    required this.notifications,
    required this.exactAlarms,
    required this.fullScreen,
    required this.batteryUnrestricted,
    required this.applies,
  });

  final bool notifications;
  final bool exactAlarms;
  final bool fullScreen;
  final bool batteryUnrestricted;

  /// False on platforms without these settings (web, desktop).
  final bool applies;

  bool get readyForNotifications => !applies || notifications;
  bool get readyForAlarms => !applies || (notifications && exactAlarms && fullScreen);
  bool get allGranted => readyForAlarms && (!applies || batteryUnrestricted);
}

class ReminderPermissions {
  const ReminderPermissions._();

  static const String _fullScreenKey = 'pharmalens_full_screen_granted';
  static const String _setupDoneKey = 'pharmalens_reminder_setup_seen';

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get _isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<ReminderSetupStatus> check() async {
    if (!_isAndroid && !_isApple) {
      return const ReminderSetupStatus(notifications: true, exactAlarms: true, fullScreen: true, batteryUnrestricted: true, applies: false);
    }

    try {
      if (_isApple) {
        final options = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.checkPermissions() ??
            await _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
        return ReminderSetupStatus(
          notifications: options?.isEnabled ?? false,
          exactAlarms: true,
          fullScreen: true,
          batteryUnrestricted: true,
          applies: true,
        );
      }

      final notifications = await Permission.notification.isGranted;

      final exact = await _android?.canScheduleExactNotifications() ?? true;
      final prefs = await SharedPreferences.getInstance();
      final battery = await Permission.ignoreBatteryOptimizations.isGranted;

      return ReminderSetupStatus(
        notifications: notifications,
        exactAlarms: exact,
        fullScreen: prefs.getBool(_fullScreenKey) ?? false,
        batteryUnrestricted: battery,
        applies: true,
      );
    } catch (error) {
      debugPrint('ReminderPermissions: check failed: $error');
      return const ReminderSetupStatus(notifications: true, exactAlarms: true, fullScreen: true, batteryUnrestricted: true, applies: false);
    }
  }

  static Future<bool> requestNotifications() async {
    try {
      if (_isApple) {
        return await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true, badge: true) ??
            await _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true, badge: true) ??
            false;
      }
      final status = await Permission.notification.request();
      if (status.isPermanentlyDenied) await openAppSettings();
      return status.isGranted;
    } catch (error) {
      debugPrint('ReminderPermissions: notification request failed: $error');
      return false;
    }
  }

  /// Opens the "Alarms & reminders" settings page when not yet allowed.
  static Future<bool> requestExactAlarms() async {
    if (!_isAndroid) return true;
    try {
      return await _android?.requestExactAlarmsPermission() ?? true;
    } catch (error) {
      debugPrint('ReminderPermissions: exact alarm request failed: $error');
      return false;
    }
  }

  /// Returns at once when already allowed; otherwise opens the settings page.
  static Future<bool> requestFullScreen() async {
    if (!_isAndroid) return true;
    try {
      final granted = await _android?.requestFullScreenIntentPermission() ?? true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_fullScreenKey, granted);
      return granted;
    } catch (error) {
      debugPrint('ReminderPermissions: full-screen request failed: $error');
      return false;
    }
  }

  /// Opens the app's system settings, where Battery can be set to
  /// "Unrestricted".
  static Future<void> openBatterySettings() async {
    try {
      await openAppSettings();
    } catch (error) {
      debugPrint('ReminderPermissions: could not open settings: $error');
    }
  }

  /// Whether the user has already seen the setup screen (granted or skipped).
  static Future<bool> setupSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_setupDoneKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markSetupSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupDoneKey, true);
    } catch (_) {}
  }
}
