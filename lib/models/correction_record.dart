class CorrectionRecord {
  final String id;
  final String imagePath;
  final String correctedText;
  final String doctorName;
  final String doctorSpecialty;
  final DateTime createdAt;

  const CorrectionRecord({
    required this.id,
    required this.imagePath,
    required this.correctedText,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'correctedText': correctedText,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CorrectionRecord.fromJson(Map<String, dynamic> json) {
    return CorrectionRecord(
      id: json['id'] ?? '',
      imagePath: json['imagePath'] ?? '',
      correctedText: json['correctedText'] ?? '',
      doctorName: json['doctorName'] ?? '',
      doctorSpecialty: json['doctorSpecialty'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
