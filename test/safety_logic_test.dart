import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/models/ai_handwriting_result.dart';
import 'package:pharmalens/models/medicine_price.dart';
import 'package:pharmalens/models/medicine_reminder.dart';
import 'package:pharmalens/models/verified_medicine_result.dart';
import 'package:pharmalens/services/medical_domain_guard_service.dart';
import 'package:pharmalens/services/medication_safety_service.dart';
import 'package:pharmalens/services/medicine_verification_service.dart';
import 'package:pharmalens/services/moph_medicine_service.dart';
import 'package:pharmalens/utils/medicine_equivalence.dart';
import 'package:pharmalens/utils/phonetic_skeleton.dart';
import 'package:pharmalens/widgets/markdown_text.dart';
import 'package:pharmalens/widgets/reminder_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

AiMedicineSuggestion line(
  String name, {
  String strength = '',
  String form = '',
  String directions = '',
  String route = 'UNKNOWN',
  bool routeWritten = false,
}) {
  return AiMedicineSuggestion.fromJson(<String, dynamic>{
    'identificationStatus': 'exact_medicine',
    'exactWrittenText': '$name $strength $form $directions'.trim(),
    'writtenFragment': name,
    'name': name,
    'strength': strength,
    'form': form,
    'writtenInstructions': directions,
    'route': route,
    'routeExplicitlyWritten': routeWritten,
    'confidence': 'high',
  });
}

