import 'dart:convert';

import '../utils/medicine_normalizer.dart';

class MedicinePrice {
  const MedicinePrice({
    required this.medicineId,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.packSize,
    required this.manufacturer,
    required this.priceLbp,
    required this.currency,
    required this.effectiveDate,
    required this.similarityScore,
    this.dataSource = 'supabase',
    this.activeIngredients = const <String>[],
    this.route,
    this.atcCode,
    this.registrationNumber,
    this.sourceName,
    this.sourceUrl,
    this.isActive = true,
    this.isVerified = false,

    // PharmaLanse V3 composition identity.
    this.compositionId,
    this.serverCompositionKey,
    this.canonicalComposition,
    this.mappingStatus,
    this.mappingMethod,
    this.mappingConfidence = 0,
  });

  final String medicineId;
  final String brandName;

  final String? genericName;
  final List<String> activeIngredients;

  final String? strength;
  final String? dosageForm;
  final String? route;

  final String? packSize;
  final String? manufacturer;

  final String? atcCode;
  final String? registrationNumber;

  final double? priceLbp;
  final String currency;
  final DateTime? effectiveDate;

  /// Search/ranking score only.
  ///
  /// This is not clinical confidence.
  final double similarityScore;

  final String dataSource;

  String get formattedPriceLbp {
    if (priceLbp == null) return '';
    final val = priceLbp!.round();
    final str = val.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  final String? sourceName;
  final String? sourceUrl;

  final bool isActive;

  /// Product-data verification flag.
  ///
  /// Clinical content verification remains separate.
  final bool isVerified;

  // ---------------------------------------------------------------------------
  // PharmaLanse V3 composition mapping
  // ---------------------------------------------------------------------------

  /// Canonical database identity for the medicine composition.
  ///
  /// This is stronger than comparing normalized text.
  final String? compositionId;

  /// Server-generated canonical composition key.
  ///
  /// Example:
  /// amoxicillin+clavulanic acid
  final String? serverCompositionKey;

  /// Human-readable canonical composition from the registry.
  final String? canonicalComposition;

  /// verified / candidate / unmapped / rejected
  final String? mappingStatus;

  /// How the mapping was produced.
  ///
  /// Example:
  /// catalog_generic_name
  /// reference_import
  final String? mappingMethod;

  /// Database mapping confidence.
  ///
  /// This is not a clinical substitution score.
  final double mappingConfidence;

  factory MedicinePrice.fromJson(
      Map<String, dynamic> json,
      ) {
    return _fromMap(
      json,
      defaultDataSource: 'supabase',
      unknownBrandFallback: 'Unknown medicine',
    );
  }

  factory MedicinePrice.fromCsvRow(
      Map<String, String> row,
      ) {
    return _fromMap(
      Map<String, dynamic>.from(row),
      defaultDataSource: 'local_csv',
      unknownBrandFallback: '',
    );
  }

  static MedicinePrice _fromMap(
      Map<String, dynamic> map, {
        required String defaultDataSource,
        required String unknownBrandFallback,
      }) {
    final rawSimilarity = _toDouble(
      _firstValue(
        map,
        const <String>[
          'similarity_score',
          'similarity',
          'score',
        ],
      ),
    );

    final genericName = _firstText(
      map,
      const <String>[
        'generic_name',
        'generic',
        'scientific_name',
      ],
    );

    final compositionText = _firstText(
      map,
      const <String>[
        'composition',
        'active_ingredient',
      ],
    );

    final canonicalComposition = _firstText(
      map,
      const <String>[
        'canonical_composition',
      ],
    );

    var activeIngredients = _firstStringList(
      map,
      const <String>[
        'active_ingredients',
        'ingredients',
        'ingredient_names',
      ],
    );

    if (activeIngredients.isEmpty &&
        MedicineNormalizer.isUsable(
          compositionText,
        )) {
      activeIngredients =
          MedicineNormalizer.ingredientsFromGenericName(
            compositionText,
          );
    }

    if (activeIngredients.isEmpty &&
        MedicineNormalizer.isUsable(
          genericName,
        )) {
      activeIngredients =
          MedicineNormalizer.ingredientsFromGenericName(
            genericName,
          );
    }

    if (activeIngredients.isEmpty &&
        MedicineNormalizer.isUsable(
          canonicalComposition,
        )) {
      activeIngredients =
          MedicineNormalizer.ingredientsFromGenericName(
            canonicalComposition,
          );
    }

    final resolvedGenericName =
    MedicineNormalizer.isUsable(genericName)
        ? genericName
        : MedicineNormalizer.isUsable(
      compositionText,
    )
        ? compositionText
        : canonicalComposition;

    final mappingStatus = _firstText(
      map,
      const <String>[
        'mapping_status',
      ],
    );

    final mappingMethod = _firstText(
      map,
      const <String>[
        'mapping_method',
      ],
    );

    final compositionId = _firstText(
      map,
      const <String>[
        'composition_id',
      ],
    );

    final serverCompositionKey = _firstText(
      map,
      const <String>[
        'composition_key',
      ],
    );

    final explicitVerified = _toBool(
      _firstValue(
        map,
        const <String>[
          'is_verified',
          'verified',
          'product_verified',
        ],
      ),
      defaultValue: false,
    );

    final normalizedMappingStatus =
        mappingStatus?.trim().toLowerCase() ?? '';

    final mappedAsVerified =
        normalizedMappingStatus == 'verified' &&
            compositionId != null &&
            compositionId.trim().isNotEmpty;

    return MedicinePrice(
      medicineId: _firstText(
        map,
        const <String>[
          'medicine_id',
          'id',
          'product_id',
          'moph_code',
          'index',
        ],
      ) ??
          '',
      brandName: _firstText(
        map,
        const <String>[
          'brand_name',
          'brand',
          'trade_name',
          'product_name',
          'name',
        ],
      ) ??
          unknownBrandFallback,
      genericName: resolvedGenericName,
      activeIngredients:
      List<String>.unmodifiable(
        activeIngredients,
      ),
      strength: _firstText(
        map,
        const <String>[
          'strength',
          'dose_strength',
          'product_strength',
        ],
      ),
      dosageForm: _firstText(
        map,
        const <String>[
          'dosage_form',
          'form',
          'pharmaceutical_form',
        ],
      ),
      route: _firstText(
        map,
        const <String>[
          'route',
          'administration_route',
          'route_of_administration',
        ],
      ),
      packSize: _firstText(
        map,
        const <String>[
          'pack_size',
          'pack',
          'presentation',
        ],
      ),
      manufacturer: _firstText(
        map,
        const <String>[
          'manufacturer',
          'company',
          'responsible_party_name',
        ],
      ),
      atcCode: _firstText(
        map,
        const <String>[
          'atc_code',
          'atc',
        ],
      ),
      registrationNumber: _firstText(
        map,
        const <String>[
          'registration_number',
          'registration_no',
          'moph_registration_number',
        ],
      ),
      priceLbp: _toDouble(
        _firstValue(
          map,
          const <String>[
            'price_lbp',
            'official_price_lbp',
            'public_price_lbp',
            'public_price',
            'price',
          ],
        ),
      ),
      currency: _firstText(
        map,
        const <String>[
          'currency',
          'price_currency',
        ],
      ) ??
          'LBP',
      effectiveDate: _toDate(
        _firstValue(
          map,
          const <String>[
            'effective_date',
            'last_updated',
            'price_date',
            'updated_at',
            'date',
          ],
        ),
      ),
      similarityScore:
      _normalizeSimilarityScore(
        rawSimilarity,
      ),
      dataSource: _firstText(
        map,
        const <String>[
          'data_source',
          'source_type',
        ],
      ) ??
          defaultDataSource,
      sourceName: _firstText(
        map,
        const <String>[
          'source_name',
          'data_source_name',
        ],
      ),
      sourceUrl: _firstText(
        map,
        const <String>[
          'source_url',
          'data_source_url',
        ],
      ),
      isActive: _toBool(
        _firstValue(
          map,
          const <String>[
            'is_active',
            'active',
          ],
        ),
        defaultValue: true,
      ),
      isVerified:
      explicitVerified || mappedAsVerified,
      compositionId: compositionId,
      serverCompositionKey:
      serverCompositionKey,
      canonicalComposition:
      canonicalComposition,
      mappingStatus: mappingStatus,
      mappingMethod: mappingMethod,
      mappingConfidence: _normalizeConfidence(
        _toDouble(
          _firstValue(
            map,
            const <String>[
              'mapping_confidence',
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'medicine_id': medicineId,
      'brand_name': brandName,
      'generic_name': genericName,
      'active_ingredients': activeIngredients,
      'composition_id': compositionId,
      'composition_key': serverCompositionKey,
      'canonical_composition':
      canonicalComposition,
      'mapping_status': mappingStatus,
      'mapping_method': mappingMethod,
      'mapping_confidence':
      mappingConfidence,
      'strength': strength,
      'dosage_form': dosageForm,
      'route': route,
      'pack_size': packSize,
      'manufacturer': manufacturer,
      'atc_code': atcCode,
      'registration_number':
      registrationNumber,
      'price_lbp': priceLbp,
      'currency': currency,
      'effective_date':
      effectiveDate?.toUtc().toIso8601String(),
      'similarity_score': similarityScore,
      'data_source': dataSource,
      'source_name': sourceName,
      'source_url': sourceUrl,
      'is_active': isActive,
      'is_verified': isVerified,
    };
  }

  MedicinePrice copyWith({
    String? medicineId,
    String? brandName,
    String? genericName,
    List<String>? activeIngredients,
    String? strength,
    String? dosageForm,
    String? route,
    String? packSize,
    String? manufacturer,
    String? atcCode,
    String? registrationNumber,
    double? priceLbp,
    String? currency,
    DateTime? effectiveDate,
    double? similarityScore,
    String? dataSource,
    String? sourceName,
    String? sourceUrl,
    bool? isActive,
    bool? isVerified,
    String? compositionId,
    String? serverCompositionKey,
    String? canonicalComposition,
    String? mappingStatus,
    String? mappingMethod,
    double? mappingConfidence,
  }) {
    return MedicinePrice(
      medicineId:
      medicineId ?? this.medicineId,
      brandName:
      brandName ?? this.brandName,
      genericName:
      genericName ?? this.genericName,
      activeIngredients:
      activeIngredients ??
          this.activeIngredients,
      strength:
      strength ?? this.strength,
      dosageForm:
      dosageForm ?? this.dosageForm,
      route: route ?? this.route,
      packSize:
      packSize ?? this.packSize,
      manufacturer:
      manufacturer ??
          this.manufacturer,
      atcCode:
      atcCode ?? this.atcCode,
      registrationNumber:
      registrationNumber ??
          this.registrationNumber,
      priceLbp:
      priceLbp ?? this.priceLbp,
      currency:
      currency ?? this.currency,
      effectiveDate:
      effectiveDate ??
          this.effectiveDate,
      similarityScore:
      similarityScore ??
          this.similarityScore,
      dataSource:
      dataSource ?? this.dataSource,
      sourceName:
      sourceName ?? this.sourceName,
      sourceUrl:
      sourceUrl ?? this.sourceUrl,
      isActive:
      isActive ?? this.isActive,
      isVerified:
      isVerified ?? this.isVerified,
      compositionId:
      compositionId ??
          this.compositionId,
      serverCompositionKey:
      serverCompositionKey ??
          this.serverCompositionKey,
      canonicalComposition:
      canonicalComposition ??
          this.canonicalComposition,
      mappingStatus:
      mappingStatus ??
          this.mappingStatus,
      mappingMethod:
      mappingMethod ??
          this.mappingMethod,
      mappingConfidence:
      mappingConfidence ??
          this.mappingConfidence,
    );
  }

  // ---------------------------------------------------------------------------
  // General product state
  // ---------------------------------------------------------------------------

  int get matchPercentage {
    return (similarityScore
        .clamp(0.0, 1.0) *
        100)
        .round();
  }

  int get mappingConfidencePercentage {
    return (mappingConfidence
        .clamp(0.0, 1.0) *
        100)
        .round();
  }

  String get form =>
      dosageForm?.trim() ?? '';

  String get pack =>
      packSize?.trim() ?? '';

  String get company =>
      manufacturer?.trim() ?? '';

  bool get hasMedicineId =>
      medicineId.trim().isNotEmpty;

  bool get hasBrandName =>
      brandName.trim().isNotEmpty;

  bool get hasGenericName =>
      genericName?.trim().isNotEmpty ??
          false;

  bool get hasActiveIngredients {
    return activeIngredients.any(
          (value) =>
      MedicineNormalizer
          .normalizeIngredient(value)
          .isNotEmpty,
    );
  }

  bool get hasComposition =>
      normalizedCompositionKey.isNotEmpty;

  bool get hasServerCompositionId =>
      compositionId?.trim().isNotEmpty ??
          false;

  bool get hasServerCompositionKey =>
      serverCompositionKey
          ?.trim()
          .isNotEmpty ??
          false;

  bool get hasCanonicalComposition =>
      canonicalComposition
          ?.trim()
          .isNotEmpty ??
          false;

  bool get hasStrength =>
      normalizedStrength.isNotEmpty;

  bool get hasDosageForm =>
      normalizedDosageForm.isNotEmpty;

  bool get hasRoute =>
      normalizedRoute.isNotEmpty;

  bool get hasPackSize =>
      packSize?.trim().isNotEmpty ??
          false;

  bool get hasManufacturer =>
      manufacturer?.trim().isNotEmpty ??
          false;

  bool get hasAtcCode =>
      atcCode?.trim().isNotEmpty ??
          false;

  bool get hasRegistrationNumber =>
      registrationNumber
          ?.trim()
          .isNotEmpty ??
          false;

  bool get hasPrice {
    final value = priceLbp;

    return value != null &&
        value.isFinite &&
        value > 0;
  }

  bool get hasEffectiveDate =>
      effectiveDate != null;

  bool get hasSourceUrl =>
      sourceUri != null;

  bool get isOnlineSource {
    return dataSource
        .trim()
        .toLowerCase() !=
        'local_csv';
  }

  bool get isOfficialSource {
    final combined = <String>[
      dataSource,
      sourceName ?? '',
    ].join(' ').toLowerCase();

    return combined.contains(
      'official',
    ) ||
        combined.contains('moph') ||
        combined.contains('ministry');
  }

  // ---------------------------------------------------------------------------
  // V3 mapping state
  // ---------------------------------------------------------------------------

  String get normalizedMappingStatus {
    return mappingStatus
        ?.trim()
        .toLowerCase() ??
        '';
  }

  String get normalizedMappingMethod {
    return mappingMethod
        ?.trim()
        .toLowerCase() ??
        '';
  }

  bool get hasVerifiedCompositionIdentity {
    return isActive &&
        normalizedMappingStatus ==
            'verified' &&
        hasServerCompositionId;
  }

  bool get isCompositionCandidate {
    return normalizedMappingStatus ==
        'candidate';
  }

  bool get isCompositionUnmapped {
    return normalizedMappingStatus
        .isEmpty ||
        normalizedMappingStatus ==
            'unmapped';
  }

  bool get isCompositionRejected {
    return normalizedMappingStatus ==
        'rejected';
  }

  /// Canonical composition identity used internally for comparisons.
  ///
  /// Server composition_id always wins when verified.
  String get compositionIdentityKey {
    if (hasVerifiedCompositionIdentity) {
      return 'id:${MedicineNormalizer.normalizeIdentity(
        compositionId,
      )}';
    }

    if (normalizedMappingStatus ==
        'verified' &&
        hasServerCompositionKey) {
      return 'server:${MedicineNormalizer.normalizeText(
        serverCompositionKey,
      )}';
    }

    final local =
        normalizedCompositionKey;

    if (local.isNotEmpty) {
      return 'local:$local';
    }

    return '';
  }

  /// Minimum requirement for broad alternative discovery.
  ///
  /// Verified server identity is preferred.
  /// Local composition remains a compatibility fallback.
  bool get hasAlternativeIdentity {
    return isActive &&
        (hasVerifiedCompositionIdentity ||
            hasComposition);
  }

  /// Requirement for conservative exact-alternative checks.
  bool get hasExactAlternativeIdentity {
    return isActive &&
        (hasVerifiedCompositionIdentity ||
            hasComposition) &&
        hasStrength &&
        hasDosageForm;
  }

  // ---------------------------------------------------------------------------
  // Display / source
  // ---------------------------------------------------------------------------

  String get sourceLabel {
    final explicit =
        sourceName?.trim() ?? '';

    if (explicit.isNotEmpty) {
      return explicit;
    }

    final source =
    dataSource.trim().toLowerCase();

    if (source == 'local_csv') {
      return 'Offline medicine catalog';
    }

    if (isOfficialSource) {
      return 'Official medicine database';
    }

    if (source == 'supabase' ||
        source == 'supabase_v3' ||
        source == 'online') {
      return 'Online medicine database';
    }

    if (source.isEmpty) {
      return 'Medicine database';
    }

    return dataSource.trim();
  }

  Uri? get sourceUri {
    final value =
        sourceUrl?.trim() ?? '';

    if (value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' &&
            uri.scheme != 'http')) {
      return null;
    }

    return uri;
  }

