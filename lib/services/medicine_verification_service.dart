import 'package:flutter/foundation.dart';

import '../models/ai_handwriting_result.dart';
import '../models/medicine_price.dart';
import '../models/verified_medicine_result.dart';
import '../utils/medicine_equivalence.dart';
import 'moph_medicine_service.dart';

/// Safety-first prescription medicine verification.
///
/// The AI only transcribes what is visible. This service decides whether a
/// database product can be treated as an exact prescription match.
///
/// Automatic verification is intentionally strict:
/// - exact cleaned brand identity;
/// - no written strength/form/route conflict;
/// - no unresolved product-variant ambiguity.
///
/// Partial names such as "Dexa" may produce POSSIBLE candidates, but are never
/// promoted automatically to a confirmed product.
class MedicineVerificationService {
  MedicineVerificationService();

  static const double _minimumPossibleScore = 0.46;
  static const double _ambiguityScoreDifference = 0.10;

  Future<List<VerifiedMedicineResult>> verifySuggestions(
    List<AiMedicineSuggestion> suggestions,
  ) async {
    final results = <VerifiedMedicineResult>[];

    for (final suggestion in suggestions) {
      results.add(await verifySuggestion(suggestion));
    }

    return List<VerifiedMedicineResult>.unmodifiable(results);
  }

  Future<VerifiedMedicineResult> verifySuggestion(
    AiMedicineSuggestion suggestion,
  ) async {
    if (suggestion.isCategoryOnly || suggestion.isUnreadable) {
      return _skippedResult(suggestion);
    }

    final writtenIdentity = _bestWrittenIdentity(suggestion);

    if (writtenIdentity.isEmpty) {
      return VerifiedMedicineResult(
        suggestion: suggestion,
        status: MedicineVerificationStatus.notFound,
        candidate: null,
        knowledge: null,
        verificationScore: 0,
        candidateCount: 0,
        message: 'No usable medicine identity was available for verification.',
      );
    }

    try {
      final candidates = await _collectCandidates(suggestion);

      if (candidates.isEmpty) {
        return VerifiedMedicineResult(
          suggestion: suggestion,
          status: MedicineVerificationStatus.notFound,
          candidate: null,
          knowledge: null,
          verificationScore: 0,
          candidateCount: 0,
          message:
              'No current medicine product matching this written name was found in the medicine catalog.',
        );
      }

      final ranked = _rankCandidates(suggestion, candidates);

      if (ranked.isEmpty) {
        return VerifiedMedicineResult(
          suggestion: suggestion,
          status: MedicineVerificationStatus.notFound,
          candidate: null,
          knowledge: null,
          verificationScore: 0,
          candidateCount: candidates.length,
          message:
              'Database products were found, but none could be matched safely to the written medicine identity.',
        );
      }

      final best = ranked.first;

      if (best.score < _minimumPossibleScore) {
        return VerifiedMedicineResult(
          suggestion: suggestion,
          status: MedicineVerificationStatus.notFound,
          candidate: null,
          knowledge: null,
          verificationScore: best.score,
          candidateCount: ranked.length,
          message:
              'The database results were too different from the written medicine.',
        );
      }

      final plausible = _plausibleCandidates(suggestion, ranked);

      final ambiguous = _isAmbiguous(
        suggestion: suggestion,
        rankedCandidates: plausible,
      );

      final canVerify = _canVerifyAutomatically(
        suggestion: suggestion,
        best: best,
        ambiguous: ambiguous,
      );

      if (!canVerify) {
        return VerifiedMedicineResult(
          suggestion: suggestion,
          status: MedicineVerificationStatus.possible,
          candidate: best.medicine,
          knowledge: null,
          verificationScore: best.score,
          candidateCount: plausible.length,
          message: _possibleMatchMessage(
            suggestion: suggestion,
            best: best,
            plausibleCount: plausible.length,
            ambiguous: ambiguous,
          ),
        );
      }

      return VerifiedMedicineResult(
        suggestion: suggestion,
        status: MedicineVerificationStatus.verified,
        candidate: best.medicine,
        knowledge: null,
        verificationScore: best.score,
        candidateCount: plausible.length,
        message: 'Medicine identity verified against the MOPH list.',
      );
    } catch (error, stackTrace) {
      _debugLog('Unexpected medicine verification failure.', error, stackTrace);

      return _failedResult(suggestion);
    }
  }

  Future<VerifiedMedicineResult> confirmManualSelection({
    required AiMedicineSuggestion suggestion,
    required MedicinePrice selectedMedicine,
  }) async {
    if (!selectedMedicine.isActive || !selectedMedicine.hasMedicineId) {
      return VerifiedMedicineResult(
        suggestion: suggestion,
        status: MedicineVerificationStatus.possible,
        candidate: selectedMedicine,
        knowledge: null,
        verificationScore: 0,
        candidateCount: 1,
        message:
            'Medicine selected manually, but the database product does not have a stable active identity.',
        selectionSource: MedicineSelectionSource.manual,
      );
    }

    return VerifiedMedicineResult(
      suggestion: suggestion,
      status: MedicineVerificationStatus.possible,
      candidate: selectedMedicine,
      knowledge: null,
      verificationScore: 0,
      candidateCount: 1,
      message:
          'Medicine selected manually. The product identity is known, but the prescription match remains unverified.',
      selectionSource: MedicineSelectionSource.manual,
    );
  }