MedicinePrice product(String brand, {List<String> ingredients = const [], String? atc, String? strength, String? form}) {
  return MedicinePrice.fromCsvRow(<String, String>{
    'medicine_id': brand,
    'brand_name': brand,
    'active_ingredients': ingredients.join('|'),
    'atc_code': atc ?? '',
    'strength': strength ?? '',
    'form': form ?? '',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await MophMedicineService().initialize();
  });

  group('equivalence', () {
    test('route-specific forms never join an oral or skin family', () {
      expect(MedicineEquivalence.formFamily('Vaginal tablet'), 'vaginal');
      expect(MedicineEquivalence.formFamily('Eye Ointment'), 'eye');
      expect(MedicineEquivalence.formFamily('Nasal spray suspension'), 'nasal');
      expect(MedicineEquivalence.formFamily('Suspension for inhalation'), 'inhalation');
      expect(MedicineEquivalence.formFamily('Cream for rectal use'), 'rectal');
      expect(MedicineEquivalence.formFamily('Powder for oral suspension'), 'oral-liquid');
    });

    test('no product in the MOPH list is equivalent across routes', () {
      final catalog = MophMedicineService().catalog;
      const routed = <String>{'eye', 'ear', 'nasal', 'inhalation', 'vaginal', 'rectal', 'suppository'};
      String family(MedicinePrice m) => MedicineEquivalence.formFamily(m.dosageForm).replaceAll('-mr', '');
      for (final a in catalog.where((m) => routed.contains(family(m)))) {
        for (final b in catalog) {
          if (identical(a, b) || !MedicineEquivalence.isEquivalent(a, b)) continue;
          expect(family(b), family(a), reason: '${a.brandName} [${a.dosageForm}] vs ${b.brandName} [${b.dosageForm}]');
        }
      }
      // The case that started this: vaginal misoprostol is not oral Cytotec.
      final misofar = catalog.where((m) => m.brandName.toUpperCase().startsWith('MISOFAR')).firstOrNull;
      final cytotec = catalog.where((m) => m.brandName.toUpperCase().startsWith('CYTOTEC')).firstOrNull;
      if (misofar != null && cytotec != null) {
        expect(MedicineEquivalence.isEquivalent(misofar, cytotec), isFalse);
      }
    });

    test('strengths in g, mg and mcg compare equal', () {
      expect(MedicineEquivalence.strengthKey('1g'), '1000mg');
      expect(MedicineEquivalence.strengthKey('250 mcg'), MedicineEquivalence.strengthKey('0.25mg'));
      expect(MedicineEquivalence.strengthKey('500µg'), '0.5mg');
    });

    test('count-times-size packs are read in full', () {
      expect(MedicineEquivalence.packQuantity('10x1ml'), (10.0, 'ml'));
      expect(MedicineEquivalence.packQuantity('1x100ml'), (100.0, 'ml'));
      expect(MedicineEquivalence.packQuantity('30 (3x10)'), (30.0, 'unit'));
    });
  });

  group('verification', () {
    final service = MedicineVerificationService();

    test('dosing directions are not read as the strength', () async {
      final result = await service.verifySuggestion(line('Augmentin', form: 'Tablet', directions: '5 ml three times daily'));
      // The candidate must still be an Augmentin tablet, not pushed to a
      // product without a strength by a "5 ml" conflict.
      expect(result.candidate?.brandName.toUpperCase(), startsWith('AUGMENTIN'));
      expect(MedicineEquivalence.formFamily(result.candidate?.dosageForm), startsWith('tablet'));
    });

    test('1000mg written matches a 1g product', () async {
      final result = await service.verifySuggestion(line('Augmentin', strength: '1000mg', form: 'Tablet'));
      expect(result.status, MedicineVerificationStatus.verified);
      expect(result.candidate?.strength, '1g');
    });

    test('a written oral route does not block verification', () async {
      final result = await service.verifySuggestion(
        line('Augmentin', strength: '1g', form: 'Tablet', route: 'ORAL', routeWritten: true),
      );
      expect(result.status, MedicineVerificationStatus.verified);
    });
  });

  group('allergies', () {
    const safety = MedicationSafetyService();
    final paracetamol = product('PARA', ingredients: ['Paracetamol'], atc: 'N02BE01');
    final ampicillin = product('AMPI', ingredients: ['Ampicillin'], atc: 'J01CA01');

    test('an allergy typed in Arabic is recognized', () {
      final alerts = safety.check(<MedicinePrice>[paracetamol], allergies: <String>['باراسيتامول']);
      expect(alerts.map((a) => a.type), contains(SafetyAlertType.allergy));
    });

    test('an ingredient allergy extends to its chemical class', () {
      final alerts = safety.check(
        <MedicinePrice>[ampicillin],
        allergies: <String>['Amoxicillin'],
        catalog: MophMedicineService().catalog,
      );
      expect(alerts.map((a) => a.type), contains(SafetyAlertType.relatedAllergy));
    });

    test('possible matches get an allergy alert worded as uncertain', () {
      final alerts = safety.check(const <MedicinePrice>[], allergies: <String>['Paracetamol'], possible: <MedicinePrice>[paracetamol]);
      expect(alerts.single.uncertain, isTrue);
      expect(alerts.single.message(isArabic: false), startsWith('If this line is'));
    });

    test('unknown allergy text is reported as unrecognized', () {
      expect(MedicationSafetyService.isRecognizedAllergy('Amoxicillin', MophMedicineService().catalog), isTrue);
      expect(MedicationSafetyService.isRecognizedAllergy('xyzzy', MophMedicineService().catalog), isFalse);
    });
  });

  group('Arabic search', () {
    test('skeletons match across scripts', () {
      expect(PhoneticSkeleton.ofArabic('بنادول'), PhoneticSkeleton.ofLatin('Panadol'));
      expect(PhoneticSkeleton.ofArabic('اوغمنتين'), PhoneticSkeleton.ofLatin('Augmentin'));
      expect(PhoneticSkeleton.ofArabic('فولتارين'), PhoneticSkeleton.ofLatin('Voltaren'));
    });

    test('a brand typed in Arabic finds the MOPH product', () async {
      final results = await MophMedicineService().searchMedicines('بنادول', limit: 5);
      expect(results, isNotEmpty);
      expect(results.first.brandName.toUpperCase(), startsWith('PANADOL'));
    });

    test('search reports the total number of matches', () async {
      final total = await MophMedicineService().countMatches('');
      expect(total, MophMedicineService().totalMedicineCount);
      expect(await MophMedicineService().countMatches('panadol'), greaterThan(5));
    });
  });

  group('chat guard', () {
    const guard = MedicalDomainGuardService();

    test('crisis messages get help lines', () {
      final decision = guard.evaluateText(input: 'I want to kill myself', responseLanguage: 'English');
      expect(decision.allowed, isFalse);
      expect(decision.userMessage, contains('1564'));
    });

    test('overdose questions are answered', () {
      expect(guard.evaluateText(input: 'what are the signs of paracetamol overdose', responseLanguage: 'English').allowed, isTrue);
    });

    test('follow-ups in a health conversation are allowed', () {
      expect(guard.evaluateText(input: 'and for kids?', responseLanguage: 'English').allowed, isFalse);
      expect(
        guard.evaluateText(input: 'and for kids?', responseLanguage: 'English', hasConversationContext: true).allowed,
        isTrue,
      );
    });
  });

  group('reminders', () {
    test('course length is read from the directions', () {
      expect(courseDaysFrom('1 tab twice daily for 7 days'), 7);
      expect(courseDaysFrom('حبة مرتين يوميًا لمدة 5 أيام'), 5);
      expect(courseDaysFrom('for 2 weeks'), 14);
      expect(courseDaysFrom('when needed'), isNull);
    });

    test('refill date follows supply and doses', () {
      final start = DateTime(2026, 1, 1);
      final reminder = MedicineReminder(id: 1, medicineName: 'X', times: const [480, 1200], startDate: start, packUnits: 28);
      expect(reminder.refillDate, DateTime(2026, 1, 15));
      // A course that ends first needs no refill.
      expect(reminder.copyWith(endDate: DateTime(2026, 1, 7)).refillDate, isNull);
    });

    test('reminders round-trip through JSON with mode and person', () {
      final reminder = MedicineReminder(
        id: 3,
        medicineName: 'X',
        times: const [480],
        mode: ReminderMode.alarm,
        profileId: 'p1',
        packUnits: 20,
        unitsPerDose: 2,
      );
      final copy = MedicineReminder.fromJson(reminder.toJson());
      expect(copy.mode, ReminderMode.alarm);
      expect(copy.profileId, 'p1');
      expect(copy.packUnits, 20);
      expect(copy.unitsPerDose, 2);
    });
  });

  testWidgets('assistant answers render bold without asterisks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownText(
            '### Price\n- **AUGMENTIN 1g**: 1,234 LBP\n* stray ***marker',
            style: TextStyle(fontSize: 14, color: Colors.black),
          ),
        ),
      ),
    );
    final text = tester.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText()).join('\n');
    expect(text, contains('AUGMENTIN 1g'));
    expect(text, isNot(contains('*')));
    expect(text, isNot(contains('#')));
  });
}
