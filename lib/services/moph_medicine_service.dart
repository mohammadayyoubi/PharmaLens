import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_similarity/string_similarity.dart';

import '../l10n/app_text.dart';
import '../models/medicine_price.dart';
import '../utils/formatters.dart';
import '../utils/medicine_equivalence.dart';
import '../utils/medicine_normalizer.dart';
import '../utils/phonetic_skeleton.dart';
import 'connectivity_service.dart';

class MophMedicineService {
  MophMedicineService._internal();

  static final MophMedicineService _instance = MophMedicineService._internal();

  factory MophMedicineService() => _instance;

  /// Lists downloaded before the manifest existed; removed on startup.
  static const String _legacyStorageKeyCsv = 'moph_custom_medicine_csv';
  static const String _storageKeyManifest = 'moph_dataset_manifest_v2';
  static const String _storageKeyWebCsv = 'moph_dataset_csv_v2';
  static const String _storageKeyLastCheck = 'moph_last_check_timestamp';
  static const String _assetCsvPath = 'assets/medicines/lebanon_medicine_prices.csv';
  static const String _assetManifestPath = 'assets/medicines/lebanon_medicine_prices.json';
  static const String _fileName = 'lebanon_medicine_prices.csv';

  /// MOPH Official Public Price List URL
  static const String mophPublicUrl = 'https://www.moph.gov.lb/en/Pages/3/3101/drugs-public-price-list';

  /// Folder URL where the GitHub workflow (.github/workflows/update-moph-prices.yml)
  /// publishes lebanon_medicine_prices.csv and its .json manifest every time
  /// MOPH releases a new sheet. Override with
  /// --dart-define=MOPH_DATA_BASE_URL=...; an empty value turns updates off.
  static const String dataBaseUrl = String.fromEnvironment(
    'MOPH_DATA_BASE_URL',
    defaultValue: 'https://raw.githubusercontent.com/mohammadayyoubi/PharmaLens/main/assets/medicines/',
  );

  /// How often the app asks whether a new list was published. Only the small
  /// manifest is downloaded unless it changed, so this can be frequent.
  static const Duration checkInterval = Duration(hours: 1);

  /// After this many days without a new list, prices are flagged as possibly outdated.
  static const int staleAfterDays = 60;

  List<MedicinePrice> _catalog = <MedicinePrice>[];
  Map<String, MedicinePrice> _byId = <String, MedicinePrice>{};

  /// Normalized brand, generic and ingredient names, computed once per
  /// product instead of on every search.
  final Expando<_SearchKeys> _searchKeys = Expando<_SearchKeys>('searchKeys');

  String _lastScoredQuery = '';
  List<MedicinePrice>? _lastScoredCatalog;
  List<_ScoredMedicine> _lastScored = const <_ScoredMedicine>[];
  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  String _lastUpdatedDate = '';
  MophDatasetManifest _manifest = const MophDatasetManifest();
  DateTime? _lastCheckTime;
  String? _loadError;
  Future<MophSyncResult>? _checkInFlight;
  bool _autoUpdatesStarted = false;
  AppLifecycleListener? _lifecycleListener;

  /// Increases whenever a newer list replaces the one in memory, so screens
  /// showing the list date or prices can rebuild.
  final ValueNotifier<int> datasetRevision = ValueNotifier<int>(0);

  /// True once the list in use is in memory. The app starts drawing before
  /// that, so anything showing counts or dates listens to this too.
  final ValueNotifier<bool> loaded = ValueNotifier<bool>(false);

  /// Fires on first load and on every newer list.
  Listenable get changes => Listenable.merge(<Listenable>[loaded, datasetRevision]);

  /// What the list is doing right now (loading, checking, downloading...)
  /// and how far along, for the status card and the Sync buttons.
  final ValueNotifier<MophSyncProgress> progress = ValueNotifier<MophSyncProgress>(MophSyncProgress.idle);

  /// True while a check or download runs; Sync buttons stay disabled.
  bool get isSyncing => _checkInFlight != null;

  void _report(MophSyncStage stage, double fraction) {
    progress.value = MophSyncProgress(stage, fraction.clamp(0.0, 1.0));
  }

  bool get isInitialized => _isInitialized;
  int get totalMedicineCount => _catalog.length;

  /// Date of the official MOPH price list currently loaded (yyyy-MM-dd), or empty.
  String get lastUpdatedDate => _lastUpdatedDate;
  DateTime? get lastCheckTime => _lastCheckTime;
  bool get canCheckForUpdates => dataBaseUrl.trim().isNotEmpty;