  // ---------------------------------------------------------------------------
  // Search identity
  // ---------------------------------------------------------------------------

  String get searchableText {
    return <String>[
      brandName,
      genericName ?? '',
      ...activeIngredients,
      canonicalComposition ?? '',
      strength ?? '',
      dosageForm ?? '',
      route ?? '',
      packSize ?? '',
      manufacturer ?? '',
      atcCode ?? '',
      registrationNumber ?? '',
      medicineId,
    ]
        .where(
          (value) =>
      value.trim().isNotEmpty,
    )
        .join(' ');
  }

  String get stableKey {
    final id = medicineId.trim();

    if (id.isNotEmpty) {
      return id.toLowerCase();
    }

    return <String>[
      MedicineNormalizer
          .normalizeMedicineName(
        brandName,
      ),
      compositionIdentityKey,
      normalizedStrength,
      normalizedDosageForm,
      normalizedRoute,
      MedicineNormalizer.normalizeText(
        packSize,
      ),
      MedicineNormalizer.normalizeText(
        manufacturer,
      ),
    ].join('|');
  }

  String get productIdentityKey {
    return <String>[
      compositionIdentityKey,
      normalizedStrength,
      normalizedDosageForm,
      normalizedRoute,
    ].join('|');
  }

  // ---------------------------------------------------------------------------
  // Normalization
  // ---------------------------------------------------------------------------

