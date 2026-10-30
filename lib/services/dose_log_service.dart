import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DoseStatus { taken, skipped, snoozed }

class DoseLogEntry {
  const DoseLogEntry({
    required this.reminderId,
    required this.medicineName,
    required this.day,
    required this.minutes,
    required this.status,
    required this.at,
  });

  final int reminderId;
  final String medicineName;

  /// Day of the scheduled dose (date only).
  final DateTime day;

  /// Scheduled time of day, minutes after midnight.
  final int minutes;
  final DoseStatus status;

  /// When the user answered.
  final DateTime at;

  String get key => '$reminderId|${_date(day)}|$minutes';

  static String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'reminder_id': reminderId,
        'medicine': medicineName,
        'day': _date(day),
        'minutes': minutes,
        'status': status.name,
        'at': at.toIso8601String(),
      };

  static DoseLogEntry? fromJson(Map<String, dynamic> json) {
    final day = DateTime.tryParse('${json['day'] ?? ''}');
    final at = DateTime.tryParse('${json['at'] ?? ''}');
    final status = DoseStatus.values.where((s) => s.name == json['status']).firstOrNull;
    if (day == null || at == null || status == null) return null;
    return DoseLogEntry(
      reminderId: (json['reminder_id'] as num?)?.toInt() ?? 0,
      medicineName: '${json['medicine'] ?? ''}',
      day: day,
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      status: status,
      at: at,
    );
  }
}

/// Which doses were taken, skipped or snoozed, kept on this device for
/// [keepDays] days. Written from the dose screen and from notification
/// buttons, which may run in a background isolate.
class DoseLogService extends ChangeNotifier {
  DoseLogService._internal();

  static final DoseLogService _instance = DoseLogService._internal();

  factory DoseLogService() => _instance;

  static const String _storageKey = 'pharmalens_dose_log_v1';
  static const int keepDays = 90;

  List<DoseLogEntry> _entries = <DoseLogEntry>[];
  bool _loaded = false;

  List<DoseLogEntry> get entries => List<DoseLogEntry>.unmodifiable(_entries);

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    _entries = await _read();
    _loaded = true;
    notifyListeners();
  }

  static Future<List<DoseLogEntry>> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return <DoseLogEntry>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <DoseLogEntry>[];
      return decoded.whereType<Map>().map((m) => DoseLogEntry.fromJson(Map<String, dynamic>.from(m))).whereType<DoseLogEntry>().toList();
    } catch (error) {
      debugPrint('DoseLogService: could not read the log: $error');
      return <DoseLogEntry>[];
    }
  }

  /// Records an answer. Static so a notification button can call it from a
  /// background isolate without the app running.
  static Future<void> record(DoseLogEntry entry) async {
    final entries = await _read();
    entries.removeWhere((e) => e.key == entry.key);
    entries.add(entry);
    final cutoff = DateTime.now().subtract(const Duration(days: keepDays));
    entries.removeWhere((e) => e.day.isBefore(cutoff));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
    } catch (error) {
      debugPrint('DoseLogService: could not save the log: $error');
    }
    if (_instance._loaded) {
      _instance._entries = entries;
      _instance.notifyListeners();
    }
  }

  DoseStatus? statusOf(int reminderId, DateTime day, int minutes) {
    final key = '$reminderId|${DoseLogEntry._date(day)}|$minutes';
    return _entries.where((e) => e.key == key).firstOrNull?.status;
  }

  /// Share of answered doses that were taken in the last [days] days, or
  /// null when nothing was answered.
  double? adherence({int days = 7, int? reminderId}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recent = _entries
        .where((e) => e.day.isAfter(cutoff) && e.status != DoseStatus.snoozed)
        .where((e) => reminderId == null || e.reminderId == reminderId)
        .toList();
    if (recent.isEmpty) return null;
    return recent.where((e) => e.status == DoseStatus.taken).length / recent.length;
  }
}
