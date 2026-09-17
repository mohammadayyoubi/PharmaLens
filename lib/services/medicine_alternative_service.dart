import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_knowledge.dart';
import '../models/medicine_price.dart';
import '../utils/medicine_normalizer.dart';
import 'moph_medicine_service.dart';

enum MedicineAlternativeErrorCode {
  timeout,
  databaseUnavailable,
  unexpected,
}

class MedicineAlternativeException implements Exception {
  const MedicineAlternativeException({
    required this.code,
    required this.message,
  });

  final MedicineAlternativeErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class MedicineAlternativeService {
  MedicineAlternativeService({
    SupabaseClient? client,
    Duration requestTimeout = const Duration(seconds: 15),
    Duration cacheDuration = const Duration(minutes: 5),
    Duration emptyCacheDuration = const Duration(seconds: 45),
  })  : _client = client ?? Supabase.instance.client,
        _requestTimeout = requestTimeout,
        _cacheDuration = cacheDuration,
        _emptyCacheDuration = emptyCacheDuration;

  static const String _catalogView = 'medicine_catalog_v3';

  static const String _alternativeRpc =
      'find_medicine_alternative_ids_v3';

  static const String _catalogColumns = '''
medicine_id,
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
atc_code,
registration_number,
is_active,
price_lbp,
currency,
effective_date,
source_name,
source_url,
mapping_status,
mapping_method,
mapping_confidence,
is_verified,
data_source
''';

  final SupabaseClient _client;
  final Duration _requestTimeout;
  final Duration _cacheDuration;
  final Duration _emptyCacheDuration;

  final Map<String, _AlternativeCacheEntry> _cache =
  <String, _AlternativeCacheEntry>{};

  final Map<String, Future<List<MedicinePrice>>> _requestsInProgress =
  <String, Future<List<MedicinePrice>>>{};

  /// Finds products that share the SAME VERIFIED composition.
  ///
  /// Eligibility:
  ///
  /// - A verified V3 composition is mandatory.
  /// - Brand similarity never establishes alternative identity.
  /// - ATC similarity never establishes alternative identity.
  /// - Manufacturer never establishes alternative identity.
  ///
  /// Ranking:
  ///
  /// - Strength.
  /// - Dosage form.
  /// - Route.
  /// - Pack.
  /// - Server ranking.
  /// - Mapping confidence.
  /// - Official-source quality.
  ///
  /// Different strengths, dosage forms and routes remain discoverable.
  /// They are informational alternatives and are NOT automatically
  /// interchangeable.
  Future<List<MedicinePrice>> findAlternatives(
      MedicinePrice medicine, {
        MedicineKnowledge? knowledge,
        int limit = 40,
        bool forceRefresh = false,
      }) async {
    return MophMedicineService().findAlternatives(
      medicine,
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }

  void clearCache() {
    _cache.clear();
  }

  void removeFromCache(
      MedicinePrice medicine, {
        MedicineKnowledge? knowledge,
      }) {
    final medicineIdentity =
    _medicineCacheIdentity(medicine);

    _cache.removeWhere(
          (key, _) => key.startsWith(
        '$medicineIdentity|',
      ),
    );
  }

  void removeExpiredCacheEntries() {
    final now = DateTime.now();

    _cache.removeWhere(
          (_, entry) =>
      !entry.expiresAt.isAfter(now),
    );
  }

  Future<List<MedicinePrice>> _loadAlternatives(
      MedicinePrice medicine, {
        required MedicineKnowledge? knowledge,
        required int limit,
      }) async {
    try {
      final alternatives = await MophMedicineService().findAlternatives(
        medicine,
        limit: limit,
      );
      if (alternatives.isNotEmpty) {
        return alternatives;
      }
    } catch (_) {}

    final sourceLookup =
    await _loadCatalogProduct(
      medicine.medicineId,
    );

    final sourceCatalogProduct =
        sourceLookup.product;

    final sourceMedicine =
        sourceCatalogProduct?.medicine ??
            medicine;

    final identityResolution =
    await _resolveAlternativeIdentity(
      medicine: sourceMedicine,
      catalogProduct: sourceCatalogProduct,
      knowledge: knowledge,
    );

    final targetIdentity =
        identityResolution.identity;

    if (targetIdentity == null) {
      if (!sourceLookup.completed &&
          !identityResolution.completed) {
        throw _exceptionForFailureCodes(
          <MedicineAlternativeErrorCode?>[
            sourceLookup.errorCode,
            identityResolution.errorCode,
          ],
        );
      }

      _debugMessage(
        'Alternative search skipped for '
            '"${sourceMedicine.brandName}": '
            'no verified composition identity could be resolved.',
      );

      return const <MedicinePrice>[];
    }

    _debugMessage(
      'Alternative search started for '
          '"${sourceMedicine.brandName}". '
          'compositionId=${targetIdentity.compositionId}, '
          'compositionKey=${targetIdentity.compositionKey}, '
          'resolution=${targetIdentity.resolution.name}.',
    );

    final lookups =
    await Future.wait<_AlternativeLookupResult>(
      <Future<_AlternativeLookupResult>>[
        _findUsingRpc(
          sourceMedicine,
          sourceCatalogProduct:
          sourceCatalogProduct,
          targetIdentity: targetIdentity,
          limit: limit,
        ),
        _findUsingCatalog(
          sourceMedicine,
          targetIdentity: targetIdentity,
          limit: limit,
        ),
      ],
    );

    final rpcLookup = lookups[0];
    final catalogLookup = lookups[1];

    if (!rpcLookup.completed &&
        !catalogLookup.completed) {
      throw _exceptionForFailureCodes(
        <MedicineAlternativeErrorCode?>[
          rpcLookup.errorCode,
          catalogLookup.errorCode,
        ],
      );
    }

    final results = _mergeAndRank(
      original: sourceMedicine,
      targetIdentity: targetIdentity,
      rpcProducts: rpcLookup.products,
      catalogProducts:
      catalogLookup.products,
      limit: limit,
    );

    _debugMessage(
      'Alternative search completed for '
          '"${sourceMedicine.brandName}": '
          '${results.length} verified products.',
    );

    return results;
  }

  Future<_CatalogProductLookupResult>
  _loadCatalogProduct(
      String medicineId,
      ) async {
    final id = medicineId.trim();

    if (id.isEmpty) {
      return const _CatalogProductLookupResult(
        product: null,
        completed: true,
      );
    }

    try {
      final response = await _client
          .from(_catalogView)
          .select(_catalogColumns)
          .eq(
        'medicine_id',
        id,
      )
          .limit(1)
          .timeout(_requestTimeout);

      final products =
      _parseCatalogProducts(response);

      return _CatalogProductLookupResult(
        product: products.isEmpty
            ? null
            : products.first,
        completed: true,
      );
    } on TimeoutException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Source medicine catalog lookup timed out.',
    error,
    stackTrace,
    );

    return const _CatalogProductLookupResult(
    product: null,
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.timeout,
    );
    } on PostgrestException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Source medicine catalog lookup failed.',
    error,
    stackTrace,
    );