  Future<List<MedicinePrice>> _collectCandidates(
    AiMedicineSuggestion suggestion,
  ) async {
    final queries = _searchQueries(suggestion);

    final collected = <String, MedicinePrice>{};

    for (final query in queries) {
      try {
        final results = await MophMedicineService().searchMedicines(
          query,
          limit: 40,
        );

        for (final medicine in results) {
          if (!medicine.isActive || !medicine.hasBrandName) {
            continue;
          }

          final key = medicine.stableKey.trim();

          if (key.isEmpty) {
            continue;
          }

          final existing = collected[key];

          if (existing == null ||
              medicine.similarityScore > existing.similarityScore) {
            collected[key] = medicine;
          }
        }
      } catch (error) {
        // Continue checking other query variants
      }
    }

    return collected.values.toList(growable: false);
  }

  List<String> _searchQueries(AiMedicineSuggestion suggestion) {
    final queries = <String>[];
    final seen = <String>{};

    void add(String value) {
      final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();

      final key = _normalizeMedicineName(cleaned);

      if (cleaned.isEmpty || key.isEmpty || !seen.add(key)) {
        return;
      }

      queries.add(cleaned);
    }

    add(suggestion.verificationQuery);
    add(_bestWrittenIdentity(suggestion));
    add(_removeStrengthAndForm(suggestion.writtenFragment));
    add(_removeStrengthAndForm(suggestion.name));
    add(_removeStrengthAndForm(suggestion.exactWrittenText));

    return queries;
  }

  List<_ScoredCandidate> _rankCandidates(
    AiMedicineSuggestion suggestion,
    List<MedicinePrice> candidates,
  ) {
    final ranked = <_ScoredCandidate>[];

    for (final medicine in candidates) {
      final identity = _identityMatch(suggestion, medicine);

      if (identity == _IdentityMatch.none) {
        continue;
      }

      final strengthCheck = _checkStrength(suggestion, medicine);

      final formCheck = _checkDosageForm(suggestion, medicine);

      final routeCheck = _checkRoute(suggestion, medicine);

      final score = _scoreCandidate(
        medicine: medicine,
        identity: identity,
        strengthCheck: strengthCheck,
        dosageFormCheck: formCheck,
        routeCheck: routeCheck,
      );

      ranked.add(
        _ScoredCandidate(
          medicine: medicine,
          score: score,
          identityMatch: identity,
          strengthCheck: strengthCheck,
          dosageFormCheck: formCheck,
          routeCheck: routeCheck,
        ),
      );
    }

    ranked.sort((first, second) {
      final conflictComparison = first.hardConflictCount.compareTo(
        second.hardConflictCount,
      );

      if (conflictComparison != 0) {
        return conflictComparison;
      }

      final identityComparison = first.identityPriority.compareTo(
        second.identityPriority,
      );

      if (identityComparison != 0) {
        return identityComparison;
      }

      final formComparison = first.formPriority.compareTo(second.formPriority);

      if (formComparison != 0) {
        return formComparison;
      }

      final strengthComparison = first.strengthPriority.compareTo(
        second.strengthPriority,
      );

      if (strengthComparison != 0) {
        return strengthComparison;
      }

      final scoreComparison = second.score.compareTo(first.score);

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      if (first.medicine.isOfficialSource != second.medicine.isOfficialSource) {
        return first.medicine.isOfficialSource ? -1 : 1;
      }

      return first.medicine.brandName.toLowerCase().compareTo(
        second.medicine.brandName.toLowerCase(),
      );
    });

    return ranked;
  }

  List<_ScoredCandidate> _plausibleCandidates(
    AiMedicineSuggestion suggestion,
    List<_ScoredCandidate> ranked,
  ) {
    if (ranked.isEmpty) {
      return const <_ScoredCandidate>[];
    }

    final best = ranked.first;
    final written = _normalizeMedicineName(_bestWrittenIdentity(suggestion));

    final results = <_ScoredCandidate>[];

    for (final candidate in ranked) {
      if (candidate.score < _minimumPossibleScore) {
        continue;
      }

      if (best.hardConflictCount == 0 && candidate.hardConflictCount > 0) {
        continue;
      }

      if (best.score - candidate.score > 0.22) {
        continue;
      }

      if (best.identityMatch.isPartial) {
        final candidateBrand = _normalizedProductBrand(candidate.medicine);

        final candidateGeneric = _normalizedProductGeneric(candidate.medicine);

        if (!_prefixOrFuzzyRelation(written, candidateBrand) &&
            !_prefixOrFuzzyRelation(written, candidateGeneric)) {
          continue;
        }
      } else if (!_sameIdentityFamily(best, candidate)) {
        continue;
      }

      results.add(candidate);
    }

    return results.isEmpty ? <_ScoredCandidate>[best] : results;
  }

