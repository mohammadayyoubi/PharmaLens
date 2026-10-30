import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine_knowledge.dart';
import '../models/medicine_price.dart';
import '../utils/medicine_equivalence.dart';
import 'gemini_client.dart';

/// Where the patient information on a medicine page came from.
enum MedicineInfoOrigin {
  /// The U.S. FDA label for the same active ingredients, shortened and
  /// translated by AI.
  fdaLabelSummary,

  /// The U.S. FDA label text itself (no AI key configured).
  fdaLabel,

  /// Written by AI from general knowledge; no official label matched.
  aiGenerated,
}

class MedicineInfo {
  const MedicineInfo({
    required this.knowledge,
    required this.origin,
    this.sourceTitle = '',
    this.sourceUrl = '',
  });

  final MedicineKnowledge knowledge;
  final MedicineInfoOrigin origin;

  /// Name of the FDA-labelled product the text was taken from.
  final String sourceTitle;
  final String sourceUrl;

  bool get isAiWritten => origin != MedicineInfoOrigin.fdaLabel;
}

class MedicineInfoUnavailableException implements Exception {
  const MedicineInfoUnavailableException();
}

/// Patient information (uses, how to take, side effects, warnings) for a
/// MOPH product, which the MOPH list itself does not include.
///
/// 1. The openFDA drug label with the same active ingredients and route is
///    the preferred source.
/// 2. Gemini rewrites it as short patient text in English and Arabic, or
///    writes it from general knowledge when no label matches. The UI labels
///    both as AI-written.
///
/// Results are cached per ingredients, dosage-form family and strength, and
/// shared by every brand with the same three.
class MedicineInfoService {
  MedicineInfoService._internal();

  static final MedicineInfoService _instance = MedicineInfoService._internal();

  factory MedicineInfoService() => _instance;

  static const String _cachePrefix = 'medicine_info_v1:';
  static const Duration _cacheLifetime = Duration(days: 120);
  static const int _sectionLimit = 2400;

  final Map<String, MedicineInfo> _memory = <String, MedicineInfo>{};
  final Map<String, Future<MedicineInfo?>> _inFlight = <String, Future<MedicineInfo?>>{};

  /// INN names used in Lebanon mapped to the US names used on FDA labels.
  static const Map<String, String> _usNames = <String, String>{
    'paracetamol': 'acetaminophen',
    'clavulanic acid': 'clavulanate',
    'salbutamol': 'albuterol',
    'adrenaline': 'epinephrine',
    'noradrenaline': 'norepinephrine',
    'glibenclamide': 'glyburide',
    'frusemide': 'furosemide',
    'lignocaine': 'lidocaine',
    'ciclosporin': 'cyclosporine',
    'colecalciferol': 'cholecalciferol',
    'amoxycillin': 'amoxicillin',
    'cefalexin': 'cephalexin',
    'cefalotin': 'cephalothin',
    'mesalazine': 'mesalamine',
    'thiamazole': 'methimazole',
    'pethidine': 'meperidine',
    'dicycloverine': 'dicyclomine',
    'beclometasone': 'beclomethasone',
    'aciclovir': 'acyclovir',
    'valaciclovir': 'valacyclovir',
    'rifampicin': 'rifampin',
    'isoprenaline': 'isoproterenol',
    'chlorphenamine': 'chlorpheniramine',
    'phenobarbitone': 'phenobarbital',
    'oestradiol': 'estradiol',
    'levothyroxine': 'levothyroxine',
    'valproic acid': 'valproic acid',
    'sodium valproate': 'valproate',
    'glyceryl trinitrate': 'nitroglycerin',
    'hydroxycarbamide': 'hydroxyurea',
    'tamsulosin': 'tamsulosin',
  };

  static String cacheKeyFor(MedicinePrice medicine) {
    final composition = MedicineEquivalence.compositionKey(medicine);
    final identity = composition.isNotEmpty ? composition : (medicine.genericName ?? medicine.brandName).trim().toLowerCase();
    // Strength is part of the key because the usual dose depends on it.
    return '$identity|${MedicineEquivalence.formFamily(medicine.dosageForm)}|${MedicineEquivalence.strengthKey(medicine.strength)}';
  }