    return const _CatalogProductLookupResult(
    product: null,
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode
        .databaseUnavailable,
    );
    } catch (error, stackTrace) {
    _debugLog(
    'Unexpected source medicine lookup failure.',
    error,
    stackTrace,
    );

    return const _CatalogProductLookupResult(
    product: null,
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.unexpected,
    );
    }
  }

  Future<_AlternativeIdentityResolution>
  _resolveAlternativeIdentity({
    required MedicinePrice medicine,
    required _CatalogProduct? catalogProduct,
    required MedicineKnowledge? knowledge,
  }) async {
    /*
     * Strongest identity:
     *
     * The selected medicine already has a verified V3 mapping.
     */
    if (catalogProduct?.isVerified == true) {
      final compositionId =
      catalogProduct!.compositionId.trim();

      if (compositionId.isNotEmpty) {
        return _AlternativeIdentityResolution(
          identity: _AlternativeIdentity(
            compositionId: compositionId,
            compositionKey:
            catalogProduct.compositionKey,
            resolution:
            _CompositionResolution
                .verifiedSourceMapping,
          ),
          completed: true,
        );
      }
    }

    /*
     * Safe fallback:
     *
     * Use explicit composition already stored on the selected
     * medicine.
     *
     * This does NOT infer anything from the brand name.
     */
    var explicitCompositionKey =
    medicine.normalizedCompositionKey.trim();

    /*
     * A reviewed MedicineKnowledge record can only contribute
     * composition identity when it belongs to this exact medicine.
     *
     * Ingredient-level or brand-level clinical profiles are never
     * allowed to establish alternative identity here.
     */
    if (explicitCompositionKey.isEmpty &&
        _knowledgeBelongsToExactMedicine(
          medicine,
          knowledge,
        )) {
      explicitCompositionKey =
          MedicineNormalizer.compositionKey(
            activeIngredients:
            knowledge!.activeIngredients,
            genericName: knowledge.genericName,
          ).trim();
    }

    if (explicitCompositionKey.isEmpty) {
      return const _AlternativeIdentityResolution(
        identity: null,
        completed: true,
      );
    }

    return _resolveCompositionFromVerifiedCatalog(
      medicine: medicine,
      knowledge: knowledge,
      explicitCompositionKey:
      explicitCompositionKey,
    );
  }

  Future<_AlternativeIdentityResolution>
  _resolveCompositionFromVerifiedCatalog({
    required MedicinePrice medicine,
    required MedicineKnowledge? knowledge,
    required String explicitCompositionKey,
  }) async {
    final exactGenericTerms = <String>[];
    final ingredientTerms = <String>[];

    void addGeneric(String? value) {
      final cleaned = _cleanSearchValue(
        value ?? '',
      );

      if (cleaned.isEmpty) {
        return;
      }

      if (!exactGenericTerms.any(
            (existing) =>
        existing.toLowerCase() ==
            cleaned.toLowerCase(),
      )) {
        exactGenericTerms.add(cleaned);
      }
    }

    void addIngredient(String value) {
      final cleaned = _cleanSearchValue(value);

      if (cleaned.length < 3) {
        return;
      }

      if (!ingredientTerms.any(
            (existing) =>
        existing.toLowerCase() ==
            cleaned.toLowerCase(),
      )) {
        ingredientTerms.add(cleaned);
      }
    }

    addGeneric(medicine.genericName);

    for (final ingredient
    in medicine.activeIngredients) {
      addIngredient(ingredient);
    }

    if (_knowledgeBelongsToExactMedicine(
      medicine,
      knowledge,
    )) {
      addGeneric(knowledge!.genericName);

      for (final ingredient
      in knowledge.activeIngredients) {
        addIngredient(ingredient);
      }
    }

    if (exactGenericTerms.isEmpty &&
        ingredientTerms.isEmpty) {
      return const _AlternativeIdentityResolution(
        identity: null,
        completed: true,
      );
    }

    final requests =
    <Future<_CatalogQueryResult>>[];

    for (final generic
    in exactGenericTerms.take(3)) {
      requests.add(
        _queryVerifiedCatalogByGeneric(
          generic,
        ),
      );
    }

    for (final ingredient
    in ingredientTerms.take(4)) {
      requests.add(
        _queryVerifiedCatalogByIngredient(
          ingredient,
        ),
      );
    }

    final queryResults =
    await Future.wait<_CatalogQueryResult>(
      requests,
    );

    final completedQueries =
    queryResults.where(
          (result) => result.completed,
    );

    if (completedQueries.isEmpty) {
      return _AlternativeIdentityResolution(
        identity: null,
        completed: false,
        errorCode: _bestFailureCode(
          queryResults
              .map(
                (result) =>
            result.errorCode,
          )
              .toList(),
        ),
      );
    }

    final candidates = <_CatalogProduct>[];

    for (final result in queryResults) {
      candidates.addAll(result.products);
    }

    final matchingCandidates =
    _deduplicateCatalogProducts(
      candidates.where(
            (candidate) {
          if (!candidate.isVerified) {
            return false;
          }

          final candidateComposition =
          candidate
              .medicine
              .normalizedCompositionKey
              .trim();

          if (candidateComposition.isEmpty) {
            return false;
          }

          return candidateComposition ==
              explicitCompositionKey;
        },
      ),
    );

    if (matchingCandidates.isEmpty) {
      return const _AlternativeIdentityResolution(
        identity: null,
        completed: true,
      );
    }

    final compositionIds =
    matchingCandidates
        .map(
          (product) =>
          product.compositionId.trim(),
    )
        .where(
          (id) => id.isNotEmpty,
    )
        .toSet();

    /*
     * Safety rule:
     *
     * The explicit composition must resolve to exactly ONE
     * verified V3 composition.
     *
     * Multiple composition IDs means the server registry is
     * ambiguous and must be reviewed instead of guessed.
     */
    if (compositionIds.length != 1) {
      _debugMessage(
        'Composition resolution rejected for '
            '"${medicine.brandName}": '
            '${compositionIds.length} verified '
            'composition IDs matched the same client composition.',
      );

      return const _AlternativeIdentityResolution(
        identity: null,
        completed: true,
      );
    }

    final compositionId =
        compositionIds.single;

    final selected = matchingCandidates
        .where(
          (product) =>
      product.compositionId.trim() ==
          compositionId,
    )
        .toList()
      ..sort(
            (first, second) =>
            _catalogProductQuality(second)
                .compareTo(
              _catalogProductQuality(first),
            ),
      );

    final best = selected.first;

    return _AlternativeIdentityResolution(
      identity: _AlternativeIdentity(
        compositionId: compositionId,
        compositionKey: best.compositionKey,
        resolution:
        _CompositionResolution
            .explicitComposition,
      ),
      completed: true,
    );
  }

  Future<_CatalogQueryResult>
  _queryVerifiedCatalogByGeneric(
      String genericName,
      ) async {
    try {
      final response = await _client
          .from(_catalogView)
          .select(_catalogColumns)
          .eq(
        'mapping_status',
        'verified',
      )
          .eq(
        'is_active',
        true,
      )
          .ilike(
        'generic_name',
        genericName,
      )
          .limit(120)
          .timeout(_requestTimeout);

      return _CatalogQueryResult(
        products:
        _parseCatalogProducts(response),
        completed: true,
      );
    } on TimeoutException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Composition generic-name lookup timed out.',
    error,
    stackTrace,
    );

    return const _CatalogQueryResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.timeout,
    );
    } on PostgrestException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Composition generic-name lookup failed.',
    error,
    stackTrace,
    );

    return const _CatalogQueryResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode
        .databaseUnavailable,
    );
    } catch (error, stackTrace) {
    _debugLog(
    'Unexpected generic-name composition lookup failure.',
    error,
    stackTrace,
    );

    return const _CatalogQueryResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.unexpected,
    );
    }
  }

  Future<_CatalogQueryResult>
  _queryVerifiedCatalogByIngredient(
      String ingredient,
      ) async {
    final term = _safeContainsTerm(
      ingredient,
    );

    if (term.isEmpty) {
      return const _CatalogQueryResult(
        completed: true,
      );
    }

    try {
      final response = await _client
          .from(_catalogView)
          .select(_catalogColumns)
          .eq(
        'mapping_status',
        'verified',
      )
          .eq(
        'is_active',
        true,
      )
          .ilike(
        'active_ingredients',
        '%$term%',
      )
          .limit(160)
          .timeout(_requestTimeout);

      return _CatalogQueryResult(
        products:
        _parseCatalogProducts(response),
        completed: true,
      );
    } on TimeoutException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Composition ingredient lookup timed out.',
    error,
    stackTrace,
    );

    return const _CatalogQueryResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.timeout,
    );
    } on PostgrestException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Composition ingredient lookup failed.',
    error,
    stackTrace,
    );

    return const _CatalogQueryResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode
        .databaseUnavailable,
    );
    } catch (error, stackTrace) {
    _debugLog(
    'Unexpected ingredient composition lookup failure.',
    error,
    stackTrace,
    );

    return const _CatalogQueryResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.unexpected,
    );
    }
  }

  Future<_AlternativeLookupResult> _findUsingRpc(
      MedicinePrice medicine, {
        required _CatalogProduct?
        sourceCatalogProduct,
        required _AlternativeIdentity targetIdentity,
        required int limit,
      }) async {
    /*
     * The V3 RPC itself requires the source medicine to have a
     * verified profile.
     *
     * Do not call it for an unmapped source. The direct
     * composition-ID query below handles safely resolved unmapped
     * source products.
     */
    if (sourceCatalogProduct?.isVerified != true) {
      return const _AlternativeLookupResult(
        completed: true,
      );
    }

    final medicineId =
    medicine.medicineId.trim();

    if (medicineId.isEmpty) {
      return const _AlternativeLookupResult(
        completed: true,
      );
    }

    try {
      final response = await _client
          .rpc(
        _alternativeRpc,
        params: <String, dynamic>{
          'p_medicine_id': medicineId,
          'p_limit': (limit * 8)
              .clamp(
            50,
            300,
          )
              .toInt(),
        },
      )
          .timeout(_requestTimeout);

      final ranks =
      _parseAlternativeRanks(response);

      if (ranks.isEmpty) {
        return const _AlternativeLookupResult(
          completed: true,
        );
      }

      final batchLookup =
      await _loadCatalogProductsByIds(
        ranks.keys.toList(
          growable: false,
        ),
      );

      if (!batchLookup.completed) {
        return _AlternativeLookupResult(
          completed: false,
          errorCode: batchLookup.errorCode,
        );
      }

      final results =
      <_RankedAlternative>[];

      for (final product
      in batchLookup.products) {
        if (!_candidateMatchesTarget(
          product,
          targetIdentity,
        )) {
          continue;
        }

        if (_sameProduct(
          medicine,
          product.medicine,
        )) {
          continue;
        }

        final alternativeId =
        product.medicine.medicineId.trim();

        results.add(
          _RankedAlternative(
            catalogProduct: product,
            databaseRank:
            ranks[alternativeId] ??
                999999,
          ),
        );
      }

      return _AlternativeLookupResult(
        products: results,
        completed: true,
      );
    } on TimeoutException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Alternative V3 RPC timed out.',
    error,
    stackTrace,
    );

    return const _AlternativeLookupResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.timeout,
    );
    } on PostgrestException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Alternative V3 RPC failed.',
    error,
    stackTrace,
    );

    return const _AlternativeLookupResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode
        .databaseUnavailable,
    );
    } catch (error, stackTrace) {
    _debugLog(
    'Unexpected alternative RPC failure.',
    error,
    stackTrace,
    );

    return const _AlternativeLookupResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.unexpected,
    );
    }
  }

  Future<_AlternativeLookupResult>
  _findUsingCatalog(
      MedicinePrice medicine, {
        required _AlternativeIdentity targetIdentity,
        required int limit,
      }) async {
    final compositionId =
    targetIdentity.compositionId.trim();

    if (compositionId.isEmpty) {
      return const _AlternativeLookupResult(
        completed: true,
      );
    }

    try {
      final response = await _client
          .from(_catalogView)
          .select(_catalogColumns)
          .eq(
        'mapping_status',
        'verified',
      )
          .eq(
        'composition_id',
        compositionId,
      )
          .eq(
        'is_active',
        true,
      )
          .limit(
        (limit * 12)
            .clamp(
          80,
          500,
        )
            .toInt(),
      )
          .timeout(_requestTimeout);

      final products =
      _parseCatalogProducts(response);

      final results =
      <_RankedAlternative>[];

      for (final product in products) {
        if (!_candidateMatchesTarget(
          product,
          targetIdentity,
        )) {
          continue;
        }

        if (_sameProduct(
          medicine,
          product.medicine,
        )) {
          continue;
        }

        results.add(
          _RankedAlternative(
            catalogProduct: product,
            databaseRank: 999999,
          ),
        );
      }

      return _AlternativeLookupResult(
        products: results,
        completed: true,
      );
    } on TimeoutException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Direct composition-ID alternative lookup timed out.',
    error,
    stackTrace,
    );

    return const _AlternativeLookupResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.timeout,
    );
    } on PostgrestException catch (
    error,
    stackTrace
    ) {
    _debugLog(
    'Direct composition-ID alternative lookup failed.',
    error,
    stackTrace,
    );

    return const _AlternativeLookupResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode
        .databaseUnavailable,
    );
    } catch (error, stackTrace) {
    _debugLog(
    'Unexpected composition-ID alternative lookup failure.',
    error,
    stackTrace,
    );

    return const _AlternativeLookupResult(
    completed: false,
    errorCode:
    MedicineAlternativeErrorCode.unexpected,
    );
    }
  }

  Future<_CatalogBatchLookupResult>
  _loadCatalogProductsByIds(
      List<String> medicineIds,
      ) async {
    final ids = medicineIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(
      growable: false,
    );

    if (ids.isEmpty) {
      return const _CatalogBatchLookupResult(
        completed: true,
      );
    }

    const chunkSize = 70;

    final results =
    <_CatalogProduct>[];

    var completedChunks = 0;

    final failureCodes =
    <MedicineAlternativeErrorCode>[];

    for (
    var start = 0;
    start < ids.length;
    start += chunkSize
    ) {
      final end =
      (start + chunkSize < ids.length)
          ? start + chunkSize
          : ids.length;

      final chunk = ids.sublist(
        start,
        end,
      );

      try {
        final response = await _client
            .from(_catalogView)
            .select(_catalogColumns)
            .inFilter(
          'medicine_id',
          chunk,
        )
            .limit(chunk.length)
            .timeout(_requestTimeout);

        completedChunks++;

        results.addAll(
          _parseCatalogProducts(response),
        );
      } on TimeoutException catch (
    error,
    stackTrace
    ) {
    failureCodes.add(
    MedicineAlternativeErrorCode.timeout,
    );

    _debugLog(
    'Alternative catalog batch lookup timed out.',
    error,
    stackTrace,
    );
    } on PostgrestException catch (
    error,
    stackTrace
    ) {
    failureCodes.add(
    MedicineAlternativeErrorCode
        .databaseUnavailable,
    );

    _debugLog(
    'Alternative catalog batch lookup failed.',
    error,
    stackTrace,
    );
    } catch (error, stackTrace) {
    failureCodes.add(
    MedicineAlternativeErrorCode.unexpected,
    );

    _debugLog(
    'Unexpected alternative catalog batch lookup failure.',
    error,
    stackTrace,
    );
    }
    }

    if (completedChunks == 0) {
    return _CatalogBatchLookupResult(
    completed: false,
    errorCode:
    _bestFailureCode(failureCodes),
    );
    }

    return _CatalogBatchLookupResult(
    products:
    _deduplicateCatalogProducts(
    results,
    ),
    completed: true,
    );
  }

  bool _candidateMatchesTarget(
      _CatalogProduct product,
      _AlternativeIdentity target,
      ) {
    if (!product.isVerified) {
      return false;
    }

    final candidateCompositionId =
    product.compositionId.trim();

    final targetCompositionId =
    target.compositionId.trim();

    if (candidateCompositionId.isEmpty ||
        targetCompositionId.isEmpty) {
      return false;
    }

    return candidateCompositionId ==
        targetCompositionId;
  }

  Map<String, int> _parseAlternativeRanks(
      dynamic response,
      ) {
    if (response is! List) {
      return const <String, int>{};
    }

    final ranks = <String, int>{};

    for (
    var index = 0;
    index < response.length;
    index++
    ) {
      final row = response[index];

      if (row is! Map) {
        continue;
      }

      final id = row['medicine_id']
          ?.toString()
          .trim() ??
          '';

      if (id.isEmpty) {
        continue;
      }

      final rank =
          _toInt(row['rank']) ??
              index;

      final previous = ranks[id];

      if (previous == null ||
          rank < previous) {
        ranks[id] = rank;
      }
    }

    return ranks;
  }

  List<_CatalogProduct> _parseCatalogProducts(
      dynamic response,
      ) {
    if (response is! List ||
        response.isEmpty) {
      return const <_CatalogProduct>[];
    }

    final results =
    <_CatalogProduct>[];

    for (final row in response) {
      if (row is! Map) {
        continue;
      }

      try {
        final json =
        Map<String, dynamic>.from(row);

        json.putIfAbsent(
          'data_source',
              () => 'supabase_v3',
        );

        json.putIfAbsent(
          'similarity_score',
              () => 0,
        );

        final medicine =
        MedicinePrice.fromJson(json);

        if (!medicine.isActive ||
            !medicine.hasBrandName) {
          continue;
        }

        final compositionId =
            json['composition_id']
                ?.toString()
                .trim() ??
                '';

        final compositionKey =
            json['composition_key']
                ?.toString()
                .trim() ??
                '';

        final mappingStatus =
            json['mapping_status']
                ?.toString()
                .trim()
                .toLowerCase() ??
                'unmapped';

        final mappingMethod =
            json['mapping_method']
                ?.toString()
                .trim()
                .toLowerCase() ??
                'none';

        results.add(
          _CatalogProduct(
            medicine: medicine,
            compositionId: compositionId,
            compositionKey:
            compositionKey,
            mappingStatus:
            mappingStatus,
            mappingMethod:
            mappingMethod,
            mappingConfidence:
            _toDouble(
              json['mapping_confidence'],
            ),
          ),
        );
      } catch (error, stackTrace) {
        _debugLog(
          'V3 catalog product parsing failed.',
          error,
          stackTrace,
        );
      }
    }

    return _deduplicateCatalogProducts(
      results,
    );
  }

  List<_CatalogProduct>
  _deduplicateCatalogProducts(
      Iterable<_CatalogProduct> products,
      ) {
    final unique =
    <String, _CatalogProduct>{};

    for (final product in products) {
      final key = _productKey(
        product.medicine,
      );

      if (key.isEmpty) {
        continue;
      }

      final previous = unique[key];

      if (previous == null ||
          _catalogProductQuality(product) >
              _catalogProductQuality(
                previous,
              )) {
        unique[key] = product;
      }
    }

    return unique.values.toList(
      growable: false,
    );
  }

  int _catalogProductQuality(
      _CatalogProduct product,
      ) {
    var score = 0;

    if (product.isVerified) {
      score += 1000;
    }

    if (product.compositionId
        .trim()
        .isNotEmpty) {
      score += 100;
    }

    if (product.mappingConfidence >=
        0.99) {
      score += 50;
    } else if (product.mappingConfidence >=
        0.95) {
      score += 40;
    } else if (product.mappingConfidence >=
        0.90) {
      score += 30;
    }

    if (product.medicine.isOfficialSource) {
      score += 20;
    }

    if (product.medicine.hasMedicineId) {
      score += 10;
    }

    if (product.medicine.hasComposition) {
      score += 10;
    }

    if (product.medicine.hasStrength) {
      score += 5;
    }

    if (product.medicine.hasDosageForm) {
      score += 4;
    }

    if (product.medicine.hasRoute) {
      score += 3;
    }

    if (product.medicine.hasPackSize) {
      score += 2;
    }

    if (product.medicine.hasPrice) {
      score += 1;
    }

    return score;
  }

  List<MedicinePrice> _mergeAndRank({
    required MedicinePrice original,
    required _AlternativeIdentity targetIdentity,
    required List<_RankedAlternative>
    rpcProducts,
    required List<_RankedAlternative>
    catalogProducts,
    required int limit,
  }) {
    final unique =
    <String, _RankedAlternative>{};

    for (final ranked
    in <_RankedAlternative>[
      ...rpcProducts,
      ...catalogProducts,
    ]) {
      final product =
          ranked.catalogProduct;

      final alternative =
          product.medicine;

      if (!_candidateMatchesTarget(
        product,
        targetIdentity,
      )) {
        continue;
      }

      if (_sameProduct(
        original,
        alternative,
      )) {
        continue;
      }

      final key = _productKey(
        alternative,
      );

      if (key.isEmpty) {
        continue;
      }

      final previous = unique[key];

      if (previous == null ||
          _isBetterDuplicate(
            ranked,
            previous,
          )) {
        unique[key] = ranked;
      }
    }

    final rankedProducts =
    unique.values.toList()
      ..sort(
            (first, second) {
          final firstMedicine =
              first
                  .catalogProduct
                  .medicine;

          final secondMedicine =
              second
                  .catalogProduct
                  .medicine;

          final compatibility =
          _compatibilityRank(
            original,
            firstMedicine,
          ).compareTo(
            _compatibilityRank(
              original,
              secondMedicine,
            ),
          );

          if (compatibility != 0) {
            return compatibility;
          }

          /*
               * Prefer another brand when presentation
               * compatibility is otherwise equal.
               */
          final firstDifferentBrand =
          !_sameBrand(
            original,
            firstMedicine,
          );

          final secondDifferentBrand =
          !_sameBrand(
            original,
            secondMedicine,
          );

          if (firstDifferentBrand !=
              secondDifferentBrand) {
            return firstDifferentBrand
                ? -1
                : 1;
          }

          final databaseRank =
          first.databaseRank.compareTo(
            second.databaseRank,
          );

          if (databaseRank != 0) {
            return databaseRank;
          }

          final confidence =
          second
              .catalogProduct
              .mappingConfidence
              .compareTo(
            first
                .catalogProduct
                .mappingConfidence,
          );

          if (confidence != 0) {
            return confidence;
          }

          if (firstMedicine
              .isOfficialSource !=
              secondMedicine
                  .isOfficialSource) {
            return firstMedicine
                .isOfficialSource
                ? -1
                : 1;
          }

          if (firstMedicine.hasPrice !=
              secondMedicine.hasPrice) {
            return firstMedicine.hasPrice
                ? -1
                : 1;
          }

          final brandComparison =
          firstMedicine.brandName
              .toLowerCase()
              .compareTo(
            secondMedicine.brandName
                .toLowerCase(),
          );

          if (brandComparison != 0) {
            return brandComparison;
          }

          final strengthComparison =
          firstMedicine
              .displayStrength
              .toLowerCase()
              .compareTo(
            secondMedicine
                .displayStrength
                .toLowerCase(),
          );

          if (strengthComparison != 0) {
            return strengthComparison;
          }

          final formComparison =
          firstMedicine
              .displayDosageForm
              .toLowerCase()
              .compareTo(
            secondMedicine
                .displayDosageForm
                .toLowerCase(),
          );

          if (formComparison != 0) {
            return formComparison;
          }

          return firstMedicine
              .displayPackSize
              .toLowerCase()
              .compareTo(
            secondMedicine
                .displayPackSize
                .toLowerCase(),
          );
        },
      );

    return _selectBrandDiverseResults(
      rankedProducts,
      limit,
    );
  }

  bool _isBetterDuplicate(
      _RankedAlternative first,
      _RankedAlternative second,
      ) {
    if (first.databaseRank !=
        second.databaseRank) {
      return first.databaseRank <
          second.databaseRank;
    }

    final firstQuality =
    _catalogProductQuality(
      first.catalogProduct,
    );

    final secondQuality =
    _catalogProductQuality(
      second.catalogProduct,
    );

    if (firstQuality != secondQuality) {
      return firstQuality > secondQuality;
    }

    return false;
  }

  List<MedicinePrice>
  _selectBrandDiverseResults(
      List<_RankedAlternative>
      rankedProducts,
      int limit,
      ) {
    final selected =
    <MedicinePrice>[];

    final usedProducts = <String>{};
    final usedBrands = <String>{};

    /*
     * Pass 1:
     *
     * Prefer one presentation from each available brand.
     */
    for (final ranked in rankedProducts) {
      if (selected.length >= limit) {
        break;
      }

      final medicine =
          ranked.catalogProduct.medicine;

      final productKey =
      _productKey(medicine);

      if (productKey.isEmpty ||
          usedProducts.contains(
            productKey,
          )) {
        continue;
      }

      final brandKey =
      MedicineNormalizer
          .normalizeMedicineName(
        medicine.brandName,
      );

      if (brandKey.isEmpty ||
          usedBrands.contains(
            brandKey,
          )) {
        continue;
      }

      usedProducts.add(productKey);
      usedBrands.add(brandKey);

      selected.add(medicine);
    }

    /*
     * Pass 2:
     *
     * Fill remaining space with extra strengths,
     * forms, routes and packs.
     */
    if (selected.length < limit) {
      for (final ranked
      in rankedProducts) {
        if (selected.length >= limit) {
          break;
        }

        final medicine =
            ranked.catalogProduct.medicine;

        final productKey =
        _productKey(medicine);

        if (productKey.isEmpty ||
            !usedProducts.add(
              productKey,
            )) {
          continue;
        }

        selected.add(medicine);
      }
    }

    return List<MedicinePrice>.unmodifiable(
      selected,
    );
  }

  /// Lower score = closer product presentation.
  ///
  /// Missing data is treated as unknown, not as a confirmed
  /// mismatch.
  int _compatibilityRank(
      MedicinePrice original,
      MedicinePrice alternative,
      ) {
    final strengthPenalty =
    _comparisonPenalty(
      original.normalizedStrength,
      alternative.normalizedStrength,
      mismatchPenalty: 4,
    );

    final formPenalty =
    _comparisonPenalty(
      original.normalizedDosageForm,
      alternative.normalizedDosageForm,
      mismatchPenalty: 3,
    );

    final routePenalty =
    _comparisonPenalty(
      original.normalizedRoute,
      alternative.normalizedRoute,
      mismatchPenalty: 4,
    );

    final packPenalty =
    _comparisonPenalty(
      MedicineNormalizer.normalizeText(
        original.packSize,
      ),
      MedicineNormalizer.normalizeText(
        alternative.packSize,
      ),
      mismatchPenalty: 2,
    );

    return strengthPenalty * 1000 +
        formPenalty * 100 +
        routePenalty * 10 +
        packPenalty;
  }

  int _comparisonPenalty(
      String first,
      String second, {
        required int mismatchPenalty,
      }) {
    final firstValue = first.trim();
    final secondValue = second.trim();

    if (firstValue.isEmpty &&
        secondValue.isEmpty) {
      return 1;
    }

    if (firstValue.isEmpty ||
        secondValue.isEmpty) {
      return 1;
    }

    if (firstValue == secondValue) {
      return 0;
    }

    return mismatchPenalty;
  }

  bool _knowledgeBelongsToExactMedicine(
      MedicinePrice medicine,
      MedicineKnowledge? knowledge,
      ) {
    if (knowledge == null) {
      return false;
    }

    if (!knowledge.isVerified ||
        !knowledge.hasComposition) {
      return false;
    }

    /*
     * When available, keep the strongest review/audit requirement.
     */
    if (!knowledge.canBeDisplayedAsReviewed) {
      return false;
    }

    final medicineId =
    MedicineNormalizer.normalizeIdentity(
      medicine.medicineId,
    );

    final knowledgeId =
    MedicineNormalizer.normalizeIdentity(
      knowledge.medicineId,
    );

    if (medicineId.isEmpty ||
        knowledgeId.isEmpty) {
      return false;
    }

    return medicineId == knowledgeId;
  }

  bool _sameBrand(
      MedicinePrice first,
      MedicinePrice second,
      ) {
    final firstBrand =
    MedicineNormalizer.normalizeMedicineName(
      first.brandName,
    );

    final secondBrand =
    MedicineNormalizer.normalizeMedicineName(
      second.brandName,
    );

    return firstBrand.isNotEmpty &&
        secondBrand.isNotEmpty &&
        firstBrand == secondBrand;
  }

  bool _sameProduct(
      MedicinePrice first,
      MedicinePrice second,
      ) {
    final firstId =
    MedicineNormalizer.normalizeIdentity(
      first.medicineId,
    );

    final secondId =
    MedicineNormalizer.normalizeIdentity(
      second.medicineId,
    );

    if (firstId.isNotEmpty &&
        secondId.isNotEmpty &&
        firstId == secondId) {
      return true;
    }

    return _productKey(first) ==
        _productKey(second);
  }

  String _productKey(
      MedicinePrice medicine,
      ) {
    /*
     * Use semantic product identity instead of medicineId alone.
     *
     * This prevents duplicate catalog rows representing the same
     * presentation from filling the alternatives list.
     */
    final semanticKey = <String>[
      MedicineNormalizer.normalizeMedicineName(
        medicine.brandName,
      ),
      medicine.normalizedCompositionKey,
      medicine.normalizedStrength,
      medicine.normalizedDosageForm,
      medicine.normalizedRoute,
      MedicineNormalizer.normalizeText(
        medicine.packSize,
      ),
      MedicineNormalizer.normalizeText(
        medicine.manufacturer,
      ),
    ].join('|');

    final semanticHasIdentity =
        MedicineNormalizer
            .normalizeMedicineName(
          medicine.brandName,
        )
            .isNotEmpty ||
            medicine.normalizedCompositionKey
                .isNotEmpty;

    if (semanticHasIdentity) {
      return semanticKey;
    }

    return MedicineNormalizer.normalizeIdentity(
      medicine.medicineId,
    );
  }

  String _cacheKey({
    required MedicinePrice medicine,
    required MedicineKnowledge? knowledge,
    required int limit,
  }) {
    final identity =
    _medicineCacheIdentity(medicine);

    var knowledgeComposition = '';

    if (_knowledgeBelongsToExactMedicine(
      medicine,
      knowledge,
    )) {
      knowledgeComposition =
          MedicineNormalizer.compositionKey(
            activeIngredients:
            knowledge!.activeIngredients,
            genericName: knowledge.genericName,
          );
    }

    return <String>[
      identity,
      'knowledge:$knowledgeComposition',
      'limit:$limit',
    ].join('|');
  }

  String _medicineCacheIdentity(
      MedicinePrice medicine,
      ) {
    final id =
    MedicineNormalizer.normalizeIdentity(
      medicine.medicineId,
    );

    if (id.isNotEmpty) {
      return 'id:$id';
    }

    return <String>[
      'product',
      MedicineNormalizer.normalizeMedicineName(
        medicine.brandName,
      ),
      medicine.normalizedCompositionKey,
      medicine.normalizedStrength,
      medicine.normalizedDosageForm,
      medicine.normalizedRoute,
    ].join('|');
  }

  List<MedicinePrice>? _readValidCache(
      String key,
      ) {
    final entry = _cache[key];

    if (entry == null) {
      return null;
    }

    if (!entry.expiresAt.isAfter(
      DateTime.now(),
    )) {
      _cache.remove(key);
      return null;
    }

    return entry.results;
  }

  String _cleanSearchValue(
      String value,
      ) {
    return value
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(
      RegExp(
        r'[^a-zA-Z0-9\u0600-\u06FF .,+&/\-]',
      ),
      ' ',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  String _safeContainsTerm(
      String value,
      ) {
    return _cleanSearchValue(value)
        .replaceAll(',', ' ')
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  MedicineAlternativeException
  _exceptionForFailureCodes(
      Iterable<MedicineAlternativeErrorCode?>
      codes,
      ) {
    final code = _bestFailureCode(codes) ??
        MedicineAlternativeErrorCode
            .databaseUnavailable;

    switch (code) {
      case MedicineAlternativeErrorCode.timeout:
        return const MedicineAlternativeException(
          code:
          MedicineAlternativeErrorCode.timeout,
          message:
          'Medicine alternatives request timed out.',
        );

      case MedicineAlternativeErrorCode
          .databaseUnavailable:
        return const MedicineAlternativeException(
          code:
          MedicineAlternativeErrorCode
              .databaseUnavailable,
          message:
          'Medicine alternatives are temporarily unavailable.',
        );

      case MedicineAlternativeErrorCode.unexpected:
        return const MedicineAlternativeException(
          code:
          MedicineAlternativeErrorCode.unexpected,
          message:
          'Medicine alternatives could not be loaded.',
        );
    }
  }

  MedicineAlternativeErrorCode? _bestFailureCode(
      Iterable<MedicineAlternativeErrorCode?>
      codes,
      ) {
    final values =
    codes.whereType<
        MedicineAlternativeErrorCode>();

    if (values.contains(
      MedicineAlternativeErrorCode
          .databaseUnavailable,
    )) {
      return MedicineAlternativeErrorCode
          .databaseUnavailable;
    }

    if (values.contains(
      MedicineAlternativeErrorCode.timeout,
    )) {
      return MedicineAlternativeErrorCode.timeout;
    }

    if (values.contains(
      MedicineAlternativeErrorCode.unexpected,
    )) {
      return MedicineAlternativeErrorCode.unexpected;
    }

    return null;
  }

  int? _toInt(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString().trim(),
    );
  }

  double _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      final result = value.toDouble();

      if (!result.isFinite) {
        return 0;
      }

      return result;
    }

    final parsed = double.tryParse(
      value.toString().trim(),
    );

    if (parsed == null ||
        !parsed.isFinite) {
      return 0;
    }

    return parsed;
  }

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

