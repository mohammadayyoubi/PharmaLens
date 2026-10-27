/// A prescription the user scanned, kept on the device for later review.
class PrescriptionRecord {
  const PrescriptionRecord({
    required this.id,
    required this.createdAt,
    required this.medicines,
    this.doctorName = '',
    this.specialty = '',
    this.imagePath = '',
  });

  final String id;
  final DateTime createdAt;
  final String doctorName;
  final String specialty;

  /// Local file path of the saved prescription photo ('' on web).
  final String imagePath;
  final List<PrescriptionMedicineEntry> medicines;

  int get verifiedCount => medicines.where((m) => m.verified).length;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'doctor_name': doctorName,
      'specialty': specialty,
      'image_path': imagePath,
      'medicines': medicines.map((m) => m.toJson()).toList(),
    };
  }

  factory PrescriptionRecord.fromJson(Map<String, dynamic> json) {
    final rawMedicines = json['medicines'];

    return PrescriptionRecord(
      id: '${json['id'] ?? ''}',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      doctorName: '${json['doctor_name'] ?? ''}',
      specialty: '${json['specialty'] ?? ''}',
      imagePath: '${json['image_path'] ?? ''}',
      medicines: rawMedicines is List
          ? rawMedicines
              .whereType<Map>()
              .map((m) => PrescriptionMedicineEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const <PrescriptionMedicineEntry>[],
    );
  }
}

/// One medicine line of a saved prescription.
class PrescriptionMedicineEntry {
  const PrescriptionMedicineEntry({
    required this.writtenName,
    this.medicineId = '',
    this.brandName = '',
    this.strength = '',
    this.dosageForm = '',
    this.ingredients = const <String>[],
    this.instructions = '',
    this.verified = false,
  });

  /// What the prescription says, as transcribed.
  final String writtenName;

  /// MOPH product it was matched to, when verified.
  final String medicineId;
  final String brandName;
  final String strength;
  final String dosageForm;
  final List<String> ingredients;
  final String instructions;
  final bool verified;

  String get displayName => brandName.isNotEmpty ? brandName : writtenName;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'written_name': writtenName,
      'medicine_id': medicineId,
      'brand_name': brandName,
      'strength': strength,
      'dosage_form': dosageForm,
      'ingredients': ingredients,
      'instructions': instructions,
      'verified': verified,
    };
  }

  factory PrescriptionMedicineEntry.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'];

    return PrescriptionMedicineEntry(
      writtenName: '${json['written_name'] ?? ''}',
      medicineId: '${json['medicine_id'] ?? ''}',
      brandName: '${json['brand_name'] ?? ''}',
      strength: '${json['strength'] ?? ''}',
      dosageForm: '${json['dosage_form'] ?? ''}',
      ingredients: rawIngredients is List ? rawIngredients.map((e) => '$e').toList() : const <String>[],
      instructions: '${json['instructions'] ?? ''}',
      verified: json['verified'] == true,
    );
  }
}