  String get normalizedCompositionKey {
    return MedicineNormalizer.compositionKey(
      activeIngredients:
      activeIngredients,
      genericName: genericName,
    );
  }

  String get normalizedServerCompositionKey {
    return MedicineNormalizer.normalizeText(
      serverCompositionKey,
    );
  }

  String get normalizedStrength {
    return MedicineNormalizer
        .normalizeStrength(
      strength,
    );
  }

  String get normalizedDosageForm {
    return MedicineNormalizer
        .normalizeDosageForm(
      dosageForm,
    );
  }

  String get normalizedRoute {
    return MedicineNormalizer.normalizeRoute(
      route,
    );
  }

  // ---------------------------------------------------------------------------
  // Comparison
  // ---------------------------------------------------------------------------

  bool hasSameCompositionAs(
      MedicinePrice other,
      ) {
    /*
     * Strongest possible comparison:
     * verified V3 composition IDs.
     */
    if (hasVerifiedCompositionIdentity &&
        other.hasVerifiedCompositionIdentity) {
      final first =
      MedicineNormalizer.normalizeIdentity(
        compositionId,
      );

      final second =
      MedicineNormalizer.normalizeIdentity(
        other.compositionId,
      );

      return first.isNotEmpty &&
          second.isNotEmpty &&
          first == second;
    }

    /*
     * Second choice:
     * verified server composition keys.
     */
    if (normalizedMappingStatus ==
        'verified' &&
        other.normalizedMappingStatus ==
            'verified') {
      final first =
          normalizedServerCompositionKey;

      final second =
          other.normalizedServerCompositionKey;

      if (first.isNotEmpty &&
          second.isNotEmpty) {
        return first == second;
      }
    }

    /*
     * Compatibility fallback:
     * locally normalized ingredients/generic name.
     */
    final first =
        normalizedCompositionKey;

    final second =
        other.normalizedCompositionKey;

    return first.isNotEmpty &&
        second.isNotEmpty &&
        first == second;
  }