  /// Day MOPH published the sheet in use; later than [lastUpdatedDate] when
  /// MOPH re-issued a list with corrections.
  String get publishedDate => _manifest.published.isNotEmpty ? _manifest.published : _lastUpdatedDate;

  /// Non-null when the bundled dataset could not be loaded.
  String? get loadError => _loadError;

  int? get dataAgeInDays {
    final date = DateTime.tryParse(publishedDate);
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
    _report(MophSyncStage.loading, 0.1);

    try {
      final assetCsv = await rootBundle.loadString(_assetCsvPath);
      _report(MophSyncStage.loading, 0.35);
      var dataset = await compute(parseMophDataset, assetCsv);
      _report(MophSyncStage.loading, 0.8);
      var manifest = await _bundledManifest(dataset);

      // A list downloaded earlier is used only when it is newer than the one
      // shipped with this app version.
      try {
        final saved = await _readSavedManifest();
        if (saved != null && saved.isNewerThan(manifest)) {
          final csv = await _readSavedCsv();
          final synced = csv == null ? null : await compute(parseMophDataset, csv);
          if (synced != null && saved.matches(synced)) {
            dataset = synced;
            manifest = saved;
          }
        } else if (saved != null) {
          // The app update shipped this list or a newer one.
          await _clearSavedDataset();
        }
      } catch (e) {
        debugPrint('MophMedicineService: ignoring saved dataset: $e');
      }

      _setCatalog(dataset.medicines);
      _lastUpdatedDate = dataset.listDate;
      _manifest = manifest;
      _loadError = _catalog.isEmpty ? 'The bundled medicine list is empty.' : null;
      debugPrint('MophMedicineService: Indexed ${_catalog.length} MOPH medicines (list ${manifest.version}).');
    } catch (e, st) {
      debugPrint('MophMedicineService initialization error: $e\n$st');
      _setCatalog(const <MedicinePrice>[]);
      _loadError = 'The medicine list could not be loaded.';
    }

    _isInitialized = true;
    // A check started meanwhile reports its own stage.
    if (_checkInFlight == null) progress.value = MophSyncProgress.idle;
    _initCompleter!.complete();
    // Screens showing the list date or count rebuild once it is loaded.
    loaded.value = true;
  }

  /// Official prices that differ between the previous list and the one
  /// that replaced it, set on each update (empty until then).
  List<PriceChange> lastPriceChanges = const <PriceChange>[];

  static List<PriceChange> _priceChanges(Map<String, MedicinePrice> before, List<MedicinePrice> after) {
    final changes = <PriceChange>[];
    for (final medicine in after) {
      final old = before[medicine.medicineId]?.priceLbp;
      final now = medicine.priceLbp;
      if (old != null && now != null && (old - now).abs() >= 1) {
        changes.add(PriceChange(medicine: medicine, oldPrice: old, newPrice: now));
      }
    }
    return changes;
  }

  void _setCatalog(List<MedicinePrice> medicines) {
    _catalog = medicines;
    _byId = <String, MedicinePrice>{for (final medicine in medicines) medicine.medicineId: medicine};
  }

  _SearchKeys _keysOf(MedicinePrice medicine) {
    final brandWords = medicine.brandName.split(RegExp(r'[\s\-_/]+'));
    return _searchKeys[medicine] ??= _SearchKeys(
      brand: MedicineNormalizer.normalizeText(medicine.brandName),
      generic: MedicineNormalizer.normalizeText(medicine.genericName ?? ''),
      ingredients: medicine.activeIngredients.map(MedicineNormalizer.normalizeText).toList(growable: false),
      brandSkeleton: PhoneticSkeleton.ofLatin(brandWords.first),
      fullBrandSkeleton: PhoneticSkeleton.ofLatin(medicine.brandName),
      genericSkeleton: PhoneticSkeleton.ofLatin((medicine.genericName ?? '').split(RegExp(r'\s+')).first),
    );
  }

