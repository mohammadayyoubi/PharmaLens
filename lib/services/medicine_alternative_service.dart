import '../models/medicine_knowledge.dart';
import '../models/medicine_price.dart';
import 'moph_medicine_service.dart';

/// Finds other MOPH-registered products with the same active ingredients.
///
/// Different strengths, dosage forms and routes remain discoverable.
/// They are informational alternatives and are NOT automatically
/// interchangeable.
class MedicineAlternativeService {
  Future<List<MedicinePrice>> findAlternatives(
      MedicinePrice medicine, {
        MedicineKnowledge? knowledge,
        int limit = 40,
        bool forceRefresh = false,
      }) {
    return MophMedicineService().findAlternatives(
      medicine,
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }

  /// Same ingredients, strength and form, cheapest first.
  Future<List<MedicinePrice>> findEquivalents(
      MedicinePrice medicine, {
        int limit = 10,
      }) {
    return MophMedicineService().findExactAlternatives(
      medicine,
      limit: limit,
    );
  }
}
