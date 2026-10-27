import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/models/doctor.dart';
import 'package:pharmalens/models/medicine_reminder.dart';
import 'package:pharmalens/models/prescription_record.dart';
import 'package:pharmalens/services/doctors_service.dart';
import 'package:pharmalens/utils/doctor_gender_resolver.dart';

void main() {
  group('DoctorGenderResolver', () {
    test('uses the first name only and folds spelling variants', () {
      expect(DoctorGenderResolver.fromArabicName('د. زينة ايلي باز'), DoctorGenderResolver.female);
      expect(DoctorGenderResolver.fromArabicName('د. زينه ايلي باز'), DoctorGenderResolver.female);
      expect(DoctorGenderResolver.fromArabicName('د. الياس اسكندر اصفر'), DoctorGenderResolver.male);
      expect(DoctorGenderResolver.fromArabicName('أحمد علي'), DoctorGenderResolver.male);
    });

    test('leaves unisex and unknown names unclassified', () {
      expect(DoctorGenderResolver.fromArabicName('د. نور حسن'), '');
      expect(DoctorGenderResolver.fromArabicName('د. جود سمير'), '');
      expect(DoctorGenderResolver.fromArabicName(''), '');
    });
  });

  group('Doctor.fromMap', () {
    Doctor parse(Map<String, dynamic> overrides) {
      return Doctor.fromMap(<String, dynamic>{
        'id': 'doc_1',
        'name_en': 'Dr. Zina Baz',
        'name_ar': 'د. زينة ايلي باز',
        'gender': '',
        'specialty_en': 'Pediatrics',
        'hospital_clinic': 'Hospital',
        'hospital_name': 'Al Makassed; Al Sahel',
        'city': 'Lebanon',
        'governorate': 'Lebanon',
        ...overrides,
      });
    }

    test('estimates gender only when the record has none', () {
      final estimated = parse(<String, dynamic>{});
      expect(estimated.gender, 'Female');
      expect(estimated.genderEstimated, isTrue);

      final recorded = parse(<String, dynamic>{'gender': 'male'});
      expect(recorded.gender, 'Male');
      expect(recorded.genderEstimated, isFalse);
    });

    test('splits hospitals and hides the placeholder country location', () {
      final doctor = parse(<String, dynamic>{});
      expect(doctor.hospitals, <String>['Al Makassed', 'Al Sahel']);
      expect(doctor.displayLocation, isEmpty);
      expect(doctor.facilityLabel(isArabic: false), 'Al Makassed • Al Sahel');
      expect(parse(<String, dynamic>{'hospital_name': ''}).facilityLabel(isArabic: false), 'Private clinic');
    });
  });

  test('bundled doctors list parses completely', () {
    final csv = File('assets/doctors/lebanon_doctors.csv').readAsStringSync();
    final rows = csv.trim().split('\n').length - 1;

    final doctors = parseDoctorsCsv(csv);

    expect(doctors.length, rows);

    final classified = doctors.where((d) => d.gender.isNotEmpty).length;
    expect(classified / doctors.length, greaterThan(0.85));
    expect(doctors.where((d) => d.isFemale), isNotEmpty);
  });

  test('reminder JSON round trip and sorting', () {
    final reminder = MedicineReminder(
      id: 3,
      medicineName: 'Augmentin',
      times: const <int>[20 * 60, 8 * 60],
      doseNote: '1 tablet',
      endDate: DateTime(2030, 1, 5),
    );

    final restored = MedicineReminder.fromJson(reminder.toJson());

    expect(restored.medicineName, 'Augmentin');
    expect(restored.times, <int>[8 * 60, 20 * 60]);
    expect(restored.endDate, DateTime(2030, 1, 5));
    expect(MedicineReminder.formatTime(8 * 60 + 5), '08:05');
  });

  test('prescription record JSON round trip', () {
    final record = PrescriptionRecord(
      id: 'r1',
      createdAt: DateTime(2026, 10, 27, 9, 30),
      doctorName: 'Dr. Example',
      medicines: const <PrescriptionMedicineEntry>[
        PrescriptionMedicineEntry(writtenName: 'Augmntin', medicineId: '9849', brandName: 'AUGMENTIN', verified: true),
        PrescriptionMedicineEntry(writtenName: 'unclear'),
      ],
    );

    final restored = PrescriptionRecord.fromJson(record.toJson());

    expect(restored.createdAt, record.createdAt);
    expect(restored.verifiedCount, 1);
    expect(restored.medicines.first.displayName, 'AUGMENTIN');
    expect(restored.medicines.last.displayName, 'unclear');
  });
}
