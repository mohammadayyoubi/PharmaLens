import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/models/medicine_price.dart';
import 'package:pharmalens/services/medication_safety_service.dart';
import 'package:pharmalens/services/moph_medicine_service.dart';
import 'package:pharmalens/utils/medicine_equivalence.dart';

MedicinePrice medicine({
  required String id,
  required String brand,
  required String ingredients,
  String strength = '500mg',
  String form = 'Tablet',
  String pack = '20',
  String price = '100000',
  String atc = '',
}) {
  return MedicinePrice.fromCsvRow(<String, String>{
    'medicine_id': id,
    'brand_name': brand,
    'generic_name': ingredients.replaceAll(', ', ' + '),
    'active_ingredients': ingredients.replaceAll(', ', ' | '),
    'strength': strength,
    'form': form,
    'pack': pack,
    'official_price_lbp': price,
    'currency': 'LBP',
    'atc_code': atc,
  });
}

void main() {
  group('parseMophDataset', () {
    const header =
        'medicine_id,registration_number,brand_name,generic_name,active_ingredients,atc_code,brand_generic,strength,form,pack,company,agent,country,official_price_lbp,currency,last_updated,source,source_url,notes';

    test('keeps every strength and pack of a brand (keyed by MOPH code)', () {
      const csv = '$header\n'
          '1,R1,PANADOL,Paracetamol,Paracetamol,N02BE01,B,500mg,Tablet,20,GSK,,UK,100000,LBP,2026-10-05,MOPH,,\n'
          '2,R2,PANADOL,Paracetamol,Paracetamol,N02BE01,B,500mg,Tablet,48,GSK,,UK,200000,LBP,2026-10-05,MOPH,,\n'
          '3,R3,PANADOL,Paracetamol,Paracetamol,N02BE01,B,1g,Tablet,8,GSK,,UK,90000,LBP,2026-10-05,MOPH,,\n'
          '3,R3,PANADOL,Paracetamol,Paracetamol,N02BE01,B,1g,Tablet,8,GSK,,UK,90000,LBP,2026-10-05,MOPH,,\n';

      final dataset = parseMophDataset(csv);

      expect(dataset.medicines.map((m) => m.medicineId), <String>['1', '2', '3']);
      expect(dataset.listDate, '2026-10-05');
      expect(dataset.medicines.first.activeIngredients, <String>['Paracetamol']);
      expect(dataset.medicines.first.atcCode, 'N02BE01');
    });

    test('rejects files that are not a medicine list', () {
      expect(parseMophDataset('<html><body>Not found</body></html>').medicines, isEmpty);
      expect(parseMophDataset('').medicines, isEmpty);
    });

    test('bundled MOPH list loads completely with ingredients', () {
      final csv = File('assets/medicines/lebanon_medicine_prices.csv').readAsStringSync();
      final rows = csv.trim().split('\n').length - 1;

      final dataset = parseMophDataset(csv);

      expect(dataset.medicines.length, rows, reason: 'no product may be dropped');
      expect(dataset.listDate, isNotEmpty);

      final withIngredients = dataset.medicines.where((m) => m.activeIngredients.isNotEmpty).length;
      expect(withIngredients / dataset.medicines.length, greaterThan(0.95));
    });
  });

  group('MedicineEquivalence', () {
    test('ingredient keys ignore salts but keep salts that are the active substance', () {
      expect(MedicineEquivalence.ingredientKey('Metformin HCl'), 'metformin');
      expect(MedicineEquivalence.ingredientKey('Esomeprazole (magnesium trihydrate)'), 'esomeprazole');
      expect(MedicineEquivalence.ingredientKey('Sodium chloride'), 'sodium chloride');
      expect(
        MedicineEquivalence.ingredientKey('Potassium chloride'),
        isNot(MedicineEquivalence.ingredientKey('Sodium chloride')),
      );
    });

    test('strength and form normalization', () {
      expect(MedicineEquivalence.strengthKey('0.5g'), '500mg');
      expect(MedicineEquivalence.strengthKey('500 mg'), '500mg');
      expect(MedicineEquivalence.formFamily('Tablet, film coated'), 'tablet');
      expect(MedicineEquivalence.formFamily('Tablet, prolonged release'), 'tablet-mr');
    });

    test('equivalent only with same ingredients, strength and form family', () {
      final augmentin = medicine(id: '1', brand: 'AUGMENTIN', ingredients: 'Amoxicillin (trihydrate), Clavulanic Acid (potassium)', strength: '625mg');
      final amoclan = medicine(id: '2', brand: 'AMOCLAN', ingredients: 'Amoxicillin trihydrate, Clavulanic acid', strength: '625 mg', form: 'Tablet, film coated');
      final amoclanStrong = medicine(id: '3', brand: 'AMOCLAN', ingredients: 'Amoxicillin, Clavulanic acid', strength: '1g');
      final amoxil = medicine(id: '4', brand: 'AMOXIL', ingredients: 'Amoxicillin', strength: '625mg');

      expect(MedicineEquivalence.isEquivalent(augmentin, amoclan), isTrue);
      expect(MedicineEquivalence.isEquivalent(augmentin, amoclanStrong), isFalse);
      expect(MedicineEquivalence.isEquivalent(augmentin, amoxil), isFalse);
    });

    test('pack quantities and fair per-dose savings', () {
      expect(MedicineEquivalence.packQuantity('20'), (20.0, 'unit'));
      expect(MedicineEquivalence.packQuantity('10 Vials'), (10.0, 'unit'));
      expect(MedicineEquivalence.packQuantity('100ml'), (100.0, 'ml'));
      expect(MedicineEquivalence.packQuantity('10 lozenges'), (10.0, 'unit'));

      final big = medicine(id: '1', brand: 'A', ingredients: 'X', pack: '20', price: '200000');
      final small = medicine(id: '2', brand: 'B', ingredients: 'X', pack: '10', price: '150000');

      // 10,000 per tablet vs 15,000 per tablet: the small pack is dearer per dose.
      expect(MedicineEquivalence.savingPercent(big, small), -50);
      expect(MedicineEquivalence.comparePrice(big, small), lessThan(0));
    });
  });

  group('MedicationSafetyService', () {
    const service = MedicationSafetyService();

    test('flags the same ingredient in two products', () {
      final alerts = service.check([
        medicine(id: '1', brand: 'PANADOL', ingredients: 'Paracetamol', atc: 'N02BE01'),
        medicine(id: '2', brand: 'PANADOL NIGHT', ingredients: 'Paracetamol, Diphenhydramine HCl', atc: 'N02BE51'),
      ]);

      expect(alerts.map((a) => a.type), contains(SafetyAlertType.duplicateIngredient));
      expect(alerts.first.subjectEn, 'Paracetamol');
    });

    test('matches allergy classes through ATC codes', () {
      final alerts = service.check(
        [medicine(id: '1', brand: 'AUGMENTIN', ingredients: 'Amoxicillin, Clavulanic acid', atc: 'J01CR02')],
        allergies: ['Penicillin'],
      );

      expect(alerts.single.type, SafetyAlertType.allergy);
      expect(alerts.single.medicines, ['AUGMENTIN']);
    });

    test('flags two different NSAIDs as the same class', () {
      final alerts = service.check([
        medicine(id: '1', brand: 'BRUFEN', ingredients: 'Ibuprofen', atc: 'M01AE01'),
        medicine(id: '2', brand: 'VOLTAREN', ingredients: 'Diclofenac sodium', atc: 'M01AB05'),
      ]);

      expect(alerts.single.type, SafetyAlertType.sameClass);
    });

    test('stays quiet for unrelated medicines', () {
      final alerts = service.check(
        [
          medicine(id: '1', brand: 'CONCOR', ingredients: 'Bisoprolol fumarate', atc: 'C07AB07'),
          medicine(id: '2', brand: 'GLUCOPHAGE', ingredients: 'Metformin HCl', atc: 'A10BA02'),
        ],
        allergies: ['Penicillin'],
      );

      expect(alerts, isEmpty);
    });
  });
}
