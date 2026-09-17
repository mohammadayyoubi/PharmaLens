import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_knowledge.dart';
import '../models/medicine_price.dart';
import '../utils/medicine_normalizer.dart';
import 'medicine_alternative_service.dart';

enum SupabaseMedicineErrorCode {
  timeout,
  unavailable,
  unexpected,
}

class SupabaseMedicineException implements Exception {
  const SupabaseMedicineException({
    required this.code,
    required this.message,
  });

  final SupabaseMedicineErrorCode code;
  final String message;

  @override
  String toString() => message;
}

/// PharmaLanse online medicine search service.
///
/// Responsibilities:
///
/// 1. Search the medicine database.
/// 2. Merge RPC + V3 catalog results.
/// 3. Hydrate RPC results with V3 mapping/composition data.
/// 4. Rank results using one shared normalization engine.
/// 5. Keep search confidence separate from clinical verification.
/// 6. Delegate alternative discovery to MedicineAlternativeService.
///
/// Important:
///
/// Search results are candidates.
/// A search result is NOT automatically:
///
/// - prescription verified;
/// - clinically interchangeable;
/// - a safe substitute.
class SupabaseMedicineService {
  SupabaseMedicineService({
    SupabaseClient? client,
    MedicineAlternativeService? alternativeService,
    Duration requestTimeout = const Duration(seconds: 15),
    Duration cacheDuration = const Duration(minutes: 3),
    Duration emptyCacheDuration = const Duration(seconds: 40),
  })  : _providedClient = client,
        _providedAlternativeService = alternativeService,
        _requestTimeout = requestTimeout,
        _cacheDuration = cacheDuration,
        _emptyCacheDuration = emptyCacheDuration;

  static const String _catalogView =
      'medicine_catalog_v3';

  static const String _searchRpc =
      'search_drug_prices';

  static const String _catalogColumns = '''
medicine_id,
moph_code,
atc_code,
brand_name,
generic_name,
active_ingredients,
composition_id,
composition_key,
canonical_composition,
strength,
dosage_form,
route,
pack_size,
manufacturer,
agent,
country_of_origin,
barcode,
registration_number,
is_marketed,
is_active,
price_lbp,
currency,
effective_date,
batch_id,
source_name,
source_url,
published_date,
imported_at,
mapping_status,
mapping_method,
mapping_confidence,
is_verified,
data_source
''';

  static const Set<String> _knownDosageForms =
  <String>{
    'tablet',
    'extended release tablet',
    'prolonged release tablet',
    'modified release tablet',
    'sustained release tablet',
    'controlled release tablet',
    'enteric coated tablet',
    'chewable tablet',
    'dispersible tablet',
    'orodispersible tablet',
    'effervescent tablet',
    'sublingual tablet',
    'capsule',
    'extended release capsule',
    'modified release capsule',
    'gastro resistant capsule',
    'syrup',
    'suspension',
    'solution',
    'elixir',
    'drops',
    'ophthalmic drops',
    'otic drops',
    'cream',
    'ointment',
    'gel',
    'lotion',
    'injection',
    'powder for injection',
    'suppository',
    'patch',
    'inhaler',
    'nebulizer solution',
    'spray',
    'nasal spray',
    'powder',
    'sachet',
  };

  static final RegExp _strengthExpressionPattern =
  RegExp(
    r'\b'
    r'\d+(?:[.,]\d+)?\s*'
    r'(?:mcg|µg|μg|ug|mg|g|kg|ml|l|iu|u|units?|unit|%)'
    r'(?:\s*/\s*'
    r'\d+(?:[.,]\d+)?\s*'
    r'(?:mcg|µg|μg|ug|mg|g|kg|ml|l|iu|u|units?|unit|%))?',
    caseSensitive: false,
  );

  static final RegExp _identityNoisePattern =
  RegExp(
    r'\b(?:'
    r'film\s+coated|'
    r'coated|'
    r'extended\s+release|'
    r'prolonged\s+release|'
    r'modified\s+release|'
    r'sustained\s+release|'
    r'controlled\s+release|'
    r'enteric\s+coated|'
    r'oral|'
    r'infusion|'
    r'tablet|tablets|tab|tabs|'
    r'capsule|capsules|cap|caps|'
    r'syrup|syrups|'
    r'suspension|suspensions|'
    r'solution|solutions|'
    r'cream|creams|'
    r'ointment|ointments|'
    r'gel|gels|'
    r'lotion|lotions|'
    r'drop|drops|'
    r'injection|injections|injectable|'
    r'ampoule|ampoules|ampule|ampules|'
    r'vial|vials|'
    r'suppository|suppositories|'
    r'inhaler|inhalers|'
    r'spray|sprays|'
    r'patch|patches|'
    r'powder|powders|'
    r'sachet|sachets'
    r')\b',
    caseSensitive: false,
  );

  final SupabaseClient? _providedClient;

  final MedicineAlternativeService?
  _providedAlternativeService;

  MedicineAlternativeService?
  _lazyAlternativeService;

  final Duration _requestTimeout;
  final Duration _cacheDuration;
  final Duration _emptyCacheDuration;

  final Map<String, _MedicineSearchCacheEntry>
  _searchCache =
  <String, _MedicineSearchCacheEntry>{};

  final Map<
      String,
      Future<List<MedicinePrice>>>
  _requestsInProgress =
  <String, Future<List<MedicinePrice>>>{};

  SupabaseClient get _client {
    return _providedClient ??
        Supabase.instance.client;
  }

