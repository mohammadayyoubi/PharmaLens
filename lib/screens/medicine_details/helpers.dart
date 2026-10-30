// Text helpers for names, strengths, forms and routes.
part of '../medicine_details_screen.dart';

String _displayMedicineName(
    MedicinePrice medicine,
    VerifiedMedicineResult? result,
    ) {
  final fromResult =
      result?.displayName.trim() ?? '';

  if (_usable(fromResult)) {
    return fromResult;
  }

  final brand = medicine.brandName.trim();

  if (_usable(brand)) {
    return brand;
  }

  return 'Medicine';
}

String _identityLine(
    MedicinePrice medicine,
    VerifiedMedicineResult? result,
    MedicineKnowledge? knowledge,
    ) {
  return _uniqueUsefulValues(
    <String>[
      _genericName(
        medicine,
        knowledge,
      ),
      _strength(
        medicine,
        result,
        knowledge,
      ),
      _dosageForm(
        medicine,
        result,
        knowledge,
      ),
    ],
  ).join(' • ');
}

String _genericName(
    MedicinePrice medicine,
    MedicineKnowledge? knowledge,
    ) {
  return <String>[
    knowledge?.genericName ?? '',
    medicine.genericName ?? '',
    medicine.displayGenericName,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

String _composition(
    MedicinePrice medicine,
    MedicineKnowledge? knowledge,
    ) {
  final reviewedIngredients =
  _uniqueUsefulValues(
    knowledge?.activeIngredients ??
        const <String>[],
  );

  if (reviewedIngredients.isNotEmpty) {
    return reviewedIngredients.join(' + ');
  }

  final medicineIngredients =
  _uniqueUsefulValues(
    medicine.activeIngredients,
  );

  if (medicineIngredients.isNotEmpty) {
    return medicineIngredients.join(' + ');
  }

  return <String>[
    knowledge?.genericName ?? '',
    medicine.genericName ?? '',
    medicine.displayGenericName,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

String _strength(
    MedicinePrice medicine,
    VerifiedMedicineResult? result,
    MedicineKnowledge? knowledge,
    ) {
  return <String>[
    medicine.strength ?? '',
    knowledge?.strength ?? '',
    result?.displayStrength ?? '',
    medicine.displayStrength,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

String _dosageForm(
    MedicinePrice medicine,
    VerifiedMedicineResult? result,
    MedicineKnowledge? knowledge,
    ) {
  return <String>[
    medicine.dosageForm ?? '',
    knowledge?.dosageForm ?? '',
    result?.displayDosageForm ?? '',
    medicine.displayDosageForm,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

String _route(
    MedicinePrice medicine,
    MedicineKnowledge? knowledge, {
      required bool isArabic,
    }) {
  return <String>[
    knowledge?.localizedRoute(
      isArabic: isArabic,
    ) ??
        '',
    medicine.route ?? '',
    medicine.displayRoute,
  ].firstWhere(
    _usable,
    orElse: () => '',
  );
}

List<String> _uniqueUsefulValues(
    Iterable<String> values,
    ) {
  final seen = <String>{};
  final result = <String>[];

  for (final rawValue in values) {
    final value = rawValue.trim();

    if (!_usable(value)) {
      continue;
    }

    final normalized = value.toLowerCase();

    if (seen.contains(normalized)) {
      continue;
    }

    seen.add(normalized);
    result.add(value);
  }

  return result;
}

bool _usable(
    String value,
    ) {
  final normalized =
  value.trim().toLowerCase();

  return normalized.isNotEmpty &&
      !const <String>{
        '-',
        '—',
        '--',
        'null',
        'none',
        'unknown',
        'n/a',
        'na',
        'not available',
        'price unavailable',
        'route unavailable',
        'source unavailable',
        'pack unavailable',
        'manufacturer unavailable',
        'generic unavailable',
        'strength unavailable',
        'form unavailable',
      }.contains(normalized);
}

TextDirection _textDirectionFor(
    String value,
    ) {
  final arabic = RegExp(
    r'[\u0600-\u06FF]',
  ).allMatches(value).length;

  final latin = RegExp(
    r'[A-Za-z]',
  ).allMatches(value).length;

  return arabic > latin
      ? TextDirection.rtl
      : TextDirection.ltr;
}

IconData _medicineIcon(
    String? dosageForm,
    ) {
  final form =
      dosageForm?.trim().toLowerCase() ?? '';

  if (form.contains('inject') ||
      form.contains('ampoule') ||
      form.contains('ampule') ||
      form.contains('vial')) {
    return Icons.vaccines_outlined;
  }

  if (form.contains('syrup') ||
      form.contains('solution') ||
      form.contains('suspension') ||
      form.contains('elixir')) {
    return Icons.local_drink_outlined;
  }

  if (form.contains('drop')) {
    return Icons.water_drop_outlined;
  }

  if (form.contains('cream') ||
      form.contains('ointment') ||
      form.contains('gel') ||
      form.contains('lotion')) {
    return Icons.sanitizer_outlined;
  }

  if (form.contains('spray') ||
      form.contains('inhal') ||
      form.contains('nebul')) {
    return Icons.air_rounded;
  }

  if (form.contains('suppository')) {
    return Icons.medication_liquid_outlined;
  }

  return Icons.medication_outlined;
}
