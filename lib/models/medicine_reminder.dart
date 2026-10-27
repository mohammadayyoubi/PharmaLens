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
  });

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

  bool get isExpired {
    final end = endDate;
    if (end == null) return false;
    final today = DateTime.now();
    return DateTime(end.year, end.month, end.day).isBefore(DateTime(today.year, today.month, today.day));
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
  }) {
    return MedicineReminder(
      id: id,
      medicineName: medicineName ?? this.medicineName,
      medicineId: medicineId,
      doseNote: doseNote ?? this.doseNote,
      times: times ?? this.times,
      enabled: enabled ?? this.enabled,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
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
    );
  }
}