  bool hasSameStrengthAs(
      MedicinePrice other,
      ) {
    final first = normalizedStrength;
    final second =
        other.normalizedStrength;

    return first.isNotEmpty &&
        second.isNotEmpty &&
        first == second;
  }

  bool hasSameDosageFormAs(
      MedicinePrice other,
      ) {
    final first =
        normalizedDosageForm;

    final second =
        other.normalizedDosageForm;

    return first.isNotEmpty &&
        second.isNotEmpty &&
        first == second;
  }

  bool hasCompatibleRouteWith(
      MedicinePrice other,
      ) {
    final first = normalizedRoute;
    final second =
        other.normalizedRoute;

    /*
     * Both missing means we cannot prove incompatibility.
     */
    if (first.isEmpty &&
        second.isEmpty) {
      return true;
    }

    /*
     * One missing = unknown.
     *
     * For conservative exact substitution checks,
     * unknown is not considered a confirmed match.
     */
    if (first.isEmpty ||
        second.isEmpty) {
      return false;
    }

    return first == second;
  }

  bool isExactAlternativeOf(
      MedicinePrice other,
      ) {
    if (!hasExactAlternativeIdentity ||
        !other.hasExactAlternativeIdentity) {
      return false;
    }

    if (_isSameProductAs(other)) {
      return false;
    }

    return hasSameCompositionAs(other) &&
        hasSameStrengthAs(other) &&
        hasSameDosageFormAs(other) &&
        hasCompatibleRouteWith(other);
  }

