import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_similarity/string_similarity.dart';

import '../models/medicine_price.dart';
import '../utils/formatters.dart';
import '../utils/medicine_equivalence.dart';
import '../utils/medicine_normalizer.dart';

class MophMedicineService {
  MophMedicineService._internal();

  static final MophMedicineService _instance = MophMedicineService._internal();

  factory MophMedicineService() => _instance;

  static const String _storageKeyMophCsv = 'moph_custom_medicine_csv';
  static const String _storageKeyLastCheck = 'moph_last_check_timestamp';
  static const String _assetCsvPath = 'assets/medicines/lebanon_medicine_prices.csv';

  /// MOPH Official Public Price List URL
  static const String mophPublicUrl = 'https://www.moph.gov.lb/en/Pages/3/3101/drugs-public-price-list';

  /// Where a newer copy of the dataset is published. MOPH only offers an XLS,
  /// so this points at a CSV built with tools/build_medicine_dataset.py and
  /// hosted by the project (any static file host). Empty means updates ship
  /// with app releases only.
  static const String remoteDatasetUrl = String.fromEnvironment('MOPH_DATASET_URL');

  /// Auto-check interval for new MOPH release (6 hours)
  static const Duration checkInterval = Duration(hours: 6);

  /// After this many days without a new list, prices are flagged as possibly outdated.
  static const int staleAfterDays = 60;

  List<MedicinePrice> _catalog = <MedicinePrice>[];
  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  String _lastUpdatedDate = '';
  DateTime? _lastCheckTime;
  String? _loadError;

  bool get isInitialized => _isInitialized;
  int get totalMedicineCount => _catalog.length;

  /// Date of the official MOPH price list currently loaded (yyyy-MM-dd), or empty.
  String get lastUpdatedDate => _lastUpdatedDate;
  DateTime? get lastCheckTime => _lastCheckTime;
  bool get canCheckForUpdates => remoteDatasetUrl.trim().isNotEmpty;

  /// Non-null when the bundled dataset could not be loaded.
  String? get loadError => _loadError;

  int? get dataAgeInDays {
    final date = DateTime.tryParse(_lastUpdatedDate);
    if (date == null) return null;
    return DateTime.now().difference(date).inDays;
  }

  bool get isDataStale {
    final age = dataAgeInDays;
    return age != null && age > staleAfterDays;
  }

  /// Ensures the MOPH database is loaded into memory.
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      final assetCsv = await rootBundle.loadString(_assetCsvPath);
      var dataset = await compute(parseMophDataset, assetCsv);

      // A list downloaded earlier is used only when it is newer than the one
      // shipped with this app version.
      try {
        final prefs = await SharedPreferences.getInstance();
        final customCsv = prefs.getString(_storageKeyMophCsv);
        if (customCsv != null && customCsv.trim().isNotEmpty) {
          final synced = await compute(parseMophDataset, customCsv);
          if (synced.medicines.isNotEmpty && synced.listDate.compareTo(dataset.listDate) > 0) {
            dataset = synced;
          } else {
            await prefs.remove(_storageKeyMophCsv);
          }
        }
      } catch (e) {
        debugPrint('MophMedicineService: ignoring saved dataset: $e');
      }

