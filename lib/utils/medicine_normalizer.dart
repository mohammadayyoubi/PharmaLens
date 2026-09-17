class MedicineNormalizer {
  const MedicineNormalizer._();

  // ---------------------------------------------------------------------------
  // Empty / invalid values
  // ---------------------------------------------------------------------------

  static const Set<String> _emptyValues = <String>{
    '',
    'null',
    'none',
    'unknown',
    'unclear',
    'unreadable',
    'not specified',
    'unspecified',
    'not detected',
    'not available',
    'n/a',
    'na',
    '-',
    '--',
    '—',
  };

  static const Set<String> _brandNoiseWords = <String>{
    'tablet',
    'tablets',
    'tab',
    'tabs',
    'capsule',
    'capsules',
    'cap',
    'caps',
    'syrup',
    'suspension',
    'solution',
    'injection',
    'injections',
    'injectable',
    'ampoule',
    'ampoules',
    'ampule',
    'ampules',
    'vial',
    'vials',
    'drop',
    'drops',
    'cream',
    'ointment',
    'gel',
    'spray',
    'suppository',
    'suppositories',
    'patch',
    'patches',
    'inhaler',
    'inhalers',
    'powder',
    'sachet',
    'sachets',
  };

  static const Set<String> _ingredientPrefixNoise = <String>{
    'tablet',
    'tablets',
    'capsule',
    'capsules',
    'solution',
    'suspension',
    'syrup',
    'injection',
    'injectable',
    'cream',
    'ointment',
    'gel',
    'drops',
    'drop',
    'powder',
  };

  // ---------------------------------------------------------------------------
  // Basic cleaning
  // ---------------------------------------------------------------------------

  static String cleanText(String? value) {
    if (value == null) {
      return '';
    }

    var cleaned = value
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) {
      return '';
    }

    if (_emptyValues.contains(
      cleaned.toLowerCase(),
    )) {
      return '';
    }

    return cleaned;
  }

  static bool isUsable(String? value) {
    return cleanText(value).isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // General normalization
  // ---------------------------------------------------------------------------

  static String normalizeText(String? value) {
    var cleaned = cleanText(value);

    if (cleaned.isEmpty) {
      return '';
    }

    cleaned = cleaned
        .toLowerCase()

    // Arabic tatweel.
        .replaceAll('\u0640', '')

    // Arabic diacritics.
        .replaceAll(
      RegExp(
        r'[\u0610-\u061A'
        r'\u064B-\u065F'
        r'\u0670'
        r'\u06D6-\u06ED]',
      ),
      '',
    )

    // Arabic letter normalization.
        .replaceAll(
      RegExp(r'[إأآٱا]'),
      'ا',
    )
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');

    return cleaned
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

  // ---------------------------------------------------------------------------
  // Brand normalization
  // ---------------------------------------------------------------------------

  static String normalizeMedicineName(
      String? value,
      ) {
    var cleaned = cleanText(value);

    if (cleaned.isEmpty) {
      return '';
    }

    cleaned = _stripMeasurements(
      cleaned,
    );

    final normalized =
    normalizeText(cleaned);

    if (normalized.isEmpty) {
      return '';
    }

    final tokens = normalized
        .split(' ')
        .where(
          (token) =>
      token.isNotEmpty &&
          !_brandNoiseWords.contains(token),
    )
        .toList();

    if (tokens.isEmpty) {
      return normalized;
    }

    return tokens.join(' ');
  }

  // ---------------------------------------------------------------------------
  // Stable identifiers
  // ---------------------------------------------------------------------------

  static String normalizeIdentity(
      String? value,
      ) {
    final cleaned = cleanText(value)
        .toLowerCase();

    if (cleaned.isEmpty) {
      return '';
    }

    return cleaned.replaceAll(
      RegExp(r'[^a-z0-9\u0600-\u06FF]'),
      '',
    );
  }

  // ---------------------------------------------------------------------------
  // Ingredient normalization
  // ---------------------------------------------------------------------------

  static String normalizeIngredient(
      String? value,
      ) {
    var cleaned = cleanText(value);

    if (cleaned.isEmpty) {
      return '';
    }

    cleaned = cleaned
        .replaceAll(
      RegExp(
        r'^\s*(?:each\s+)?'
        r'(?:tablet|tablets|capsule|capsules|'
        r'solution|suspension|syrup|injection|'
        r'injectable|cream|ointment|gel|drops?|powder)'
        r'\s+(?:contains?\s+)?',
        caseSensitive: false,
      ),
      '',
    )
        .replaceAll(
      RegExp(
        r'^\s*contains?\s+',
        caseSensitive: false,
      ),
      '',
    );

    cleaned = _stripMeasurements(
      cleaned,
    );

    /*
     * Preserve salt / hydrate information.
     *
     * Example:
     *
     * Amoxicillin (sodium)
     *
     * becomes:
     *
     * amoxicillin sodium
     *
     * We deliberately DO NOT automatically convert salts to their
     * base molecules here. That decision belongs to the verified
     * composition registry in Supabase.
     */
    cleaned = cleaned
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .replaceAll('[', ' ')
        .replaceAll(']', ' ')
        .replaceAll(
      RegExp(
        r'\bhcl\b',
        caseSensitive: false,
      ),
      ' hydrochloride ',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();

    var normalized =
    normalizeText(cleaned);

    if (normalized.isEmpty) {
      return '';
    }

    /*
     * Remove dosage-form noise only when it appears as an isolated
     * ingredient token.
     */
    final tokens = normalized.split(' ');

    while (tokens.isNotEmpty &&
        _ingredientPrefixNoise.contains(
          tokens.first,
        )) {
      tokens.removeAt(0);
    }

    normalized = tokens.join(' ').trim();

    return normalized;
  }

  // ---------------------------------------------------------------------------
  // Ingredient extraction
  // ---------------------------------------------------------------------------

  static List<String> ingredientsFromGenericName(
      String? genericName,
      ) {
    final source = cleanText(
      genericName,
    );

    if (source.isEmpty) {
      return const <String>[];
    }

    var prepared = source;

    /*
     * Explicit ingredient separators.
     */
    prepared = prepared
        .replaceAll(
      RegExp(
        r'\s+\+\s+|\s*\+\s*',
      ),
      ' + ',
    )
        .replaceAll(
      RegExp(
        r'\s*&\s*',
      ),
      ' + ',
    )
        .replaceAll(
      RegExp(
        r'\s*;\s*',
      ),
      ' + ',
    )
        .replaceAll(
      RegExp(
        r'\bwith\b',
        caseSensitive: false,
      ),
      ' + ',
    );

    /*
     * Slash is ambiguous because:
     *
     * Amoxicillin / Clavulanic Acid
     *
     * uses "/" as an ingredient separator, while:
     *
     * 125mg/5ml
     *
     * uses "/" inside a strength.
     *
     * Only whitespace-surrounded slashes are treated as ingredient
     * separators.
     */
    prepared = prepared.replaceAll(
      RegExp(r'\s+/\s+'),
      ' + ',
    );

    /*
     * Some source data uses:
     *
     * Amoxicillin (sodium) - 1g,
     * Clavulanic Acid (potassium) - 200mg
     *
     * When multiple measurement expressions are present, commas are
     * very likely separating composition components.
     */
    if (_countMeasurements(prepared) >= 2) {
      prepared = prepared.replaceAll(
        RegExp(
          r',\s*(?=[A-Za-z\u0600-\u06FF])',
        ),
        ' + ',
      );
    }

    final results = <String>[];
    final seen = <String>{};

    for (final rawPart
    in prepared.split('+')) {
      var part = cleanText(rawPart);

      if (part.isEmpty) {
        continue;
      }

      part = _stripMeasurements(
        part,
      )
          .replaceAll(
        RegExp(
          r'^\s*[-–—:]+\s*',
        ),
        '',
      )
          .replaceAll(
        RegExp(
          r'\s*[-–—:]+\s*$',
        ),
        '',
      )
          .replaceAll(
        RegExp(r'\s+'),
        ' ',
      )
          .trim();

      final normalized =
      normalizeIngredient(part);

      if (part.isEmpty ||
          normalized.isEmpty ||
          !seen.add(normalized)) {
        continue;
      }

      results.add(part);
    }

    return List<String>.unmodifiable(
      results,
    );
  }

  // ---------------------------------------------------------------------------
  // Composition identity
  // ---------------------------------------------------------------------------

  static String compositionKey({
    required Iterable<String>
    activeIngredients,
    String? genericName,
  }) {
    final extracted =
    <String>[];

    for (final rawIngredient
    in activeIngredients) {
      final cleaned =
      cleanText(rawIngredient);

      if (cleaned.isEmpty) {
        continue;
      }

      /*
       * Important V2 fix:
       *
       * Some APIs return:
       *
       * ["Amoxicillin + Clavulanic Acid"]
       *
       * instead of:
       *
       * ["Amoxicillin", "Clavulanic Acid"]
       *
       * Both now produce the same composition key.
       */
      final split =
      ingredientsFromGenericName(
        cleaned,
      );

      if (split.isNotEmpty) {
        extracted.addAll(split);
      } else {
        extracted.add(cleaned);
      }
    }

    if (extracted.isEmpty) {
      extracted.addAll(
        ingredientsFromGenericName(
          genericName,
        ),
      );
    }

    if (extracted.isEmpty) {
      return '';
    }

    final normalizedIngredients =
    <String>{};

    for (final ingredient
    in extracted) {
      final normalized =
      normalizeIngredient(
        ingredient,
      );

      if (normalized.isEmpty) {
        continue;
      }

      normalizedIngredients.add(
        normalized,
      );
    }

    if (normalizedIngredients.isEmpty) {
      return '';
    }

    final sorted =
    normalizedIngredients.toList()
      ..sort();

    return sorted.join('+');
  }

  // ---------------------------------------------------------------------------
  // Strength normalization
  // ---------------------------------------------------------------------------

  static String normalizeStrength(
      String? value,
      ) {
    var normalized =
    cleanText(value).toLowerCase();

    if (normalized.isEmpty) {
      return '';
    }

    normalized = normalized
        .replaceAll(',', '.')
        .replaceAll('μ', 'u')
        .replaceAll('µ', 'u')
        .replaceAll('×', 'x')

    // Microgram.
        .replaceAll(
      RegExp(r'\bmicrograms?\b'),
      'mcg',
    )
        .replaceAll(
      RegExp(r'\bmicrogrammes?\b'),
      'mcg',
    )

    // Milligram.
        .replaceAll(
      RegExp(r'\bmilligrams?\b'),
      'mg',
    )
        .replaceAll(
      RegExp(r'\bmilligrammes?\b'),
      'mg',
    )

    // Gram.
        .replaceAll(
      RegExp(r'\bgrams?\b'),
      'g',
    )
        .replaceAll(
      RegExp(r'\bgrammes?\b'),
      'g',
    )

    // Kilogram.
        .replaceAll(
      RegExp(r'\bkilograms?\b'),
      'kg',
    )

    // Millilitre.
        .replaceAll(
      RegExp(
        r'\bmillilit(?:er|re)s?\b',
      ),
      'ml',
    )

    // Litre.
        .replaceAll(
      RegExp(
        r'\blit(?:er|re)s?\b',
      ),
      'l',
    )

    // International unit.
        .replaceAll(
      RegExp(
        r'\binternational\s+units?\b',
      ),
      'iu',
    )

    // Microgram abbreviations.
        .replaceAll(
      RegExp(r'\bug\b'),
      'mcg',
    )

    // "per".
        .replaceAll(
      RegExp(r'\bper\b'),
      '/',
    );

    /*
     * Canonicalize every measurement independently.
     *
     * Examples:
     *
     * 1 g        -> 1000mg
     * 500 mcg    -> 0.5mg
     * 1 g/100 ml -> 1000mg/100ml
     */
    normalized =
        normalized.replaceAllMapped(
          RegExp(
            r'(\d+(?:\.\d+)?)\s*'
            r'(mcg|mg|kg|ml|iu|units?|unit|g|l|u|%)',
            caseSensitive: false,
          ),
              (match) {
            final amount = double.tryParse(
              match.group(1) ?? '',
            );

            final unit = (match.group(2) ?? '')
                .toLowerCase();

            if (amount == null ||
                !amount.isFinite) {
              return match.group(0) ?? '';
            }

            return _canonicalMeasurement(
              amount,
              unit,
            );
          },
        );

    normalized = normalized
        .replaceAll(
      RegExp(r'\s+'),
      '',
    )
        .replaceAll(
      RegExp(
        r'[^a-z0-9.%/+x:\-]+',
      ),
      '',
    )
        .trim();

    return normalized;
  }

  // ---------------------------------------------------------------------------
  // Dosage form normalization
  // ---------------------------------------------------------------------------

  static String normalizeDosageForm(
      String? value,
      ) {
    var normalized =
    normalizeText(
      _stripMeasurements(
        cleanText(value),
      ),
    );

    if (normalized.isEmpty) {
      return '';
    }

    const exactAliases =
    <String, String>{
      // Tablets.
      'tab': 'tablet',
      'tabs': 'tablet',
      'tablet': 'tablet',
      'tablets': 'tablet',
      'film coated tablet': 'tablet',
      'film coated tablets': 'tablet',
      'coated tablet': 'tablet',
      'coated tablets': 'tablet',

      // Modified-release tablets.
      'extended release tablet':
      'extended release tablet',
      'extended release tablets':
      'extended release tablet',
      'xr tablet':
      'extended release tablet',
      'xr tablets':
      'extended release tablet',
      'er tablet':
      'extended release tablet',
      'er tablets':
      'extended release tablet',

      'prolonged release tablet':
      'prolonged release tablet',
      'prolonged release tablets':
      'prolonged release tablet',

      'modified release tablet':
      'modified release tablet',
      'modified release tablets':
      'modified release tablet',

      'sustained release tablet':
      'sustained release tablet',
      'sustained release tablets':
      'sustained release tablet',
      'sr tablet':
      'sustained release tablet',
      'sr tablets':
      'sustained release tablet',

      'controlled release tablet':
      'controlled release tablet',
      'controlled release tablets':
      'controlled release tablet',
      'cr tablet':
      'controlled release tablet',

      'enteric coated tablet':
      'enteric coated tablet',
      'enteric coated tablets':
      'enteric coated tablet',

      'chewable tablet':
      'chewable tablet',
      'chewable tablets':
      'chewable tablet',

      'dispersible tablet':
      'dispersible tablet',
      'dispersible tablets':
      'dispersible tablet',

      'orodispersible tablet':
      'orodispersible tablet',
      'orodispersible tablets':
      'orodispersible tablet',

      'effervescent tablet':
      'effervescent tablet',
      'effervescent tablets':
      'effervescent tablet',

      'sublingual tablet':
      'sublingual tablet',
      'sublingual tablets':
      'sublingual tablet',

      // Capsules.
      'cap': 'capsule',
      'caps': 'capsule',
      'capsule': 'capsule',
      'capsules': 'capsule',
      'oral capsule': 'capsule',
      'oral capsules': 'capsule',

      'extended release capsule':
      'extended release capsule',
      'extended release capsules':
      'extended release capsule',

      'modified release capsule':
      'modified release capsule',
      'modified release capsules':
      'modified release capsule',

      'gastro resistant capsule':
      'gastro resistant capsule',
      'gastro resistant capsules':
      'gastro resistant capsule',

      // Liquids.
      'syrup': 'syrup',
      'syrups': 'syrup',
      'oral syrup': 'syrup',

      'suspension': 'suspension',
      'suspensions': 'suspension',
      'oral suspension': 'suspension',
      'powder for suspension':
      'suspension',
      'powder for oral suspension':
      'suspension',
      'powder for oral suspensions':
      'suspension',

      'solution': 'solution',
      'solutions': 'solution',
      'oral solution': 'solution',

      'elixir': 'elixir',
      'oral elixir': 'elixir',

      // Drops.
      'drops': 'drops',
      'drop': 'drops',
      'oral drops': 'drops',

      'eye drops':
      'ophthalmic drops',
      'ophthalmic drops':
      'ophthalmic drops',
      'ophthalmic solution':
      'ophthalmic drops',

      'ear drops':
      'otic drops',
      'otic drops':
      'otic drops',
      'otic solution':
      'otic drops',

      // Topical.
      'cream': 'cream',
      'creams': 'cream',

      'ointment': 'ointment',
      'ointments': 'ointment',

      'gel': 'gel',
      'gels': 'gel',

      'lotion': 'lotion',
      'lotions': 'lotion',

      // Injectable.
      'injection': 'injection',
      'injections': 'injection',
      'injectable': 'injection',
      'amp': 'injection',
      'ampoule': 'injection',
      'ampoules': 'injection',
      'ampule': 'injection',
      'ampules': 'injection',
      'vial': 'injection',
      'vials': 'injection',

      'powder for injection':
      'powder for injection',
      'powder for solution for injection':
      'powder for injection',

      // Other.
      'suppository':
      'suppository',
      'suppositories':
      'suppository',

      'patch': 'patch',
      'patches': 'patch',

      'inhaler': 'inhaler',
      'inhalers': 'inhaler',

      'metered dose inhaler':
      'inhaler',

      'nebulizer solution':
      'nebulizer solution',
      'nebuliser solution':
      'nebulizer solution',

      'spray': 'spray',
      'sprays': 'spray',

      'nasal spray':
      'nasal spray',

      'powder': 'powder',

      'sachet': 'sachet',
      'sachets': 'sachet',

      // Arabic.
      'قرص': 'tablet',
      'اقراص': 'tablet',

      'كبسوله': 'capsule',
      'كبسولات': 'capsule',

      'شراب': 'syrup',

      'معلق': 'suspension',

      'محلول': 'solution',

      'قطره': 'drops',
      'قطرات': 'drops',

      'حقن': 'injection',
      'حقنه': 'injection',

      'امبول': 'injection',
      'امبوله': 'injection',

      'كريم': 'cream',

      'مرهم': 'ointment',

      'جل': 'gel',

      'بخاخ': 'spray',
    };

    final exact =
    exactAliases[normalized];

    if (exact != null) {
      return exact;
    }

    /*
     * Phrase matching handles values containing pack/presentation
     * noise while preserving clinically important release types.
     */

    if (_containsTablet(normalized)) {
      if (_containsAny(
        normalized,
        const <String>[
          'extended release',
          ' xr ',
          ' er ',
        ],
      )) {
        return 'extended release tablet';
      }

      if (normalized.contains(
        'prolonged release',
      )) {
        return 'prolonged release tablet';
      }

      if (normalized.contains(
        'sustained release',
      )) {
        return 'sustained release tablet';
      }

      if (normalized.contains(
        'modified release',
      )) {
        return 'modified release tablet';
      }

      if (normalized.contains(
        'controlled release',
      )) {
        return 'controlled release tablet';
      }

      if (normalized.contains(
        'enteric coated',
      )) {
        return 'enteric coated tablet';
      }

      if (normalized.contains(
        'chewable',
      )) {
        return 'chewable tablet';
      }

      if (normalized.contains(
        'orodispersible',
      )) {
        return 'orodispersible tablet';
      }

      if (normalized.contains(
        'dispersible',
      )) {
        return 'dispersible tablet';
      }

      if (normalized.contains(
        'effervescent',
      )) {
        return 'effervescent tablet';
      }

      if (normalized.contains(
        'sublingual',
      )) {
        return 'sublingual tablet';
      }

      return 'tablet';
    }

    if (_containsCapsule(normalized)) {
      if (normalized.contains(
        'extended release',
      )) {
        return 'extended release capsule';
      }

      if (normalized.contains(
        'modified release',
      )) {
        return 'modified release capsule';
      }

      if (normalized.contains(
        'gastro resistant',
      )) {
        return 'gastro resistant capsule';
      }

      return 'capsule';
    }

    if (normalized.contains(
      'powder for oral suspension',
    ) ||
        normalized.contains(
          'powder for suspension',
        )) {
      return 'suspension';
    }

    if (normalized.contains(
      'oral suspension',
    )) {
      return 'suspension';
    }

    if (normalized.contains(
      'suspension',
    )) {
      return 'suspension';
    }

    if (normalized.contains(
      'oral syrup',
    )) {
      return 'syrup';
    }

    if (normalized.contains(
      'syrup',
    )) {
      return 'syrup';
    }

    if (normalized.contains(
      'ophthalmic',
    )) {
      if (normalized.contains('drop') ||
          normalized.contains(
            'solution',
          )) {
        return 'ophthalmic drops';
      }
    }

    if (normalized.contains('otic')) {
      if (normalized.contains('drop') ||
          normalized.contains(
            'solution',
          )) {
        return 'otic drops';
      }
    }

    if (normalized.contains(
      'powder for injection',
    ) ||
        normalized.contains(
          'powder for solution for injection',
        )) {
      return 'powder for injection';
    }

    if (normalized.contains(
      'injection',
    ) ||
        normalized.contains(
          'injectable',
        ) ||
        normalized.contains(
          'ampoule',
        ) ||
        normalized.contains(
          'ampule',
        ) ||
        normalized.contains(
          'vial',
        )) {
      return 'injection';
    }

    if (normalized.contains(
      'nebulizer',
    ) ||
        normalized.contains(
          'nebuliser',
        )) {
      return 'nebulizer solution';
    }

    if (normalized.contains(
      'inhaler',
    )) {
      return 'inhaler';
    }

    if (normalized.contains(
      'nasal spray',
    )) {
      return 'nasal spray';
    }

    if (normalized.contains(
      'spray',
    )) {
      return 'spray';
    }

    if (normalized.contains(
      'cream',
    )) {
      return 'cream';
    }

    if (normalized.contains(
      'ointment',
    )) {
      return 'ointment';
    }

    if (normalized.contains(
      'gel',
    )) {
      return 'gel';
    }

    if (normalized.contains(
      'lotion',
    )) {
      return 'lotion';
    }

    if (normalized.contains(
      'suppositor',
    )) {
      return 'suppository';
    }

    if (normalized.contains(
      'patch',
    )) {
      return 'patch';
    }

    if (normalized.contains(
      'sachet',
    )) {
      return 'sachet';
    }

    return normalized;
  }

  // ---------------------------------------------------------------------------
  // Route normalization
  // ---------------------------------------------------------------------------

  static String normalizeRoute(
      String? value,
      ) {
    final normalized =
    normalizeText(value);

    if (normalized.isEmpty ||
        normalized == 'unknown') {
      return '';
    }

    const aliases =
    <String, String>{
      // Oral.
      'po': 'oral',
      'oral': 'oral',
      'by mouth': 'oral',
      'per oral': 'oral',
      'per os': 'oral',
      'mouth': 'oral',

      // IV.
      'iv': 'intravenous',
      'intravenous':
      'intravenous',
      'intravenously':
      'intravenous',

      // IM.
      'im': 'intramuscular',
      'intramuscular':
      'intramuscular',
      'intramuscularly':
      'intramuscular',

      // SC.
      'sc': 'subcutaneous',
      'sq': 'subcutaneous',
      'subcut': 'subcutaneous',
      'subcutaneous':
      'subcutaneous',
      'subcutaneously':
      'subcutaneous',

      // Intradermal.
      'id': 'intradermal',
      'intradermal':
      'intradermal',

      // Topical.
      'topical': 'topical',
      'cutaneous': 'topical',
      'skin': 'topical',

      // Ophthalmic.
      'ophthalmic':
      'ophthalmic',
      'ocular': 'ophthalmic',
      'eye': 'ophthalmic',
      'eyes': 'ophthalmic',

      // Otic.
      'otic': 'otic',
      'auricular': 'otic',
      'ear': 'otic',
      'ears': 'otic',

      // Nasal.
      'nasal': 'nasal',
      'intranasal': 'nasal',

      // Inhalation.
      'inhaled':
      'inhalation',
      'inhalation':
      'inhalation',
      'inhale':
      'inhalation',
      'respiratory':
      'inhalation',
      'nebulized':
      'inhalation',
      'nebulised':
      'inhalation',
      'nebulization':
      'inhalation',
      'nebulisation':
      'inhalation',

      // Sublingual / buccal.
      'sublingual':
      'sublingual',
      'buccal': 'buccal',

      // Rectal.
      'rectal': 'rectal',

      // Vaginal.
      'vaginal': 'vaginal',
      'intravaginal':
      'vaginal',

      // Transdermal.
      'transdermal':
      'transdermal',

      // Other routes.
      'intrathecal':
      'intrathecal',
      'intra articular':
      'intraarticular',
      'intraarticular':
      'intraarticular',

      // Arabic.
      'عن طريق الفم':
      'oral',
      'فموي': 'oral',

      'وريدي':
      'intravenous',

      'عضلي':
      'intramuscular',

      'تحت الجلد':
      'subcutaneous',

      'موضعي':
      'topical',

      'للعين':
      'ophthalmic',
      'للعينين':
      'ophthalmic',

      'للاذن':
      'otic',
      'للاذنين':
      'otic',

      'انفي':
      'nasal',

      'استنشاق':
      'inhalation',

      'تحت اللسان':
      'sublingual',

      'شرجي':
      'rectal',

      'مهبلي':
      'vaginal',
    };

    final exact =
    aliases[normalized];

    if (exact != null) {
      return exact;
    }

    if (normalized.contains(
      'intravenous',
    )) {
      return 'intravenous';
    }

    if (normalized.contains(
      'intramuscular',
    )) {
      return 'intramuscular';
    }

    if (normalized.contains(
      'subcutaneous',
    )) {
      return 'subcutaneous';
    }

    if (normalized.contains(
      'ophthalmic',
    )) {
      return 'ophthalmic';
    }

    if (normalized.contains(
      'otic',
    )) {
      return 'otic';
    }

    if (normalized.contains(
      'inhal',
    ) ||
        normalized.contains(
          'nebul',
        )) {
      return 'inhalation';
    }

    if (normalized.contains(
      'transdermal',
    )) {
      return 'transdermal';
    }

    if (normalized.contains(
      'sublingual',
    )) {
      return 'sublingual';
    }

    if (normalized.contains(
      'rectal',
    )) {
      return 'rectal';
    }

    if (normalized.contains(
      'vaginal',
    )) {
      return 'vaginal';
    }

    if (normalized.contains(
      'nasal',
    )) {
      return 'nasal';
    }

    if (normalized.contains(
      'oral',
    )) {
      return 'oral';
    }

    return normalized;
  }

  // ---------------------------------------------------------------------------
  // Search sanitization
  // ---------------------------------------------------------------------------

  static String cleanUserQuery(
      String value,
      ) {
    return value
        .replaceAll('\u00A0', ' ')
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(',', ' ')
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  static String safeDatabaseToken(
      String? value,
      ) {
    return cleanText(value)
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(',', '')
        .replaceAll(
      RegExp(
        r'[^a-zA-Z0-9\u0600-\u06FF\-]',
      ),
      '',
    )
        .trim();
  }

  // ---------------------------------------------------------------------------
  // Composition comparison
  // ---------------------------------------------------------------------------

  static bool sameComposition({
    required Iterable<String>
    firstIngredients,
    required String? firstGeneric,
    required Iterable<String>
    secondIngredients,
    required String? secondGeneric,
  }) {
    final first = compositionKey(
      activeIngredients:
      firstIngredients,
      genericName: firstGeneric,
    );

    final second = compositionKey(
      activeIngredients:
      secondIngredients,
      genericName: secondGeneric,
    );

    return first.isNotEmpty &&
        second.isNotEmpty &&
        first == second;
  }

  // ---------------------------------------------------------------------------
  // Private strength helpers
  // ---------------------------------------------------------------------------

  static String _canonicalMeasurement(
      double amount,
      String unit,
      ) {
    switch (unit) {
      case 'mcg':
        return '${_compactNumber(
          amount / 1000,
        )}mg';

      case 'g':
        return '${_compactNumber(
          amount * 1000,
        )}mg';

      case 'kg':
        return '${_compactNumber(
          amount * 1000000,
        )}mg';

      case 'l':
        return '${_compactNumber(
          amount * 1000,
        )}ml';

    /*
       * Do not automatically treat "unit" as "IU".
       *
       * They may be equivalent for some products, but that is a
       * pharmaceutical interpretation that belongs in the verified
       * registry, not a generic string normalizer.
       */
      case 'u':
      case 'unit':
      case 'units':
        return '${_compactNumber(
          amount,
        )}unit';

      case 'iu':
        return '${_compactNumber(
          amount,
        )}iu';

      case 'mg':
      case 'ml':
      case '%':
        return '${_compactNumber(
          amount,
        )}$unit';

      default:
        return '${_compactNumber(
          amount,
        )}$unit';
    }
  }

  static String _compactNumber(
      double value,
      ) {
    if (!value.isFinite) {
      return '';
    }

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(8)
        .replaceFirst(
      RegExp(r'0+$'),
      '',
    )
        .replaceFirst(
      RegExp(r'\.$'),
      '',
    );
  }

  // ---------------------------------------------------------------------------
  // Private ingredient helpers
  // ---------------------------------------------------------------------------

  static String _stripMeasurements(
      String value,
      ) {
    var result = value;

    /*
     * Ratio / concentration:
     *
     * 125 mg / 5 ml
     * 100 mcg / dose
     * 1 g / 100 ml
     */
    result = result.replaceAll(
      RegExp(
        r'\b\d+(?:[.,]\d+)?\s*'
        r'(?:mcg|µg|μg|ug|mg|g|kg|ml|l|iu|u|units?|unit|%)'
        r'(?:\s*/\s*'
        r'\d+(?:[.,]\d+)?\s*'
        r'(?:mcg|µg|μg|ug|mg|g|kg|ml|l|iu|u|units?|unit|%))?',
        caseSensitive: false,
      ),
      ' ',
    );

    /*
     * Remaining standalone measurements.
     */
    result = result.replaceAll(
      RegExp(
        r'\b\d+(?:[.,]\d+)?\s*'
        r'(?:mcg|µg|μg|ug|mg|g|kg|ml|l|iu|u|units?|unit|%)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    return result
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();
  }

  static int _countMeasurements(
      String value,
      ) {
    return RegExp(
      r'\b\d+(?:[.,]\d+)?\s*'
      r'(?:mcg|µg|μg|ug|mg|g|kg|ml|l|iu|u|units?|unit|%)\b',
      caseSensitive: false,
    ).allMatches(value).length;
  }

  // ---------------------------------------------------------------------------
  // Private dosage-form helpers
  // ---------------------------------------------------------------------------

  static bool _containsTablet(
      String value,
      ) {
    return RegExp(
      r'\b(?:tablet|tablets|tab|tabs)\b',
    ).hasMatch(value);
  }

  static bool _containsCapsule(
      String value,
      ) {
    return RegExp(
      r'\b(?:capsule|capsules|cap|caps)\b',
    ).hasMatch(value);
  }

  static bool _containsAny(
      String source,
      Iterable<String> values,
      ) {
    final padded = ' $source ';

    for (final value in values) {
      if (padded.contains(value)) {
        return true;
      }
    }

    return false;
  }
}