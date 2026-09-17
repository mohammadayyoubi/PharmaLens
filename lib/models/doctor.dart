class Doctor {
  const Doctor({
    required this.id,
    required this.doctorCode,
    required this.nameEn,
    required this.nameAr,
    required this.gender,
    required this.specialtyEn,
    required this.specialtyAr,
    required this.subspecialty,
    required this.diseases,
    required this.hospitalClinic,
    required this.clinicName,
    required this.hospitalName,
    required this.cityArea,
    required this.address,
    required this.area,
    required this.city,
    required this.governorate,
    required this.phone,
    required this.whatsapp,
    required this.whatsappVerified,
    required this.email,
    required this.notes,
    required this.latitude,
    required this.longitude,
    required this.sourceName,
    required this.sourceUrl,
    required this.lastVerifiedAt,
    required this.isVerified,
    required this.isActive,
  });

  final String id;
  final String doctorCode;

  final String nameEn;
  final String nameAr;

  final String gender;

  final String specialtyEn;
  final String specialtyAr;
  final String subspecialty;

  final List<String> diseases;

  final String hospitalClinic;
  final String clinicName;
  final String hospitalName;

  final String cityArea;
  final String address;
  final String area;
  final String city;
  final String governorate;

  final String phone;
  final String whatsapp;
  final bool whatsappVerified;

  final String email;
  final String notes;

  final double? latitude;
  final double? longitude;

  final String sourceName;
  final String sourceUrl;

  final DateTime? lastVerifiedAt;

  final bool isVerified;
  final bool isActive;

  factory Doctor.fromMap(
      Map<String, dynamic> map,
      ) {
    final legacyFullName = _stringValue(
      map['full_name'],
    );

    final nameEn = _firstEnglishValue(
      <dynamic>[
        map['full_name_en'],
        map['name_en'],
        map['doctor_name_en'],
        legacyFullName,
      ],
    );

    final nameAr = _firstArabicValue(
      <dynamic>[
        map['full_name_ar'],
        map['name_ar'],
        map['doctor_name_ar'],
        legacyFullName,
      ],
    );

    final legacySpecialty = _firstNonEmpty(
      <dynamic>[
        map['main_specialty'],
        map['specialty'],
      ],
    );

    final specialtyEn = _firstEnglishValue(
      <dynamic>[
        map['specialty_en'],
        map['specialty_english'],
        legacySpecialty,
      ],
    );

    final specialtyAr = _firstArabicValue(
      <dynamic>[
        map['specialty_ar'],
        map['specialty_arabic'],
      ],
    );

    final subspecialty = _firstNonEmpty(
      <dynamic>[
        map['subspecialty'],
        map['specialty_details'],
      ],
    );

    final clinicName = _stringValue(
      map['clinic_name'],
    );

    final hospitalName = _stringValue(
      map['hospital_name'],
    );

    final hospitalClinic = _firstNonEmpty(
      <dynamic>[
        map['hospital_clinic'],
        map['facility_name'],
        hospitalName,
        clinicName,
      ],
    );

    final area = _stringValue(
      map['area'],
    );

    final city = _stringValue(
      map['city'],
    );

    final governorate = _stringValue(
      map['governorate'],
    );

    final cityArea = _firstNonEmpty(
      <dynamic>[
        map['city_area'],
        area,
        city,
        governorate,
      ],
    );

    return Doctor(
      id: _stringValue(
        map['id'],
      ),
      doctorCode: _firstNonEmpty(
        <dynamic>[
          map['doctor_code'],
          map['external_doctor_id'],
          map['external_id'],
          map['order_number'],
        ],
      ),
      nameEn: nameEn,
      nameAr: nameAr,
      gender: _normalizeGender(
        _stringValue(
          map['gender'],
        ),
      ),
      specialtyEn: specialtyEn,
      specialtyAr: specialtyAr,
      subspecialty: subspecialty,
      diseases: _stringList(
        map['diseases'],
      ),
      hospitalClinic: hospitalClinic,
      clinicName: clinicName,
      hospitalName: hospitalName,
      cityArea: cityArea,
      address: _stringValue(
        map['address'],
      ),
      area: area,
      city: city,
      governorate: governorate,
      phone: _stringValue(
        map['phone'],
      ),
      whatsapp: _stringValue(
        map['whatsapp'],
      ),
      whatsappVerified: _whatsappVerifiedValue(
        map['whatsapp_verified'],
        map['whatsapp_verification_status'],
      ),
      email: _stringValue(
        map['email'],
      ),
      notes: _stringValue(
        map['notes'],
      ),
      latitude: _doubleValue(
        map['latitude'],
      ),
      longitude: _doubleValue(
        map['longitude'],
      ),
      sourceName: _stringValue(
        map['source_name'],
      ),
      sourceUrl: _stringValue(
        map['source_url'],
      ),
      lastVerifiedAt: _dateValue(
        map['last_verified_at'],
      ),
      isVerified: _boolValue(
        map['is_verified'],
      ),
      isActive: _boolValue(
        map['is_active'],
        fallback: true,
      ),
    );
  }

  // ============================================================
  // LANGUAGE-SAFE DISPLAY
  // ============================================================

  String localizedName({
    required bool isArabic,
  }) {
    if (isArabic) {
      if (_isGoodArabicValue(nameAr)) {
        return nameAr.trim();
      }

      if (_isGoodEnglishValue(nameEn)) {
        return nameEn.trim();
      }

      return 'طبيب';
    }

    if (_isGoodEnglishValue(nameEn)) {
      return nameEn.trim();
    }

    /*
     * Never intentionally place an Arabic doctor name
     * in the main English doctor-name field.
     *
     * Active PharmaLanse records should have nameEn.
     */
    return 'Doctor';
  }

  String localizedSpecialty({
    required bool isArabic,
  }) {
    if (isArabic) {
      if (_isGoodArabicValue(specialtyAr)) {
        return specialtyAr.trim();
      }

      if (_isGoodEnglishValue(specialtyEn)) {
        return specialtyEn.trim();
      }

      return '';
    }

    if (_isGoodEnglishValue(specialtyEn)) {
      return specialtyEn.trim();
    }

    return '';
  }

  /*
   * IMPORTANT:
   *
   * We intentionally return an empty secondary value.
   *
   * Previously the Doctors UI displayed:
   *
   * Dr. English Name
   * الاسم العربي
   *
   * even when the whole application was English.
   *
   * PharmaLanse now keeps each screen language-pure.
   */
  String secondaryName({
    required bool isArabic,
  }) {
    return '';
  }

  String secondarySpecialty({
    required bool isArabic,
  }) {
    return '';
  }

  // ============================================================
  // BACKWARD COMPATIBILITY
  // ============================================================

  String get fullName {
    if (_isGoodEnglishValue(nameEn)) {
      return nameEn.trim();
    }

    if (_isGoodArabicValue(nameAr)) {
      return nameAr.trim();
    }

    return '';
  }

  String get specialty {
    return specialtyEn.trim();
  }

  String get mainSpecialty {
    return specialtyEn.trim();
  }

  String get specialtyDetails {
    if (subspecialty.trim().isNotEmpty) {
      return subspecialty.trim();
    }

    return specialtyEn.trim();
  }

  String get displaySpecialty {
    final values = <String>[
      specialtyEn.trim(),
      subspecialty.trim(),
    ].where(
          (value) => value.isNotEmpty,
    ).toSet().toList();

    return values.join(
      ' • ',
    );
  }

  String get displayMainSpecialty {
    return specialtyEn.trim();
  }

  // ============================================================
  // FACILITY
  // ============================================================

  String get displayHospital {
    if (hospitalClinic.trim().isNotEmpty) {
      return hospitalClinic.trim();
    }

    if (hospitalName.trim().isNotEmpty) {
      return hospitalName.trim();
    }

    return clinicName.trim();
  }

  String get displayFacility {
    final values = <String>[
      hospitalClinic,
      clinicName,
      hospitalName,
    ]
        .map(
          (value) => value.trim(),
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .toSet()
        .toList();

    return values.join(
      ' • ',
    );
  }

  // ============================================================
  // LOCATION
  // ============================================================

  String get displayLocation {
    final values = <String>[
      cityArea,
      area,
      city,
      governorate,
    ]
        .map(
          (value) => value.trim(),
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .toSet()
        .toList();

    if (values.isEmpty) {
      return address.trim();
    }

    return values.join(
      ' • ',
    );
  }

  String get displayAddress {
    if (address.trim().isNotEmpty) {
      return address.trim();
    }

    return displayLocation;
  }

  // ============================================================
  // SOURCE
  // ============================================================

  String get displaySource {
    if (sourceName.trim().isNotEmpty) {
      return sourceName.trim();
    }

    if (sourceUrl.trim().isNotEmpty) {
      return 'Public source';
    }

    return 'PharmaLanse directory';
  }

  Uri? get sourceUri {
    final value = sourceUrl.trim();

    if (value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(
      value,
    );

    if (uri == null) {
      return null;
    }

    if (uri.scheme != 'https' &&
        uri.scheme != 'http') {
      return null;
    }

    return uri;
  }

  // ============================================================
  // GENDER
  // ============================================================

  bool get isFemale {
    return gender == 'Female';
  }

  bool get isMale {
    return gender == 'Male';
  }

  String localizedGender({
    required bool isArabic,
  }) {
    if (gender == 'Female') {
      return isArabic
          ? 'أنثى'
          : 'Female';
    }

    if (gender == 'Male') {
      return isArabic
          ? 'ذكر'
          : 'Male';
    }

    return isArabic
        ? 'غير محدد'
        : 'Not specified';
  }

  // ============================================================
  // CONTACT
  // ============================================================

  bool get hasPhone {
    return phone.trim().isNotEmpty;
  }

  bool get hasWhatsapp {
    return whatsapp.trim().isNotEmpty;
  }

  bool get hasEmail {
    return email.trim().isNotEmpty;
  }

  bool get hasNotes {
    return notes.trim().isNotEmpty;
  }

  bool get hasSourceUrl {
    return sourceUri != null;
  }

  bool get hasContactInformation {
    return hasPhone ||
        hasWhatsapp ||
        hasEmail;
  }

  String whatsappStatusLabel({
    required bool isArabic,
  }) {
    if (!hasWhatsapp) {
      return isArabic
          ? 'غير متوفر'
          : 'Not available';
    }

    if (whatsappVerified) {
      return isArabic
          ? 'WhatsApp موثّق'
          : 'WhatsApp verified';
    }

    return isArabic
        ? 'WhatsApp غير موثّق'
        : 'WhatsApp unverified';
  }

  // ============================================================
  // COORDINATES
  // ============================================================

  bool get hasCoordinates {
    return latitude != null &&
        longitude != null;
  }

  bool get hasHospitalOrClinic {
    return displayFacility.isNotEmpty;
  }

  bool get hasAddressOrCoordinates {
    return displayAddress.isNotEmpty ||
        hasCoordinates;
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String get initials {
    final value = _isGoodEnglishValue(nameEn)
        ? nameEn
        : nameAr;

    var cleaned = value.trim();

    cleaned = cleaned.replaceFirst(
      RegExp(
        r'^(?:dr\.?|doctor)\s*',
        caseSensitive: false,
      ),
      '',
    );

    cleaned = cleaned.replaceFirst(
      RegExp(
        r'^(?:الدكتور|الدكتورة|دكتور|دكتورة|د\.?)\s*',
      ),
      '',
    );

    final parts = cleaned
        .split(
      RegExp(r'\s+'),
    )
        .where(
          (value) => value.trim().isNotEmpty,
    )
        .toList();

    if (parts.isEmpty) {
      return 'DR';
    }

    if (parts.length == 1) {
      final runes = parts.first.runes.toList();

      if (runes.isEmpty) {
        return 'DR';
      }

      if (runes.length == 1) {
        return String.fromCharCode(
          runes.first,
        ).toUpperCase();
      }

      return '${String.fromCharCode(runes[0])}${String.fromCharCode(runes[1])}'
          .toUpperCase();
    }

    final first = String.fromCharCode(
      parts.first.runes.first,
    );

    final last = String.fromCharCode(
      parts.last.runes.first,
    );

    return '$first$last'.toUpperCase();
  }

  // ============================================================
  // LOCAL FILTER HELPERS
  // ============================================================

  bool matchesQuery(
      String query,
      ) {
    final normalizedQuery = _normalize(
      query,
    );

    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchable = <String>[
      doctorCode,
      nameEn,
      nameAr,
      specialtyEn,
      specialtyAr,
      subspecialty,
      ...diseases,
      hospitalClinic,
      clinicName,
      hospitalName,
      cityArea,
      address,
      area,
      city,
      governorate,
      phone,
      whatsapp,
      email,
      notes,
      sourceName,
    ]
        .map(
      _normalize,
    )
        .join(' ');

    return searchable.contains(
      normalizedQuery,
    );
  }

  bool matchesSpecialty(
      String value,
      ) {
    final query = _normalize(
      value,
    );

    if (query.isEmpty) {
      return true;
    }

    final specialtyText = <String>[
      specialtyEn,
      specialtyAr,
      subspecialty,
    ]
        .map(
      _normalize,
    )
        .join(' ');

    return specialtyText.contains(
      query,
    );
  }

  bool matchesGender(
      String value,
      ) {
    final selected =
    _normalizeGender(
      value,
    );

    if (selected.isEmpty) {
      return true;
    }

    return gender == selected;
  }

  bool matchesHospital(
      String value,
      ) {
    final query = _normalize(
      value,
    );

    if (query.isEmpty) {
      return true;
    }

    final facility = <String>[
      hospitalClinic,
      hospitalName,
      clinicName,
    ]
        .map(
      _normalize,
    )
        .join(' ');

    return facility.contains(
      query,
    );
  }

  // ============================================================
  // LANGUAGE DETECTION
  // ============================================================

  static bool _isGoodEnglishValue(
      String value,
      ) {
    final text = value.trim();

    if (text.isEmpty) {
      return false;
    }

    final arabicCount = RegExp(
      r'[\u0600-\u06FF]',
    ).allMatches(text).length;

    final latinCount = RegExp(
      r'[A-Za-z]',
    ).allMatches(text).length;

    return latinCount > 0 &&
        latinCount >= arabicCount;
  }

  static bool _isGoodArabicValue(
      String value,
      ) {
    final text = value.trim();

    if (text.isEmpty) {
      return false;
    }

    return RegExp(
      r'[\u0600-\u06FF]',
    ).hasMatch(text);
  }

  // ============================================================
  // PARSING
  // ============================================================

  static String _firstEnglishValue(
      List<dynamic> values,
      ) {
    for (final value in values) {
      final text = _stringValue(
        value,
      );

      if (_isGoodEnglishValue(
        text,
      )) {
        return text;
      }
    }

    return '';
  }

  static String _firstArabicValue(
      List<dynamic> values,
      ) {
    for (final value in values) {
      final text = _stringValue(
        value,
      );

      if (_isGoodArabicValue(
        text,
      )) {
        return text;
      }
    }

    return '';
  }

  static String _firstNonEmpty(
      List<dynamic> values,
      ) {
    for (final value in values) {
      final text = _stringValue(
        value,
      );

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  static String _stringValue(
      dynamic value,
      ) {
    if (value == null) {
      return '';
    }

    final text = value
        .toString()
        .trim();

    final normalized =
    text.toLowerCase();

    if (const <String>{
      '',
      'null',
      'none',
      'n/a',
      'na',
      '-',
      'unknown',
      'not available',
      'not specified',
    }.contains(normalized)) {
      return '';
    }

    return text;
  }

  static List<String> _stringList(
      dynamic value,
      ) {
    if (value == null) {
      return const <String>[];
    }

    final raw = <dynamic>[];

    if (value is List) {
      raw.addAll(
        value,
      );
    } else {
      var text = value
          .toString()
          .trim();

      if (text.isEmpty) {
        return const <String>[];
      }

      if (text.startsWith('{') &&
          text.endsWith('}')) {
        text = text.substring(
          1,
          text.length - 1,
        );

        raw.addAll(
          text.split(','),
        );
      } else {
        raw.addAll(
          text.split(
            RegExp(
              r'\r?\n|\||;',
            ),
          ),
        );
      }
    }

    final result = <String>[];

    final seen = <String>{};

    for (final item in raw) {
      final text = _stringValue(
        item,
      );

      if (text.isEmpty) {
        continue;
      }

      final key = _normalize(
        text,
      );

      if (key.isEmpty) {
        continue;
      }

      if (seen.add(key)) {
        result.add(text);
      }
    }

    return List<String>.unmodifiable(
      result,
    );
  }

  static double? _doubleValue(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().trim(),
    );
  }

  static DateTime? _dateValue(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    final text = value
        .toString()
        .trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(
      text,
    );
  }

  static bool _boolValue(
      dynamic value, {
        bool fallback = false,
      }) {
    if (value == null) {
      return fallback;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = value
        .toString()
        .trim()
        .toLowerCase();

    if (const <String>{
      'true',
      '1',
      'yes',
      'y',
      'verified',
      'active',
    }.contains(text)) {
      return true;
    }

    if (const <String>{
      'false',
      '0',
      'no',
      'n',
      'unverified',
      'inactive',
    }.contains(text)) {
      return false;
    }

    return fallback;
  }

  static bool _whatsappVerifiedValue(
      dynamic value,
      dynamic status,
      ) {
    if (value != null) {
      return _boolValue(
        value,
      );
    }

    return _stringValue(
      status,
    ).toLowerCase() ==
        'verified';
  }

  static String _normalizeGender(
      String value,
      ) {
    final normalized = _normalize(
      value,
    );

    if (const <String>{
      'female',
      'f',
      'woman',
      'انثى',
    }.contains(normalized)) {
      return 'Female';
    }

    if (const <String>{
      'male',
      'm',
      'man',
      'ذكر',
    }.contains(normalized)) {
      return 'Male';
    }

    return '';
  }

  static String _normalize(
      String value,
      ) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(
      RegExp(
        r'[\u064B-\u065F]',
      ),
      '',
    )
        .replaceAll(
      RegExp(
        r'[إأآا]',
      ),
      'ا',
    )
        .replaceAll(
      'ى',
      'ي',
    )
        .replaceAll(
      'ة',
      'ه',
    )
        .replaceAll(
      RegExp(
        r'[^a-z0-9\u0600-\u06FF]+',
      ),
      ' ',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }
}