      _catalog = dataset.medicines;
      _lastUpdatedDate = dataset.listDate;
      _loadError = _catalog.isEmpty ? 'The bundled medicine list is empty.' : null;
      debugPrint('MophMedicineService: Indexed ${_catalog.length} MOPH medicines (list date $_lastUpdatedDate).');
    } catch (e, st) {
      debugPrint('MophMedicineService initialization error: $e\n$st');
      _catalog = <MedicinePrice>[];
      _loadError = 'The medicine list could not be loaded.';
    }

    _isInitialized = true;
    _initCompleter!.complete();

    if (canCheckForUpdates) {
      unawaited(_autoCheckOnStartup());
    }
  }

  // ---------------------------------------------------------------------------
  // Public Search API
  // ---------------------------------------------------------------------------

  /// Main search method across the MOPH medicine list with offset support.
  Future<List<MedicinePrice>> searchMedicines(
    String query, {
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    await initialize();

    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;

    final cleanedQuery = MedicineNormalizer.cleanUserQuery(query);
    if (cleanedQuery.isEmpty) {
      // Direct browse when query is empty: return catalog sliced by offset and limit
      return getMedicinesPage(limit: safeLimit, offset: safeOffset);
    }

    final normalizedQuery = MedicineNormalizer.normalizeText(cleanedQuery);
    if (normalizedQuery.isEmpty) {
      return getMedicinesPage(limit: safeLimit, offset: safeOffset);
    }

    final scored = <_ScoredMedicine>[];

    for (final med in _catalog) {
      final score = _calculateMatchScore(med, normalizedQuery, cleanedQuery);
      if (score > 0.15) {
        scored.add(_ScoredMedicine(med: med, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    final results = scored.skip(safeOffset).take(safeLimit).map((item) {
      return item.med.copyWith(similarityScore: item.score);
    }).toList();

    return List<MedicinePrice>.unmodifiable(results);
  }

  /// Returns paginated medicines directly from the catalog.
  List<MedicinePrice> getMedicinesPage({int limit = 30, int offset = 0}) {
    if (_catalog.isEmpty) return const <MedicinePrice>[];
    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;
    return List<MedicinePrice>.unmodifiable(_catalog.skip(safeOffset).take(safeLimit));
  }

  /// Read-only access to all loaded MOPH medicines.
  List<MedicinePrice> get catalog => List<MedicinePrice>.unmodifiable(_catalog);

  /// The product with MOPH code [medicineId], or null.
  MedicinePrice? findById(String medicineId) {
    final id = medicineId.trim();
    if (id.isEmpty) return null;
    for (final medicine in _catalog) {
      if (medicine.medicineId == id) return medicine;
    }
    return null;
  }

  /// Finds medicines mentioned inside a natural language sentence or chatbot query.
  Future<List<MedicinePrice>> extractMedicinesFromText(String text, {int limit = 5}) async {
    await initialize();
    if (text.trim().isEmpty || _catalog.isEmpty) return const <MedicinePrice>[];

    final cleanText = MedicineNormalizer.cleanUserQuery(text).toLowerCase();
    final words = cleanText.split(RegExp(r'\s+')).where((w) => w.length >= 3).toList();

    final matched = <MedicinePrice>[];
    final seen = <String>{};

    // 1. Check if any catalog brand or primary brand token appears in user text
    for (final med in _catalog) {
      final brandLower = med.brandName.toLowerCase();
      final primaryToken = brandLower.split(RegExp(r'[\s\-_/]+')).first;

      if (primaryToken.length >= 3 && cleanText.contains(primaryToken)) {
        if (seen.add(med.brandName.toLowerCase())) {
          matched.add(med);
          if (matched.length >= limit) break;
        }
      }
    }

    // 2. Generic name match (e.g. "paracetamol", "amoxicillin", "ibuprofen")
    if (matched.length < limit) {
      for (final med in _catalog) {
        final generic = med.genericName?.toLowerCase();
        if (generic != null && generic.length >= 3 && cleanText.contains(generic)) {
          if (seen.add(med.brandName.toLowerCase())) {
            matched.add(med);
            if (matched.length >= limit) break;
          }
        }
      }
    }

    // 3. Fallback: search individual non-stop words
    if (matched.isEmpty) {
      const stopWords = {
        'what', 'is', 'the', 'price', 'of', 'does', 'side', 'effects',
        'cost', 'how', 'much', 'for', 'tell', 'about', 'show', 'generic',
        'alternative', 'alternatives', 'with', 'from', 'take', 'taking',
        'have', 'give', 'good', 'best', 'safe', 'safety', 'available',
        'lebanon', 'lbp', 'usd', 'who', 'when', 'where', 'why', 'can',
        'سعر', 'كم', 'شو', 'ما', 'هو', 'ماهو', 'دواء', 'ادوية', 'علاج',
        'اعراض', 'جانبية', 'بديل', 'بدائل', 'في', 'لبنان', 'ليرة', 'دولار'
      };

      for (final word in words) {
        if (!stopWords.contains(word)) {
          final wordMatches = await searchMedicines(word, limit: 3);
          for (final wm in wordMatches) {
            if (seen.add(wm.brandName.toLowerCase())) {
              matched.add(wm);
              if (matched.length >= limit) break;
            }
          }
        }
        if (matched.length >= limit) break;
      }
    }

    return List<MedicinePrice>.unmodifiable(matched);
  }

  double _calculateMatchScore(MedicinePrice med, String normQuery, String rawQuery) {
    final normBrand = MedicineNormalizer.normalizeText(med.brandName);
    final normGeneric = MedicineNormalizer.normalizeText(med.genericName ?? '');

    // Exact brand match
    if (normBrand == normQuery) return 1.0;
    if (normBrand.startsWith(normQuery)) return 0.90;
    if (normBrand.contains(normQuery)) return 0.80;

    // Generic match
    if (normGeneric == normQuery) return 0.85;
    if (normGeneric.startsWith(normQuery)) return 0.75;
    if (normGeneric.contains(normQuery)) return 0.70;

    // Ingredient match
    for (final ing in med.activeIngredients) {
      final normIng = MedicineNormalizer.normalizeText(ing);
      if (normIng.contains(normQuery)) return 0.65;
    }

    // Registration or MOPH Code match
    if (med.medicineId.toLowerCase() == rawQuery.toLowerCase() ||
        (med.registrationNumber != null && med.registrationNumber!.contains(rawQuery))) {
      return 0.95;
    }

    // Similarity fuzzy match
    final brandSimilarity = normBrand.similarityTo(normQuery);
    final genericSimilarity = normGeneric.similarityTo(normQuery);
    final maxSim = brandSimilarity > genericSimilarity ? brandSimilarity : genericSimilarity;

    return maxSim >= 0.45 ? maxSim * 0.75 : 0.0;
  }

  Future<MedicinePrice?> findBestMatch(
    String query, {
    double minimumScore = 0.45,
    bool forceRefresh = false,
  }) async {
    final results = await searchMedicines(query, limit: 5);
    if (results.isEmpty) return null;

    final top = results.first;
    if (top.similarityScore >= minimumScore) {
      return top;
    }
    return null;
  }

  Future<List<MedicinePrice>> searchOcrCandidates(
    List<String> candidates, {
    int resultsPerCandidate = 5,
  }) async {
    await initialize();
    final collected = <MedicinePrice>[];
    final seen = <String>{};

    for (final raw in candidates) {
      final query = MedicineNormalizer.cleanUserQuery(raw);
      if (query.length < 2) continue;

      final results = await searchMedicines(query, limit: resultsPerCandidate);
      for (final res in results) {
        if (seen.add(res.medicineId)) {
          collected.add(res);
        }
      }
    }

    collected.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return List<MedicinePrice>.unmodifiable(collected);
  }

  // ---------------------------------------------------------------------------
  // Alternative Discovery
  // ---------------------------------------------------------------------------

  /// Other MOPH products with the same active ingredients (any strength or
  /// form). Same-strength, same-form products come first, cheapest first.
  Future<List<MedicinePrice>> findAlternatives(
    MedicinePrice medicine, {
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    await initialize();

    if (MedicineEquivalence.compositionKey(medicine).isEmpty) {
      return const <MedicinePrice>[];
    }

    final alternatives = <MedicinePrice>[];

    for (final candidate in _catalog) {
      if (candidate.medicineId == medicine.medicineId) continue;
      if (!MedicineEquivalence.sameComposition(medicine, candidate)) continue;

      alternatives.add(candidate.copyWith(
        similarityScore: MedicineEquivalence.isEquivalent(medicine, candidate) ? 1.0 : 0.9,
        mappingStatus: 'verified',
        dataSource: 'MOPH Lebanon Registry',
      ));
    }

    alternatives.sort((a, b) {
      final rank = b.similarityScore.compareTo(a.similarityScore);
      if (rank != 0) return rank;
      return _comparePrice(a, b);
    });

    return List<MedicinePrice>.unmodifiable(alternatives.take(limit));
  }

  /// Products with the same ingredients, strength and dosage form,
  /// sorted from cheapest to most expensive official price.
  Future<List<MedicinePrice>> findExactAlternatives(
    MedicinePrice medicine, {
    int limit = 6,
    bool forceRefresh = false,
  }) async {
    await initialize();

    final exact = _catalog
        .where((candidate) =>
            candidate.medicineId != medicine.medicineId && MedicineEquivalence.isEquivalent(medicine, candidate))
        .toList()
      ..sort(_comparePrice);

    return List<MedicinePrice>.unmodifiable(exact.take(limit));
  }

  /// The cheapest equivalent product when it costs less than [medicine].
  Future<MedicinePrice?> findCheaperEquivalent(MedicinePrice medicine) async {
    final price = medicine.priceLbp;
    if (price == null) return null;

    final exact = await findExactAlternatives(medicine, limit: 1);
    if (exact.isEmpty) return null;

    final cheapest = exact.first;
    final saving = MedicineEquivalence.savingPercent(medicine, cheapest);
    return saving != null && saving > 0 ? cheapest : null;
  }

  int _comparePrice(MedicinePrice a, MedicinePrice b) => MedicineEquivalence.comparePrice(a, b);

  // ---------------------------------------------------------------------------
  // Dataset updates
  // ---------------------------------------------------------------------------

  /// Non-blocking startup auto-check for new MOPH dataset releases.
  Future<void> _autoCheckOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckMs = prefs.getInt(_storageKeyLastCheck) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (nowMs - lastCheckMs < checkInterval.inMilliseconds) {
        return;
      }

      final result = await checkAndUpdateIfStale();
      debugPrint('MophMedicineService auto-check result: ${result.status}');
    } catch (e) {
      debugPrint('MophMedicineService background auto-check error: $e');
    }
  }

  /// Downloads [remoteDatasetUrl] and replaces the catalog when it holds a
  /// newer official list. If [force] is false, checks are throttled to once
  /// every [checkInterval].
  Future<MophSyncResult> checkAndUpdateIfStale({bool force = false}) async {
    await initialize();

    if (!canCheckForUpdates) {
      return MophSyncResult(
        status: MophSyncStatus.notConfigured,
        medicineCount: _catalog.length,
        listDate: _lastUpdatedDate,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _lastCheckTime = DateTime.fromMillisecondsSinceEpoch(nowMs);

    if (!force) {
      final lastCheckMs = prefs.getInt(_storageKeyLastCheck) ?? 0;
      if (nowMs - lastCheckMs < checkInterval.inMilliseconds) {
        return MophSyncResult(
          status: MophSyncStatus.upToDate,
          medicineCount: _catalog.length,
          listDate: _lastUpdatedDate,
        );
      }
    }

    try {
      final response = await http.get(Uri.parse(remoteDatasetUrl)).timeout(const Duration(seconds: 20));
      await prefs.setInt(_storageKeyLastCheck, nowMs);

      if (response.statusCode != 200) {
        return MophSyncResult(
          status: MophSyncStatus.failed,
          medicineCount: _catalog.length,
          listDate: _lastUpdatedDate,
          detail: 'HTTP ${response.statusCode}',
        );
      }

      final body = utf8.decode(response.bodyBytes);
      final dataset = await compute(parseMophDataset, body);

      if (dataset.medicines.isEmpty) {
        return MophSyncResult(
          status: MophSyncStatus.failed,
          medicineCount: _catalog.length,
          listDate: _lastUpdatedDate,
          detail: 'The downloaded file is not a valid medicine list.',
        );
      }

      if (dataset.listDate.compareTo(_lastUpdatedDate) <= 0) {
        return MophSyncResult(
          status: MophSyncStatus.upToDate,
          medicineCount: _catalog.length,
          listDate: _lastUpdatedDate,
        );
      }

      await prefs.setString(_storageKeyMophCsv, body);
      _catalog = dataset.medicines;
      _lastUpdatedDate = dataset.listDate;
      _loadError = null;

      return MophSyncResult(
        status: MophSyncStatus.updated,
        medicineCount: _catalog.length,
        listDate: _lastUpdatedDate,
      );
    } catch (e) {
      debugPrint('MophMedicineService release check network error: $e');
      return MophSyncResult(
        status: MophSyncStatus.failed,
        medicineCount: _catalog.length,
        listDate: _lastUpdatedDate,
        detail: '$e',
      );
    }
  }

  /// Forces a check of [remoteDatasetUrl] for a newer official list.
  Future<MophSyncResult> updateFromMophWebsite() async {
    return checkAndUpdateIfStale(force: true);
  }
}

class _ScoredMedicine {
  final MedicinePrice med;
  final double score;

  _ScoredMedicine({required this.med, required this.score});
}

enum MophSyncStatus {
  updated,
  upToDate,
  notConfigured,
  failed,
}

class MophSyncResult {
  final MophSyncStatus status;
  final int medicineCount;

  /// Date of the official list in use after the check (yyyy-MM-dd).
  final String listDate;
  final String detail;

  MophSyncResult({
    required this.status,
    required this.medicineCount,
    required this.listDate,
    this.detail = '',
  });

  bool get success => status != MophSyncStatus.failed;

  String describe({required bool isArabic}) {
    final date = listDate.isEmpty ? (isArabic ? 'غير معروف' : 'unknown') : listDate;

    switch (status) {
      case MophSyncStatus.updated:
        return isArabic
            ? 'تم التحديث إلى لائحة وزارة الصحة بتاريخ $date (${formatCount(medicineCount)} دواء).'
            : 'Updated to the MOPH list of $date (${formatCount(medicineCount)} medicines).';
      case MophSyncStatus.upToDate:
        return isArabic
            ? 'لديك أحدث لائحة من وزارة الصحة ($date).'
            : 'You already have the latest MOPH list ($date).';
      case MophSyncStatus.notConfigured:
        return isArabic
            ? 'يتم استخدام لائحة وزارة الصحة بتاريخ $date. تصل اللوائح الجديدة مع تحديثات التطبيق.'
            : 'Using the MOPH list of $date. New lists arrive with app updates.';
      case MophSyncStatus.failed:
        return isArabic
            ? 'تعذر التحقق من لائحة أحدث. يتم عرض لائحة $date.'
            : 'Could not check for a newer MOPH list. Showing the list of $date.';
    }
  }
}

/// Result of parsing a MOPH CSV: the medicines plus the list's publication date.
class MophDataset {
  const MophDataset({required this.medicines, required this.listDate});

  final List<MedicinePrice> medicines;
  final String listDate;
}

/// Parses the CSV produced by tools/build_medicine_dataset.py.
///
/// Rows are keyed by MOPH code, so every strength and pack of a brand is kept.
/// Top-level so it can run in a background isolate via [compute].
MophDataset parseMophDataset(String csvContent) {
  final lines = const LineSplitter().convert(csvContent);
  if (lines.isEmpty) return const MophDataset(medicines: <MedicinePrice>[], listDate: '');

  final headers = parseCsvLine(lines.first).map((h) => h.trim().toLowerCase()).toList();
  if (!headers.contains('brand_name')) {
    return const MophDataset(medicines: <MedicinePrice>[], listDate: '');
  }

  final byId = <String, MedicinePrice>{};
  final dateCounts = <String, int>{};

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final values = parseCsvLine(line);
    final map = <String, String>{};

    for (var j = 0; j < headers.length; j++) {
      map[headers[j]] = j < values.length ? values[j].trim() : '';
    }

    if ((map['medicine_id'] ?? '').isEmpty) {
      final codeMatch = RegExp(r'Code:\s*(\d+)').firstMatch(map['notes'] ?? '');
      map['medicine_id'] = codeMatch?.group(1) ?? 'moph_$i';
    }

    final medicine = MedicinePrice.fromCsvRow(map);
    if (medicine.brandName.isEmpty) continue;

    byId.putIfAbsent(medicine.medicineId, () => medicine);

    final date = map['last_updated'] ?? '';
    if (date.isNotEmpty) {
      dateCounts[date] = (dateCounts[date] ?? 0) + 1;
    }
  }

  var listDate = '';
  var best = 0;
  dateCounts.forEach((date, count) {
    if (count > best) {
      best = count;
      listDate = date;
    }
  });

  return MophDataset(medicines: List<MedicinePrice>.unmodifiable(byId.values), listDate: listDate);
}

List<String> parseCsvLine(String line) {
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