enum _CompositionResolution {
  verifiedSourceMapping,
  explicitComposition,
}

class _AlternativeIdentity {
  const _AlternativeIdentity({
    required this.compositionId,
    required this.compositionKey,
    required this.resolution,
  });

  final String compositionId;
  final String compositionKey;
  final _CompositionResolution resolution;
}

class _AlternativeIdentityResolution {
  const _AlternativeIdentityResolution({
    required this.identity,
    required this.completed,
    this.errorCode,
  });

  final _AlternativeIdentity? identity;
  final bool completed;
  final MedicineAlternativeErrorCode? errorCode;
}

class _CatalogProduct {
  const _CatalogProduct({
    required this.medicine,
    required this.compositionId,
    required this.compositionKey,
    required this.mappingStatus,
    required this.mappingMethod,
    required this.mappingConfidence,
  });

  final MedicinePrice medicine;

  final String compositionId;
  final String compositionKey;

  final String mappingStatus;
  final String mappingMethod;

  final double mappingConfidence;

  bool get isVerified {
    return medicine.isActive &&
        mappingStatus == 'verified' &&
        compositionId.trim().isNotEmpty;
  }
}

class _RankedAlternative {
  const _RankedAlternative({
    required this.catalogProduct,
    required this.databaseRank,
  });