  Future<MophDatasetManifest> _bundledManifest(MophDataset dataset) async {
    try {
      final parsed = MophDatasetManifest.tryParse(await rootBundle.loadString(_assetManifestPath));
      if (parsed != null) return parsed;
    } catch (_) {
      // Older builds have no manifest asset.
    }
    return MophDatasetManifest(version: dataset.listDate, listDate: dataset.listDate, published: dataset.listDate);
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
    if (cleanedQuery.isEmpty && !PhoneticSkeleton.hasArabic(query)) {
      // Direct browse when query is empty: return catalog sliced by offset and limit
      return getMedicinesPage(limit: safeLimit, offset: safeOffset);
    }

    // A brand typed in Arabic letters ("بنادول") is matched by sound.
    if (PhoneticSkeleton.hasArabic(query)) {
      final scored = _scoredArabic(query);
      return List<MedicinePrice>.unmodifiable(
        scored.skip(safeOffset).take(safeLimit).map((item) => item.med.copyWith(similarityScore: item.score)),
      );
    }

    final normalizedQuery = MedicineNormalizer.normalizeText(cleanedQuery);
    if (normalizedQuery.isEmpty) {
      return getMedicinesPage(limit: safeLimit, offset: safeOffset);
    }

    final scored = _scored(normalizedQuery, cleanedQuery);

    final results = scored.skip(safeOffset).take(safeLimit).map((item) {
      return item.med.copyWith(similarityScore: item.score);
    }).toList();

    return List<MedicinePrice>.unmodifiable(results);
  }

