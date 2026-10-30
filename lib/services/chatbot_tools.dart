import 'package:geolocator/geolocator.dart';

import '../l10n/app_text.dart';
import '../models/medicine_price.dart';
import '../models/medicine_reminder.dart';
import '../utils/medicine_equivalence.dart';
import 'doctors_service.dart';
import 'gemini_client.dart';
import 'health_profile_service.dart';
import 'medication_safety_service.dart';
import 'medicine_info_service.dart';
import 'moph_medicine_service.dart';
import 'nearby_healthcare_service.dart';
import 'prescription_history_service.dart';
import 'reminder_service.dart';

/// Functions the chat model can call to answer from the app's own data:
/// the MOPH list, the user's health data on this device, the doctors list
/// and nearby pharmacies. Each returns a small JSON-able map.
class ChatbotTools {
  ChatbotTools({this.languageCode = 'en'});

  final String languageCode;

  static const List<GeminiTool> declarations = <GeminiTool>[
    GeminiTool(
      name: 'search_medicines',
      description: 'Search the official MOPH Lebanon price list by brand, generic name, ingredient or MOPH code. '
          'Returns products with medicine_id, strength, form, pack and official price in LBP.',
      parameters: <String, dynamic>{
        'type': 'OBJECT',
        'properties': <String, dynamic>{
          'query': <String, dynamic>{'type': 'STRING', 'description': 'Brand or ingredient, optionally with strength, e.g. "Augmentin 1g".'},
          'limit': <String, dynamic>{'type': 'INTEGER', 'description': 'Maximum results, 1 to 10. Default 6.'},
        },
        'required': <String>['query'],
      },
    ),
    GeminiTool(
      name: 'get_medicine_details',
      description: 'Full MOPH record of one product: ingredients, ATC class, manufacturer, agent, country, pack, '
          'official price, price per unit and the cheapest equivalent product.',
      parameters: <String, dynamic>{
        'type': 'OBJECT',
        'properties': <String, dynamic>{
          'medicine_id': <String, dynamic>{'type': 'STRING', 'description': 'MOPH code from search_medicines.'},
        },
        'required': <String>['medicine_id'],
      },
    ),
    GeminiTool(
      name: 'find_alternatives',
      description: 'Other MOPH products with the same active ingredients. exact_only=true keeps only the same strength '
          'and dosage form, cheapest first, with the saving in percent.',
      parameters: <String, dynamic>{
        'type': 'OBJECT',
        'properties': <String, dynamic>{
          'medicine_id': <String, dynamic>{'type': 'STRING'},
          'exact_only': <String, dynamic>{'type': 'BOOLEAN', 'description': 'Default true.'},
        },
        'required': <String>['medicine_id'],
      },
    ),
    GeminiTool(
      name: 'check_safety',
      description: "Checks MOPH products against each other and against the user's allergy list: allergies, "
          'related-class allergies, the same ingredient twice and two medicines from one class.',
      parameters: <String, dynamic>{
        'type': 'OBJECT',
        'properties': <String, dynamic>{
          'medicine_ids': <String, dynamic>{
            'type': 'ARRAY',
            'items': <String, dynamic>{'type': 'STRING'},
            'description': 'MOPH codes of the products to check.',
          },
        },
        'required': <String>['medicine_ids'],
      },
    ),
    GeminiTool(
      name: 'get_my_health',
      description: "Data saved on this device for the selected person (the user or a family member): allergies, "
          'health conditions (pregnant, breastfeeding, child, kidney, liver), medicine reminders and the most recent '
          'scanned prescriptions with their medicines.',
    ),
    GeminiTool(
      name: 'get_patient_information',
      description: 'Uses, how to take, side effects, warnings, interactions, pregnancy and storage for one MOPH product. '
          'Taken from the matching U.S. FDA label when one exists, otherwise AI-written. Includes its origin.',
      parameters: <String, dynamic>{
        'type': 'OBJECT',
        'properties': <String, dynamic>{
          'medicine_id': <String, dynamic>{'type': 'STRING'},
        },
        'required': <String>['medicine_id'],
      },
    ),
    GeminiTool(
      name: 'find_doctors',
      description: 'Search the Lebanese Order of Physicians list by doctor name, specialty, hospital or area. '
          'No phone numbers are available.',
      parameters: <String, dynamic>{
        'type': 'OBJECT',
        'properties': <String, dynamic>{
          'query': <String, dynamic>{'type': 'STRING', 'description': 'Name, specialty (e.g. "Cardiology"), hospital or area.'},
          'limit': <String, dynamic>{'type': 'INTEGER', 'description': '1 to 10. Default 6.'},
        },
        'required': <String>['query'],
      },
    ),
    GeminiTool(
      name: 'nearby_pharmacies',
      description: "Pharmacies near the user's current location (or central Beirut when location is off), "
          'with address, phone, open status and a Google Maps link.',
    ),
    GeminiTool(
      name: 'dataset_info',
      description: 'Date of the MOPH price list in use, number of products and whether prices may be out of date.',
    ),
  ];

