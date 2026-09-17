class AiMedicineSuggestion {
  const AiMedicineSuggestion({
    required this.identificationStatus,
    required this.exactWrittenText,
    required this.writtenFragment,
    required this.medicineCategory,
    required this.name,
    required this.genericName,
    required this.strength,
    required this.form,
    required this.dose,
    required this.frequency,
    required this.duration,
    required this.writtenInstructions,
    required this.route,
    required this.routeConfidence,
    required this.routeEvidence,
    required this.routeExplicitlyWritten,
    required this.confidence,
    required this.specialtyMatch,
    required this.specialtyReason,
    required this.catalogMatch,
    required this.possibleUse,
    required this.problemMatch,
    required this.patientExplanation,
    required this.reasons,
    required this.pharmacistChecks,
    required this.warnings,
    required this.redFlags,
    required this.requiresDoctorConfirmation,
  });

  final String identificationStatus;

  /// Exact readable text from this prescription line.
  ///
  /// This remains transcription evidence only.
  final String exactWrittenText;

  /// Visible medicine-name fragment.
  ///
  /// This is preferred for database searching because the full line may
  /// contain dose/frequency/duration.
  final String writtenFragment;

  /// Broad written category when no exact product name is readable.
  final String medicineCategory;

  /// AI transcription candidate only.
  ///
  /// This must never be treated as database-verified medicine identity.
  final String name;

  /// Generic text only when visibly written.
  ///
  /// This must never be promoted to reviewed database information.
  final String genericName;

  final String strength;
  final String form;

  final String dose;
  final String frequency;
  final String duration;

  /// Prescription directions preserved as read.
  final String writtenInstructions;

  final String route;
  final String routeConfidence;
  final String routeEvidence;

  /// True only when the route itself was explicitly supported by the
  /// prescription text/image.
  final bool routeExplicitlyWritten;

  /// AI transcription confidence only.
  ///
  /// This is NOT medicine verification confidence.
  final String confidence;

  /*
   * -------------------------------------------------------------------------
   * Legacy compatibility fields.
   * -------------------------------------------------------------------------
   *
   * They remain in the model temporarily so old widgets/services compile.
   *
   * They must NOT be used as clinical medicine information.
   */
  final String specialtyMatch;
  final String specialtyReason;
  final String catalogMatch;

  final String possibleUse;
  final String problemMatch;
  final String patientExplanation;

  /// Transcription evidence only.
  final List<String> reasons;

  /// Temporary compatibility field.
  ///
  /// New AI responses intentionally do not populate clinical dispensing
  /// advice here.
  final List<String> pharmacistChecks;

  /// Transcription uncertainty only.
  final List<String> warnings;

  /// Deprecated clinical field. New AI parsing always leaves it empty.
  final List<String> redFlags;

  final bool requiresDoctorConfirmation;

  factory AiMedicineSuggestion.fromJson(
      Map<String, dynamic> json,
      ) {
    final status = _safeIdentificationStatus(
      json['identificationStatus']?.toString(),
    );

    final categoryOnly =
        status == 'category_only';

    final unreadable =
        status == 'unreadable';

    final route = unreadable
        ? 'UNKNOWN'
        : _safeRoute(
      json['route']?.toString(),
    );

    final confidence =
    _safeConfidence(
      json['confidence']?.toString(),
    );

    final routeConfidence =
    route == 'UNKNOWN'
        ? 'low'
        : _safeConfidence(
      json['routeConfidence']
          ?.toString(),
    );

    final routeExplicit =
        route != 'UNKNOWN' &&
            _toBool(
              json['routeExplicitlyWritten'],
            );

    /*
     * Clinical AI-generated fields are deliberately discarded.
     *
     * Clinical knowledge belongs to MedicineKnowledge after database
     * verification/review, never to prescription OCR/vision output.
     */
    return AiMedicineSuggestion(
      identificationStatus:
      status,

      exactWrittenText:
      _cleanText(
        json['exactWrittenText'],
      ),

      writtenFragment:
      unreadable
          ? ''
          : _cleanOptionalText(
        json['writtenFragment'],
      ),

      medicineCategory:
      unreadable
          ? ''
          : _cleanOptionalText(
        json['medicineCategory'],
      ),

      name:
      categoryOnly || unreadable
          ? ''
          : _cleanOptionalText(
        json['name'],
      ),

      genericName:
      categoryOnly || unreadable
          ? ''
          : _cleanOptionalText(
        json['genericName'],
      ),

      strength:
      unreadable
          ? ''
          : _cleanOptionalText(
        json['strength'],
      ),

      form:
      unreadable
          ? ''
          : _cleanOptionalText(
        json['form'],
      ),

      dose:
      unreadable
          ? ''
          : _cleanOptionalText(
        json['dose'],
      ),

      frequency:
      unreadable
          ? ''
          : _cleanOptionalText(
        json['frequency'],
      ),

      duration:
      unreadable
          ? ''
          : _cleanOptionalText(
        json['duration'],
      ),

      writtenInstructions:
      unreadable
          ? ''
          : _cleanOptionalText(
        json['writtenInstructions'],
      ),

      route: route,

      routeConfidence:
      routeConfidence,

      routeEvidence:
      route == 'UNKNOWN'
          ? ''
          : _cleanOptionalText(
        json['routeEvidence'],
      ),

      routeExplicitlyWritten:
      routeExplicit,

      confidence:
      confidence,

      /*
       * Legacy metadata is no longer trusted for medicine verification.
       */
      specialtyMatch: 'none',
      specialtyReason: '',
      catalogMatch: 'not_applicable',

      possibleUse: '',
      problemMatch: '',
      patientExplanation: '',

      reasons:
      _parseStringList(
        json['reasons'],
      ),

      /*
       * Do not allow AI-generated pharmacist/clinical advice into the
       * prescription-transcription model.
       */
      pharmacistChecks:
      const <String>[],

      warnings:
      _parseStringList(
        json['warnings'],
      ),

      redFlags:
      const <String>[],

      requiresDoctorConfirmation:
      _toBool(
        json[
        'requiresDoctorConfirmation'
        ],
      ) ||
          status != 'exact_medicine' ||
          confidence == 'low',
    );
  }

  AiMedicineSuggestion copyWith({
    String? identificationStatus,
    String? exactWrittenText,
    String? writtenFragment,
    String? medicineCategory,
    String? name,
    String? genericName,
    String? strength,
    String? form,
    String? dose,
    String? frequency,
    String? duration,
    String? writtenInstructions,
    String? route,
    String? routeConfidence,
    String? routeEvidence,
    bool? routeExplicitlyWritten,
    String? confidence,
    String? specialtyMatch,
    String? specialtyReason,
    String? catalogMatch,
    String? possibleUse,
    String? problemMatch,
    String? patientExplanation,
    List<String>? reasons,
    List<String>? pharmacistChecks,
    List<String>? warnings,
    List<String>? redFlags,
    bool? requiresDoctorConfirmation,
  }) {
    return AiMedicineSuggestion(
      identificationStatus:
      identificationStatus ??
          this.identificationStatus,
      exactWrittenText:
      exactWrittenText ??
          this.exactWrittenText,
      writtenFragment:
      writtenFragment ??
          this.writtenFragment,
      medicineCategory:
      medicineCategory ??
          this.medicineCategory,
      name:
      name ??
          this.name,
      genericName:
      genericName ??
          this.genericName,
      strength:
      strength ??
          this.strength,
      form:
      form ??
          this.form,
      dose:
      dose ??
          this.dose,
      frequency:
      frequency ??
          this.frequency,
      duration:
      duration ??
          this.duration,
      writtenInstructions:
      writtenInstructions ??
          this.writtenInstructions,
      route:
      route ??
          this.route,
      routeConfidence:
      routeConfidence ??
          this.routeConfidence,
      routeEvidence:
      routeEvidence ??
          this.routeEvidence,
      routeExplicitlyWritten:
      routeExplicitlyWritten ??
          this.routeExplicitlyWritten,
      confidence:
      confidence ??
          this.confidence,
      specialtyMatch:
      specialtyMatch ??
          this.specialtyMatch,
      specialtyReason:
      specialtyReason ??
          this.specialtyReason,
      catalogMatch:
      catalogMatch ??
          this.catalogMatch,
      possibleUse:
      possibleUse ??
          this.possibleUse,
      problemMatch:
      problemMatch ??
          this.problemMatch,
      patientExplanation:
      patientExplanation ??
          this.patientExplanation,
      reasons:
      reasons ??
          this.reasons,
      pharmacistChecks:
      pharmacistChecks ??
          this.pharmacistChecks,
      warnings:
      warnings ??
          this.warnings,
      redFlags:
      redFlags ??
          this.redFlags,
      requiresDoctorConfirmation:
      requiresDoctorConfirmation ??
          this.requiresDoctorConfirmation,
    );
  }

  bool get hasName {
    return !_isPlaceholder(
      name,
    );
  }

  bool get hasGenericName {
    return !_isPlaceholder(
      genericName,
    );
  }

  bool get hasStrength {
    return !_isPlaceholder(
      strength,
    );
  }

  bool get hasForm {
    return !_isPlaceholder(
      form,
    );
  }

  bool get isExactMedicine {
    return identificationStatus ==
        'exact_medicine';
  }

  bool get isPossibleMedicine {
    return identificationStatus ==
        'possible_medicine';
  }

  bool get isCategoryOnly {
    return identificationStatus ==
        'category_only';
  }

  bool get isUnreadable {
    return identificationStatus ==
        'unreadable';
  }

  bool get hasIdentifiedMedicine {
    if (!isExactMedicine &&
        !isPossibleMedicine) {
      return false;
    }

    return hasName ||
        !_isPlaceholder(
          writtenFragment,
        ) ||
        !_isPlaceholder(
          exactWrittenText,
        );
  }

  bool get canUseForCatalogMatch {
    return hasIdentifiedMedicine &&
        verificationQuery.isNotEmpty;
  }

  bool get hasUsefulResult {
    if (isUnreadable) {
      return exactWrittenText
          .trim()
          .isNotEmpty ||
          identificationStatus ==
              'unreadable';
    }

    return exactWrittenText
        .trim()
        .isNotEmpty ||
        writtenFragment
            .trim()
            .isNotEmpty ||
        medicineCategory
            .trim()
            .isNotEmpty ||
        hasName ||
        hasGenericName ||
        hasStrength ||
        hasForm ||
        writtenInstructions
            .trim()
            .isNotEmpty ||
        route != 'UNKNOWN';
  }

  bool get routeNeedsConfirmation {
    if (route == 'UNKNOWN') {
      return true;
    }

    if (routeConfidence == 'low') {
      return true;
    }

    return false;
  }

  bool get requiresOverallReview {
    return isPossibleMedicine ||
        isCategoryOnly ||
        isUnreadable ||
        confidence == 'low' ||
        requiresDoctorConfirmation;
  }

  /// AI transcription confidence only.
  double get confidenceScore {
    switch (confidence) {
      case 'high':
        return 0.90;

      case 'medium':
        return 0.60;

      default:
        return 0.30;
    }
  }

  String get displayTitle {
    if (hasName) {
      return name;
    }

    if (!_isPlaceholder(
      writtenFragment,
    )) {
      return writtenFragment;
    }

    if (!_isPlaceholder(
      medicineCategory,
    )) {
      return medicineCategory;
    }

    if (!_isPlaceholder(
      exactWrittenText,
    )) {
      return exactWrittenText;
    }

    return 'Unreadable medicine order';
  }

  /// Query used for medicine database verification.
  ///
  /// Visible medicine-name fragment is preferred.
  ///
  /// The entire prescription line is only used as a last resort because it
  /// may contain dose/frequency/duration.
  String get verificationQuery {
    if (isCategoryOnly ||
        isUnreadable) {
      return '';
    }

    final candidates = <String>[
      writtenFragment,
      name,
      genericName,
      exactWrittenText,
    ];

    String identity = '';

    for (final candidate
    in candidates) {
      final cleaned =
      _cleanOptionalText(
        candidate,
      );

      if (cleaned.isEmpty) {
        continue;
      }

      identity = cleaned;
      break;
    }

    if (identity.isEmpty) {
      return '';
    }

    if (!hasStrength) {
      return identity;
    }

    final normalizedIdentity =
    _normalizeComparison(
      identity,
    );

    final normalizedStrength =
    _normalizeComparison(
      strength,
    );

    if (normalizedStrength.isEmpty ||
        normalizedIdentity.contains(
          normalizedStrength,
        )) {
      return identity;
    }

    return '$identity $strength'
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  /// AI-extracted identity details.
  ///
  /// These remain unverified until the database matches the product.
  String get medicineDetailsLine {
    return _joinUniqueDetails(
      <String>[
        genericName,
        strength,
        form,
      ],
    );
  }

  String get displayDirections {
    final written =
    _cleanOptionalText(
      writtenInstructions,
    );

    final structured =
    _joinUniqueDetails(
      <String>[
        dose,
        frequency,
        duration,
      ],
    );

    if (written.isEmpty) {
      return structured;
    }

    if (structured.isEmpty) {
      return written;
    }

    final normalizedWritten =
    _normalizeComparison(
      written,
    );

    final normalizedStructured =
    _normalizeComparison(
      structured,
    );

    if (normalizedWritten.contains(
      normalizedStructured,
    ) ||
        normalizedStructured.contains(
          normalizedWritten,
        )) {
      return written.length >=
          structured.length
          ? written
          : structured;
    }

    return '$written • $structured';
  }

  /// Clean prescription text retained for contextual display/OCR comparison.
  ///
  /// This must not be interpreted as verified database identity.
  String get cleanLine {
    return _joinUniqueDetails(
      <String>[
        exactWrittenText,
        writtenFragment,
        name,
        genericName,
        strength,
        form,
        dose,
        frequency,
        duration,
        writtenInstructions,
        route == 'UNKNOWN'
            ? ''
            : route,
      ],
    );
  }

  /// Legacy compatibility getter.
  ///
  /// New AI parsing deliberately prevents clinical content from entering this
  /// model, so this should normally remain false.
  bool get hasUnverifiedClinicalContent {
    return possibleUse.isNotEmpty ||
        problemMatch.isNotEmpty ||
        patientExplanation.isNotEmpty ||
        pharmacistChecks.isNotEmpty ||
        redFlags.isNotEmpty;
  }

  static String _joinUniqueDetails(
      Iterable<String> values,
      ) {
    final selected =
    <String>[];

    for (final rawValue
    in values) {
      final value =
      _cleanOptionalText(
        rawValue,
      );

      if (value.isEmpty) {
        continue;
      }

      final normalized =
      _normalizeComparison(
        value,
      );

      if (normalized.isEmpty) {
        continue;
      }

      var addValue = true;

      for (
      var index = 0;
      index < selected.length;
      index++
      ) {
        final existing =
        selected[index];

        final existingNormalized =
        _normalizeComparison(
          existing,
        );

        if (existingNormalized ==
            normalized) {
          addValue = false;
          break;
        }

        if (existingNormalized.contains(
          normalized,
        )) {
          addValue = false;
          break;
        }

        if (normalized.contains(
          existingNormalized,
        )) {
          selected[index] =
              value;

          addValue = false;
          break;
        }
      }

      if (addValue) {
        selected.add(
          value,
        );
      }
    }

    return selected.join(
      ' • ',
    );
  }

  static String _safeIdentificationStatus(
      String? value,
      ) {
    final status =
        value
            ?.trim()
            .toLowerCase() ??
            'unreadable';

    const allowed =
    <String>{
      'exact_medicine',
      'possible_medicine',
      'category_only',
      'unreadable',
    };

    return allowed.contains(
      status,
    )
        ? status
        : 'unreadable';
  }

  static String _safeRoute(
      String? value,
      ) {
    final route =
        value
            ?.trim()
            .toUpperCase() ??
            'UNKNOWN';

    const allowed =
    <String>{
      'ORAL',
      'RECTAL',
      'IM',
      'IV',
      'TOPICAL',
      'OPHTHALMIC',
      'OTIC',
      'NASAL',
      'INHALED',
      'SUBCUTANEOUS',
      'SUBLINGUAL',
      'UNKNOWN',
    };

    return allowed.contains(
      route,
    )
        ? route
        : 'UNKNOWN';
  }

  static String _safeConfidence(
      String? value,
      ) {
    final confidence =
        value
            ?.trim()
            .toLowerCase() ??
            'low';

    const allowed =
    <String>{
      'high',
      'medium',
      'low',
    };

    return allowed.contains(
      confidence,
    )
        ? confidence
        : 'low';
  }

  static bool _toBool(
      dynamic value,
      ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  static String _cleanText(
      dynamic value,
      ) {
    if (value == null) {
      return '';
    }

    return value
        .toString()
        .replaceAll(
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'),
      '',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  static String _cleanOptionalText(
      dynamic value,
      ) {
    final cleaned =
    _cleanText(
      value,
    );

    if (_isPlaceholder(
      cleaned,
    )) {
      return '';
    }

    return cleaned;
  }

  static bool _isPlaceholder(
      String value,
      ) {
    final normalized =
    value
        .trim()
        .toLowerCase();

    const placeholders =
    <String>{
      '',
      'unknown',
      'unclear',
      'unreadable',
      'not readable',
      'not specified',
      'unspecified',
      'not detected',
      'none',
      'null',
      'n/a',
      'na',
      '-',
      '--',
      '—',
    };

    return placeholders.contains(
      normalized,
    );
  }

  static String _normalizeComparison(
      String value,
      ) {
    return value
        .toLowerCase()
        .replaceAll(
      RegExp(
        r'[\u064B-\u065F]',
      ),
      '',
    )
        .replaceAll(
      RegExp(r'[إأآا]'),
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

  static List<String> _parseStringList(
      dynamic value,
      ) {
    if (value is! List) {
      return const <String>[];
    }

    final results =
    <String>[];

    final seen =
    <String>{};

    for (final item in value) {
      final cleaned =
      _cleanOptionalText(
        item,
      );

      if (cleaned.isEmpty) {
        continue;
      }

      final normalized =
      _normalizeComparison(
        cleaned,
      );

      if (normalized.isEmpty ||
          !seen.add(
            normalized,
          )) {
        continue;
      }

      results.add(
        cleaned,
      );
    }

    return List<String>.unmodifiable(
      results,
    );
  }
}

class AiHandwritingResult {
  const AiHandwritingResult({
    required this.detectedDoctorName,
    required this.detectedSpecialty,
    required this.detectedPatientProblem,
    required this.rawInterpretation,
    required this.suggestions,
    required this.generalWarnings,
  });

  final String detectedDoctorName;
  final String detectedSpecialty;

  /// Only explicit patient problem text from the prescription.
  ///
  /// This must remain empty when the image does not explicitly state one.
  final String detectedPatientProblem;

  /// Transcription notes only.
  ///
  /// This must never contain a generated diagnosis or treatment conclusion.
  final String rawInterpretation;

  final List<AiMedicineSuggestion> suggestions;

  /// General transcription-quality warnings only.
  final List<String> generalWarnings;

  factory AiHandwritingResult.fromJson(
      Map<String, dynamic> json,
      ) {
    final suggestions =
    <AiMedicineSuggestion>[];

    final duplicateKeys =
    <String>{};

    final rawSuggestions =
    json['suggestions'];

    if (rawSuggestions is List) {
      for (final rawItem
      in rawSuggestions) {
        if (rawItem is! Map) {
          continue;
        }

        try {
          final suggestion =
          AiMedicineSuggestion.fromJson(
            Map<String, dynamic>.from(
              rawItem,
            ),
          );

          if (!suggestion
              .hasUsefulResult) {
            continue;
          }

          final duplicateKey =
          _buildDuplicateKey(
            suggestion,
          );

          if (duplicateKey.isEmpty ||
              !duplicateKeys.add(
                duplicateKey,
              )) {
            continue;
          }

          suggestions.add(
            suggestion,
          );
        } catch (_) {
          /*
           * One malformed line must not discard all other readable lines.
           */
        }
      }
    }

    return AiHandwritingResult(
      detectedDoctorName:
      _cleanOptionalText(
        json['detectedDoctorName'],
      ),
      detectedSpecialty:
      _cleanOptionalText(
        json['detectedSpecialty'],
      ),
      detectedPatientProblem:
      _cleanOptionalText(
        json['detectedPatientProblem'],
      ),
      rawInterpretation:
      _cleanOptionalText(
        json['rawInterpretation'],
      ),
      suggestions:
      List<AiMedicineSuggestion>.unmodifiable(
        suggestions,
      ),
      generalWarnings:
      _parseWarningList(
        json['generalWarnings'],
      ),
    );
  }

  bool get hasSuggestions {
    return suggestions.any(
          (suggestion) =>
      suggestion.hasUsefulResult,
    );
  }

  bool get hasIdentifiedMedicines {
    return suggestions.any(
          (suggestion) =>
      suggestion
          .hasIdentifiedMedicine,
    );
  }

  bool get hasCategoryOnlyOrders {
    return suggestions.any(
          (suggestion) =>
      suggestion.isCategoryOnly,
    );
  }

  bool get hasUnreadableOrders {
    return suggestions.any(
          (suggestion) =>
      suggestion.isUnreadable,
    );
  }

  int get identifiedMedicineCount {
    return suggestions
        .where(
          (suggestion) =>
      suggestion
          .hasIdentifiedMedicine,
    )
        .length;
  }

  int get reviewRequiredCount {
    return suggestions
        .where(
          (suggestion) =>
      suggestion
          .requiresOverallReview,
    )
        .length;
  }

  String toPrescriptionTextForMatching() {
    final lines =
    <String>[];

    final seen =
    <String>{};

    for (final suggestion
    in suggestions) {
      if (suggestion.isUnreadable) {
        continue;
      }

      final line =
      suggestion.cleanLine.trim();

      if (line.isEmpty) {
        continue;
      }

      final normalized =
      line
          .toLowerCase()
          .replaceAll(
        RegExp(r'\s+'),
        ' ',
      )
          .trim();

      if (!seen.add(
        normalized,
      )) {
        continue;
      }

      lines.add(
        line,
      );
    }

    return lines
        .join('\n')
        .trim();
  }

  String toPrescriptionText() {
    return toPrescriptionTextForMatching();
  }

  static String _buildDuplicateKey(
      AiMedicineSuggestion suggestion,
      ) {
    final values =
    <String>[
      suggestion
          .exactWrittenText,
      suggestion
          .writtenFragment,
      suggestion
          .displayTitle,
      suggestion
          .displayDirections,
    ];

    return values
        .join('|')
        .toLowerCase()
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  static String _cleanText(
      dynamic value,
      ) {
    if (value == null) {
      return '';
    }

    return value
        .toString()
        .replaceAll(
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'),
      '',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  static String _cleanOptionalText(
      dynamic value,
      ) {
    final cleaned =
    _cleanText(
      value,
    );

    final normalized =
    cleaned
        .toLowerCase()
        .trim();

    const placeholders =
    <String>{
      '',
      'unknown',
      'unclear',
      'unreadable',
      'not specified',
      'unspecified',
      'not detected',
      'none',
      'null',
      'n/a',
      'na',
      '-',
      '--',
      '—',
    };

    return placeholders.contains(
      normalized,
    )
        ? ''
        : cleaned;
  }

  static List<String> _parseWarningList(
      dynamic value,
      ) {
    if (value is! List) {
      return const <String>[];
    }

    final warnings =
    <String>[];

    final seen =
    <String>{};

    for (final item in value) {
      final warning =
      _cleanOptionalText(
        item,
      );

      if (warning.isEmpty) {
        continue;
      }

      final key =
      warning
          .toLowerCase()
          .replaceAll(
        RegExp(r'\s+'),
        ' ',
      )
          .trim();

      if (!seen.add(
        key,
      )) {
        continue;
      }

      warnings.add(
        warning,
      );
    }

    return List<String>.unmodifiable(
      warnings,
    );
  }
}