  /// Ranked matches for a query. The last ranking is kept, so loading the
  /// next page of the same search does not score the catalog again.
  List<_ScoredMedicine> _scored(String normalizedQuery, String cleanedQuery) {
    if (normalizedQuery == _lastScoredQuery && identical(_lastScoredCatalog, _catalog)) {
      return _lastScored;
    }

    final scored = <_ScoredMedicine>[];
    for (final med in _catalog) {
      final score = _calculateMatchScore(med, normalizedQuery, cleanedQuery);
      if (score > 0.15) {
        scored.add(_ScoredMedicine(med: med, score: score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    _lastScoredQuery = normalizedQuery;
    _lastScoredCatalog = _catalog;
    _lastScored = scored;
    return scored;
  }

  List<_ScoredMedicine> _scoredArabic(String query) {
    final skeleton = PhoneticSkeleton.ofArabic(query);
    final cacheKey = 'ar:$skeleton';
    if (cacheKey == _lastScoredQuery && identical(_lastScoredCatalog, _catalog)) return _lastScored;

    final scored = <_ScoredMedicine>[];
    if (skeleton.length >= 3) {
      for (final med in _catalog) {
        final keys = _keysOf(med);
        double score = 0;
        if (keys.brandSkeleton == skeleton) {
          score = 0.72;
        } else if (keys.genericSkeleton == skeleton) {
          score = 0.66;
        } else if (keys.brandSkeleton.startsWith(skeleton)) {
          score = 0.6;
        } else if (keys.fullBrandSkeleton.startsWith(skeleton)) {
          score = 0.55;
        }
        if (score > 0) scored.add(_ScoredMedicine(med: med, score: score));
      }
      scored.sort((a, b) => b.score.compareTo(a.score));
    }

    _lastScoredQuery = cacheKey;
    _lastScoredCatalog = _catalog;
    _lastScored = scored;
    return scored;
  }

  /// How many products match [query] in total (all of them for an empty
  /// query), for "128 matches" labels while results load page by page.
  Future<int> countMatches(String query) async {
    await initialize();
    if (PhoneticSkeleton.hasArabic(query)) return _scoredArabic(query).length;
    final cleanedQuery = MedicineNormalizer.cleanUserQuery(query);
    final normalizedQuery = MedicineNormalizer.normalizeText(cleanedQuery);
    if (normalizedQuery.isEmpty) return _catalog.length;
    return _scored(normalizedQuery, cleanedQuery).length;
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
    return _byId[id];
  }

  /// Finds medicines mentioned inside a natural language sentence or chatbot query.
  Future<List<MedicinePrice>> extractMedicinesFromText(String text, {int limit = 5}) async {
    await initialize();
    if (text.trim().isEmpty || _catalog.isEmpty) return const <MedicinePrice>[];

    final cleanText = MedicineNormalizer.cleanUserQuery(text).toLowerCase();
    final words = cleanText.split(RegExp(r'\s+')).where((w) => w.length >= 3).toList();
    // Whole words only: the brand "ACE" must not match "face".
    final paddedText = ' ${cleanText.replaceAll(RegExp(r'[^a-z0-9؀-ۿ]+'), ' ')} ';
    bool mentions(String phrase) => phrase.length >= 3 && paddedText.contains(' $phrase ');

    final matched = <MedicinePrice>[];
    final seen = <String>{};

    // 1. Check if any catalog brand or primary brand token appears in user text
    for (final med in _catalog) {
      final brandLower = med.brandName.toLowerCase();
      final primaryToken = brandLower.split(RegExp(r'[\s\-_/]+')).first;

      if (mentions(primaryToken)) {
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
        if (generic != null && mentions(generic)) {
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
    final keys = _keysOf(med);
    final normBrand = keys.brand;
    final normGeneric = keys.generic;

    // Exact brand match
    if (normBrand == normQuery) return 1.0;
    if (normBrand.startsWith(normQuery)) return 0.90;
    if (normBrand.contains(normQuery)) return 0.80;

    // Generic match
    if (normGeneric == normQuery) return 0.85;
    if (normGeneric.startsWith(normQuery)) return 0.75;
    if (normGeneric.contains(normQuery)) return 0.70;

    // Ingredient match
    for (final normIng in keys.ingredients) {
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

  /// Checks for a newer list now, and (at most every [checkInterval]) whenever
  /// the device comes back online or the app returns to the foreground. Call
  /// once after [initialize].
  void startAutoUpdates() {
    if (_autoUpdatesStarted || !canCheckForUpdates) return;
    _autoUpdatesStarted = true;

    // Every launch asks once (a 1 KB manifest), so the user sees the list
    // being checked; reconnects and resumes stay rate-limited.
    unawaited(checkAndUpdateIfStale(force: true));

    final connectivity = ConnectivityService();
    var wasOnline = connectivity.isOnline;
    connectivity.addListener(() {
      final online = connectivity.isOnline;
      if (online && !wasOnline) unawaited(checkAndUpdateIfStale());
      wasOnline = online;
    });

    _lifecycleListener = AppLifecycleListener(onResume: () => unawaited(checkAndUpdateIfStale()));
  }

  /// Downloads the published manifest and, when it describes a newer list,
  /// the list itself, then swaps it in. Unless [force] is set, the server is
  /// asked at most once every [checkInterval].
  Future<MophSyncResult> checkAndUpdateIfStale({bool force = false}) {
    // Startup, reconnection and the Sync button can overlap; share one check.
    if (force && _checkInFlight == null && _isInitialized) _report(MophSyncStage.checking, 0);
    return _checkInFlight ??= _check(force).whenComplete(() {
      _checkInFlight = null;
      progress.value = MophSyncProgress.idle;
    });
  }

  /// Downloads [uri], reporting progress between [from] and [to].
  Future<List<int>> _download(Uri uri, Duration timeout, double from, double to) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      // An uncompressed transfer gives an exact size for the percentage
      // (browsers choose the encoding themselves).
      if (!kIsWeb) request.headers['Accept-Encoding'] = 'identity';
      final response = await client.send(request).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', uri);
      }

      final total = response.contentLength ?? 0;
      final bytes = <int>[];
      await response.stream.timeout(timeout).forEach((chunk) {
        bytes.addAll(chunk);
        if (total > 0) _report(MophSyncStage.downloading, from + (to - from) * bytes.length / total);
      });
      return bytes;
    } finally {
      client.close();
    }
  }

  Future<MophSyncResult> _check(bool force) async {
    await initialize();

    MophSyncResult result(MophSyncStatus status, [String detail = '']) => MophSyncResult(
          status: status,
          medicineCount: _catalog.length,
          listDate: _lastUpdatedDate,
          publishedDate: publishedDate,
          detail: detail,
        );

    if (!canCheckForUpdates) return result(MophSyncStatus.notConfigured);

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    if (!force) {
      final lastCheckMs = prefs.getInt(_storageKeyLastCheck) ?? 0;
      if (now.millisecondsSinceEpoch - lastCheckMs < checkInterval.inMilliseconds) {
        return result(MophSyncStatus.upToDate);
      }
    }

    try {
      final base = dataBaseUrl.endsWith('/') ? dataBaseUrl : '$dataBaseUrl/';
      _report(MophSyncStage.checking, 0.05);
      final manifestResponse = await http.get(Uri.parse('${base}lebanon_medicine_prices.json')).timeout(const Duration(seconds: 15));
      if (manifestResponse.statusCode != 200) {
        return result(MophSyncStatus.failed, 'HTTP ${manifestResponse.statusCode}');
      }
      _report(MophSyncStage.checking, 0.1);

      _lastCheckTime = now;
      await prefs.setInt(_storageKeyLastCheck, now.millisecondsSinceEpoch);

      final remote = MophDatasetManifest.tryParse(utf8.decode(manifestResponse.bodyBytes));
      if (remote == null) return result(MophSyncStatus.failed, 'The published manifest is not valid.');
      if (!remote.isNewerThan(_manifest)) {
        _report(MophSyncStage.checking, 1);
        return result(MophSyncStatus.upToDate);
      }

      _report(MophSyncStage.downloading, 0.1);
      final csvBytes = await _download(Uri.parse('${base}lebanon_medicine_prices.csv'), const Duration(seconds: 90), 0.1, 0.8);

      // The manifest's checksum proves the file is the one the workflow
      // published, complete and unchanged.
      _report(MophSyncStage.verifying, 0.82);
      if (remote.sha256.isNotEmpty && sha256.convert(csvBytes).toString() != remote.sha256) {
        return result(MophSyncStatus.failed, 'The downloaded list does not match its checksum.');
      }

      final body = utf8.decode(csvBytes);
      final dataset = await compute(parseMophDataset, body);
      // A partial download or a file from another build must not replace a
      // complete list.
      if (!remote.matches(dataset)) {
        return result(MophSyncStatus.failed, 'The downloaded list is incomplete.');
      }

      _report(MophSyncStage.applying, 0.9);
      await _saveDataset(remote, body);
      lastPriceChanges = _priceChanges(_byId, dataset.medicines);
      _setCatalog(dataset.medicines);
      _lastUpdatedDate = dataset.listDate;
      _manifest = remote;
      _loadError = null;
      datasetRevision.value++;
      debugPrint('MophMedicineService: updated to ${remote.version}.');

      return result(MophSyncStatus.updated);
    } catch (e) {
      debugPrint('MophMedicineService: update check failed: $e');
      return result(MophSyncStatus.failed, '$e');
    }
  }

  /// Forces a check for a newer official list.
  Future<MophSyncResult> updateFromMophWebsite() {
    return checkAndUpdateIfStale(force: true);
  }

  // Downloaded lists live in a file on phones and desktops; the web has no
  // files, so it uses browser storage, which may refuse 3 MB (then the
  // update lasts for the session only).

  Future<File> _savedCsvFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<MophDatasetManifest?> _readSavedManifest() async {
    final prefs = await SharedPreferences.getInstance();
    // Lists saved by older versions have no manifest to compare against.
    if (prefs.containsKey(_legacyStorageKeyCsv)) await prefs.remove(_legacyStorageKeyCsv);
    final raw = prefs.getString(_storageKeyManifest);
    return raw == null ? null : MophDatasetManifest.tryParse(raw);
  }

  Future<String?> _readSavedCsv() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_storageKeyWebCsv);
    }
    final file = await _savedCsvFile();
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> _saveDataset(MophDatasetManifest manifest, String csv) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (kIsWeb) {
        await prefs.setString(_storageKeyWebCsv, csv);
      } else {
        final file = await _savedCsvFile();
        await file.parent.create(recursive: true);
        await file.writeAsString(csv, flush: true);
      }
      // Written last: a manifest is only ever saved next to a complete list.
      await prefs.setString(_storageKeyManifest, manifest.toJsonString());
    } catch (e) {
      debugPrint('MophMedicineService: could not keep the new list offline: $e');
    }
  }

  Future<void> _clearSavedDataset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKeyManifest);
    if (kIsWeb) {
      await prefs.remove(_storageKeyWebCsv);
    } else {
      final file = await _savedCsvFile();
      if (await file.exists()) await file.delete();
    }
  }