  bool _sameIdentityFamily(_ScoredCandidate first, _ScoredCandidate second) {
    final firstBrand = _normalizedProductBrand(first.medicine);

    final secondBrand = _normalizedProductBrand(second.medicine);

    if (firstBrand.isNotEmpty && firstBrand == secondBrand) {
      return true;
    }

    final firstGeneric = _normalizedProductGeneric(first.medicine);

    final secondGeneric = _normalizedProductGeneric(second.medicine);

    return firstGeneric.isNotEmpty && firstGeneric == secondGeneric;
  }

  bool _isAmbiguous({
    required AiMedicineSuggestion suggestion,
    required List<_ScoredCandidate> rankedCandidates,
  }) {
    if (rankedCandidates.length < 2) {
      return false;
    }

    final best = rankedCandidates.first;

    if (best.identityMatch.isPartial) {
      return true;
    }

    final writtenStrength = _writtenStrength(suggestion);

    if (writtenStrength.isEmpty) {
      final differentStrength = rankedCandidates.skip(1).any((candidate) {
        final first = best.medicine.normalizedStrength;

        final second = candidate.medicine.normalizedStrength;

        return first.isNotEmpty && second.isNotEmpty && first != second;
      });

      if (differentStrength) {
        return true;
      }
    }

    final writtenForm = _writtenDosageForm(suggestion);

    if (writtenForm.isEmpty) {
      final differentForm = rankedCandidates.skip(1).any((candidate) {
        final first = best.medicine.normalizedDosageForm;

        final second = candidate.medicine.normalizedDosageForm;

        return first.isNotEmpty && second.isNotEmpty && first != second;
      });

      if (differentForm) {
        return true;
      }
    }

    final second = rankedCandidates[1];

    if (best.hardConflictCount != second.hardConflictCount) {
      return false;
    }

    return best.score - second.score < _ambiguityScoreDifference;
  }

  bool _canVerifyAutomatically({
    required AiMedicineSuggestion suggestion,
    required _ScoredCandidate best,
    required bool ambiguous,
  }) {
    if (!suggestion.isExactMedicine || suggestion.isPossibleMedicine) {
      return false;
    }

    if (!best.medicine.hasMedicineId) {
      return false;
    }

    if (best.identityMatch != _IdentityMatch.exactBrand) {
      return false;
    }

    if (best.hardConflictCount > 0) {
      return false;
    }

    if (!best.strengthCheck.isSafeForAutomaticVerification) {
      return false;
    }

    if (!best.dosageFormCheck.isSafeForAutomaticVerification) {
      return false;
    }

    if (!best.routeCheck.isSafeForAutomaticVerification) {
      return false;
    }

    return !ambiguous;
  }

  double _scoreCandidate({
    required MedicinePrice medicine,
    required _IdentityMatch identity,
    required _FieldMatchCheck strengthCheck,
    required _FieldMatchCheck dosageFormCheck,
    required _FieldMatchCheck routeCheck,
  }) {
    var score = switch (identity) {
      _IdentityMatch.exactBrand => 0.76,
      _IdentityMatch.exactGeneric => 0.65,
      _IdentityMatch.exactComposition => 0.62,
      _IdentityMatch.prefixBrand => 0.60,
      _IdentityMatch.prefixGeneric => 0.54,
      _IdentityMatch.fuzzyBrand => 0.50,
      _IdentityMatch.fuzzyGeneric => 0.44,
      _IdentityMatch.none => 0.0,
    };

    score += _fieldScore(
      strengthCheck,
      match: 0.18,
      missing: -0.08,
      mismatch: -0.42,
    );

    score += _fieldScore(
      dosageFormCheck,
      match: 0.20,
      missing: -0.06,
      mismatch: -0.40,
    );

    score += _fieldScore(
      routeCheck,
      match: 0.07,
      missing: -0.04,
      mismatch: -0.25,
    );

    score += medicine.similarityScore.clamp(0.0, 1.0).toDouble() * 0.04;

    if (medicine.isOfficialSource) {
      score += 0.02;
    }

    return score.clamp(0.0, 1.0).toDouble();
  }

  double _fieldScore(
    _FieldMatchCheck state, {
    required double match,
    required double missing,
    required double mismatch,
  }) {
    switch (state) {
      case _FieldMatchCheck.notProvided:
        return 0;
      case _FieldMatchCheck.match:
        return match;
      case _FieldMatchCheck.databaseValueMissing:
        return missing;
      case _FieldMatchCheck.mismatch:
        return mismatch;
    }
  }

