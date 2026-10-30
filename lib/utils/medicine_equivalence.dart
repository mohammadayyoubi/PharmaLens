import '../models/medicine_price.dart';

/// Compares MOPH products by active ingredient, strength and dosage form.
///
/// Used for "same medicine, other brand" lists, cheapest-equivalent pricing
/// and duplicate-ingredient warnings. Two products with the same keys are
/// pharmaceutically comparable, not automatically interchangeable: the UI
/// always tells the user to confirm a switch with a pharmacist.
class MedicineEquivalence {
  const MedicineEquivalence._();

  static const Set<String> _saltWords = <String>{
    'hcl', 'hydrochloride', 'dihydrochloride', 'hydrobromide', 'sodium',
    'potassium', 'calcium', 'magnesium', 'zinc', 'trihydrate', 'dihydrate',
    'monohydrate', 'hemihydrate', 'sesquihydrate', 'hydrate', 'anhydrous',
    'fumarate', 'hemifumarate', 'maleate', 'besylate', 'besilate', 'mesylate',
    'mesilate', 'succinate', 'tartrate', 'bitartrate', 'acetate', 'citrate',
    'phosphate', 'sulfate', 'sulphate', 'bromide', 'chloride', 'nitrate',
    'lactate', 'gluconate', 'propionate', 'dipropionate', 'valerate',
    'butyrate', 'furoate', 'palmitate', 'stearate', 'tosylate', 'oxalate',
    'malate', 'embonate', 'pamoate', 'trometamol', 'tromethamine', 'arginine',
    'lysine', 'meglumine', 'as', 'base', 'equivalent', 'eq', 'of', 'micronized',
  };

  /// Whole words only: " cr" used to match "cream", which made every cream
  /// look modified-release.
  static final RegExp _modifiedRelease = RegExp(
    r'prolonged|extended|modified|sustained|controlled|delayed|gastro|enteric|retard|\b(?:xr|sr|er|mr|cr|xl|la)\b',
  );

