import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/doctor.dart';

class DoctorsService {
  DoctorsService._internal();
  static final DoctorsService _instance = DoctorsService._internal();
  factory DoctorsService() => _instance;

  static const String _storageKeyDoctorsCsv = 'custom_doctors_csv';
  static const String _assetCsvPath = 'assets/doctors/lebanon_doctors.csv';

  List<Doctor> _catalog = <Doctor>[];
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  String? _loadError;

  bool get isInitialized => _isInitialized;
  int get totalDoctorCount => _catalog.length;

  /// Non-null when the bundled dataset could not be loaded.
  String? get loadError => _loadError;

  bool _isGoodCsv(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty || t.startsWith('<!') || t.startsWith('<html') || t.startsWith('<?xml')) {
      return false;
    }
    return t.contains('name_en') || t.contains('doctor_code') || t.contains('specialty_en') || t.contains('doc_');
  }

  /// Ensures the Doctors database is loaded into memory.
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null && !_initCompleter!.isCompleted) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final customCsv = prefs.getString(_storageKeyDoctorsCsv);

      final csvData = customCsv != null && _isGoodCsv(customCsv)
          ? customCsv
          : await rootBundle.loadString(_assetCsvPath);

      _catalog = await compute(parseDoctorsCsv, csvData);
      _loadError = _catalog.isEmpty ? 'The doctors list is empty.' : null;
      debugPrint('DoctorsService: Successfully indexed ${_catalog.length} doctors.');
    } catch (e, st) {
      debugPrint('DoctorsService initialization error: $e\n$st');
      _catalog = <Doctor>[];
      _loadError = 'The doctors list could not be loaded.';
    }

    _isInitialized = true;
    _initCompleter!.complete();
  }

  Future<List<Doctor>> loadDoctors({int limit = 50}) {
    return searchDoctorsPage(limit: limit, offset: 0);
  }

  Future<List<Doctor>> searchDoctors({
    String query = '',
    String specialty = '',
    String gender = '',
    int limit = 50,
  }) {
    return searchDoctorsPage(
      query: query,
      specialty: specialty,
      gender: gender,
      limit: limit,
      offset: 0,
    );
  }

  Future<List<Doctor>> searchDoctorsPage({
    String query = '',
    String specialty = '',
    String gender = '',
    int limit = 50,
    int offset = 0,
  }) async {
    await initialize();

    final safeLimit = limit.clamp(1, 100).toInt();
    final safeOffset = offset < 0 ? 0 : offset;

    final cleanQuery = query.trim().toLowerCase();
    final cleanSpecialty = specialty.trim().toLowerCase();
    final cleanGender = _normalizeGender(gender).toLowerCase();

    final filtered = _catalog.where((doc) {
      if (cleanQuery.isNotEmpty) {
        final matchNameEn = doc.nameEn.toLowerCase().contains(cleanQuery);
        final matchNameAr = doc.nameAr.contains(query.trim());
        final matchCity = doc.city.toLowerCase().contains(cleanQuery) ||
            doc.governorate.toLowerCase().contains(cleanQuery) ||
            doc.area.toLowerCase().contains(cleanQuery);
        final matchHospital = doc.hospitalName.toLowerCase().contains(cleanQuery) ||
            doc.clinicName.toLowerCase().contains(cleanQuery);
        final matchSpecialty = doc.specialtyEn.toLowerCase().contains(cleanQuery) ||
            doc.specialtyAr.contains(query.trim());

        if (!matchNameEn && !matchNameAr && !matchCity && !matchHospital && !matchSpecialty) {
          return false;
        }
      }

      if (cleanSpecialty.isNotEmpty) {
        if (doc.specialtyEn.trim().toLowerCase() != cleanSpecialty &&
            doc.specialtyAr.trim() != specialty.trim()) {
          return false;
        }
      }

      if (cleanGender.isNotEmpty) {
        if (doc.gender.trim().toLowerCase() != cleanGender) {
          return false;
        }
      }

      return true;
    }).toList();

    return List<Doctor>.unmodifiable(filtered.skip(safeOffset).take(safeLimit));
  }

  Future<DoctorsFilterMetadata> loadFilterMetadata({int limit = 20000}) async {
    await initialize();

    final specialtyCounts = <String, int>{};
    final specialtyArabic = <String, String>{};
    final genderCounts = <String, int>{};

    for (final doc in _catalog) {
      if (doc.specialtyEn.isNotEmpty) {
        specialtyCounts[doc.specialtyEn] = (specialtyCounts[doc.specialtyEn] ?? 0) + 1;
        if (doc.specialtyAr.isNotEmpty) {
          specialtyArabic.putIfAbsent(doc.specialtyEn, () => doc.specialtyAr);
        }
      }
      if (doc.gender.isNotEmpty) {
        genderCounts[doc.gender] = (genderCounts[doc.gender] ?? 0) + 1;
      }
    }

    final sortedSpecs = specialtyCounts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return DoctorsFilterMetadata(
      specialties: List<String>.unmodifiable(sortedSpecs),
      specialtyArabicByEnglish: Map<String, String>.unmodifiable(specialtyArabic),
      specialtyCounts: Map<String, int>.unmodifiable(specialtyCounts),
      genderCounts: Map<String, int>.unmodifiable(genderCounts),
      totalDoctors: _catalog.length,
    );
  }

  static String _normalizeGender(String value) {
    final normalized = value.trim().toLowerCase();

    if (const <String>{
      'female',
      'f',
      'woman',
      'أنثى',
      'انثى',
    }.contains(normalized)) {
      return 'Female';
    }

    if (const <String>{'male', 'm', 'man', 'ذكر'}.contains(normalized)) {
      return 'Male';
    }

    return '';
  }
}

