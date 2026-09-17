class DoctorContext {
  final String detectedDoctorName;
  final String detectedSpecialty;
  final double confidence;

  const DoctorContext({
    required this.detectedDoctorName,
    required this.detectedSpecialty,
    required this.confidence,
  });

  bool get hasSpecialty => detectedSpecialty.trim().isNotEmpty;

  bool get hasDoctorName => detectedDoctorName.trim().isNotEmpty;

  factory DoctorContext.empty() {
    return const DoctorContext(
      detectedDoctorName: '',
      detectedSpecialty: '',
      confidence: 0,
    );
  }
}