  /// Returns null when no information exists for this medicine, and throws
  /// [MedicineInfoUnavailableException] when it could not be loaded (for
  /// example offline), so the UI can offer a retry.
  Future<MedicineInfo?> load(MedicinePrice medicine, {bool forceRefresh = false}) {
    final key = cacheKeyFor(medicine);
    if (!forceRefresh && _memory.containsKey(key)) {
      return Future<MedicineInfo?>.value(_rebind(_memory[key]!, medicine));
    }
    // A block body: Map.remove returns the removed future, and whenComplete
    // would wait for it, i.e. for itself.
    return _inFlight[key] ??= _load(medicine, key, forceRefresh).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<MedicineInfo?> _load(MedicinePrice medicine, String key, bool forceRefresh) async {
    if (!forceRefresh) {
      final cached = await _readCache(key, medicine);
      // A raw label saved before an AI key was added gets the readable
      // summary on the next load.
      if (cached != null && !(cached.origin == MedicineInfoOrigin.fdaLabel && GeminiClient.isConfigured)) {
        _memory[key] = cached;
        return cached;
      }
    }

    var failed = false;

    _FdaLabel? label;
    try {
      label = await _findFdaLabel(medicine);
    } catch (error) {
      failed = true;
      debugPrint('MedicineInfoService: FDA lookup failed: $error');
    }

    MedicineInfo? info;
    if (GeminiClient.isConfigured) {
      try {
        info = await _writeWithAi(medicine, label);
      } catch (error) {
        failed = true;
        debugPrint('MedicineInfoService: AI summary failed: $error');
      }
    }
    if (info == null && label != null) {
      info = _fromRawLabel(medicine, label);
    }

    if (info == null) {
      if (failed) throw const MedicineInfoUnavailableException();
      return null;
    }

    _memory[key] = info;
    unawaited(_writeCache(key, info));
    return info;
  }

  // ---------------------------------------------------------------------------
  // openFDA
  // ---------------------------------------------------------------------------

  List<String> _labelIngredients(MedicinePrice medicine) {
    return medicine.activeIngredients
        .map(MedicineEquivalence.ingredientKey)
        .where((key) => key.isNotEmpty)
        .map((key) => _usNames[key] ?? key)
        .toSet()
        .toList();
  }

  Future<_FdaLabel?> _findFdaLabel(MedicinePrice medicine) async {
    final ingredients = _labelIngredients(medicine);
    if (ingredients.isEmpty) return null;

    final base = ingredients.map((name) => 'openfda.substance_name:"${name.toUpperCase()}"').join(' AND ');
    final terms = _formTerms(medicine);
    final queries = <String>[
      // Same dosage form first, so a tablet does not get a syrup's label.
      if (terms.isNotEmpty) '$base AND (dosage_forms_and_strengths:($terms) OR package_label_principal_display_panel:($terms))',
      base,
    ];

    for (final search in queries) {
      final uri = Uri.https('api.fda.gov', '/drug/label.json', <String, String>{'search': search, 'limit': '5'});
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) continue; // openFDA: no matches
      if (response.statusCode != 200) {
        throw Exception('openFDA returned ${response.statusCode}');
      }

      final label = await compute(_pickFdaLabel, <String, Object>{
        'body': response.body,
        'ingredients': ingredients.length,
        'routes': _expectedRoutes(medicine),
        // "500mg" -> "500", "1g" -> "1000": matched against label strengths.
        'strengths': RegExp(r'\d+(\.\d+)?').allMatches(MedicineEquivalence.strengthKey(medicine.strength)).map((m) => m.group(0)!).toList(),
        'modifiedRelease': MedicineEquivalence.formFamily(medicine.dosageForm).endsWith('-mr'),
        'forChildren': RegExp(r'baby|kid|child|infant|pediatric|paediatric|junior|enfant', caseSensitive: false).hasMatch(medicine.brandName),
      });
      if (label != null) return label;
    }
    return null;
  }