  MedicineAlternativeService
  get _alternativeService {
    final provided =
        _providedAlternativeService;

    if (provided != null) {
      return provided;
    }

    return _lazyAlternativeService ??=
        MedicineAlternativeService(
          client: _client,
          requestTimeout: _requestTimeout,
          cacheDuration: _cacheDuration,
        );
  }

  // ---------------------------------------------------------------------------
  // Public search API
  // ---------------------------------------------------------------------------

  Future<List<MedicinePrice>> searchMedicines(
      String query, {
        int limit = 20,
        bool forceRefresh = false,
      }) async {
    final cleanedQuery =
    MedicineNormalizer.cleanUserQuery(
      query,
    );

    if (cleanedQuery.isEmpty) {
      return const <MedicinePrice>[];
    }

    final intent =
    _buildSearchIntent(
      cleanedQuery,
    );

    if (!intent.hasMedicineIdentity) {
      return const <MedicinePrice>[];
    }

    final safeLimit =
    limit.clamp(1, 50).toInt();

    final cacheKey = <String>[
      MedicineNormalizer.normalizeText(
        cleanedQuery,
      ),
      'limit:$safeLimit',
    ].join('|');

    if (forceRefresh) {
      _searchCache.remove(cacheKey);
    } else {
      final cached =
      _readValidCache(cacheKey);

      if (cached != null) {
        return cached;
      }

      final running =
      _requestsInProgress[
      cacheKey];

      if (running != null) {
        return running;
      }
    }

    final request = _performSearch(
      originalQuery: cleanedQuery,
      intent: intent,
      limit: safeLimit,
    );

    _requestsInProgress[
    cacheKey] = request;

    try {
      final results =
      await request;

      final immutable =
      List<MedicinePrice>.unmodifiable(
        results,
      );

      final lifetime =
      immutable.isEmpty
          ? _emptyCacheDuration
          : _cacheDuration;

      _searchCache[cacheKey] =
          _MedicineSearchCacheEntry(
            results: immutable,
            expiresAt: DateTime.now().add(
              lifetime,
            ),
          );

      return immutable;
    } finally {
      _requestsInProgress.remove(
        cacheKey,
      );
    }
  }

  Future<MedicinePrice?> findBestMatch(
      String query, {
        double minimumScore = 0,
        bool forceRefresh = false,
      }) async {
    final threshold =
    minimumScore
        .clamp(0.0, 1.0)
        .toDouble();

    final results =
    await searchMedicines(
      query,
      limit: 12,
      forceRefresh: forceRefresh,
    );

    for (final medicine in results) {
      if (medicine.similarityScore >=
          threshold) {
        return medicine;
      }
    }

    return null;
  }

