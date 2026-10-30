import '../models/medicine_price.dart';
import '../utils/medicine_equivalence.dart';
import 'medicine_info_service.dart';

/// A line of one medicine's label that names another medicine on the same
/// prescription.
class LabelInteraction {
  const LabelInteraction({required this.labelOf, required this.mentions, required this.line});

  /// Brand whose label contains [line].
  final String labelOf;

  /// Brand of the other prescribed medicine that [line] refers to.
  final String mentions;
  final String line;
}

/// Looks through the interaction sections of the prescribed medicines'
/// labels (see MedicineInfoService) for the other prescribed medicines, by
/// ingredient or by drug group. It only reports what a label says; finding
/// nothing does not mean a combination is safe.
class LabelInteractionService {
  const LabelInteractionService();

  /// Words labels use for a whole group, keyed by ATC prefix.
  static const Map<String, List<String>> _groupWords = {
    'M01A': ['nsaid', 'anti-inflammatory', 'antiinflammatory'],
    'N02BA': ['salicylate', 'aspirin'],
    'B01AA': ['anticoagulant', 'warfarin', 'vitamin k antagonist', 'blood thinner'],
    'B01AC': ['antiplatelet', 'platelet'],
    'B01AF': ['anticoagulant', 'blood thinner'],
    'N06AB': ['ssri', 'serotonin', 'antidepressant'],
    'N06AX': ['serotonin', 'antidepressant'],
    'N02A': ['opioid', 'narcotic'],
    'N05B': ['benzodiazepine', 'sedative', 'cns depressant'],
    'N05C': ['sedative', 'hypnotic', 'cns depressant'],
    'C09A': ['ace inhibitor', 'angiotensin'],
    'C09C': ['angiotensin', 'arb'],
    'C03': ['diuretic'],
    'C07': ['beta blocker', 'beta-blocker'],
    'C08': ['calcium channel blocker'],
    'C10AA': ['statin', 'hmg-coa'],
    'A02BC': ['proton pump', 'ppi'],
    'A02A': ['antacid'],
    'A10B': ['antidiabetic', 'hypoglycemic', 'sulfonylurea'],
    'A10A': ['insulin'],
    'H02AB': ['corticosteroid', 'steroid'],
    'J01FA': ['macrolide'],
    'J01MA': ['quinolone', 'fluoroquinolone'],
    'J01AA': ['tetracycline'],
    'G03A': ['contraceptive'],
    'R06A': ['antihistamine'],
  };

  Future<List<LabelInteraction>> check(List<MedicinePrice> products, {bool isArabic = false}) async {
    final unique = <String, MedicinePrice>{for (final p in products) p.medicineId: p}.values.toList();
    if (unique.length < 2) return const <LabelInteraction>[];

    final infos = await Future.wait(unique.map((p) async {
      try {
        return await MedicineInfoService().load(p);
      } catch (_) {
        return null;
      }
    }));

    final found = <LabelInteraction>[];
    for (var i = 0; i < unique.length; i++) {
      final knowledge = infos[i]?.knowledge;
      if (knowledge == null) continue;
      // Matching runs on the English text; the Arabic is shown when asked.
      final linesEn = <String>[...knowledge.interactionsEn, ...knowledge.contraindicationsEn, ...knowledge.seriousWarningsEn];
      final linesAr = <String>[...knowledge.interactionsAr, ...knowledge.contraindicationsAr, ...knowledge.seriousWarningsAr];

      for (var j = 0; j < unique.length; j++) {
        if (i == j) continue;
        final other = unique[j];
        if (MedicineEquivalence.sameComposition(unique[i], other)) continue;
        final terms = _termsFor(other);
        for (var l = 0; l < linesEn.length; l++) {
          final lower = linesEn[l].toLowerCase();
          if (terms.any((t) => RegExp('\\b${RegExp.escape(t)}').hasMatch(lower))) {
            final line = isArabic && l < linesAr.length && linesAr.length == linesEn.length ? linesAr[l] : linesEn[l];
            found.add(LabelInteraction(labelOf: unique[i].brandName, mentions: other.brandName, line: line));
            break;
          }
        }
      }
    }
    return found;
  }

  List<String> _termsFor(MedicinePrice medicine) {
    final terms = <String>{
      for (final ingredient in medicine.activeIngredients)
        for (final word in MedicineEquivalence.ingredientKey(ingredient).split(' '))
          if (word.length >= 5) word,
    };
    // INN names that U.S. labels spell differently.
    if (terms.contains('paracetamol')) terms.add('acetaminophen');
    if (terms.contains('acetylsalicylic')) terms.add('aspirin');
    final atc = (medicine.atcCode ?? '').toUpperCase();
    for (final entry in _groupWords.entries) {
      if (atc.startsWith(entry.key)) terms.addAll(entry.value);
    }
    return terms.toList();
  }
}