  /// Words FDA labels use for the product's dosage form.
  static String _formTerms(MedicinePrice medicine) {
    const terms = <String, String>{
      'tablet': 'tablet tablets',
      'capsule': 'capsule capsules',
      'oral-liquid': 'suspension syrup solution',
      'powder-oral': 'granules sachet powder',
      'injection': 'injection',
      'cream': 'cream',
      'ointment': 'ointment',
      'gel': 'gel',
      'eye': 'ophthalmic',
      'ear': 'otic',
      'nasal': 'nasal',
      'inhalation': 'inhalation inhaler aerosol',
      'suppository': 'suppository suppositories',
      'rectal': 'rectal',
      'vaginal': 'vaginal',
      'patch': 'patch transdermal',
    };
    return terms[MedicineEquivalence.formFamily(medicine.dosageForm).replaceAll('-mr', '')] ?? '';
  }

  /// openFDA route names that fit the product's dosage form.
  static List<String> _expectedRoutes(MedicinePrice medicine) {
    final family = MedicineEquivalence.formFamily(medicine.dosageForm).replaceAll('-mr', '');
    switch (family) {
      case 'tablet':
      case 'capsule':
      case 'oral-liquid':
      case 'powder-oral':
        return const <String>['ORAL'];
      case 'injection':
        return const <String>['INTRAVENOUS', 'INTRAMUSCULAR', 'SUBCUTANEOUS'];
      case 'cream':
      case 'ointment':
      case 'gel':
        return const <String>['TOPICAL', 'CUTANEOUS'];
      case 'eye':
        return const <String>['OPHTHALMIC'];
      case 'ear':
        return const <String>['AURICULAR (OTIC)'];
      case 'nasal':
        return const <String>['NASAL'];
      case 'inhalation':
        return const <String>['RESPIRATORY (INHALATION)'];
      case 'suppository':
        return const <String>['RECTAL', 'VAGINAL'];
      case 'rectal':
        return const <String>['RECTAL'];
      case 'vaginal':
        return const <String>['VAGINAL'];
      case 'patch':
        return const <String>['TRANSDERMAL'];
      default:
        return const <String>[];
    }
  }

  // ---------------------------------------------------------------------------
  // AI writing
  // ---------------------------------------------------------------------------

  Future<MedicineInfo?> _writeWithAi(MedicinePrice medicine, _FdaLabel? label) async {
    final product = <String>[
      'Brand: ${medicine.brandName}',
      if (medicine.activeIngredients.isNotEmpty) 'Active ingredients: ${medicine.activeIngredients.join(', ')}',
      if ((medicine.strength ?? '').trim().isNotEmpty) 'Strength: ${medicine.strength}',
      if ((medicine.dosageForm ?? '').trim().isNotEmpty) 'Dosage form: ${medicine.dosageForm}',
      if ((medicine.atcCode ?? '').trim().isNotEmpty) 'ATC code: ${medicine.atcCode}',
    ].join('\n');

    final source = label == null
        ? '''
SOURCE: no official label is available. Use only well-established, widely accepted
pharmacology of these active ingredients. If you do not reliably know this
medicine, return empty strings and empty lists for every field.'''
        : '''
SOURCE: excerpts of the U.S. FDA label for "${label.title}", which has the same
active ingredients. Use only facts found in these excerpts.

${label.excerpts}''';

    final prompt = '''
You write short, patient-friendly medicine information for PharmaLens, a medicine
app used in Lebanon.

PRODUCT (registered with the Lebanese Ministry of Public Health):
$product

RULES:
- Plain language a patient understands. Short sentences, no jargon.
- uses: 1 to 3 sentences on what the medicine treats.
- howToTake: how adults usually take THIS product, e.g. "Usually 1 tablet
  twice a day with food." Begin with "Follow your doctor's directions." The
  source may describe other strengths: give a number of tablets or a mg dose
  only if it is stated for this product's strength; otherwise give only how
  often it is usually taken and say the dose depends on what the doctor
  prescribes. Mention when children or people with kidney or liver problems
  need different doses.
- foodInstructions: with or without food, or "".
- commonSideEffects: up to 6 of the most common.
- seriousWarnings: up to 6 serious warnings and signs that need urgent care.
- contraindications: up to 5 situations where it must not be used.
- interactions: up to 6 important medicines or groups to avoid or watch.
- pregnancy: 1 or 2 sentences on pregnancy and breastfeeding, or "".
- storage: 1 sentence, or "".
- "en" is in English. "ar" is a faithful Modern Standard Arabic translation
  of "en"; keep medicine names in Latin letters.
- Leave a field empty when the source does not cover it. Never guess doses.
$source
''';

    final json = await const GeminiClient().generateJson(
      parts: <Map<String, dynamic>>[
        <String, dynamic>{'text': prompt},
      ],
      responseSchema: _schema,
      maxOutputTokens: 8192,
      requestTimeout: const Duration(seconds: 35),
      totalBudget: const Duration(seconds: 70),
    );

    final en = _section(json['en']);
    final ar = _section(json['ar']);
    if (!en.hasContent && !ar.hasContent) return null;

    return MedicineInfo(
      knowledge: _knowledge(medicine, en, ar, sourceName: label == null ? 'AI-generated' : 'U.S. FDA label (AI summary)', sourceUrl: label?.url ?? ''),
      origin: label == null ? MedicineInfoOrigin.aiGenerated : MedicineInfoOrigin.fdaLabelSummary,
      sourceTitle: label?.title ?? '',
      sourceUrl: label?.url ?? '',
    );
  }