  // ---------------------------------------------------------------------------
  // Formatted values
  // ---------------------------------------------------------------------------

  String get formattedPrice {
    final value = priceLbp;

    if (value == null ||
        !value.isFinite ||
        value <= 0) {
      return 'Price unavailable';
    }

    final decimals =
    value % 1 == 0 ? 0 : 2;

    final formatted = _formatNumber(
      value,
      decimals: decimals,
    );

    final safeCurrency =
    currency.trim().isEmpty
        ? 'LBP'
        : currency
        .trim()
        .toUpperCase();

    return '$formatted $safeCurrency';
  }

  String get displayGenericName {
    return _displayValue(
      genericName,
    );
  }

  String get displayComposition {
    final ingredients = activeIngredients
        .map(
      MedicineNormalizer.cleanText,
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .toList();

    if (ingredients.isNotEmpty) {
      return ingredients.join(' + ');
    }

    final generic =
    MedicineNormalizer.cleanText(
      genericName,
    );

    if (generic.isNotEmpty) {
      return generic;
    }

    final canonical =
    MedicineNormalizer.cleanText(
      canonicalComposition,
    );

    if (canonical.isNotEmpty) {
      return canonical;
    }

    return '—';
  }

  String get displayStrength {
    return _displayValue(strength);
  }

  String get displayDosageForm {
    return _displayValue(
      dosageForm,
    );
  }

  String get displayRoute {
    return _displayValue(route);
  }

  String get displayPackSize {
    return _displayValue(packSize);
  }

  String get displayManufacturer {
    return _displayValue(
      manufacturer,
    );
  }

  String get displayAtcCode {
    return _displayValue(atcCode);
  }

  String get displayMappingStatus {
    switch (normalizedMappingStatus) {
      case 'verified':
        return 'Verified';

      case 'candidate':
        return 'Needs review';

      case 'rejected':
        return 'Rejected';

      case 'unmapped':
      case '':
        return 'Unmapped';

      default:
        return mappingStatus?.trim() ??
            'Unmapped';
    }
  }

  String get formattedEffectiveDate {
    final date = effectiveDate;

    if (date == null) {
      return '—';
    }

    final day = date.day
        .toString()
        .padLeft(2, '0');

    final month = date.month
        .toString()
        .padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  bool _isSameProductAs(
      MedicinePrice other,
      ) {
    final firstId =
    MedicineNormalizer.normalizeIdentity(
      medicineId,
    );

    final secondId =
    MedicineNormalizer.normalizeIdentity(
      other.medicineId,
    );

    if (firstId.isNotEmpty &&
        secondId.isNotEmpty) {
      return firstId == secondId;
    }

    return stableKey ==
        other.stableKey;
  }

  // ---------------------------------------------------------------------------
  // Parsing helpers
  // ---------------------------------------------------------------------------

  static String _displayValue(
      String? value,
      ) {
    final cleaned =
    MedicineNormalizer.cleanText(
      value,
    );

    return cleaned.isEmpty
        ? '—'
        : cleaned;
  }

  static dynamic _firstValue(
      Map<String, dynamic> map,
      List<String> keys,
      ) {
    for (final key in keys) {
      final value = map[key];

      if (value == null) {
        continue;
      }

      if (value is List &&
          value.isEmpty) {
        continue;
      }

      if (value is String &&
          !MedicineNormalizer.isUsable(
            value,
          )) {
        continue;
      }

      return value;
    }

    return null;
  }

  static String? _firstText(
      Map<String, dynamic> map,
      List<String> keys,
      ) {
    final value = _firstValue(
      map,
      keys,
    );

    if (value == null) {
      return null;
    }

    final cleaned =
    MedicineNormalizer.cleanText(
      value.toString(),
    );

    return cleaned.isEmpty
        ? null
        : cleaned;
  }

  static List<String> _firstStringList(
      Map<String, dynamic> map,
      List<String> keys,
      ) {
    for (final key in keys) {
      final result =
      _toStringList(
        map[key],
      );

      if (result.isNotEmpty) {
        return result;
      }
    }

    return const <String>[];
  }

  static List<String> _toStringList(
      dynamic value,
      ) {
    if (value == null) {
      return const <String>[];
    }

    final rawItems = <dynamic>[];

    if (value is List) {
      rawItems.addAll(value);
    } else if (value is String) {
      final cleaned = value.trim();

      if (cleaned.isEmpty) {
        return const <String>[];
      }

      /*
       * JSON array.
       */
      if (cleaned.startsWith('[') &&
          cleaned.endsWith(']')) {
        try {
          final decoded =
          jsonDecode(cleaned);

          if (decoded is List) {
            rawItems.addAll(decoded);
          } else {
            rawItems.add(decoded);
          }
        } catch (_) {
          rawItems.addAll(
            cleaned
                .substring(
              1,
              cleaned.length - 1,
            )
                .split(','),
          );
        }
      }

      /*
       * PostgreSQL array.
       */
      else if (cleaned.startsWith('{') &&
          cleaned.endsWith('}')) {
        rawItems.addAll(
          cleaned
              .substring(
            1,
            cleaned.length - 1,
          )
              .split(
            RegExp(r'\s*,\s*'),
          ),
        );
      }

      /*
       * Explicit multi-value separators.
       */
      else if (cleaned.contains('|') ||
          cleaned.contains(';') ||
          cleaned.contains('\n')) {
        rawItems.addAll(
          cleaned.split(
            RegExp(r'\r?\n|\||;'),
          ),
        );
      }

      /*
       * Composition-style text.
       *
       * Let the shared normalizer understand:
       * A + B
       * A / B
       * A & B
       * etc.
       */
      else {
        final parsed =
        MedicineNormalizer
            .ingredientsFromGenericName(
          cleaned,
        );

        if (parsed.length > 1) {
          rawItems.addAll(parsed);
        } else {
          rawItems.add(cleaned);
        }
      }
    } else {
      rawItems.add(value);
    }

    final results = <String>[];
    final seen = <String>{};

    for (final rawItem in rawItems) {
      var text =
      MedicineNormalizer.cleanText(
        rawItem.toString(),
      );

      if (text.length >= 2 &&
          ((text.startsWith('"') &&
              text.endsWith('"')) ||
              (text.startsWith("'") &&
                  text.endsWith("'")))) {
        text = text.substring(
          1,
          text.length - 1,
        );
      }

      final normalized =
      MedicineNormalizer
          .normalizeIngredient(
        text,
      );

      if (text.isEmpty ||
          normalized.isEmpty ||
          !seen.add(normalized)) {
        continue;
      }

      results.add(text);
    }

    return List<String>.unmodifiable(
      results,
    );
  }

  static double? _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final number =
      value.toDouble();

      return number.isFinite
          ? number
          : null;
    }

    final cleaned = value
        .toString()
        .replaceAll(',', '')
        .replaceAll(
      RegExp(r'[^0-9.\-]'),
      '',
    )
        .trim();

    if (cleaned.isEmpty ||
        cleaned == '-' ||
        cleaned == '.') {
      return null;
    }

    final parsed =
    double.tryParse(cleaned);

    if (parsed == null ||
        !parsed.isFinite) {
      return null;
    }

    return parsed;
  }