  @visibleForTesting
  void stopAutoUpdates() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _autoUpdatesStarted = false;
  }
}

/// lebanon_medicine_prices.json, written by tools/update_moph_dataset.py next
/// to the CSV. Says which MOPH sheet the list was built from, so the app can
/// tell a new list (or a corrected re-issue of the same list) from the one it
/// has without downloading the CSV.
class MophDatasetManifest {
  const MophDatasetManifest({
    this.version = '',
    this.listDate = '',
    this.published = '',
    this.rows = 0,
    this.generatedAt = '',
    this.sha256 = '',
  });

  final String version;
  final String listDate;

  /// When MOPH published the sheet (a re-issue keeps [listDate]).
  final String published;
  final int rows;
  final String generatedAt;

  /// SHA-256 of the CSV this manifest describes, or '' for older manifests.
  final String sha256;

  static MophDatasetManifest? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map || '${json['version'] ?? ''}'.isEmpty) return null;
      return MophDatasetManifest(
        version: '${json['version']}',
        listDate: '${json['list_date'] ?? ''}',
        published: '${json['published'] ?? json['list_date'] ?? ''}',
        rows: int.tryParse('${json['rows'] ?? 0}') ?? 0,
        generatedAt: '${json['generated_at'] ?? ''}',
        sha256: '${json['sha256'] ?? ''}'.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(<String, Object>{
        'version': version,
        'list_date': listDate,
        'published': published,
        'rows': rows,
        'generated_at': generatedAt,
        'sha256': sha256,
      });

  /// Later publication wins; for the same publication, a later rebuild.
  bool isNewerThan(MophDatasetManifest other) {
    final byDate = published.compareTo(other.published);
    if (byDate != 0) return byDate > 0;
    return version != other.version && generatedAt.compareTo(other.generatedAt) > 0;
  }

  /// Whether [dataset] is the complete list this manifest describes.
  bool matches(MophDataset dataset) {
    if (dataset.medicines.isEmpty) return false;
    return rows == 0 || dataset.medicines.length == rows;
  }
}