  static final Map<String, dynamic> _schema = () {
    Map<String, dynamic> text() => <String, dynamic>{'type': 'STRING'};
    Map<String, dynamic> list() => <String, dynamic>{
          'type': 'ARRAY',
          'items': <String, dynamic>{'type': 'STRING'},
        };
    final fields = <String, dynamic>{
      'uses': text(),
      'howToTake': text(),
      'foodInstructions': text(),
      'commonSideEffects': list(),
      'seriousWarnings': list(),
      'contraindications': list(),
      'interactions': list(),
      'pregnancy': text(),
      'storage': text(),
    };
    final section = <String, dynamic>{
      'type': 'OBJECT',
      'properties': fields,
      'required': fields.keys.toList(),
    };
    return <String, dynamic>{
      'type': 'OBJECT',
      'properties': <String, dynamic>{'en': section, 'ar': section},
      'required': const <String>['en', 'ar'],
    };
  }();

  MedicineInfo _fromRawLabel(MedicinePrice medicine, _FdaLabel label) {
    String brief(String text, {int sentences = 3}) {
      final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
      final value = parts.take(sentences).join(' ').trim();
      return value.length > 600 ? '${value.substring(0, 600).trim()}…' : value;
    }

    List<String> item(String text) => text.isEmpty ? const <String>[] : <String>[brief(text, sentences: 2)];

    final en = _InfoSection(
      uses: brief(label.uses),
      howToTake: brief(label.dosage),
      commonSideEffects: item(label.sideEffects),
      seriousWarnings: item(label.warnings),
      contraindications: item(label.contraindications),
      interactions: item(label.interactions),
      pregnancy: brief(label.pregnancy, sentences: 2),
      storage: brief(label.storage, sentences: 1),
    );

    return MedicineInfo(
      knowledge: _knowledge(medicine, en, const _InfoSection(), sourceName: 'U.S. FDA label', sourceUrl: label.url),
      origin: MedicineInfoOrigin.fdaLabel,
      sourceTitle: label.title,
      sourceUrl: label.url,
    );
  }

  MedicineKnowledge _knowledge(
    MedicinePrice medicine,
    _InfoSection en,
    _InfoSection ar, {
    required String sourceName,
    required String sourceUrl,
  }) {
    return MedicineKnowledge(
      medicineId: medicine.medicineId,
      genericName: medicine.genericName ?? '',
      brandNames: <String>[medicine.brandName],
      activeIngredients: medicine.activeIngredients,
      strength: medicine.strength ?? '',
      dosageForm: medicine.dosageForm ?? '',
      atcCode: medicine.atcCode ?? '',
      therapeuticClassEn: '',
      therapeuticClassAr: '',
      usesEn: en.uses,
      usesAr: ar.uses,
      howToTakeEn: en.howToTake,
      howToTakeAr: ar.howToTake,
      foodInstructionsEn: en.foodInstructions,
      foodInstructionsAr: ar.foodInstructions,
      commonSideEffectsEn: en.commonSideEffects,
      commonSideEffectsAr: ar.commonSideEffects,
      seriousWarningsEn: en.seriousWarnings,
      seriousWarningsAr: ar.seriousWarnings,
      contraindicationsEn: en.contraindications,
      contraindicationsAr: ar.contraindications,
      interactionsEn: en.interactions,
      interactionsAr: ar.interactions,
      pregnancyWarningEn: en.pregnancy,
      pregnancyWarningAr: ar.pregnancy,
      storageEn: en.storage,
      storageAr: ar.storage,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      lastReviewedAt: null,
      isVerified: false,
      reviewedBy: '',
    );
  }