  static bool _toBool(
      dynamic value, {
        required bool defaultValue,
      }) {
    if (value == null) {
      return defaultValue;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final normalized = value
        .toString()
        .trim()
        .toLowerCase();

    if (const <String>{
      'true',
      '1',
      'yes',
      'y',
      'active',
      'verified',
    }.contains(normalized)) {
      return true;
    }

    if (const <String>{
      'false',
      '0',
      'no',
      'n',
      'inactive',
      'unverified',
    }.contains(normalized)) {
      return false;
    }

    return defaultValue;
  }

  static double _normalizeSimilarityScore(
      double? value,
      ) {
    if (value == null ||
        !value.isFinite ||
        value <= 0) {
      return 0;
    }

    if (value > 1 &&
        value <= 100) {
      return (value / 100)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    return value
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static double _normalizeConfidence(
      double? value,
      ) {
    if (value == null ||
        !value.isFinite ||
        value <= 0) {
      return 0;
    }

    if (value > 1 &&
        value <= 100) {
      return (value / 100)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    return value
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static DateTime? _toDate(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final raw = value.toInt();

      try {
        if (raw > 100000000000) {
          return DateTime
              .fromMillisecondsSinceEpoch(
            raw,
          );
        }

        if (raw > 1000000000) {
          return DateTime
              .fromMillisecondsSinceEpoch(
            raw * 1000,
          );
        }
      } catch (_) {
        return null;
      }
    }

    final text =
    value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    final iso =
    DateTime.tryParse(text);

    if (iso != null) {
      return iso;
    }

    final match = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$',
    ).firstMatch(text);

    if (match == null) {
      return null;
    }

    final day = int.tryParse(
      match.group(1) ?? '',
    );

    final month = int.tryParse(
      match.group(2) ?? '',
    );

    final year = int.tryParse(
      match.group(3) ?? '',
    );

    if (day == null ||
        month == null ||
        year == null) {
      return null;
    }

    final parsed =
    DateTime(
      year,
      month,
      day,
    );

    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      return null;
    }

    return parsed;
  }

  static String _formatNumber(
      double value, {
        required int decimals,
      }) {
    final text =
    value.toStringAsFixed(
      decimals,
    );

    final parts = text.split('.');

    final integerPart =
        parts.first;

    final isNegative =
    integerPart.startsWith('-');

    final digits = isNegative
        ? integerPart.substring(1)
        : integerPart;

    final buffer = StringBuffer();

    for (
    var index = 0;
    index < digits.length;
    index++
    ) {
      final remaining =
          digits.length - index;

      buffer.write(
        digits[index],
      );

      if (remaining > 1 &&
          remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    final result = StringBuffer();

    if (isNegative) {
      result.write('-');
    }

    result.write(
      buffer.toString(),
    );

    if (parts.length > 1 &&
        parts.last.isNotEmpty) {
      result
        ..write('.')
        ..write(parts.last);
    }

    return result.toString();
  }
}