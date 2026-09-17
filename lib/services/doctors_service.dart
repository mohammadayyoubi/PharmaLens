import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
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
  DoctorsFilterMetadata? _cachedMetadata;
  List<_IndexedDoctor> _indexedCatalog = <_IndexedDoctor>[];

  Completer<void>? _initCompleter;

  bool get isInitialized => _isInitialized;
  int get totalDoctorCount => _catalog.length;

  bool _isGoodCsv(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty || t.startsWith('<!') || t.startsWith('<html') || t.startsWith('<?xml')) {
      return false;
    }
    return t.contains('name_en') ||
        t.contains('doctor_code') ||
        t.contains('specialty_en') ||
        t.contains('doc_') ||
        t.contains('doctor name') ||
        t.contains('physician code') ||
        t.contains('specialty') ||
        t.contains('hospitals');
  }

  /// Ensures the Doctors database is loaded into memory.
  Future<void> initialize() async {
    if (_isInitialized && _catalog.isNotEmpty) return;
    if (_initCompleter != null && !_initCompleter!.isCompleted) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final customCsv = prefs.getString(_storageKeyDoctorsCsv);

      String csvData = '';
      if (customCsv != null && _isGoodCsv(customCsv)) {
        csvData = customCsv;
        debugPrint('DoctorsService: Loaded custom saved Doctors dataset (${csvData.length} bytes)');
      } else {
        try {
          final assetData = await rootBundle.loadString(_assetCsvPath);
          if (_isGoodCsv(assetData)) {
            csvData = assetData;
          }
        } catch (_) {}

        if (csvData.isEmpty) {
          try {
            final res1 = await http.get(Uri.parse('doctors/lebanon_doctors.csv')).timeout(const Duration(seconds: 3));
            if (res1.statusCode == 200 && _isGoodCsv(res1.body)) {
              csvData = res1.body;
            } else {
              final res2 = await http.get(Uri.parse('assets/doctors/lebanon_doctors.csv')).timeout(const Duration(seconds: 3));
              if (res2.statusCode == 200 && _isGoodCsv(res2.body)) {
                csvData = res2.body;
              }
            }
          } catch (_) {}
        }
        debugPrint('DoctorsService: Loaded asset Doctors dataset (${csvData.length} bytes)');
      }

      if (csvData.isNotEmpty) {
        _catalog = _parseCsvToDoctors(csvData);
      }
      if (_catalog.isEmpty) {
        _catalog = _getBuiltinDoctorsCatalog();
      }
      
      _buildIndexes();
      _isInitialized = true;
      debugPrint('DoctorsService: Successfully indexed ${_catalog.length} doctors.');
      _initCompleter!.complete();
    } catch (e, st) {
      debugPrint('DoctorsService initialization error: $e\n$st');
      _catalog = _getBuiltinDoctorsCatalog();
      _buildIndexes();
      _isInitialized = true;
      _initCompleter!.complete();
    }
  }

  void _buildIndexes() {
    _indexedCatalog = _catalog.map((d) => _IndexedDoctor(d)).toList();

    final specialtyCounts = <String, int>{};
    final specialtyArabic = <String, String>{};
    final genderCounts = <String, int>{};

    for (final doc in _catalog) {
      final specs = doc.specialtyEn
          .split(RegExp(r'[;\|]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      for (final spec in specs) {
        specialtyCounts[spec] = (specialtyCounts[spec] ?? 0) + 1;
        if (doc.specialtyAr.isNotEmpty) {
          specialtyArabic.putIfAbsent(spec, () => doc.specialtyAr);
        }
      }

      if (doc.gender.isNotEmpty) {
        genderCounts[doc.gender] = (genderCounts[doc.gender] ?? 0) + 1;
      }
    }

    final sortedSpecs = specialtyCounts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    _cachedMetadata = DoctorsFilterMetadata(
      specialties: List<String>.unmodifiable(sortedSpecs),
      specialtyArabicByEnglish: Map<String, String>.unmodifiable(specialtyArabic),
      specialtyCounts: Map<String, int>.unmodifiable(specialtyCounts),
      genderCounts: Map<String, int>.unmodifiable(genderCounts),
      totalDoctors: _catalog.length,
    );
  }

  Future<List<Doctor>> loadDoctors({int limit = 500}) {
    return searchDoctorsPage(limit: limit, offset: 0);
  }

  Future<List<Doctor>> searchDoctors({
    String query = '',
    String specialty = '',
    String gender = '',
    int limit = 500,
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
    int limit = 500,
    int offset = 0,
  }) async {
    await initialize();
    if (_catalog.isEmpty) {
      _catalog = _getBuiltinDoctorsCatalog();
      _buildIndexes();
    }

    final safeLimit = limit.clamp(1, 10000).toInt();
    final safeOffset = offset < 0 ? 0 : offset;

    final cleanQuery = query.trim().toLowerCase();
    final cleanSpecialty = specialty.trim().toLowerCase();
    final cleanGender = _normalizeGender(gender).toLowerCase();

    final filtered = _indexedCatalog.where((item) {
      final doc = item.doctor;

      if (cleanQuery.isNotEmpty) {
        final matchSearchText = item.normalizedSearchText.contains(cleanQuery);
        final matchNameAr = doc.nameAr.contains(query.trim());
        final matchSpecAr = doc.specialtyAr.contains(query.trim());

        if (!matchSearchText && !matchNameAr && !matchSpecAr) {
          return false;
        }
      }

      if (cleanSpecialty.isNotEmpty) {
        if (!item.normalizedSpecialtyEn.contains(cleanSpecialty) &&
            !item.normalizedSpecialtyAr.contains(specialty.trim())) {
          return false;
        }
      }

      if (cleanGender.isNotEmpty) {
        if (item.normalizedGender != cleanGender) {
          return false;
        }
      }

      return true;
    }).map((item) => item.doctor).toList();

    return List<Doctor>.unmodifiable(filtered.skip(safeOffset).take(safeLimit));
  }

  Future<DoctorsFilterMetadata> loadFilterMetadata({int limit = 20000}) async {
    await initialize();
    if (_cachedMetadata != null) {
      return _cachedMetadata!;
    }
    _buildIndexes();
    return _cachedMetadata!;
  }

  List<Doctor> _parseCsvToDoctors(String csvContent) {
    final lines = const LineSplitter().convert(csvContent);
    if (lines.isEmpty) return <Doctor>[];

    final headers = _parseCsvLine(lines.first);
    final results = <Doctor>[];

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = _parseCsvLine(line);
      final map = <String, dynamic>{
        'generated_id': 'doc_$i',
      };

      for (var j = 0; j < headers.length; j++) {
        final key = headers[j].trim().toLowerCase();
        final val = j < values.length ? values[j].trim() : '';

        if (key == 'is_verified' || key == 'is_active' || key == 'whatsapp_verified') {
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

  List<Doctor> _getBuiltinDoctorsCatalog() {
    return const [
      Doctor(
        id: 'doc_101',
        doctorCode: '101',
        nameEn: 'Dr. Hassan El Sayed',
        nameAr: 'د. حسن السيد',
        gender: 'Male',
        specialtyEn: 'Cardiology',
        specialtyAr: 'أمراض القلب',
        subspecialty: 'Interventional Cardiology',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'AUBMC',
        cityArea: 'Beirut',
        address: 'Hamra Main Street',
        area: 'Hamra',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 360000',
        whatsapp: '+961 70 123456',
        whatsappVerified: true,
        email: 'hassan.sayed@aubmc.edu.lb',
        notes: 'Consultant Cardiologist',
        latitude: 33.8992,
        longitude: 35.4815,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_102',
        doctorCode: '102',
        nameEn: 'Dr. Marie Khoury',
        nameAr: 'د. ماري خوري',
        gender: 'Female',
        specialtyEn: 'Pediatrics',
        specialtyAr: 'طب الأطفال',
        subspecialty: 'Pediatric Cardiology',
        diseases: [],
        hospitalClinic: 'Clinic',
        clinicName: 'Khoury Pediatric Clinic',
        hospitalName: '',
        cityArea: 'Metn',
        address: 'Main Road',
        area: 'Brummana',
        city: 'Metn',
        governorate: 'Mount Lebanon',
        phone: '+961 4 718000',
        whatsapp: '+961 3 987654',
        whatsappVerified: true,
        email: 'marie.khoury@gmail.com',
        notes: 'Senior Pediatrician',
        latitude: 33.8890,
        longitude: 35.6321,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_103',
        doctorCode: '103',
        nameEn: 'Dr. George Haddad',
        nameAr: 'د. جورج حداد',
        gender: 'Male',
        specialtyEn: 'Dermatology',
        specialtyAr: 'أمراض الجلد',
        subspecialty: 'Cosmetic Dermatology',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Hôtel-Dieu de France',
        cityArea: 'Beirut',
        address: 'Achrafieh',
        area: 'Achrafieh',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 615300',
        whatsapp: '+961 71 456789',
        whatsappVerified: true,
        email: 'ghaddad@hdf.usj.edu.lb',
        notes: 'Head of Dermatology Dept',
        latitude: 33.8845,
        longitude: 35.5180,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_104',
        doctorCode: '104',
        nameEn: 'Dr. Layla Nasr',
        nameAr: 'د. ليلى نصر',
        gender: 'Female',
        specialtyEn: 'Obstetrics & Gynecology',
        specialtyAr: 'أمراض النساء والتوليد',
        subspecialty: 'Maternal-Fetal Medicine',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'LAU Medical Center - Rizk Hospital',
        cityArea: 'Beirut',
        address: 'Achrafieh',
        area: 'Achrafieh',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 200800',
        whatsapp: '+961 3 112233',
        whatsappVerified: true,
        email: 'layla.nasr@laumcrh.com',
        notes: 'Consultant Obstetrician',
        latitude: 33.8872,
        longitude: 35.5140,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_105',
        doctorCode: '105',
        nameEn: 'Dr. Antoine Chahine',
        nameAr: 'د. أنطوان شاهين',
        gender: 'Male',
        specialtyEn: 'Orthopedics',
        specialtyAr: 'جراحة العظام',
        subspecialty: 'Joint Replacement',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Bellevue Medical Center',
        cityArea: 'Metn',
        address: 'Mansourieh',
        area: 'El Metn',
        city: 'Metn',
        governorate: 'Mount Lebanon',
        phone: '+961 4 682000',
        whatsapp: '+961 70 334455',
        whatsappVerified: true,
        email: 'achahine@bmc.com.lb',
        notes: 'Orthopedic Surgeon',
        latitude: 33.8681,
        longitude: 35.5891,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_106',
        doctorCode: '106',
        nameEn: 'Dr. Rania Kabbara',
        nameAr: 'د. رانيا كبارة',
        gender: 'Female',
        specialtyEn: 'Neurology',
        specialtyAr: 'أمراض الأعصاب',
        subspecialty: 'Epilepsy & Neuromuscular',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Nini Hospital',
        cityArea: 'Tripoli',
        address: 'Maarad Street',
        area: 'Maarad',
        city: 'Tripoli',
        governorate: 'North Lebanon',
        phone: '+961 6 431400',
        whatsapp: '+961 3 556677',
        whatsappVerified: true,
        email: 'rania.kabbara@ninihospital.com',
        notes: 'Consultant Neurologist',
        latitude: 34.4332,
        longitude: 35.8321,
        sourceName: 'Order of Physicians Tripoli',
        sourceUrl: 'https://loptripoli.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_107',
        doctorCode: '107',
        nameEn: 'Dr. Walid Gemayel',
        nameAr: 'د. وليد الجميل',
        gender: 'Male',
        specialtyEn: 'Gastroenterology',
        specialtyAr: 'أمراض الجهاز الهضمي',
        subspecialty: 'Hepatology',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Mount Lebanon Hospital',
        cityArea: 'Hazmieh',
        address: 'Baabda',
        area: 'Hazmieh',
        city: 'Baabda',
        governorate: 'Mount Lebanon',
        phone: '+961 5 957000',
        whatsapp: '+961 71 889900',
        whatsappVerified: true,
        email: 'wgemayel@mlh.com.lb',
        notes: 'Senior Gastroenterologist',
        latitude: 33.8564,
        longitude: 35.5392,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_108',
        doctorCode: '108',
        nameEn: 'Dr. Zeina Saad',
        nameAr: 'د. زينة سعد',
        gender: 'Female',
        specialtyEn: 'Ophthalmology',
        specialtyAr: 'طب وجراحة العيون',
        subspecialty: 'Retina & Laser Surgery',
        diseases: [],
        hospitalClinic: 'Clinic',
        clinicName: 'Saad Eye Clinic',
        hospitalName: '',
        cityArea: 'Sidon',
        address: 'Riad El Solh Street',
        area: 'Central Sidon',
        city: 'Sidon',
        governorate: 'South Lebanon',
        phone: '+961 7 720100',
        whatsapp: '+961 3 445566',
        whatsappVerified: true,
        email: 'zeinasaad@eyeclinic.lb',
        notes: 'Ophthalmic Surgeon',
        latitude: 33.5631,
        longitude: 35.3689,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_109',
        doctorCode: '109',
        nameEn: 'Dr. Tarek Sleiman',
        nameAr: 'د. طارق سليمان',
        gender: 'Male',
        specialtyEn: 'ENT (Otorhinolaryngology)',
        specialtyAr: 'أنف وأذن وحنجرة',
        subspecialty: 'Head & Neck Surgery',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'St. George Hospital UMCR',
        cityArea: 'Beirut',
        address: 'Achrafieh',
        area: 'Achrafieh',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 441000',
        whatsapp: '+961 70 667788',
        whatsappVerified: true,
        email: 'tsleiman@stgeorgehospital.org',
        notes: 'ENT Specialist',
        latitude: 33.8931,
        longitude: 35.5221,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_110',
        doctorCode: '110',
        nameEn: 'Dr. Noha Ghanem',
        nameAr: 'د. نهى غانم',
        gender: 'Female',
        specialtyEn: 'Endocrinology',
        specialtyAr: 'أمراض الغدد الصماء والسكري',
        subspecialty: 'Diabetes & Thyroid',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Khoury General Hospital',
        cityArea: 'Zahle',
        address: 'Boulevard Street',
        area: 'Central Zahle',
        city: 'Zahle',
        governorate: 'Bekaa',
        phone: '+961 8 807000',
        whatsapp: '+961 3 223344',
        whatsappVerified: true,
        email: 'noha.ghanem@kgh.com.lb',
        notes: 'Consultant Endocrinologist',
        latitude: 33.8462,
        longitude: 35.9031,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_111',
        doctorCode: '111',
        nameEn: 'Dr. Fadi Matar',
        nameAr: 'د. فادي مطر',
        gender: 'Male',
        specialtyEn: 'Urology',
        specialtyAr: 'جراحة المسالك البولية',
        subspecialty: 'Urologic Oncology & Kidney Stones',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Notre Dame de Secours',
        cityArea: 'Byblos',
        address: 'Hospital Street',
        area: 'Voie Verte',
        city: 'Jbeil',
        governorate: 'Mount Lebanon',
        phone: '+961 9 944000',
        whatsapp: '+961 71 556677',
        whatsappVerified: true,
        email: 'fadi.matar@nds.org.lb',
        notes: 'Consultant Urologist',
        latitude: 34.1215,
        longitude: 35.6512,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_112',
        doctorCode: '112',
        nameEn: 'Dr. Samar Hamdan',
        nameAr: 'د. سمر حمدان',
        gender: 'Female',
        specialtyEn: 'Psychiatry',
        specialtyAr: 'الطب النفسي',
        subspecialty: 'Adult & Adolescent Psychiatry',
        diseases: [],
        hospitalClinic: 'Clinic',
        clinicName: 'Beirut Mental Health Clinic',
        hospitalName: '',
        cityArea: 'Beirut',
        address: 'Hamra Street',
        area: 'Hamra',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 340500',
        whatsapp: '+961 3 778899',
        whatsappVerified: true,
        email: 'samar.hamdan@bmhc.lb',
        notes: 'Consultant Psychiatrist',
        latitude: 33.8965,
        longitude: 35.4852,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_113',
        doctorCode: '113',
        nameEn: 'Dr. Bilal Kassir',
        nameAr: 'د. بلال قصير',
        gender: 'Male',
        specialtyEn: 'Pulmonology',
        specialtyAr: 'أمراض الرئة والجهاز التنفسي',
        subspecialty: 'Asthma & Sleep Medicine',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Hiram Hospital',
        cityArea: 'Tyre',
        address: 'Main Highway',
        area: 'Abbassieh',
        city: 'Tyre',
        governorate: 'South Lebanon',
        phone: '+961 7 343700',
        whatsapp: '+961 70 990011',
        whatsappVerified: true,
        email: 'bilal.kassir@hiramhospital.com',
        notes: 'Pulmonologist',
        latitude: 33.2721,
        longitude: 35.2045,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_114',
        doctorCode: '114',
        nameEn: 'Dr. Carmen Azar',
        nameAr: 'د. كارمن عازار',
        gender: 'Female',
        specialtyEn: 'Nephrology',
        specialtyAr: 'أمراض الكلى',
        subspecialty: 'Dialysis & Kidney Transplantation',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'St. Joseph Hospital',
        cityArea: 'Dora',
        address: 'Dora Highway',
        area: 'Dora',
        city: 'Metn',
        governorate: 'Mount Lebanon',
        phone: '+961 1 240250',
        whatsapp: '+961 3 114477',
        whatsappVerified: true,
        email: 'carmen.azar@stjoseph.lb',
        notes: 'Nephrology Specialist',
        latitude: 33.8962,
        longitude: 35.5491,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_115',
        doctorCode: '115',
        nameEn: 'Dr. Elias Rahme',
        nameAr: 'د. إلياس رحمة',
        gender: 'Male',
        specialtyEn: 'General Surgery',
        specialtyAr: 'الجراحة العامة',
        subspecialty: 'Laparoscopic & Bariatric Surgery',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Middle East Institute of Health',
        cityArea: 'Bsalim',
        address: 'Main Road',
        area: 'Bsalim',
        city: 'Metn',
        governorate: 'Mount Lebanon',
        phone: '+961 4 710400',
        whatsapp: '+961 71 223344',
        whatsappVerified: true,
        email: 'erahme@meih.org',
        notes: 'Senior Surgeon',
        latitude: 33.9125,
        longitude: 35.5842,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_116',
        doctorCode: '116',
        nameEn: 'Dr. Selim Abou Jaoude',
        nameAr: 'د. سليم أبو جودة',
        gender: 'Male',
        specialtyEn: 'Cardiology',
        specialtyAr: 'أمراض القلب',
        subspecialty: 'Electrophysiology',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Hôtel-Dieu de France',
        cityArea: 'Beirut',
        address: 'Achrafieh',
        area: 'Achrafieh',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 615400',
        whatsapp: '+961 70 112244',
        whatsappVerified: true,
        email: 's.aboujaoude@hdf.usj.edu.lb',
        notes: 'Cardiologist',
        latitude: 33.8848,
        longitude: 35.5182,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_117',
        doctorCode: '117',
        nameEn: 'Dr. Nadine Helou',
        nameAr: 'د. نادين الحلو',
        gender: 'Female',
        specialtyEn: 'Dermatology',
        specialtyAr: 'أمراض الجلد',
        subspecialty: 'Pediatric Dermatology',
        diseases: [],
        hospitalClinic: 'Clinic',
        clinicName: 'Helou Skin Center',
        hospitalName: '',
        cityArea: 'Jounieh',
        address: 'Highway Road',
        area: 'Kaslik',
        city: 'Keserwan',
        governorate: 'Mount Lebanon',
        phone: '+961 9 640100',
        whatsapp: '+961 3 445588',
        whatsappVerified: true,
        email: 'nadine@helouskin.com',
        notes: 'Dermatologist',
        latitude: 33.9812,
        longitude: 35.6189,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_118',
        doctorCode: '118',
        nameEn: 'Dr. Joseph Aoun',
        nameAr: 'د. جوزيف عون',
        gender: 'Male',
        specialtyEn: 'Pediatrics',
        specialtyAr: 'طب الأطفال',
        subspecialty: 'Neonatology',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'St. George Hospital UMCR',
        cityArea: 'Beirut',
        address: 'Achrafieh',
        area: 'Achrafieh',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 441100',
        whatsapp: '+961 71 332211',
        whatsappVerified: true,
        email: 'jaoun@stgeorgehospital.org',
        notes: 'Pediatric Neonatologist',
        latitude: 33.8935,
        longitude: 35.5225,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_119',
        doctorCode: '119',
        nameEn: 'Dr. Mona Zgheib',
        nameAr: 'د. مونا زغيب',
        gender: 'Female',
        specialtyEn: 'Oncology',
        specialtyAr: 'أمراض الورم والسرطان',
        subspecialty: 'Medical Oncology',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'LAU Medical Center - Rizk Hospital',
        cityArea: 'Beirut',
        address: 'Achrafieh',
        area: 'Achrafieh',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 200900',
        whatsapp: '+961 3 667744',
        whatsappVerified: true,
        email: 'mona.zgheib@laumcrh.com',
        notes: 'Oncology Consultant',
        latitude: 33.8875,
        longitude: 35.5143,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_120',
        doctorCode: '120',
        nameEn: 'Dr. Michel Sfeir',
        nameAr: 'د. ميشال سفير',
        gender: 'Male',
        specialtyEn: 'Orthopedics',
        specialtyAr: 'جراحة العظام',
        subspecialty: 'Spine Surgery',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'AUBMC',
        cityArea: 'Beirut',
        address: 'Bliss Street',
        area: 'Hamra',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 350000',
        whatsapp: '+961 70 885522',
        whatsappVerified: true,
        email: 'msfeir@aubmc.edu.lb',
        notes: 'Spine Surgeon',
        latitude: 33.8995,
        longitude: 35.4818,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_121',
        doctorCode: '121',
        nameEn: 'Dr. Ghada Atallah',
        nameAr: 'د. غادة عطا الله',
        gender: 'Female',
        specialtyEn: 'Obstetrics & Gynecology',
        specialtyAr: 'أمراض النساء والتوليد',
        subspecialty: 'Reproductive Endocrinology & IVF',
        diseases: [],
        hospitalClinic: 'Clinic',
        clinicName: 'Atallah Fertility Clinic',
        hospitalName: '',
        cityArea: 'Beirut',
        address: 'Verdun Street',
        area: 'Verdun',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 800300',
        whatsapp: '+961 3 998811',
        whatsappVerified: true,
        email: 'gatallah@fertility.lb',
        notes: 'IVF Specialist',
        latitude: 33.8821,
        longitude: 35.4876,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_122',
        doctorCode: '122',
        nameEn: 'Dr. Ibrahim Dib',
        nameAr: 'د. إبراهيم ديب',
        gender: 'Male',
        specialtyEn: 'Gastroenterology',
        specialtyAr: 'أمراض الجهاز الهضمي',
        subspecialty: 'Inflammatory Bowel Disease',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Monla Hospital',
        cityArea: 'Tripoli',
        address: 'Dam & Farez',
        area: 'Maarad',
        city: 'Tripoli',
        governorate: 'North Lebanon',
        phone: '+961 6 430200',
        whatsapp: '+961 71 441122',
        whatsappVerified: true,
        email: 'idib@monlahospital.com',
        notes: 'Gastroenterologist',
        latitude: 34.4365,
        longitude: 35.8350,
        sourceName: 'Order of Physicians Tripoli',
        sourceUrl: 'https://loptripoli.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_123',
        doctorCode: '123',
        nameEn: 'Dr. Maya Bitar',
        nameAr: 'د. مايا بيطار',
        gender: 'Female',
        specialtyEn: 'Ophthalmology',
        specialtyAr: 'طب وجراحة العيون',
        subspecialty: 'Cornea & Refractive Surgery',
        diseases: [],
        hospitalClinic: 'Clinic',
        clinicName: 'Bitar Laser Eye Center',
        hospitalName: '',
        cityArea: 'Antelias',
        address: 'Main Highway',
        area: 'Antelias',
        city: 'Metn',
        governorate: 'Mount Lebanon',
        phone: '+961 4 410200',
        whatsapp: '+961 3 771122',
        whatsappVerified: true,
        email: 'maya@bitareye.com',
        notes: 'Refractive Surgeon',
        latitude: 33.9162,
        longitude: 35.5901,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_124',
        doctorCode: '124',
        nameEn: 'Dr. Rabih Khoury',
        nameAr: 'د. ربيع خوري',
        gender: 'Male',
        specialtyEn: 'Urology',
        specialtyAr: 'جراحة المسالك البولية',
        subspecialty: 'Laparoscopic Urology',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Mount Lebanon Hospital',
        cityArea: 'Hazmieh',
        address: 'Hazmieh',
        area: 'Baabda',
        city: 'Mount Lebanon',
        governorate: 'Mount Lebanon',
        phone: '+961 5 957100',
        whatsapp: '+961 70 224466',
        whatsappVerified: true,
        email: 'rkhoury@mlh.com.lb',
        notes: 'Consultant Urologist',
        latitude: 33.8567,
        longitude: 35.5395,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_125',
        doctorCode: '125',
        nameEn: 'Dr. Hanan Chammas',
        nameAr: 'د. حنان شماس',
        gender: 'Female',
        specialtyEn: 'Rheumatology',
        specialtyAr: 'أمراض الروماتيزم والمفاصل',
        subspecialty: 'Arthritis & Autoimmune',
        diseases: [],
        hospitalClinic: 'Clinic',
        clinicName: 'Chammas Clinic',
        hospitalName: '',
        cityArea: 'Beirut',
        address: 'Badaro Street',
        area: 'Badaro',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 380400',
        whatsapp: '+961 3 558899',
        whatsappVerified: true,
        email: 'hanan@chammasclinic.lb',
        notes: 'Rheumatologist',
        latitude: 33.8741,
        longitude: 35.5192,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_126',
        doctorCode: '126',
        nameEn: 'Dr. Bassam Younes',
        nameAr: 'د. بسام يونس',
        gender: 'Male',
        specialtyEn: 'Cardiology',
        specialtyAr: 'أمراض القلب',
        subspecialty: 'Interventional Cardiology',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Hammoud Hospital UMC',
        cityArea: 'Sidon',
        address: 'Doctor Street',
        area: 'Central Sidon',
        city: 'Sidon',
        governorate: 'South Lebanon',
        phone: '+961 7 721040',
        whatsapp: '+961 70 339900',
        whatsappVerified: true,
        email: 'byounes@hammoudhospital.com',
        notes: 'Interventional Cardiologist',
        latitude: 33.5612,
        longitude: 35.3711,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_127',
        doctorCode: '127',
        nameEn: 'Dr. Souad Kanaan',
        nameAr: 'د. سعاد كنعان',
        gender: 'Female',
        specialtyEn: 'Pediatrics',
        specialtyAr: 'طب الأطفال',
        subspecialty: 'General Pediatrics',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Keserwan Medical Center',
        cityArea: 'Ghazir',
        address: 'Highway Center',
        area: 'Ghazir',
        city: 'Keserwan',
        governorate: 'Mount Lebanon',
        phone: '+961 9 851000',
        whatsapp: '+961 3 884422',
        whatsappVerified: true,
        email: 'skanaan@kmc.com.lb',
        notes: 'Pediatrician',
        latitude: 34.0215,
        longitude: 35.6601,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_128',
        doctorCode: '128',
        nameEn: 'Dr. Raymond Sayegh',
        nameAr: 'د. ريمون صايغ',
        gender: 'Male',
        specialtyEn: 'General Practice',
        specialtyAr: 'الطب الداخلي والطب العام',
        subspecialty: 'Internal Medicine & Hypertension',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Hôtel-Dieu de France',
        cityArea: 'Beirut',
        address: 'Achrafieh',
        area: 'Achrafieh',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 615000',
        whatsapp: '+961 71 881122',
        whatsappVerified: true,
        email: 'rsayegh@hdf.usj.edu.lb',
        notes: 'Professor of Internal Medicine',
        latitude: 33.8845,
        longitude: 35.5180,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_129',
        doctorCode: '129',
        nameEn: 'Dr. Youssef Fadel',
        nameAr: 'د. يوسف فاضل',
        gender: 'Male',
        specialtyEn: 'Vascular Surgery',
        specialtyAr: 'جراحة الأوعية الدموية',
        subspecialty: 'Endovascular Surgery',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'Clementeau Medical Center',
        cityArea: 'Beirut',
        address: 'Clemenceau Street',
        area: 'Hamra',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 372888',
        whatsapp: '+961 70 550033',
        whatsappVerified: true,
        email: 'yfadel@cmc.com.lb',
        notes: 'Vascular Surgeon',
        latitude: 33.8981,
        longitude: 35.4912,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
      Doctor(
        id: 'doc_130',
        doctorCode: '130',
        nameEn: 'Dr. Hoda Sleiman',
        nameAr: 'د. هدى سليمان',
        gender: 'Female',
        specialtyEn: 'Infectious Diseases',
        specialtyAr: 'الأمراض المعدية',
        subspecialty: 'Infectious Diseases & Immunology',
        diseases: [],
        hospitalClinic: 'Hospital',
        clinicName: '',
        hospitalName: 'AUBMC',
        cityArea: 'Beirut',
        address: 'Maamari Street',
        area: 'Hamra',
        city: 'Beirut',
        governorate: 'Beirut',
        phone: '+961 1 350000',
        whatsapp: '+961 3 226688',
        whatsappVerified: true,
        email: 'hsleiman@aubmc.edu.lb',
        notes: 'Infectious Diseases Specialist',
        latitude: 33.8990,
        longitude: 35.4812,
        sourceName: 'Lebanese Order of Physicians',
        sourceUrl: 'https://lopbeirut.org',
        lastVerifiedAt: null,
        isVerified: true,
        isActive: true,
      ),
    ];
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

class _IndexedDoctor {
  final Doctor doctor;
  final String normalizedSearchText;
  final String normalizedSpecialtyEn;
  final String normalizedSpecialtyAr;
  final String normalizedGender;

  _IndexedDoctor(this.doctor)
      : normalizedSearchText = '${doctor.doctorCode} ${doctor.nameEn} ${doctor.nameAr} ${doctor.specialtyEn} ${doctor.specialtyAr} ${doctor.subspecialty} ${doctor.hospitalName} ${doctor.clinicName} ${doctor.hospitalClinic} ${doctor.cityArea} ${doctor.address} ${doctor.area} ${doctor.city} ${doctor.governorate} ${doctor.phone} ${doctor.email}'
            .toLowerCase(),
        normalizedSpecialtyEn = doctor.specialtyEn.toLowerCase(),
        normalizedSpecialtyAr = doctor.specialtyAr,
        normalizedGender = doctor.gender.toLowerCase();
}