  /// Cached entries are shared by every brand with the same ingredients;
  /// show them under the brand being viewed.
  MedicineInfo _rebind(MedicineInfo info, MedicinePrice medicine) {
    if (info.knowledge.medicineId == medicine.medicineId) return info;
    final k = info.knowledge;
    return MedicineInfo(
      knowledge: _knowledge(
        medicine,
        _InfoSection.fromKnowledge(k, arabic: false),
        _InfoSection.fromKnowledge(k, arabic: true),
        sourceName: k.sourceName,
        sourceUrl: k.sourceUrl,
      ),
      origin: info.origin,
      sourceTitle: info.sourceTitle,
      sourceUrl: info.sourceUrl,
    );
  }

  static _InfoSection _section(Object? value) {
    if (value is! Map) return const _InfoSection();
    String text(String key) => '${value[key] ?? ''}'.trim();
    List<String> list(String key) {
      final raw = value[key];
      if (raw is! List) return const <String>[];
      return raw.map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList();
    }

    return _InfoSection(
      uses: text('uses'),
      howToTake: text('howToTake'),
      foodInstructions: text('foodInstructions'),
      commonSideEffects: list('commonSideEffects'),
      seriousWarnings: list('seriousWarnings'),
      contraindications: list('contraindications'),
      interactions: list('interactions'),
      pregnancy: text('pregnancy'),
      storage: text('storage'),
    );
  }

  // ---------------------------------------------------------------------------
  // Cache
  // ---------------------------------------------------------------------------

  Future<MedicineInfo?> _readCache(String key, MedicinePrice medicine) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$key');
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse('${json['savedAt']}');
      if (savedAt == null || DateTime.now().difference(savedAt) > _cacheLifetime) return null;

      final origin = MedicineInfoOrigin.values.firstWhere(
        (value) => value.name == json['origin'],
        orElse: () => MedicineInfoOrigin.aiGenerated,
      );
      final url = '${json['sourceUrl'] ?? ''}';
      return MedicineInfo(
        knowledge: _knowledge(
          medicine,
          _section(json['en']),
          _section(json['ar']),
          sourceName: '${json['sourceName'] ?? ''}',
          sourceUrl: url,
        ),
        origin: origin,
        sourceTitle: '${json['sourceTitle'] ?? ''}',
        sourceUrl: url,
      );
    } catch (error) {
      debugPrint('MedicineInfoService: ignoring cached entry: $error');
      return null;
    }
  }

  Future<void> _writeCache(String key, MedicineInfo info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final k = info.knowledge;
      await prefs.setString(
        '$_cachePrefix$key',
        jsonEncode(<String, dynamic>{
          'savedAt': DateTime.now().toIso8601String(),
          'origin': info.origin.name,
          'sourceName': k.sourceName,
          'sourceTitle': info.sourceTitle,
          'sourceUrl': info.sourceUrl,
          'en': _InfoSection.fromKnowledge(k, arabic: false).toJson(),
          'ar': _InfoSection.fromKnowledge(k, arabic: true).toJson(),
        }),
      );
    } catch (error) {
      debugPrint('MedicineInfoService: could not cache: $error');
    }
  }
}

class _InfoSection {
  const _InfoSection({
    this.uses = '',
    this.howToTake = '',
    this.foodInstructions = '',
    this.commonSideEffects = const <String>[],
    this.seriousWarnings = const <String>[],
    this.contraindications = const <String>[],
    this.interactions = const <String>[],
    this.pregnancy = '',
    this.storage = '',
  });