  _IdentityMatch _identityMatch(
    AiMedicineSuggestion suggestion,
    MedicinePrice medicine,
  ) {
    final written = _normalizeMedicineName(_bestWrittenIdentity(suggestion));

    if (written.isEmpty) {
      return _IdentityMatch.none;
    }

    final brand = _normalizedProductBrand(medicine);

    final generic = _normalizedProductGeneric(medicine);

    final composition = _normalizeMedicineName(medicine.displayComposition);

    if (brand.isNotEmpty && written == brand) {
      return _IdentityMatch.exactBrand;
    }

    if (generic.isNotEmpty && written == generic) {
      return _IdentityMatch.exactGeneric;
    }

    if (composition.isNotEmpty && written == composition) {
      return _IdentityMatch.exactComposition;
    }

    if (_isSafePrefixIdentity(written, brand)) {
      return _IdentityMatch.prefixBrand;
    }

    if (_isSafePrefixIdentity(written, generic)) {
      return _IdentityMatch.prefixGeneric;
    }

    if (_meaningfulFuzzyMatch(written, brand)) {
      return _IdentityMatch.fuzzyBrand;
    }

    if (_meaningfulFuzzyMatch(written, generic)) {
      return _IdentityMatch.fuzzyGeneric;
    }

    return _IdentityMatch.none;
  }

  String _normalizedProductBrand(MedicinePrice medicine) {
    return _normalizeMedicineName(_removeStrengthAndForm(medicine.brandName));
  }

  String _normalizedProductGeneric(MedicinePrice medicine) {
    return _normalizeMedicineName(
      _removeStrengthAndForm(medicine.genericName ?? ''),
    );
  }

  bool _prefixOrFuzzyRelation(String written, String databaseValue) {
    return _isSafePrefixIdentity(written, databaseValue) ||
        _meaningfulFuzzyMatch(written, databaseValue);
  }

  bool _isSafePrefixIdentity(String written, String databaseValue) {
    if (written.length < 4 ||
        databaseValue.length < 4 ||
        written == databaseValue ||
        !databaseValue.startsWith(written)) {
      return false;
    }

    if (databaseValue.length <= written.length) {
      return false;
    }

    if (databaseValue[written.length] == ' ') {
      return true;
    }

    final coverage = written.length / databaseValue.length;

    return coverage >= 0.45;
  }

  bool _meaningfulFuzzyMatch(String first, String second) {
    if (first.length < 4 || second.length < 4) {
      return false;
    }

    if (first == second) {
      return true;
    }

    final firstTokens = first
        .split(' ')
        .where((token) => token.length >= 3)
        .toList();

    final secondTokens = second
        .split(' ')
        .where((token) => token.length >= 3)
        .toList();

    if (firstTokens.isEmpty || secondTokens.isEmpty) {
      return false;
    }

    var matched = 0;

    for (final token in firstTokens) {
      var best = 0.0;

      for (final candidate in secondTokens) {
        final score = _normalizedEditSimilarity(token, candidate);

        if (score > best) {
          best = score;
        }
      }

      if (best >= 0.82) {
        matched++;
      }
    }

    final coverage = matched / firstTokens.length;

    if (coverage >= 0.75) {
      return true;
    }

    return _normalizedEditSimilarity(first, second) >= 0.82;
  }

  double _normalizedEditSimilarity(String first, String second) {
    if (first.isEmpty || second.isEmpty) {
      return 0;
    }

    if (first == second) {
      return 1;
    }

    final distance = _levenshteinDistance(first, second);

    final maxLength = first.length > second.length
        ? first.length
        : second.length;

    return (1 - distance / maxLength).clamp(0.0, 1.0).toDouble();
  }

  int _levenshteinDistance(String first, String second) {
    var previous = List<int>.generate(second.length + 1, (index) => index);

    for (var i = 1; i <= first.length; i++) {
      final current = List<int>.filled(second.length + 1, 0);

      current[0] = i;

      for (var j = 1; j <= second.length; j++) {
        final cost = first.codeUnitAt(i - 1) == second.codeUnitAt(j - 1)
            ? 0
            : 1;

        final deletion = previous[j] + 1;

        final insertion = current[j - 1] + 1;

        final substitution = previous[j - 1] + cost;

        current[j] = _min3(deletion, insertion, substitution);
      }

      previous = current;
    }

    return previous[second.length];
  }

  int _min3(int first, int second, int third) {
    var result = first;

    if (second < result) {
      result = second;
    }

    if (third < result) {
      result = third;
    }

    return result;
  }