  /// Normalized active moiety of one ingredient, e.g.
  /// "Metformin HCl" and "Metformin hydrochloride" -> "metformin".
  static String ingredientKey(String ingredient) {
    final words = ingredient
        .toLowerCase()
        .replaceAll(RegExp(r'[()\[\],]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final core = words.where((w) => !_saltWords.contains(w)).toList();

    // "Sodium chloride" or "Potassium chloride" are the active substance
    // themselves; keep them whole rather than reducing them to nothing.
    return (core.isEmpty ? words : core).join(' ');
  }

  /// Sorted '+'-joined ingredient keys for a product, or '' when unknown.
  static String compositionKey(MedicinePrice medicine) {
    final keys = medicine.activeIngredients
        .map(ingredientKey)
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return keys.join(' + ');
  }

  /// "500 mg", "0.5g", "500mg" and "500000mcg" all become "500mg".
  static String strengthKey(String? strength) {
    final value = (strength ?? '')
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp('µg|μg|microgram(?:me)?s?|ug'), 'mcg')
        .replaceAll(RegExp('milligram(?:me)?s?'), 'mg');
    if (value.isEmpty) return '';

    String mg(double amount) {
      final rounded = (amount * 10000).round() / 10000;
      return rounded == rounded.roundToDouble() ? '${rounded.toInt()}mg' : '${rounded}mg';
    }

    return value
        .replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)mcg'), (m) {
          final micrograms = double.tryParse(m.group(1)!);
          return micrograms == null ? m.group(0)! : mg(micrograms / 1000);
        })
        .replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)g(?![a-z])'), (m) {
          final grams = double.tryParse(m.group(1)!);
          return grams == null ? m.group(0)! : mg(grams * 1000);
        })
        .replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)mg'), (m) {
          final value = double.tryParse(m.group(1)!);
          return value == null ? m.group(0)! : mg(value);
        });
  }

  /// Route families come first: an eye ointment, a vaginal tablet or a nasal
  /// spray suspension must never be grouped with a skin ointment, an oral
  /// tablet or an oral suspension.
  static const List<MapEntry<String, List<String>>> _formFamilies = <MapEntry<String, List<String>>>[
    MapEntry('eye', ['eye', 'ophthalmic', 'ocular']),
    MapEntry('ear', [' ear ', 'ear drops', ' otic', 'auricular']),
    MapEntry('nasal', ['nasal', ' nose']),
    MapEntry('inhalation', ['inhal', 'nebuli', 'evohaler', 'diskus', 'turbuhaler']),
    MapEntry('vaginal', ['vagin', 'pessar', 'ovule']),
    MapEntry('rectal', ['rectal', 'enema']),
    MapEntry('suppository', ['suppositor']),
    MapEntry('injection', ['inject', 'infusion', 'vial', 'ampoule', 'powder for solution for', ' pen', 'prefilled', 'pre-filled']),
    MapEntry('patch', ['patch', 'transdermal']),
    MapEntry('oral-liquid', ['syrup', 'suspension', 'oral solution', 'elixir', 'drops, oral', 'oral drops', 'oral liquid']),
    MapEntry('powder-oral', ['sachet', 'granules', 'powder for oral', 'effervescent powder']),
    MapEntry('tablet', ['tablet', 'caplet']),
    MapEntry('capsule', ['capsule']),
    MapEntry('cream', ['cream']),
    MapEntry('ointment', ['ointment']),
    MapEntry('gel', ['gel']),
  ];

  /// Groups dosage forms that are interchangeable in presentation, while
  /// keeping modified-release forms apart from immediate-release ones and
  /// each route of administration apart from the others.
  static String formFamily(String? form) {
    final value = ' ${(form ?? '').toLowerCase().replaceAll('/', ' / ')} ';
    if (value.trim().isEmpty) return '';

    final modified = _modifiedRelease.hasMatch(value) ? '-mr' : '';

    for (final entry in _formFamilies) {
      if (entry.value.any(value.contains)) {
        return '${entry.key}$modified';
      }
    }

    return '${value.trim()}$modified';
  }

  /// Route of administration implied by a dosage form, or '' when the form
  /// does not say (an injection can be IV, IM or SC).
  static String routeOfForm(String? form) {
    final family = formFamily(form).replaceAll('-mr', '');
    final value = (form ?? '').toLowerCase();
    if (value.contains('sublingual')) return 'sublingual';
    switch (family) {
      case 'tablet':
      case 'capsule':
      case 'oral-liquid':
      case 'powder-oral':
        return 'oral';
      case 'eye':
        return 'ophthalmic';
      case 'ear':
        return 'otic';
      case 'nasal':
        return 'nasal';
      case 'inhalation':
        return 'inhalation';
      case 'vaginal':
        return 'vaginal';
      case 'rectal':
      case 'suppository':
        return 'rectal';
      case 'cream':
      case 'ointment':
      case 'gel':
      case 'patch':
        return 'topical';
    }
    return '';
  }

  /// Same ingredients (any strength or form).
  static bool sameComposition(MedicinePrice a, MedicinePrice b) {
    final key = compositionKey(a);
    return key.isNotEmpty && key == compositionKey(b);
  }

  /// Same ingredients, same strength and same dosage form family.
  static bool isEquivalent(MedicinePrice a, MedicinePrice b) {
    if (!sameComposition(a, b)) return false;

    final strengthA = strengthKey(a.strength);
    final strengthB = strengthKey(b.strength);
    if (strengthA.isEmpty || strengthA != strengthB) return false;

    final formA = formFamily(a.dosageForm);
    final formB = formFamily(b.dosageForm);
    return formA.isNotEmpty && formA == formB;
  }

  /// Pack contents as (amount, unit): "20" or "10 Vials" -> (20, 'unit'),
  /// "100ml" -> (100, 'ml'), "30g" -> (30, 'g'). Null when unreadable.
  static (double, String)? packQuantity(String? pack) {
    final value = (pack ?? '').trim().toLowerCase();

    // "10x1ml", "100 x 10ml", "1x50ml": count times the size of each unit.
    // A count in brackets such as "30 (3x10)" is already the total.
    final multiplied = RegExp(r'^(\d+)\s*x\s*(\d+(?:\.\d+)?)\s*(ml|l|g)?(?![a-z])').firstMatch(value);
    if (multiplied != null) {
      final count = double.parse(multiplied.group(1)!);
      final each = double.parse(multiplied.group(2)!);
      if (count <= 0 || each <= 0) return null;
      switch (multiplied.group(3)) {
        case 'ml':
          return (count * each, 'ml');
        case 'l':
          return (count * each * 1000, 'ml');
        case 'g':
          return (count * each, 'g');
        default:
          return (count * each, 'unit');
      }
    }

    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(ml|l|g|mg|tablets?|tabs?|capsules?|caps?|sachets?|ampoules?|amps?|vials?|suppositories|pcs?|pieces?)?(?![a-z])',
    ).firstMatch(value);
    if (match == null) return null;

    var amount = double.tryParse(match.group(1)!);
    if (amount == null || amount <= 0) return null;

    final word = match.group(2) ?? '';
    switch (word) {
      case 'ml':
        return (amount, 'ml');
      case 'l':
        return (amount * 1000, 'ml');
      case 'g':
        return (amount, 'g');
      case 'mg':
        amount = amount / 1000;
        return (amount, 'g');
      default:
        // A bare number or a count word ("20", "10 Vials") counts dose units.
        return (amount, 'unit');
    }
  }

  /// Official price per tablet / vial / ml / g, or null when the pack size
  /// cannot be read.
  static double? unitPrice(MedicinePrice medicine) {
    final price = medicine.priceLbp;
    final quantity = packQuantity(medicine.packSize);
    if (price == null || quantity == null) return null;
    return price / quantity.$1;
  }

  /// Compares [a] and [b] by price per unit when their packs use the same
  /// kind of unit, otherwise by pack price. Lower first.
  static int comparePrice(MedicinePrice a, MedicinePrice b) {
    final unitA = packQuantity(a.packSize)?.$2;
    final unitB = packQuantity(b.packSize)?.$2;
    final perUnitA = unitPrice(a);
    final perUnitB = unitPrice(b);

    if (perUnitA != null && perUnitB != null && unitA == unitB) {
      return perUnitA.compareTo(perUnitB);
    }

    final priceA = a.priceLbp;
    final priceB = b.priceLbp;
    if (priceA != null && priceB != null) return priceA.compareTo(priceB);
    if (priceA != null) return -1;
    if (priceB != null) return 1;
    return a.brandName.compareTo(b.brandName);
  }

  /// Percentage by which [candidate] is cheaper than [reference] for the same
  /// amount of medicine, or null when they cannot be compared fairly.
  static int? savingPercent(MedicinePrice reference, MedicinePrice candidate) {
    final refQuantity = packQuantity(reference.packSize);
    final candQuantity = packQuantity(candidate.packSize);

    double? refPrice;
    double? candPrice;

    if (refQuantity != null && candQuantity != null && refQuantity.$2 == candQuantity.$2) {
      refPrice = unitPrice(reference);
      candPrice = unitPrice(candidate);
    } else if ((reference.packSize ?? '').trim().toLowerCase() == (candidate.packSize ?? '').trim().toLowerCase()) {
      refPrice = reference.priceLbp;
      candPrice = candidate.priceLbp;
    }

    if (refPrice == null || candPrice == null || refPrice <= 0) return null;
    return ((refPrice - candPrice) / refPrice * 100).round();
  }
}