  factory _InfoSection.fromKnowledge(MedicineKnowledge k, {required bool arabic}) {
    return _InfoSection(
      uses: arabic ? k.usesAr : k.usesEn,
      howToTake: arabic ? k.howToTakeAr : k.howToTakeEn,
      foodInstructions: arabic ? k.foodInstructionsAr : k.foodInstructionsEn,
      commonSideEffects: arabic ? k.commonSideEffectsAr : k.commonSideEffectsEn,
      seriousWarnings: arabic ? k.seriousWarningsAr : k.seriousWarningsEn,
      contraindications: arabic ? k.contraindicationsAr : k.contraindicationsEn,
      interactions: arabic ? k.interactionsAr : k.interactionsEn,
      pregnancy: arabic ? k.pregnancyWarningAr : k.pregnancyWarningEn,
      storage: arabic ? k.storageAr : k.storageEn,
    );
  }

  final String uses;
  final String howToTake;
  final String foodInstructions;
  final List<String> commonSideEffects;
  final List<String> seriousWarnings;
  final List<String> contraindications;
  final List<String> interactions;
  final String pregnancy;
  final String storage;

  bool get hasContent => uses.isNotEmpty || howToTake.isNotEmpty || commonSideEffects.isNotEmpty || seriousWarnings.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uses': uses,
        'howToTake': howToTake,
        'foodInstructions': foodInstructions,
        'commonSideEffects': commonSideEffects,
        'seriousWarnings': seriousWarnings,
        'contraindications': contraindications,
        'interactions': interactions,
        'pregnancy': pregnancy,
        'storage': storage,
      };
}

class _FdaLabel {
  const _FdaLabel({
    required this.title,
    required this.url,
    required this.uses,
    required this.dosage,
    required this.sideEffects,
    required this.warnings,
    required this.contraindications,
    required this.interactions,
    required this.pregnancy,
    required this.storage,
  });

  final String title;
  final String url;
  final String uses;
  final String dosage;
  final String sideEffects;
  final String warnings;
  final String contraindications;
  final String interactions;
  final String pregnancy;
  final String storage;

  String get excerpts {
    String part(String name, String text) => text.isEmpty ? '' : '[$name]\n$text\n\n';
    return part('USES', uses) +
        part('DOSAGE AND ADMINISTRATION', dosage) +
        part('CONTRAINDICATIONS', contraindications) +
        part('WARNINGS', warnings) +
        part('ADVERSE REACTIONS', sideEffects) +
        part('DRUG INTERACTIONS', interactions) +
        part('PREGNANCY AND BREASTFEEDING', pregnancy) +
        part('STORAGE', storage);
  }
}

final RegExp _labelHeading = RegExp(
  r'^\s*(\d+(\.\d+)*\s+)?(BOXED WARNING|WARNINGS?( AND PRECAUTIONS)?|INDICATIONS( AND| &) USAGE|USES?|PURPOSE|'
  r'DOSAGE( AND| &) ADMINISTRATION|DIRECTIONS|CONTRAINDICATIONS|ADVERSE REACTIONS|DRUG INTERACTIONS|'
  r'PREGNANCY|LACTATION|STORAGE( AND HANDLING)?|HOW SUPPLIED[A-Z/ ]*|DO NOT USE|STOP USE[A-Z ]*)\b:?\s*',
);