/// One product whose official price changed with a new MOPH list.
class PriceChange {
  const PriceChange({required this.medicine, required this.oldPrice, required this.newPrice});

  final MedicinePrice medicine;
  final double oldPrice;
  final double newPrice;

  int get percent => ((newPrice - oldPrice) / oldPrice * 100).round();
}

class _SearchKeys {
  const _SearchKeys({
    required this.brand,
    required this.generic,
    required this.ingredients,
    required this.brandSkeleton,
    required this.fullBrandSkeleton,
    required this.genericSkeleton,
  });

  final String brand;
  final String generic;
  final List<String> ingredients;

  /// Consonant skeletons for searches typed in Arabic letters.
  final String brandSkeleton;
  final String fullBrandSkeleton;
  final String genericSkeleton;
}

class _ScoredMedicine {
  final MedicinePrice med;
  final double score;

  _ScoredMedicine({required this.med, required this.score});
}

enum MophSyncStage { idle, loading, checking, downloading, verifying, applying }

/// Where the list is in loading or syncing, with overall progress 0..1.
class MophSyncProgress {
  const MophSyncProgress(this.stage, this.fraction);

  static const idle = MophSyncProgress(MophSyncStage.idle, 0);

  final MophSyncStage stage;
  final double fraction;

  bool get busy => stage != MophSyncStage.idle;
  int get percent => (fraction * 100).round();

  String label({required bool isArabic}) {
    switch (stage) {
      case MophSyncStage.idle:
        return '';
      case MophSyncStage.loading:
        return appText(isArabic).loadingTheMedicineList;
      case MophSyncStage.checking:
        return appText(isArabic).checkingForNewData;
      case MophSyncStage.downloading:
        return appText(isArabic).downloadingTheNewList;
      case MophSyncStage.verifying:
        return appText(isArabic).verifyingTheList;
      case MophSyncStage.applying:
        return appText(isArabic).applyingTheUpdate;
    }
  }
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

  /// Day MOPH published that list (later than [listDate] for a re-issue).
  final String publishedDate;

  MophSyncResult({
    required this.status,
    required this.medicineCount,
    required this.listDate,
    this.publishedDate = '',
    this.detail = '',
  });

  bool get success => status != MophSyncStatus.failed;

  String describe({required bool isArabic}) {
    var date = listDate.isEmpty ? appText(isArabic).unknown : listDate;
    if (publishedDate.isNotEmpty && publishedDate != listDate) {
      date = appText(isArabic).revised(date, publishedDate);
    }

    switch (status) {
      case MophSyncStatus.updated:
        return appText(isArabic).updatedToTheMophListOf(date, formatCount(medicineCount));
      case MophSyncStatus.upToDate:
        return appText(isArabic).youAlreadyHaveTheLatestMoph(date);
      case MophSyncStatus.notConfigured:
        return appText(isArabic).usingTheMophListOfNew(date);
      case MophSyncStatus.failed:
        return appText(isArabic).couldNotCheckForANewer(date);
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

    // Every row comes from the same MOPH page, so the CSV no longer repeats it.
    if ((map['source_url'] ?? '').isEmpty) map['source_url'] = MophMedicineService.mophPublicUrl;

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