  /// Display names of the data sources behind the tools used in one answer.
  static List<String> sourcesFor(Iterable<String> toolsUsed, {required bool isArabic}) {
    final moph = MophMedicineService();
    final sources = <String>{};
    for (final tool in toolsUsed) {
      switch (tool) {
        case 'search_medicines':
        case 'get_medicine_details':
        case 'find_alternatives':
        case 'dataset_info':
          sources.add(appText(isArabic).mophPriceList2(moph.publishedDate));
        case 'check_safety':
          sources.add(appText(isArabic).pharmalensSafetyCheck);
        case 'get_my_health':
          sources.add(appText(isArabic).yourDataOnThisDevice);
        case 'get_patient_information':
          sources.add(appText(isArabic).fdaLabelAiSummary);
        case 'find_doctors':
          sources.add(appText(isArabic).lebaneseOrderOfPhysicians);
        case 'nearby_pharmacies':
          sources.add('Google Places');
      }
    }
    return sources.toList();
  }

  Future<Map<String, dynamic>> run(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'search_medicines':
        return _search('${args['query'] ?? ''}', _limit(args['limit'], 6));
      case 'get_medicine_details':
        return _details('${args['medicine_id'] ?? ''}');
      case 'find_alternatives':
        return _alternatives('${args['medicine_id'] ?? ''}', args['exact_only'] != false);
      case 'check_safety':
        final ids = args['medicine_ids'] is List ? (args['medicine_ids'] as List).map((e) => '$e').toList() : <String>[];
        return _safety(ids);
      case 'get_my_health':
        return _myHealth();
      case 'get_patient_information':
        return _patientInfo('${args['medicine_id'] ?? ''}');
      case 'find_doctors':
        return _doctors('${args['query'] ?? ''}', _limit(args['limit'], 6));
      case 'nearby_pharmacies':
        return _pharmacies();
      case 'dataset_info':
        return _datasetInfo();
    }
    return <String, dynamic>{'error': 'Unknown tool $name.'};
  }

  int _limit(Object? value, int fallback) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return (parsed ?? fallback).clamp(1, 10);
  }

  Map<String, dynamic> _product(MedicinePrice m) => <String, dynamic>{
        'medicine_id': m.medicineId,
        'brand': m.brandName,
        'ingredients': m.activeIngredients,
        if ((m.strength ?? '').isNotEmpty) 'strength': m.strength,
        if ((m.dosageForm ?? '').isNotEmpty) 'form': m.dosageForm,
        if ((m.packSize ?? '').isNotEmpty) 'pack': m.packSize,
        'price_lbp': m.priceLbp == null ? 'not listed' : m.formattedPriceLbp,
      };

  Future<Map<String, dynamic>> _search(String query, int limit) async {
    if (query.trim().isEmpty) return <String, dynamic>{'error': 'Empty query.'};
    final results = await MophMedicineService().searchMedicines(query, limit: limit);
    return <String, dynamic>{
      'query': query,
      'count': results.length,
      'results': results.map(_product).toList(),
      if (results.isEmpty) 'note': 'Not found in the MOPH list. It may be spelled differently or not registered in Lebanon.',
    };
  }

  MedicinePrice? _find(String id) => MophMedicineService().findById(id.trim());

  Future<Map<String, dynamic>> _details(String id) async {
    final medicine = _find(id);
    if (medicine == null) return <String, dynamic>{'error': 'No MOPH product with code $id.'};

    final cheaper = await MophMedicineService().findCheaperEquivalent(medicine);
    final perUnit = MedicineEquivalence.unitPrice(medicine);
    final unit = MedicineEquivalence.packQuantity(medicine.packSize)?.$2;

    return <String, dynamic>{
      ..._product(medicine),
      if ((medicine.atcCode ?? '').isNotEmpty) 'atc_code': medicine.atcCode,
      if ((medicine.manufacturer ?? '').isNotEmpty) 'manufacturer': medicine.manufacturer,
      if (perUnit != null) 'price_per_${unit == 'unit' ? 'tablet_or_unit' : unit}_lbp': perUnit.round(),
      if (cheaper != null)
        'cheapest_equivalent': <String, dynamic>{
          ..._product(cheaper),
          'saving_percent': MedicineEquivalence.savingPercent(medicine, cheaper),
        },
      'list_date': MophMedicineService().publishedDate,
    };
  }

  Future<Map<String, dynamic>> _alternatives(String id, bool exactOnly) async {
    final medicine = _find(id);
    if (medicine == null) return <String, dynamic>{'error': 'No MOPH product with code $id.'};

    final service = MophMedicineService();
    final list = exactOnly
        ? await service.findExactAlternatives(medicine, limit: 8)
        : await service.findAlternatives(medicine, limit: 10);

    return <String, dynamic>{
      'for': _product(medicine),
      'exact_only': exactOnly,
      'count': list.length,
      'alternatives': <Map<String, dynamic>>[
        for (final alternative in list)
          <String, dynamic>{
            ..._product(alternative),
            'same_strength_and_form': MedicineEquivalence.isEquivalent(medicine, alternative),
            if (MedicineEquivalence.savingPercent(medicine, alternative) case final saving?) 'saving_percent': saving,
          },
      ],
      'note': 'Comparable products, not automatically interchangeable: a switch must be confirmed by a pharmacist.',
    };
  }

  Future<Map<String, dynamic>> _safety(List<String> ids) async {
    final products = ids.map(_find).whereType<MedicinePrice>().toList();
    final allergies = HealthProfileService().allergies;
    final alerts = const MedicationSafetyService().check(
      products,
      allergies: allergies,
      catalog: MophMedicineService().catalog,
    );
    final isArabic = languageCode == 'ar';

    return <String, dynamic>{
      'checked': products.map((p) => p.brandName).toList(),
      if (products.length < ids.length) 'not_found': ids.where((id) => _find(id) == null).toList(),
      'allergies_on_file': allergies,
      'alerts': <Map<String, dynamic>>[
        for (final alert in alerts)
          <String, dynamic>{
            'type': alert.type.name,
            'title': alert.title(isArabic: isArabic),
            'message': alert.message(isArabic: isArabic),
          },
      ],
      'note': 'Not an interaction checker: no alerts does not prove a combination is safe.',
    };
  }

  Future<Map<String, dynamic>> _myHealth() async {
    final profile = HealthProfileService();
    final history = PrescriptionHistoryService();
    final reminders = ReminderService();
    await Future.wait<void>(<Future<void>>[profile.load(), history.load(), reminders.load()]);

    final person = profile.active;
    return <String, dynamic>{
      'person': person.isOwner ? 'the user' : person.name,
      if (profile.hasFamily) 'family_members': profile.profiles.where((p) => !p.isOwner).map((p) => p.name).toList(),
      'allergies': profile.allergies,
      'conditions': profile.conditions.map((c) => c.name).toList(),
      'reminders': <Map<String, dynamic>>[
        for (final reminder in reminders.reminders.where((r) => r.profileId == person.id))
          <String, dynamic>{
            'medicine': reminder.medicineName,
            if (reminder.medicineId.isNotEmpty) 'medicine_id': reminder.medicineId,
            'times': reminder.times.map(MedicineReminder.formatTime).toList(),
            if (reminder.doseNote.isNotEmpty) 'note': reminder.doseNote,
            if (reminder.endDate != null) 'until': reminder.endDate!.toIso8601String().substring(0, 10),
            'active': reminder.enabled && !reminder.isExpired,
          },
      ],
      'recent_prescriptions': <Map<String, dynamic>>[
        for (final record in history.records.where((r) => r.profileId == person.id).take(5))
          <String, dynamic>{
            'date': record.createdAt.toIso8601String().substring(0, 10),
            if (record.doctorName.isNotEmpty) 'doctor': record.doctorName,
            'medicines': <Map<String, dynamic>>[
              for (final entry in record.medicines)
                <String, dynamic>{
                  'name': entry.displayName,
                  if (entry.medicineId.isNotEmpty) 'medicine_id': entry.medicineId,
                  if (entry.strength.isNotEmpty) 'strength': entry.strength,
                  if (entry.instructions.isNotEmpty) 'directions': entry.instructions,
                  'verified': entry.verified,
                },
            ],
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _patientInfo(String id) async {
    final medicine = _find(id);
    if (medicine == null) return <String, dynamic>{'error': 'No MOPH product with code $id.'};

    final info = await MedicineInfoService().load(medicine);
    if (info == null) return <String, dynamic>{'error': 'No patient information is available for this product.'};

    final k = info.knowledge;
    final ar = languageCode == 'ar';
    String pick(String en, String arText) => ar && arText.isNotEmpty ? arText : en;
    List<String> pickList(List<String> en, List<String> arList) => ar && arList.isNotEmpty ? arList : en;

    return <String, dynamic>{
      'product': medicine.brandName,
      'origin': switch (info.origin) {
        MedicineInfoOrigin.fdaLabelSummary => 'AI summary of the U.S. FDA label for the same ingredients',
        MedicineInfoOrigin.fdaLabel => 'U.S. FDA label text',
        MedicineInfoOrigin.aiGenerated => 'AI-written from general knowledge (no official label matched)',
      },
      'uses': pick(k.usesEn, k.usesAr),
      'how_to_take': pick(k.howToTakeEn, k.howToTakeAr),
      'food': pick(k.foodInstructionsEn, k.foodInstructionsAr),
      'common_side_effects': pickList(k.commonSideEffectsEn, k.commonSideEffectsAr),
      'serious_warnings': pickList(k.seriousWarningsEn, k.seriousWarningsAr),
      'contraindications': pickList(k.contraindicationsEn, k.contraindicationsAr),
      'interactions': pickList(k.interactionsEn, k.interactionsAr),
      'pregnancy': pick(k.pregnancyWarningEn, k.pregnancyWarningAr),
      'storage': pick(k.storageEn, k.storageAr),
    };
  }

  Future<Map<String, dynamic>> _doctors(String query, int limit) async {
    final doctors = await DoctorsService().searchDoctors(query: query, limit: limit);
    final ar = languageCode == 'ar';
    return <String, dynamic>{
      'query': query,
      'count': doctors.length,
      'doctors': <Map<String, dynamic>>[
        for (final doctor in doctors)
          <String, dynamic>{
            'name': ar && doctor.nameAr.isNotEmpty ? doctor.nameAr : doctor.nameEn,
            'specialty': ar && doctor.specialtyAr.isNotEmpty ? doctor.specialtyAr : doctor.specialtyEn,
            if (doctor.hospitalName.isNotEmpty) 'hospital': doctor.hospitalName,
            if (doctor.city.isNotEmpty) 'city': doctor.city,
          },
      ],
      'note': 'From the Lebanese Order of Physicians list. Tell the user they can open the Doctors tab for more.',
    };
  }

  Future<Map<String, dynamic>> _pharmacies() async {
    Position? position;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 6)),
        );
      }
    } catch (_) {}

    try {
      final places = await NearbyHealthcareService().loadNearby(
        latitude: position?.latitude ?? 33.8938,
        longitude: position?.longitude ?? 35.5018,
        languageCode: languageCode,
        maxResults: 6,
      );
      return <String, dynamic>{
        'location': position == null ? 'unavailable (showing central Beirut; ask the user to enable location)' : 'device location',
        'pharmacies': <Map<String, dynamic>>[
          for (final place in places.where((p) => p.isPharmacy))
            <String, dynamic>{
              'name': place.name,
              if (place.address.isNotEmpty) 'address': place.address,
              if (place.phone.isNotEmpty) 'phone': place.phone,
              'open_now': place.openNow == null ? 'unknown' : (place.openNow! ? 'yes' : 'no'),
              if (place.googleMapsUri.isNotEmpty) 'maps_link': place.googleMapsUri,
            },
        ],
      };
    } catch (error) {
      return <String, dynamic>{'error': 'Nearby search is unavailable right now. Suggest the Pharmacies tab.'};
    }
  }

  Map<String, dynamic> _datasetInfo() {
    final moph = MophMedicineService();
    return <String, dynamic>{
      'list_published': moph.publishedDate,
      'list_date': moph.lastUpdatedDate,
      'products': moph.totalMedicineCount,
      'age_days': moph.dataAgeInDays,
      'may_be_outdated': moph.isDataStale,
      'source': MophMedicineService.mophPublicUrl,
    };
  }
}