/// Picks the openFDA label whose ingredient count and route match the MOPH
/// product. Runs in an isolate: label responses are several hundred KB.
_FdaLabel? _pickFdaLabel(Map<String, Object> input) {
  final decoded = jsonDecode(input['body']! as String);
  final results = decoded is Map ? decoded['results'] : null;
  if (results is! List || results.isEmpty) return null;

  final ingredientCount = input['ingredients']! as int;
  final routes = (input['routes']! as List).cast<String>();
  final forChildren = input['forChildren']! as bool;
  final modifiedRelease = input['modifiedRelease']! as bool;
  final strengths = (input['strengths']! as List).cast<String>();

  Map? best;
  var bestScore = -1;
  for (final result in results.whereType<Map>()) {
    final openfda = result['openfda'];
    if (openfda is! Map) continue;
    final substances = openfda['substance_name'];
    // A single-ingredient medicine must not borrow a combination product's
    // label, and the reverse.
    if (substances is! List || substances.length != ingredientCount) continue;

    final labelRoutes = (openfda['route'] is List ? openfda['route'] as List : const []).map((r) => '$r').toList();
    final routeMatches = routes.isEmpty || labelRoutes.any(routes.contains);
    // A label for another route (e.g. an injection for a tablet) would give
    // the wrong directions.
    if (!routeMatches) continue;
    var score = 1;
    if (result.containsKey('indications_and_usage')) score += 1;
    // Adult products should not borrow a children-only label, and the reverse.
    final brand = '${openfda['brand_name'] ?? ''}';
    final indication = '${result['indications_and_usage'] ?? ''}';
    final childLabel = RegExp(r"child|infant|pediatric patients", caseSensitive: false)
        .hasMatch(brand + indication.substring(0, indication.length < 300 ? indication.length : 300));
    if (childLabel == forChildren) score += 2;
    // Extended-release labels have different dosing from plain tablets.
    final forms = '$brand ${openfda['generic_name'] ?? ''} ${result['dosage_forms_and_strengths'] ?? ''} '
        '${result['active_ingredient'] ?? ''} ${result['package_label_principal_display_panel'] ?? ''}';
    final mrLabel = RegExp(r'extended.release|delayed.release|prolonged.release|\b(8|12|24).?hr?\b|\b(ER|XR|SR|CR)\b', caseSensitive: false)
        .hasMatch(forms);
    if (mrLabel == modifiedRelease) score += 3;
    if (strengths.isNotEmpty && strengths.every((value) => RegExp('\\b$value\\s*mg', caseSensitive: false).hasMatch(forms))) {
      score += 3;
    }
    if (score > bestScore) {
      best = result;
      bestScore = score;
    }
  }
  if (best == null) return null;

  String field(List<String> names, {int limit = MedicineInfoService._sectionLimit}) {
    for (final name in names) {
      final value = best![name];
      if (value is List && value.isNotEmpty) {
        final text = value
            .map((v) => '$v')
            .join(' ')
            // Drop the numbered section heading the label text starts with.
            .replaceFirst(_labelHeading, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (text.isNotEmpty) return text.length > limit ? '${text.substring(0, limit)}…' : text;
      }
    }
    return '';
  }

  final openfda = best['openfda'] as Map;
  final brand = openfda['brand_name'] is List && (openfda['brand_name'] as List).isNotEmpty ? '${(openfda['brand_name'] as List).first}' : '';
  final generic = openfda['generic_name'] is List && (openfda['generic_name'] as List).isNotEmpty ? '${(openfda['generic_name'] as List).first}' : '';
  final setId = '${best['set_id'] ?? ''}';

  final purpose = field(const <String>['purpose'], limit: 300);
  final uses = field(const <String>['indications_and_usage']);

  return _FdaLabel(
    title: <String>[brand, if (generic.isNotEmpty && generic.toLowerCase() != brand.toLowerCase()) '($generic)'].join(' ').trim(),
    url: setId.isEmpty ? '' : 'https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=$setId',
    uses: [purpose, uses].where((v) => v.isNotEmpty).join(' '),
    dosage: field(const <String>['dosage_and_administration']),
    sideEffects: field(const <String>['adverse_reactions']),
    warnings: [
      field(const <String>['boxed_warning'], limit: 1200),
      field(const <String>['warnings_and_cautions', 'warnings']),
      field(const <String>['do_not_use', 'stop_use'], limit: 800),
    ].where((v) => v.isNotEmpty).join(' '),
    contraindications: field(const <String>['contraindications'], limit: 1200),
    interactions: field(const <String>['drug_interactions'], limit: 1500),
    pregnancy: field(const <String>['pregnancy', 'pregnancy_or_breast_feeding', 'lactation'], limit: 1000),
    storage: field(const <String>['storage_and_handling', 'how_supplied'], limit: 500),
  );
}