  Future<List<MedicinePrice>>
  searchOcrCandidates(
      List<String> candidates, {
        int resultsPerCandidate = 5,
      }) async {
    final safeLimit =
    resultsPerCandidate
        .clamp(1, 20)
        .toInt();

    final collected =
    <MedicinePrice>[];

    final seenQueries = <String>{};

    /*
     * Protect the backend from very noisy OCR output.
     *
     * A prescription normally does not require dozens of separate
     * search calls for the same medicine line.
     */
    const maxDistinctQueries = 12;

    var processedQueries = 0;

    for (final raw in candidates) {
      if (processedQueries >=
          maxDistinctQueries) {
        break;
      }

      final query =
      MedicineNormalizer.cleanUserQuery(
        raw,
      );

      final key =
      MedicineNormalizer.normalizeText(
        query,
      );

      if (query.isEmpty ||
          key.isEmpty ||
          !seenQueries.add(key)) {
        continue;
      }

      processedQueries++;

      try {
        final results =
        await searchMedicines(
          query,
          limit: safeLimit,
        );

        collected.addAll(results);
      } on SupabaseMedicineException {
        /*
         * One OCR candidate must not kill the entire
         * prescription search.
         */
      }
    }

    return List<MedicinePrice>.unmodifiable(
      _deduplicateMedicineRecords(
        collected,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Alternative discovery
  // ---------------------------------------------------------------------------

  /// Broad verified-composition alternative discovery.
  ///
  /// Different strengths/forms/routes may be returned and ranked
  /// by MedicineAlternativeService.
  Future<List<MedicinePrice>> findAlternatives(
      MedicinePrice medicine, {
        MedicineKnowledge? knowledge,
        int limit = 20,
        bool forceRefresh = false,
      }) {
    return _alternativeService.findAlternatives(
      medicine,
      knowledge: knowledge,
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }

  /// Conservative exact-presentation alternatives.
  ///
  /// This method is retained for compatibility with older callers.
  ///
  /// For the main PharmaLanse Alternatives UI, use [findAlternatives].
  Future<List<MedicinePrice>> findExactAlternatives(
      MedicinePrice medicine, {
        int limit = 6,
        bool forceRefresh = false,
      }) async {
    if (!medicine.isActive ||
        !medicine.hasAlternativeIdentity) {
      return const <MedicinePrice>[];
    }

    final safeLimit =
    limit.clamp(1, 20).toInt();

    final broadLimit =
    (safeLimit * 5)
        .clamp(20, 60)
        .toInt();

    final candidates =
    await _alternativeService
        .findAlternatives(
      medicine,
      limit: broadLimit,
      forceRefresh: forceRefresh,
    );

    final exact = candidates
        .where(
          (candidate) =>
          candidate
              .isExactAlternativeOf(
            medicine,
          ),
    )
        .toList()
      ..sort(
            (first, second) =>
            _compareExactAlternatives(
              medicine,
              first,
              second,
            ),
      );

    return List<MedicinePrice>.unmodifiable(
      exact.take(safeLimit),
    );
  }

  // ---------------------------------------------------------------------------
  // Cache management
  // ---------------------------------------------------------------------------

  void clearCache() {
    _searchCache.clear();

    _providedAlternativeService
        ?.clearCache();

    _lazyAlternativeService
        ?.clearCache();
  }

  void removeExpiredCacheEntries() {
    final now = DateTime.now();

    _searchCache.removeWhere(
          (_, entry) =>
      !entry.expiresAt.isAfter(
        now,
      ),
    );

    _providedAlternativeService
        ?.removeExpiredCacheEntries();

    _lazyAlternativeService
        ?.removeExpiredCacheEntries();
  }

  // ---------------------------------------------------------------------------
  // Main search pipeline
  // ---------------------------------------------------------------------------

  Future<List<MedicinePrice>>
  _performSearch({
    required String originalQuery,
    required _MedicineSearchIntent intent,
    required int limit,
  }) async {
    final collected =
    <String, MedicinePrice>{};

    Object? lastFailure;
    StackTrace? lastStackTrace;

    var successfulSources = 0;

    final rpcQueries = <String>[
      originalQuery,
      if (MedicineNormalizer.normalizeText(
        intent.namePhrase,
      ) !=
          MedicineNormalizer.normalizeText(
            originalQuery,
          ))
        intent.namePhrase,
    ];

    final seenRpcQueries = <String>{};

    for (final query in rpcQueries) {
      final normalizedQuery =
      MedicineNormalizer.normalizeText(
        query,
      );

      if (normalizedQuery.isEmpty ||
          !seenRpcQueries.add(
            normalizedQuery,
          )) {
        continue;
      }

      try {
        final rpcResults =
        await _searchUsingRpc(
          query,
          (limit * 6)
              .clamp(50, 120)
              .toInt(),
        );

        successfulSources++;

        _mergeProducts(
          collected,
          rpcResults,
        );
      } catch (error, stackTrace) {
        lastFailure = error;
        lastStackTrace = stackTrace;

        _debugLog(
          'Medicine RPC search failed for "$query".',
          error,
          stackTrace,
        );
      }
    }

    try {
      final catalogResults =
      await _searchUsingCatalogView(
        intent,
        limit: (limit * 12)
            .clamp(100, 350)
            .toInt(),
      );

      successfulSources++;

      _mergeProducts(
        collected,
        catalogResults,
      );
    } catch (error, stackTrace) {
      lastFailure = error;
      lastStackTrace = stackTrace;

      _debugLog(
        'Medicine V3 catalog search failed.',
        error,
        stackTrace,
      );
    }

    if (successfulSources == 0) {
      _throwSearchFailure(
        lastFailure,
        lastStackTrace,
      );
    }

    if (collected.isEmpty) {
      return const <MedicinePrice>[];
    }

    /*
     * Critical PharmaLanse V2 step:
     *
     * search_drug_prices does not necessarily return all V3 mapping
     * metadata.
     *
     * Re-read the products by medicine_id from medicine_catalog_v3
     * so composition_id, mapping status, canonical composition,
     * route, source metadata, etc. are attached before ranking.
     */
    try {
      final hydrated =
      await _hydrateCatalogRecords(
        collected.values,
      );

      _mergeProducts(
        collected,
        hydrated,
      );
    } catch (error, stackTrace) {
      /*
       * Hydration is enrichment.
       *
       * If the primary search succeeded, do not discard useful search
       * results solely because enrichment failed.
       */
      _debugLog(
        'Medicine V3 result hydration failed.',
        error,
        stackTrace,
      );
    }

    return _rankAndFilterResults(
      medicines: collected.values,
      intent: intent,
      limit: limit,
    );
  }

  // ---------------------------------------------------------------------------
  // RPC search
  // ---------------------------------------------------------------------------

  Future<List<MedicinePrice>>
  _searchUsingRpc(
      String query,
      int limit,
      ) async {
    final response = await _client
        .rpc(
      _searchRpc,
      params: <String, dynamic>{
        'p_query': query,
        'p_limit': limit,
      },
    )
        .timeout(
      _requestTimeout,
    );

    final results = _parseResponse(
      response,
      sourceFallback: _searchRpc,
    );

    _debugMessage(
      'Medicine RPC "$query": '
          '${results.length} rows.',
    );

    return results;
  }

  // ---------------------------------------------------------------------------
  // V3 catalog direct search
  // ---------------------------------------------------------------------------

  Future<List<MedicinePrice>>
  _searchUsingCatalogView(
      _MedicineSearchIntent intent, {
        required int limit,
      }) async {
    final token =
    MedicineNormalizer.safeDatabaseToken(
      intent.primaryNameToken,
    );

    if (token.isEmpty) {
      return const <MedicinePrice>[];
    }

    final response = await _client
        .from(_catalogView)
        .select(_catalogColumns)
        .or(
      'brand_name.ilike.%$token%,'
          'generic_name.ilike.%$token%,'
          'active_ingredients.ilike.%$token%,'
          'canonical_composition.ilike.%$token%',
    )
        .limit(limit)
        .timeout(
      _requestTimeout,
    );

    final results = _parseResponse(
      response,
      sourceFallback: _catalogView,
    );

    _debugMessage(
      'Medicine V3 catalog "$token": '
          '${results.length} rows.',
    );

    return results;
  }

  // ---------------------------------------------------------------------------
  // V3 hydration
  // ---------------------------------------------------------------------------

  Future<List<MedicinePrice>>
  _hydrateCatalogRecords(
      Iterable<MedicinePrice> medicines,
      ) async {
    final ids = medicines
        .map(
          (medicine) =>
          medicine.medicineId.trim(),
    )
        .where(
          (id) => id.isNotEmpty,
    )
        .toSet()
        .toList(
      growable: false,
    );

    if (ids.isEmpty) {
      return const <MedicinePrice>[];
    }

    const chunkSize = 75;

    final hydrated =
    <MedicinePrice>[];

    for (
    var start = 0;
    start < ids.length;
    start += chunkSize
    ) {
      final end =
      start + chunkSize < ids.length
          ? start + chunkSize
          : ids.length;

      final chunk =
      ids.sublist(
        start,
        end,
      );

      final response = await _client
          .from(_catalogView)
          .select(_catalogColumns)
          .inFilter(
        'medicine_id',
        chunk,
      )
          .limit(chunk.length)
          .timeout(
        _requestTimeout,
      );

      hydrated.addAll(
        _parseResponse(
          response,
          sourceFallback:
          _catalogView,
        ),
      );
    }

    return _deduplicateMedicineRecords(
      hydrated,
    );
  }

  // ---------------------------------------------------------------------------
  // Database response parsing
  // ---------------------------------------------------------------------------

  List<MedicinePrice> _parseResponse(
      dynamic response, {
        required String sourceFallback,
      }) {
    if (response is! List ||
        response.isEmpty) {
      return const <MedicinePrice>[];
    }

    final results =
    <MedicinePrice>[];

    for (final row in response) {
      if (row is! Map) {
        continue;
      }

      try {
        final json =
        Map<String, dynamic>.from(
          row,
        );

        final mappingStatus =
        json['mapping_status']
            ?.toString()
            .trim()
            .toLowerCase();

        if (json['is_verified'] == null &&
            mappingStatus != null) {
          json['is_verified'] =
              mappingStatus ==
                  'verified';
        }

        json.putIfAbsent(
          'similarity_score',
              () => 0,
        );

        json.putIfAbsent(
          'data_source',
              () => sourceFallback,
        );

        final medicine =
        MedicinePrice.fromJson(
          json,
        );

        final brand =
        MedicineNormalizer
            .normalizeMedicineName(
          medicine.brandName,
        );

        if (!medicine.isActive ||
            !medicine.hasBrandName ||
            brand.isEmpty ||
            brand ==
                'unknown medicine') {
          continue;
        }

        results.add(medicine);
      } catch (error, stackTrace) {
        _debugLog(
          'Medicine product parsing failed.',
          error,
          stackTrace,
        );
      }
    }

    return _deduplicateMedicineRecords(
      results,
    );
  }

  // ---------------------------------------------------------------------------
  // Record merging
  // ---------------------------------------------------------------------------

  void _mergeProducts(
      Map<String, MedicinePrice> target,
      Iterable<MedicinePrice> products,
      ) {
    for (final medicine in products) {
      final key =
      medicine.stableKey.trim();

      if (key.isEmpty) {
        continue;
      }

      final previous =
      target[key];

      if (previous == null) {
        target[key] = medicine;
        continue;
      }

      target[key] =
          _combineMedicineRecords(
            previous,
            medicine,
          );
    }
  }

  MedicinePrice _combineMedicineRecords(
      MedicinePrice first,
      MedicinePrice second,
      ) {
    final firstQuality =
    _recordQuality(first);

    final secondQuality =
    _recordQuality(second);

    final MedicinePrice base;
    final MedicinePrice other;

    if (secondQuality >
        firstQuality) {
      base = second;
      other = first;
    } else {
      base = first;
      other = second;
    }

    final bestSimilarity =
    math.max(
      first.similarityScore,
      second.similarityScore,
    ).toDouble();

    final bestMappingConfidence =
    math.max(
      first.mappingConfidence,
      second.mappingConfidence,
    ).toDouble();

    return base.copyWith(
      genericName: base.hasGenericName
          ? base.genericName
          : other.genericName,
      activeIngredients:
      base.hasActiveIngredients
          ? base.activeIngredients
          : other.activeIngredients,
      strength: base.hasStrength
          ? base.strength
          : other.strength,
      dosageForm:
      base.hasDosageForm
          ? base.dosageForm
          : other.dosageForm,
      route: base.hasRoute
          ? base.route
          : other.route,
      packSize:
      base.hasPackSize
          ? base.packSize
          : other.packSize,
      manufacturer:
      base.hasManufacturer
          ? base.manufacturer
          : other.manufacturer,
      atcCode: base.hasAtcCode
          ? base.atcCode
          : other.atcCode,
      registrationNumber:
      base.hasRegistrationNumber
          ? base.registrationNumber
          : other.registrationNumber,
      priceLbp: base.hasPrice
          ? base.priceLbp
          : other.priceLbp,
      currency:
      base.currency.trim().isNotEmpty
          ? base.currency
          : other.currency,
      effectiveDate:
      base.hasEffectiveDate
          ? base.effectiveDate
          : other.effectiveDate,
      similarityScore:
      bestSimilarity,
      sourceName:
      (base.sourceName?.trim().isNotEmpty ??
          false)
          ? base.sourceName
          : other.sourceName,
      sourceUrl:
      base.hasSourceUrl
          ? base.sourceUrl
          : other.sourceUrl,
      isVerified:
      base.isVerified ||
          other.isVerified,
      compositionId:
      base.hasServerCompositionId
          ? base.compositionId
          : other.compositionId,
      serverCompositionKey:
      base.hasServerCompositionKey
          ? base.serverCompositionKey
          : other.serverCompositionKey,
      canonicalComposition:
      base.hasCanonicalComposition
          ? base.canonicalComposition
          : other.canonicalComposition,
      mappingStatus:
      base.normalizedMappingStatus
          .isNotEmpty
          ? base.mappingStatus
          : other.mappingStatus,
      mappingMethod:
      base.normalizedMappingMethod
          .isNotEmpty
          ? base.mappingMethod
          : other.mappingMethod,
      mappingConfidence:
      bestMappingConfidence,
    );
  }

  // ---------------------------------------------------------------------------
  // Search ranking
  // ---------------------------------------------------------------------------

  List<MedicinePrice>
  _rankAndFilterResults({
    required Iterable<MedicinePrice>
    medicines,
    required _MedicineSearchIntent intent,
    required int limit,
  }) {
    final ranked =
    <_RankedMedicineSearchResult>[];

    for (final medicine in medicines) {
      final identity =
      _calculateIdentityMatch(
        medicine,
        intent,
      );

      /*
       * Do not accept unrelated database products merely because
       * they matched a weak substring somewhere.
       */
      if (identity.score < 0.45) {
        continue;
      }

      final strengthState =
      _strengthState(
        medicine,
        intent,
      );

      final formState =
      _dosageFormState(
        medicine,
        intent,
      );

      final finalScore =
      _calculateFinalScore(
        medicine: medicine,
        identityScore:
        identity.score,
        strengthState:
        strengthState,
        formState: formState,
        hasWrittenStrength:
        intent.hasStrength,
        hasWrittenForm:
        intent.hasDosageForm,
      );

      ranked.add(
        _RankedMedicineSearchResult(
          medicine: medicine.copyWith(
            similarityScore:
            finalScore,
            dataSource:
            medicine.dataSource
                .trim()
                .isEmpty
                ? 'supabase'
                : medicine
                .dataSource,
          ),
          identity: identity,
          strengthState:
          strengthState,
          formState: formState,
          score: finalScore,
        ),
      );
    }

    ranked.sort(
      _compareRankedResults,
    );

    final selected =
    <MedicinePrice>[];

    final used = <String>{};

    for (final result in ranked) {
      final key =
      result.medicine.stableKey
          .trim();

      if (key.isEmpty ||
          !used.add(key)) {
        continue;
      }

      selected.add(
        result.medicine,
      );

      if (selected.length >= limit) {
        break;
      }
    }

    return List<MedicinePrice>.unmodifiable(
      selected,
    );
  }

  int _compareRankedResults(
      _RankedMedicineSearchResult first,
      _RankedMedicineSearchResult second,
      ) {
    final identityPriority =
    first.identity.priority.compareTo(
      second.identity.priority,
    );

    if (identityPriority != 0) {
      return identityPriority;
    }

    final conflicts =
    first.hardConflictCount
        .compareTo(
      second.hardConflictCount,
    );

    if (conflicts != 0) {
      return conflicts;
    }

    final strength =
    first.strengthState.priority
        .compareTo(
      second.strengthState.priority,
    );

    if (strength != 0) {
      return strength;
    }

    final form =
    first.formState.priority
        .compareTo(
      second.formState.priority,
    );

    if (form != 0) {
      return form;
    }

    final score =
    second.score.compareTo(
      first.score,
    );

    if (score != 0) {
      return score;
    }

    /*
     * Search can still show unmapped products.
     *
     * Verified mappings are only used as a tie-breaker.
     * We do not hide an exact product just because its composition
     * has not yet been reviewed.
     */
    if (first.medicine
        .hasVerifiedCompositionIdentity !=
        second.medicine
            .hasVerifiedCompositionIdentity) {
      return first.medicine
          .hasVerifiedCompositionIdentity
          ? -1
          : 1;
    }

    if (first.medicine
        .isOfficialSource !=
        second.medicine
            .isOfficialSource) {
      return first.medicine
          .isOfficialSource
          ? -1
          : 1;
    }

    if (first.medicine.hasPrice !=
        second.medicine.hasPrice) {
      return first.medicine.hasPrice
          ? -1
          : 1;
    }

    return first.medicine.brandName
        .toLowerCase()
        .compareTo(
      second.medicine.brandName
          .toLowerCase(),
    );
  }

  // ---------------------------------------------------------------------------
  // Medicine identity scoring
  // ---------------------------------------------------------------------------

  _SearchIdentityMatch
  _calculateIdentityMatch(
      MedicinePrice medicine,
      _MedicineSearchIntent intent,
      ) {
    final phrase =
        intent.namePhrase;

    final brand =
    MedicineNormalizer
        .normalizeMedicineName(
      medicine.brandName,
    );

    final generic =
    _cleanIdentityField(
      medicine.genericName ?? '',
    );

    final composition =
    _cleanIdentityField(
      medicine.displayComposition,
    );

    final canonical =
    _cleanIdentityField(
      medicine.canonicalComposition ??
          '',
    );

    if (brand.isNotEmpty &&
        brand == phrase) {
      return const _SearchIdentityMatch(
        score: 1,
        priority: 0,
      );
    }

    if (generic.isNotEmpty &&
        generic == phrase) {
      return const _SearchIdentityMatch(
        score: 0.985,
        priority: 1,
      );
    }

    if (canonical.isNotEmpty &&
        canonical == phrase) {
      return const _SearchIdentityMatch(
        score: 0.975,
        priority: 2,
      );
    }

    if (composition.isNotEmpty &&
        composition == phrase) {
      return const _SearchIdentityMatch(
        score: 0.97,
        priority: 2,
      );
    }

    final brandScore =
    _identityFieldScore(
      phrase,
      brand,
    );

    final genericScore =
    _identityFieldScore(
      phrase,
      generic,
    );

    final canonicalScore =
    _identityFieldScore(
      phrase,
      canonical,
    );

    final compositionScore =
    _identityFieldScore(
      phrase,
      composition,
    );

    var bestScore =
        brandScore;

    var priority =
    brandScore >= 0.90 ? 3 : 6;

    if (genericScore >
        bestScore) {
      bestScore =
          genericScore * 0.985;

      priority =
      genericScore >= 0.90
          ? 4
          : 7;
    }

    if (canonicalScore >
        bestScore) {
      bestScore =
          canonicalScore * 0.975;

      priority =
      canonicalScore >= 0.90
          ? 4
          : 7;
    }

    if (compositionScore >
        bestScore) {
      bestScore =
          compositionScore * 0.97;

      priority =
      compositionScore >= 0.90
          ? 5
          : 8;
    }

    return _SearchIdentityMatch(
      score: bestScore,
      priority: priority,
    );
  }

  double _identityFieldScore(
      String query,
      String field,
      ) {
    if (query.isEmpty ||
        field.isEmpty) {
      return 0;
    }

    if (query == field) {
      return 1;
    }

    if (field.startsWith(
      '$query ',
    )) {
      return 0.985;
    }

    if (field.startsWith(query)) {
      final coverage =
          query.length /
              field.length;

      if (coverage >= 0.45) {
        return 0.95;
      }
    }

    if (field.contains(
      ' $query ',
    ) ||
        field.endsWith(
          ' $query',
        )) {
      return 0.91;
    }

    if (field.contains(query)) {
      final coverage =
          query.length /
              field.length;

      if (coverage >= 0.45) {
        return 0.87;
      }
    }

    final queryTokens =
    query
        .split(' ')
        .where(
          (token) =>
      token.length >= 3,
    )
        .toList();

    final fieldTokens =
    field
        .split(' ')
        .where(
          (token) =>
      token.length >= 3,
    )
        .toList();

    if (queryTokens.isEmpty ||
        fieldTokens.isEmpty) {
      return 0;
    }

    var matched = 0;
    var scoreTotal = 0.0;

    for (final queryToken
    in queryTokens) {
      var best = 0.0;

      for (final fieldToken
      in fieldTokens) {
        final score =
        _tokenSimilarity(
          queryToken,
          fieldToken,
        );

        if (score > best) {
          best = score;
        }
      }

      if (best >= 0.78) {
        matched++;
        scoreTotal += best;
      }
    }

    if (matched == 0) {
      return 0;
    }

    final coverage =
        matched /
            queryTokens.length;

    if (queryTokens.length > 1 &&
        coverage < 0.67) {
      return 0;
    }

    final average =
        scoreTotal / matched;

    if (coverage == 1) {
      return (0.72 +
          average * 0.18)
          .clamp(
        0.0,
        0.90,
      )
          .toDouble();
    }

    return 0;
  }

  double _tokenSimilarity(
      String first,
      String second,
      ) {
    if (first == second) {
      return 1;
    }

    if (first.length < 4 ||
        second.length < 4) {
      return 0;
    }

    if (second.startsWith(first) ||
        first.startsWith(second)) {
      final shorter =
      first.length <
          second.length
          ? first.length
          : second.length;

      final longer =
      first.length >
          second.length
          ? first.length
          : second.length;

      final coverage =
          shorter / longer;

      return coverage >= 0.45
          ? 0.90
          : 0;
    }

    return _normalizedEditSimilarity(
      first,
      second,
    );
  }

  // ---------------------------------------------------------------------------
  // Strength / dosage form matching
  // ---------------------------------------------------------------------------

  _VariantState _strengthState(
      MedicinePrice medicine,
      _MedicineSearchIntent intent,
      ) {
    if (!intent.hasStrength) {
      return _VariantState.notRequested;
    }

    final candidate =
    MedicineNormalizer
        .normalizeStrength(
      medicine.strength,
    );

    if (candidate.isEmpty) {
      return _VariantState.unknown;
    }

    if (intent.strengthKeys.contains(
      candidate,
    )) {
      return _VariantState.match;
    }

    return _VariantState.conflict;
  }

  _VariantState _dosageFormState(
      MedicinePrice medicine,
      _MedicineSearchIntent intent,
      ) {
    if (!intent.hasDosageForm) {
      return _VariantState.notRequested;
    }

    final candidateForm =
    _recognizedDosageForm(
      medicine.dosageForm ?? '',
    );

    if (candidateForm.isEmpty) {
      return _VariantState.unknown;
    }

    return intent.forms.contains(
      candidateForm,
    )
        ? _VariantState.match
        : _VariantState.conflict;
  }

  double _calculateFinalScore({
    required MedicinePrice medicine,
    required double identityScore,
    required _VariantState strengthState,
    required _VariantState formState,
    required bool hasWrittenStrength,
    required bool hasWrittenForm,
  }) {
    /*
     * Identity remains the dominant factor.
     *
     * Strength/form improve ordering but cannot turn an unrelated
     * product into a strong search match.
     */
    var score = identityScore;

    if (hasWrittenStrength) {
      score += switch (strengthState) {
        _VariantState.match =>
        0.035,
        _VariantState.notRequested =>
        0,
        _VariantState.unknown =>
        -0.035,
        _VariantState.conflict =>
        -0.18,
      };
    }

    if (hasWrittenForm) {
      score += switch (formState) {
        _VariantState.match =>
        0.025,
        _VariantState.notRequested =>
        0,
        _VariantState.unknown =>
        -0.025,
        _VariantState.conflict =>
        -0.14,
      };
    }

    if (medicine.isOfficialSource) {
      score += 0.005;
    }

    if (medicine
        .hasVerifiedCompositionIdentity) {
      score += 0.005;
    }

    return score
        .clamp(0.0, 1.0)
        .toDouble();
  }

  // ---------------------------------------------------------------------------
  // Query interpretation
  // ---------------------------------------------------------------------------

  _MedicineSearchIntent
  _buildSearchIntent(
      String query,
      ) {
    final namePhrase =
    _cleanIdentityField(
      query,
    );

    final nameTokens =
    namePhrase
        .split(' ')
        .where(
          (token) =>
      token.length >= 2,
    )
        .toList();

    final strengths =
    _extractStrengthKeys(
      query,
    );

    final forms = <String>{};

    final wholeForm =
    _recognizedDosageForm(
      query,
    );

    if (wholeForm.isNotEmpty) {
      forms.add(wholeForm);
    }

    return _MedicineSearchIntent(
      nameTokens:
      List<String>.unmodifiable(
        nameTokens,
      ),
      namePhrase: namePhrase,
      primaryNameToken:
      _selectPrimaryNameToken(
        nameTokens,
      ),
      strengthKeys:
      Set<String>.unmodifiable(
        strengths,
      ),
      forms:
      Set<String>.unmodifiable(
        forms,
      ),
    );
  }

  String _cleanIdentityField(
      String value,
      ) {
    var cleaned =
    MedicineNormalizer.cleanText(
      value,
    );

    if (cleaned.isEmpty) {
      return '';
    }

    cleaned = cleaned
        .replaceAll(
      _strengthExpressionPattern,
      ' ',
    )
        .replaceAll(
      _identityNoisePattern,
      ' ',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();

    /*
     * normalizeMedicineName also removes product-presentation
     * noise and applies the shared Arabic/text normalization.
     */
    return MedicineNormalizer
        .normalizeMedicineName(
      cleaned,
    );
  }

  Set<String> _extractStrengthKeys(
      String value,
      ) {
    final keys = <String>{};

    for (final match
    in _strengthExpressionPattern
        .allMatches(value)) {
      final raw =
          match.group(0) ?? '';

      final normalized =
      MedicineNormalizer
          .normalizeStrength(
        raw,
      );

      if (normalized.isEmpty) {
        continue;
      }

      keys.add(normalized);
    }

    return keys;
  }

  String _recognizedDosageForm(
      String value,
      ) {
    final normalized =
    MedicineNormalizer
        .normalizeDosageForm(
      value,
    );

    if (_knownDosageForms.contains(
      normalized,
    )) {
      return normalized;
    }

    return '';
  }

  String _selectPrimaryNameToken(
      List<String> tokens,
      ) {
    if (tokens.isEmpty) {
      return '';
    }

    var selected =
        tokens.first;

    for (final token
    in tokens.skip(1)) {
      if (token.length >
          selected.length) {
        selected = token;
      }
    }

    return selected;
  }

  // ---------------------------------------------------------------------------
  // Result quality / deduplication
  // ---------------------------------------------------------------------------

  int _recordQuality(
      MedicinePrice medicine,
      ) {
    var quality = 0;

    if (medicine
        .hasVerifiedCompositionIdentity) {
      quality += 120;
    } else if (medicine
        .isCompositionCandidate) {
      quality += 30;
    }

    if (medicine.hasMedicineId) {
      quality += 25;
    }

    if (medicine.isOfficialSource) {
      quality += 20;
    }

    if (medicine.isVerified) {
      quality += 15;
    }

    if (medicine
        .hasServerCompositionKey) {
      quality += 12;
    }

    if (medicine.hasComposition) {
      quality += 10;
    }

    if (medicine.hasCanonicalComposition) {
      quality += 8;
    }

    if (medicine.hasGenericName) {
      quality += 6;
    }

    if (medicine.hasStrength) {
      quality += 4;
    }

    if (medicine.hasDosageForm) {
      quality += 4;
    }

    if (medicine.hasRoute) {
      quality += 3;
    }

    if (medicine.hasPackSize) {
      quality += 2;
    }

    if (medicine.hasManufacturer) {
      quality += 2;
    }

    if (medicine.hasPrice) {
      quality += 2;
    }

    return quality;
  }

  List<MedicinePrice>
  _deduplicateMedicineRecords(
      Iterable<MedicinePrice> medicines,
      ) {
    final unique =
    <String, MedicinePrice>{};

    _mergeProducts(
      unique,
      medicines,
    );

    return unique.values.toList(
      growable: false,
    );
  }

  int _compareExactAlternatives(
      MedicinePrice original,
      MedicinePrice first,
      MedicinePrice second,
      ) {
    final firstDifferentBrand =
        MedicineNormalizer
            .normalizeMedicineName(
          first.brandName,
        ) !=
            MedicineNormalizer
                .normalizeMedicineName(
              original.brandName,
            );

    final secondDifferentBrand =
        MedicineNormalizer
            .normalizeMedicineName(
          second.brandName,
        ) !=
            MedicineNormalizer
                .normalizeMedicineName(
              original.brandName,
            );

    if (firstDifferentBrand !=
        secondDifferentBrand) {
      return firstDifferentBrand
          ? -1
          : 1;
    }

    if (first.isOfficialSource !=
        second.isOfficialSource) {
      return first.isOfficialSource
          ? -1
          : 1;
    }

    final brand =
    first.brandName
        .toLowerCase()
        .compareTo(
      second.brandName
          .toLowerCase(),
    );

    if (brand != 0) {
      return brand;
    }

    return (first.priceLbp ??
        double.infinity)
        .compareTo(
      second.priceLbp ??
          double.infinity,
    );
  }

  // ---------------------------------------------------------------------------
  // Fuzzy matching
  // ---------------------------------------------------------------------------

  double _normalizedEditSimilarity(
      String first,
      String second,
      ) {
    if (first.isEmpty ||
        second.isEmpty) {
      return 0;
    }

    if (first == second) {
      return 1;
    }

    final distance =
    _levenshteinDistance(
      first,
      second,
    );

    final maxLength =
    first.length >
        second.length
        ? first.length
        : second.length;

    if (maxLength == 0) {
      return 0;
    }

    return (1 -
        distance / maxLength)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  int _levenshteinDistance(
      String first,
      String second,
      ) {
    var previous =
    List<int>.generate(
      second.length + 1,
          (index) => index,
    );

    for (
    var firstIndex = 1;
    firstIndex <= first.length;
    firstIndex++
    ) {
      final current =
      List<int>.filled(
        second.length + 1,
        0,
      );

      current[0] =
          firstIndex;

      for (
      var secondIndex = 1;
      secondIndex <=
          second.length;
      secondIndex++
      ) {
        final cost =
        first.codeUnitAt(
          firstIndex - 1,
        ) ==
            second.codeUnitAt(
              secondIndex - 1,
            )
            ? 0
            : 1;

        current[secondIndex] =
            _min3(
              previous[secondIndex] + 1,
              current[secondIndex - 1] + 1,
              previous[secondIndex - 1] +
                  cost,
            );
      }

      previous = current;
    }

    return previous[
    second.length];
  }

  int _min3(
      int first,
      int second,
      int third,
      ) {
    var result = first;

    if (second < result) {
      result = second;
    }

    if (third < result) {
      result = third;
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Cache helpers
  // ---------------------------------------------------------------------------

  List<MedicinePrice>?
  _readValidCache(
      String key,
      ) {
    final entry =
    _searchCache[key];

    if (entry == null) {
      return null;
    }

    if (!entry.expiresAt.isAfter(
      DateTime.now(),
    )) {
      _searchCache.remove(key);

      return null;
    }

    return entry.results;
  }

  // ---------------------------------------------------------------------------
  // Error handling
  // ---------------------------------------------------------------------------

  Never _throwSearchFailure(
      Object? error,
      StackTrace? stackTrace,
      ) {
    if (error != null &&
        stackTrace != null) {
      _debugLog(
        'All medicine search sources failed.',
        error,
        stackTrace,
      );
    }

    if (error is TimeoutException) {
      throw const SupabaseMedicineException(
        code:
        SupabaseMedicineErrorCode.timeout,
        message:
        'Online medicine search timed out.',
      );
    }

    if (error is PostgrestException) {
      throw const SupabaseMedicineException(
        code:
        SupabaseMedicineErrorCode
            .unavailable,
        message:
        'Online medicine database is temporarily unavailable.',
      );
    }

    throw const SupabaseMedicineException(
      code:
      SupabaseMedicineErrorCode
          .unexpected,
      message:
      'Online medicine search could not be completed.',
    );
  }

  // ---------------------------------------------------------------------------
  // Debug helpers
  // ---------------------------------------------------------------------------

  void _debugMessage(
      String message,
      ) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(message);
  }

  void _debugLog(
      String message,
      Object error,
      StackTrace stackTrace,
      ) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '$message\n$error',
    );

    debugPrintStack(
      stackTrace: stackTrace,
    );
  }
}

class _MedicineSearchIntent {
  const _MedicineSearchIntent({
    required this.nameTokens,
    required this.namePhrase,
    required this.primaryNameToken,
    required this.strengthKeys,
    required this.forms,
  });

  final List<String> nameTokens;

  final String namePhrase;

  final String primaryNameToken;

  final Set<String> strengthKeys;

  final Set<String> forms;

  bool get hasMedicineIdentity {
    return nameTokens.isNotEmpty &&
        namePhrase.isNotEmpty &&
        primaryNameToken.isNotEmpty;
  }

  bool get hasStrength {
    return strengthKeys.isNotEmpty;
  }

  bool get hasDosageForm {
    return forms.isNotEmpty;
  }
}

enum _VariantState {
  match,
  notRequested,
  unknown,
  conflict;

  int get priority {
    switch (this) {
      case _VariantState.match:
        return 0;

      case _VariantState.notRequested:
        return 1;

      case _VariantState.unknown:
        return 2;

      case _VariantState.conflict:
        return 3;
    }
  }
}

class _SearchIdentityMatch {
  const _SearchIdentityMatch({
    required this.score,
    required this.priority,
  });

  final double score;
  final int priority;
}

class _RankedMedicineSearchResult {
  const _RankedMedicineSearchResult({
    required this.medicine,
    required this.identity,
    required this.strengthState,
    required this.formState,
    required this.score,
  });

  final MedicinePrice medicine;

  final _SearchIdentityMatch identity;

  final _VariantState strengthState;

  final _VariantState formState;

  final double score;

  int get hardConflictCount {
    var count = 0;

    if (strengthState ==
        _VariantState.conflict) {
      count++;
    }

    if (formState ==
        _VariantState.conflict) {
      count++;
    }

    return count;
  }
}

class _MedicineSearchCacheEntry {
  const _MedicineSearchCacheEntry({
    required this.results,
    required this.expiresAt,
  });

  final List<MedicinePrice> results;

  final DateTime expiresAt;
}