  final _CatalogProduct catalogProduct;
  final int databaseRank;
}

class _AlternativeLookupResult {
  const _AlternativeLookupResult({
    this.products =
    const <_RankedAlternative>[],
    required this.completed,
    this.errorCode,
  });

  final List<_RankedAlternative> products;
  final bool completed;
  final MedicineAlternativeErrorCode? errorCode;
}

class _CatalogProductLookupResult {
  const _CatalogProductLookupResult({
    required this.product,
    required this.completed,
    this.errorCode,
  });

  final _CatalogProduct? product;
  final bool completed;
  final MedicineAlternativeErrorCode? errorCode;
}

class _CatalogQueryResult {
  const _CatalogQueryResult({
    this.products = const <_CatalogProduct>[],
    required this.completed,
    this.errorCode,
  });

  final List<_CatalogProduct> products;
  final bool completed;
  final MedicineAlternativeErrorCode? errorCode;
}

class _CatalogBatchLookupResult {
  const _CatalogBatchLookupResult({
    this.products = const <_CatalogProduct>[],
    required this.completed,
    this.errorCode,
  });

  final List<_CatalogProduct> products;
  final bool completed;
  final MedicineAlternativeErrorCode? errorCode;
}

class _AlternativeCacheEntry {
  const _AlternativeCacheEntry({
    required this.results,
    required this.expiresAt,
  });

  final List<MedicinePrice> results;
  final DateTime expiresAt;
}