  _FieldMatchCheck _checkStrength(
    AiMedicineSuggestion suggestion,
    MedicinePrice medicine,
  ) {
    final written = _writtenStrength(suggestion);

    if (written.isEmpty) {
      return _FieldMatchCheck.notProvided;
    }

    final database = _normalizeStrength(medicine.strength ?? '');

    if (database.isEmpty) {
      return _FieldMatchCheck.databaseValueMissing;
    }

    if (written == database) {
      return _FieldMatchCheck.match;
    }

    // A combination product is often written by its total or main strength
    // ("Augmentin 1g" for 875mg/125mg); that is not a conflict.
    final parts = database.split('/').where((part) => part.isNotEmpty).toList();
    final writtenAmount = _milligrams(written);
    if (parts.length > 1 && writtenAmount != null) {
      final amounts = parts.map(_milligrams).whereType<double>().toList();
      final total = amounts.fold<double>(0, (sum, value) => sum + value);
      if (amounts.contains(writtenAmount) || (total - writtenAmount).abs() < 0.001) {
        return _FieldMatchCheck.match;
      }
    }

    return _FieldMatchCheck.mismatch;
  }

  double? _milligrams(String strength) {
    final match = RegExp(r'^(\d+(?:\.\d+)?)mg$').firstMatch(strength);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  /// The strength written next to the medicine name. Dosing directions are
  /// left out on purpose: "5 ml three times daily" is a dose, not the
  /// product's strength.
  String _writtenStrength(AiMedicineSuggestion suggestion) {
    final explicit = _normalizeStrength(suggestion.strength);

    if (explicit.isNotEmpty) {
      return explicit;
    }

    final match = RegExp(
      r'\b\d+(?:[.,]\d+)?\s*'
      r'(?:mcg|µg|μg|ug|mg|g|kg|iu|units?|%)'
      r'(?:\s*/\s*\d+(?:[.,]\d+)?\s*'
      r'(?:mcg|µg|μg|ug|mg|g|kg|ml|l|iu|units?|%))?',
      caseSensitive: false,
    ).firstMatch(_productText(suggestion));

    return _normalizeStrength(match?.group(0) ?? '');
  }

  _FieldMatchCheck _checkDosageForm(
    AiMedicineSuggestion suggestion,
    MedicinePrice medicine,
  ) {
    final written = _writtenDosageForm(suggestion);

    if (written.isEmpty) {
      return _FieldMatchCheck.notProvided;
    }

    final databaseForm = medicine.dosageForm ?? '';

    if (_normalizeDosageForm(databaseForm).isEmpty &&
        MedicineEquivalence.formFamily(databaseForm).isEmpty) {
      return _FieldMatchCheck.databaseValueMissing;
    }

    return _formsCompatible(written, suggestion.form.trim().isEmpty ? written : suggestion.form, databaseForm)
        ? _FieldMatchCheck.match
        : _FieldMatchCheck.mismatch;
  }

  /// Compares a written form ("syrup", "drops", "tab") with a MOPH dosage
  /// form by family, so "syrup" fits "Powder for oral suspension" and
  /// "drops" fits "Eye drops solution", while "tablet" never fits a vaginal
  /// tablet or an injection.
  bool _formsCompatible(String written, String writtenRaw, String databaseForm) {
    final database = MedicineEquivalence.formFamily(databaseForm);
    final databaseBase = database.replaceAll('-mr', '');
    final writtenFamily = MedicineEquivalence.formFamily(writtenRaw);
    final writtenBase = writtenFamily.replaceAll('-mr', '');

    // A modified-release order needs a modified-release product; a plain
    // "tab" may be filled by a gastro-resistant or prolonged-release one.
    if (writtenFamily.endsWith('-mr') && !database.endsWith('-mr')) {
      return false;
    }

    if (writtenBase == databaseBase) return true;

    // A route named in writing ("eye drops", "vaginal tablet") must match.
    const routeFamilies = <String>{'eye', 'ear', 'nasal', 'inhalation', 'vaginal', 'rectal', 'injection'};
    if (routeFamilies.contains(writtenBase)) return false;

    const oral = <String>{'oral-liquid', 'powder-oral'};
    if (oral.contains(writtenBase) && oral.contains(databaseBase)) return true;

    // Generic words that do not name a route.
    switch (written) {
      case 'drops':
        return const <String>{'eye', 'ear', 'nasal', 'oral-liquid'}.contains(databaseBase);
      case 'solution':
        return const <String>{'oral-liquid', 'eye', 'ear', 'nasal', 'injection'}.contains(databaseBase) ||
            databaseForm.toLowerCase().contains('solution');
      case 'spray':
        return const <String>{'nasal', 'inhalation'}.contains(databaseBase) ||
            databaseForm.toLowerCase().contains('spray');
      case 'powder':
        return databaseForm.toLowerCase().contains('powder') || databaseBase == 'powder-oral';
      case 'inhaler':
        return databaseBase == 'inhalation';
      case 'ointment':
      case 'cream':
      case 'gel':
        // "Eye ointment" or "vaginal gel" share the presentation word.
        return databaseForm.toLowerCase().contains(written);
    }

    return false;
  }

  String _writtenDosageForm(AiMedicineSuggestion suggestion) {
    final explicit = _normalizeDosageForm(suggestion.form);

    if (explicit.isNotEmpty) {
      return explicit;
    }

    final text = _normalizeMedicineName(_combinedPrescriptionText(suggestion));

    const patterns = <_FormPattern>[
      _FormPattern(pattern: r'\btablets?\b|\btabs?\b', normalized: 'tablet'),
      _FormPattern(pattern: r'\bcapsules?\b|\bcaps?\b', normalized: 'capsule'),
      _FormPattern(pattern: r'\bsyrups?\b', normalized: 'syrup'),
      _FormPattern(pattern: r'\bsuspensions?\b', normalized: 'suspension'),
      _FormPattern(pattern: r'\bsolutions?\b', normalized: 'solution'),
      _FormPattern(pattern: r'\bdrops?\b', normalized: 'drops'),
      _FormPattern(pattern: r'\bcreams?\b', normalized: 'cream'),
      _FormPattern(pattern: r'\bointments?\b', normalized: 'ointment'),
      _FormPattern(pattern: r'\bgels?\b', normalized: 'gel'),
      _FormPattern(
        pattern:
            r'\binjections?\b|\binjectable\b|\bampoules?\b|\bampules?\b|\bvials?\b',
        normalized: 'injection',
      ),
      _FormPattern(
        pattern: r'\bsuppositor(?:y|ies)\b',
        normalized: 'suppository',
      ),
      _FormPattern(pattern: r'\binhalers?\b', normalized: 'inhaler'),
      _FormPattern(pattern: r'\bsprays?\b', normalized: 'spray'),
      _FormPattern(pattern: r'\bpatch(?:es)?\b', normalized: 'patch'),
      _FormPattern(pattern: r'\bsachets?\b', normalized: 'sachet'),
      _FormPattern(pattern: r'\bpowders?\b', normalized: 'powder'),
    ];

    for (final entry in patterns) {
      if (RegExp(entry.pattern, caseSensitive: false).hasMatch(text)) {
        return entry.normalized;
      }
    }

    return '';
  }

  _FieldMatchCheck _checkRoute(
    AiMedicineSuggestion suggestion,
    MedicinePrice medicine,
  ) {
    if (!suggestion.routeExplicitlyWritten) {
      return _FieldMatchCheck.notProvided;
    }

    final written = _normalizeRoute(suggestion.route);

    if (written.isEmpty || written == 'unknown') {
      return _FieldMatchCheck.notProvided;
    }

    // The MOPH list has no route column; the dosage form implies one.
    var database = _normalizeRoute(medicine.route ?? '');
    if (database.isEmpty) {
      database = MedicineEquivalence.routeOfForm(medicine.dosageForm);
    }

    // Injections (IV, IM or SC) and sublingual use of a tablet cannot be
    // told apart from the form, so they neither confirm nor conflict.
    if (database.isEmpty ||
        (database == 'oral' && written == 'sublingual') ||
        (MedicineEquivalence.formFamily(medicine.dosageForm).startsWith('injection') &&
            const <String>{'intravenous', 'intramuscular', 'subcutaneous'}.contains(written))) {
      return _FieldMatchCheck.notProvided;
    }

    if (written == 'topical' && database == 'vaginal') {
      return _FieldMatchCheck.notProvided;
    }

    return written == database
        ? _FieldMatchCheck.match
        : _FieldMatchCheck.mismatch;
  }

  String _possibleMatchMessage({
    required AiMedicineSuggestion suggestion,
    required _ScoredCandidate best,
    required int plausibleCount,
    required bool ambiguous,
  }) {
    if (!best.medicine.hasMedicineId) {
      return 'A possible medicine match was found, but the product does not have a stable database identity.';
    }

    if (best.strengthCheck == _FieldMatchCheck.mismatch) {
      return 'The medicine name may match, but the written strength conflicts with this database product.';
    }

    if (best.dosageFormCheck == _FieldMatchCheck.mismatch) {
      return 'The medicine name may match, but the written dosage form conflicts with this database product.';
    }

    if (best.routeCheck == _FieldMatchCheck.mismatch) {
      return 'The written administration route conflicts with this database product.';
    }

    if (best.identityMatch.isPartial) {
      if (plausibleCount > 1) {
        return '$plausibleCount possible products match the readable medicine fragment. Confirm the exact brand/product before using product-specific information.';
      }

      return 'A database product matches the readable medicine fragment, but the written identity is incomplete. Confirm the exact product.';
    }

    if (ambiguous && plausibleCount > 1) {
      final strength = _writtenStrength(suggestion);

      final form = _writtenDosageForm(suggestion);

      if (strength.isEmpty && form.isEmpty) {
        return '$plausibleCount matching product variants were found. The exact strength and dosage form must be confirmed.';
      }

      if (strength.isEmpty) {
        return '$plausibleCount matching product variants were found. The exact strength must be confirmed.';
      }

      if (form.isEmpty) {
        return '$plausibleCount matching product variants were found. The exact dosage form must be confirmed.';
      }

      return '$plausibleCount similar product variants remain. The exact product must be confirmed.';
    }

    if (best.identityMatch == _IdentityMatch.exactGeneric ||
        best.identityMatch == _IdentityMatch.exactComposition) {
      return 'The medicine composition/generic identity was identified, but the exact branded product must be confirmed.';
    }

    if (suggestion.isPossibleMedicine) {
      return 'The product is a possible prescription match. Professional confirmation is required.';
    }

    return 'A possible prescription match was found. Professional confirmation is required.';
  }

  VerifiedMedicineResult _skippedResult(AiMedicineSuggestion suggestion) {
    return VerifiedMedicineResult(
      suggestion: suggestion,
      status: MedicineVerificationStatus.skipped,
      candidate: null,
      knowledge: null,
      verificationScore: 0,
      candidateCount: 0,
      message: suggestion.isCategoryOnly
          ? 'A medicine category was detected, but no exact medicine product was identified.'
          : 'The medicine line could not be read safely.',
    );
  }

  VerifiedMedicineResult _failedResult(AiMedicineSuggestion suggestion) {
    return VerifiedMedicineResult(
      suggestion: suggestion,
      status: MedicineVerificationStatus.failed,
      candidate: null,
      knowledge: null,
      verificationScore: 0,
      candidateCount: 0,
      message:
          'Medicine verification is temporarily unavailable. Please try again.',
    );
  }

  String _bestWrittenIdentity(AiMedicineSuggestion suggestion) {
    final values = <String>[
      suggestion.writtenFragment,
      suggestion.name,
      suggestion.genericName,
      suggestion.exactWrittenText,
      suggestion.verificationQuery,
    ];

    for (final value in values) {
      final cleaned = _removeStrengthAndForm(value);

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return '';
  }

  String _combinedPrescriptionText(AiMedicineSuggestion suggestion) {
    return <String>[
      suggestion.exactWrittenText,
      suggestion.writtenFragment,
      suggestion.name,
      suggestion.genericName,
      suggestion.strength,
      suggestion.form,
      suggestion.writtenInstructions,
    ].where((value) => value.trim().isNotEmpty).join(' ');
  }

  /// Text that names the product, without the dosing directions.
  String _productText(AiMedicineSuggestion suggestion) {
    var line = suggestion.exactWrittenText;
    final directions = suggestion.writtenInstructions.trim();
    if (directions.isNotEmpty) {
      line = line.replaceAll(directions, ' ');
    }
    return <String>[
      suggestion.writtenFragment,
      suggestion.name,
      suggestion.genericName,
      suggestion.strength,
      // Without separate directions, only the start of the line, before any
      // dose such as "1 x 3" or "5 ml", can hold the strength.
      directions.isEmpty ? line.split(RegExp(r'\s(?:\d+\s*[x×*]|take|apply|po\b)', caseSensitive: false)).first : line,
    ].where((value) => value.trim().isNotEmpty).join(' ');
  }

  String _removeStrengthAndForm(String value) {
    return value
        .replaceAll(
          RegExp(
            r'\b\d+(?:[.,]\d+)?\s*'
            r'(?:mcg|µg|μg|ug|mg|g|kg|ml|l|iu|u|units?|%)'
            r'(?:\s*/\s*\d+(?:[.,]\d+)?\s*'
            r'(?:mcg|µg|μg|ug|mg|g|kg|ml|l|iu|u|units?|%))?',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'\b(?:'
            r'film|coated|oral|infusion|'
            r'tablet|tablets|tab|tabs|'
            r'capsule|capsules|cap|caps|'
            r'syrup|syrups|'
            r'suspension|suspensions|'
            r'solution|solutions|'
            r'cream|creams|'
            r'ointment|ointments|'
            r'gel|gels|'
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
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// "1 g", "1000mg" and "1000000mcg" all become "1000mg".
  String _normalizeStrength(String value) {
    return MedicineEquivalence.strengthKey(value);
  }

  String _normalizeDosageForm(String value) {
    final normalized = _normalizeMedicineName(value);

    if (normalized.isEmpty) {
      return '';
    }

    if (normalized.contains('tablet') ||
        normalized == 'tab' ||
        normalized == 'tabs' ||
        normalized.contains('film coated')) {
      return 'tablet';
    }

    if (normalized.contains('capsule') ||
        normalized == 'cap' ||
        normalized == 'caps') {
      return 'capsule';
    }

    if (normalized.contains('syrup')) {
      return 'syrup';
    }

    if (normalized.contains('suspension')) {
      return 'suspension';
    }

    if (normalized.contains('ophthalmic') &&
        (normalized.contains('drop') || normalized.contains('solution'))) {
      return 'ophthalmic drops';
    }

    if (normalized.contains('otic') &&
        (normalized.contains('drop') || normalized.contains('solution'))) {
      return 'otic drops';
    }

    if (normalized.contains('solution')) {
      return 'solution';
    }

    if (normalized.contains('drop')) {
      return 'drops';
    }

    if (normalized.contains('cream')) {
      return 'cream';
    }

    if (normalized.contains('ointment')) {
      return 'ointment';
    }

    if (normalized.contains('gel')) {
      return 'gel';
    }

    if (normalized.contains('inject') ||
        normalized.contains('ampoule') ||
        normalized.contains('ampule') ||
        normalized.contains('vial')) {
      return 'injection';
    }

    if (normalized.contains('suppository')) {
      return 'suppository';
    }

    if (normalized.contains('inhaler')) {
      return 'inhaler';
    }

    if (normalized.contains('spray')) {
      return 'spray';
    }

    if (normalized.contains('patch')) {
      return 'patch';
    }

    if (normalized.contains('sachet')) {
      return 'sachet';
    }

    if (normalized.contains('powder')) {
      return 'powder';
    }

    return '';
  }

  String _normalizeRoute(String value) {
    final normalized = _normalizeMedicineName(value);

    const aliases = <String, String>{
      'po': 'oral',
      'oral': 'oral',
      'by mouth': 'oral',
      'iv': 'intravenous',
      'intravenous': 'intravenous',
      'im': 'intramuscular',
      'intramuscular': 'intramuscular',
      'sc': 'subcutaneous',
      'sq': 'subcutaneous',
      'subcutaneous': 'subcutaneous',
      'rectal': 'rectal',
      'pr': 'rectal',
      'ophthalmic': 'ophthalmic',
      'eye': 'ophthalmic',
      'otic': 'otic',
      'ear': 'otic',
      'nasal': 'nasal',
      'inhaled': 'inhalation',
      'inhalation': 'inhalation',
      'inhale': 'inhalation',
      'topical': 'topical',
      'sublingual': 'sublingual',
      'unknown': 'unknown',
    };

    return aliases[normalized] ?? normalized;
  }

  String _normalizeMedicineName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
        .replaceAll(RegExp(r'[إأآا]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _debugLog(String message, Object error, StackTrace stackTrace) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('$message\n$error');

    debugPrintStack(stackTrace: stackTrace);
  }
}

enum _IdentityMatch {
  exactBrand,
  exactGeneric,
  exactComposition,
  prefixBrand,
  prefixGeneric,
  fuzzyBrand,
  fuzzyGeneric,
  none;

  bool get isPartial {
    return this == _IdentityMatch.prefixBrand ||
        this == _IdentityMatch.prefixGeneric ||
        this == _IdentityMatch.fuzzyBrand ||
        this == _IdentityMatch.fuzzyGeneric;
  }
}

enum _FieldMatchCheck {
  notProvided,
  match,
  databaseValueMissing,
  mismatch;

  bool get isSafeForAutomaticVerification {
    return this == _FieldMatchCheck.notProvided ||
        this == _FieldMatchCheck.match;
  }
}

class _ScoredCandidate {
  const _ScoredCandidate({
    required this.medicine,
    required this.score,
    required this.identityMatch,
    required this.strengthCheck,
    required this.dosageFormCheck,
    required this.routeCheck,
  });

  final MedicinePrice medicine;
  final double score;
  final _IdentityMatch identityMatch;
  final _FieldMatchCheck strengthCheck;
  final _FieldMatchCheck dosageFormCheck;
  final _FieldMatchCheck routeCheck;

  int get hardConflictCount {
    var count = 0;

    if (strengthCheck == _FieldMatchCheck.mismatch) {
      count++;
    }

    if (dosageFormCheck == _FieldMatchCheck.mismatch) {
      count++;
    }

    if (routeCheck == _FieldMatchCheck.mismatch) {
      count++;
    }

    return count;
  }

  int get identityPriority {
    switch (identityMatch) {
      case _IdentityMatch.exactBrand:
        return 0;
      case _IdentityMatch.exactGeneric:
        return 1;
      case _IdentityMatch.exactComposition:
        return 2;
      case _IdentityMatch.prefixBrand:
        return 3;
      case _IdentityMatch.prefixGeneric:
        return 4;
      case _IdentityMatch.fuzzyBrand:
        return 5;
      case _IdentityMatch.fuzzyGeneric:
        return 6;
      case _IdentityMatch.none:
        return 7;
    }
  }

  int get formPriority {
    switch (dosageFormCheck) {
      case _FieldMatchCheck.match:
        return 0;
      case _FieldMatchCheck.notProvided:
        return 1;
      case _FieldMatchCheck.databaseValueMissing:
        return 2;
      case _FieldMatchCheck.mismatch:
        return 3;
    }
  }

  int get strengthPriority {
    switch (strengthCheck) {
      case _FieldMatchCheck.match:
        return 0;
      case _FieldMatchCheck.notProvided:
        return 1;
      case _FieldMatchCheck.databaseValueMissing:
        return 2;
      case _FieldMatchCheck.mismatch:
        return 3;
    }
  }
}

class _FormPattern {
  const _FormPattern({required this.pattern, required this.normalized});

  final String pattern;
  final String normalized;
}
