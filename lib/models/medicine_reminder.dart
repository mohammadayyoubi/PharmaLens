/// How a reminder gets the user's attention.
enum ReminderMode {
  /// A normal notification with the default sound.
  notification,

  /// An alarm: plays the PharmaLens alarm tone until answered, opens the
  /// dose screen over the lock screen and can say the medicine name aloud.
  alarm,
}

/// A daily reminder to take a medicine at one or more times of day.
class MedicineReminder {
  const MedicineReminder({
    required this.id,
    required this.medicineName,
    required this.times,
    this.medicineId = '',
    this.doseNote = '',
    this.enabled = true,
    this.endDate,
    this.mode = ReminderMode.notification,
    this.speakName = true,
    this.startDate,
    this.packUnits,
    this.unitsPerDose = 1,
    this.profileId = 'me',
  });

  /// Whose medicine this is (HealthProfile.id; "me" for the owner).
  final String profileId;

  /// Small positive integer; notification ids are derived from it.
  final int id;
  final String medicineName;
  final String medicineId;
  final String doseNote;

  /// Times of day as minutes after midnight, sorted.
  final List<int> times;
  final bool enabled;

  /// Last day the reminder fires (inclusive), or null for no end date.
  final DateTime? endDate;

  final ReminderMode mode;

  /// In alarm mode, read "Time to take [medicineName]" aloud on the dose
  /// screen.
  final bool speakName;

  /// Day the user started this supply, for the refill estimate.
  final DateTime? startDate;

  /// Tablets, capsules or doses the user has (all packs together), or null
  /// when refill tracking is off.
  final int? packUnits;

  /// Units taken at each time, e.g. 2 tablets.
  final double unitsPerDose;

  bool get isAlarm => mode == ReminderMode.alarm;

  bool get isExpired {
    final end = endDate;
    if (end == null) return false;
    final today = DateTime.now();
    return DateTime(end.year, end.month, end.day).isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Day the supply runs out at the scheduled doses, or null when refill
  /// tracking is off.
  DateTime? get refillDate {
    final units = packUnits;
    final start = startDate;
    if (units == null || units <= 0 || start == null || times.isEmpty || unitsPerDose <= 0) return null;
    final days = (units / (unitsPerDose * times.length)).floor();
    final day = DateTime(start.year, start.month, start.day).add(Duration(days: days));
    final end = endDate;
    // A course that ends before the supply does needs no refill.
    if (end != null && !day.isBefore(DateTime(end.year, end.month, end.day).add(const Duration(days: 1)))) return null;
    return day;
  }

  static String formatTime(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  MedicineReminder copyWith({
    String? medicineName,
    String? doseNote,
    List<int>? times,
    bool? enabled,
    DateTime? endDate,
    bool clearEndDate = false,
    ReminderMode? mode,
    bool? speakName,
    DateTime? startDate,
    int? packUnits,
    bool clearPackUnits = false,
    double? unitsPerDose,
  }) {
    return MedicineReminder(
      id: id,
      medicineName: medicineName ?? this.medicineName,
      medicineId: medicineId,
      doseNote: doseNote ?? this.doseNote,
      times: times ?? this.times,
      enabled: enabled ?? this.enabled,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      mode: mode ?? this.mode,
      speakName: speakName ?? this.speakName,
      startDate: startDate ?? this.startDate,
      packUnits: clearPackUnits ? null : packUnits ?? this.packUnits,
      unitsPerDose: unitsPerDose ?? this.unitsPerDose,
      profileId: profileId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'medicine_name': medicineName,
      'medicine_id': medicineId,
      'dose_note': doseNote,
      'times': times,
      'enabled': enabled,
      'end_date': endDate?.toIso8601String(),
      'mode': mode.name,
      'speak_name': speakName,
      'start_date': startDate?.toIso8601String(),
      'pack_units': packUnits,
      'units_per_dose': unitsPerDose,
      'profile_id': profileId,
    };
  }

  factory MedicineReminder.fromJson(Map<String, dynamic> json) {
    final rawTimes = json['times'];
    final times = rawTimes is List
        ? rawTimes.whereType<num>().map((t) => t.toInt()).where((t) => t >= 0 && t < 24 * 60).toList()
        : <int>[];
    times.sort();

    return MedicineReminder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      medicineName: '${json['medicine_name'] ?? ''}',
      medicineId: '${json['medicine_id'] ?? ''}',
      doseNote: '${json['dose_note'] ?? ''}',
      times: times,
      enabled: json['enabled'] != false,
      endDate: DateTime.tryParse('${json['end_date'] ?? ''}'),
      mode: json['mode'] == 'alarm' ? ReminderMode.alarm : ReminderMode.notification,
      speakName: json['speak_name'] != false,
      startDate: DateTime.tryParse('${json['start_date'] ?? ''}'),
      packUnits: (json['pack_units'] as num?)?.toInt(),
      unitsPerDose: (json['units_per_dose'] as num?)?.toDouble() ?? 1,
      profileId: '${json['profile_id'] ?? 'me'}',
    );
  }
}

/// One scheduled dose: a reminder at one time on one day.
class DueDose {
  const DueDose({required this.reminder, required this.minutes, required this.day});

  final MedicineReminder reminder;

  /// Scheduled time of day, minutes after midnight.
  final int minutes;
  final DateTime day;

  DateTime get scheduledAt => DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
}