class DoctorsFilterMetadata {
  const DoctorsFilterMetadata({
    required this.specialties,
    required this.specialtyArabicByEnglish,
    required this.specialtyCounts,
    required this.genderCounts,
    required this.totalDoctors,
  });

  const DoctorsFilterMetadata.empty()
    : specialties = const <String>[],
      specialtyArabicByEnglish = const <String, String>{},
      specialtyCounts = const <String, int>{},
      genderCounts = const <String, int>{},
      totalDoctors = 0;

  final List<String> specialties;

  final Map<String, String> specialtyArabicByEnglish;

  final Map<String, int> specialtyCounts;

  final Map<String, int> genderCounts;

  final int totalDoctors;

  int get femaleDoctors {
    return genderCounts['Female'] ?? 0;
  }

  int get maleDoctors {
    return genderCounts['Male'] ?? 0;
  }

  int get classifiedDoctors {
    return femaleDoctors + maleDoctors;
  }

  int get unclassifiedDoctors {
    final value = totalDoctors - classifiedDoctors;

    return value < 0 ? 0 : value;
  }

  String specialtyArabic(String english) {
    return specialtyArabicByEnglish[english.trim()] ?? '';
  }
}

class DoctorsServiceException implements Exception {
  const DoctorsServiceException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

/// Parses the doctors CSV. Top-level so it can run in a background isolate.
List<Doctor> parseDoctorsCsv(String csvContent) {
  final lines = const LineSplitter().convert(csvContent);
  if (lines.isEmpty) return <Doctor>[];

  final headers = _parseCsvLine(lines.first);
  final results = <Doctor>[];

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final values = _parseCsvLine(line);
    final map = <String, dynamic>{};

    for (var j = 0; j < headers.length; j++) {
      final key = headers[j].trim().toLowerCase();
      final val = j < values.length ? values[j].trim() : '';

      if (key == 'is_verified' || key == 'is_active' || key == 'isactive' || key == 'whatsapp_verified') {
        map[key] = val.toLowerCase() == 'true';
      } else {
        map[key] = val;
      }
    }

    final doc = Doctor.fromMap(map);
    if (doc.nameEn.isNotEmpty || doc.nameAr.isNotEmpty) {
      results.add(doc);
    }
  }

  return results;
}

List<String> _parseCsvLine(String line) {
  final values = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        sb.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      values.add(sb.toString());
      sb.clear();
    } else {
      sb.write(char);
    }
  }
  values.add(sb.toString());
  return values;
}
