import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/models/medicine_price.dart';
import 'package:pharmalens/screens/medicine_details_screen.dart';
import 'package:pharmalens/screens/medicine_search_screen.dart';
import 'package:pharmalens/screens/my_health_screen.dart';
import 'package:pharmalens/services/health_profile_service.dart';
import 'package:pharmalens/services/moph_medicine_service.dart';
import 'package:pharmalens/services/prescription_history_service.dart';
import 'package:pharmalens/widgets/for_you_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'new_screens_test.dart' show setSize, wrap;

MedicinePrice medicine({String atc = 'B01AF01'}) {
  return MedicinePrice.fromCsvRow(<String, String>{
    'medicine_id': 'TEST',
    'brand_name': 'TESTMED',
    'active_ingredients': 'Rivaroxaban',
    'atc_code': atc,
    'strength': '20 mg',
    'form': 'Tablet',
    'pack': '30',
    'official_price_lbp': '100000',
    'currency': 'LBP',
  });
}

void main() {
  // The services are app-wide singletons that load once, so the stored data
  // is set up before anything reads it and the tests run in this order.
  setUpAll(() {
    final now = DateTime(2026, 10, 30);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pharmalens_prescription_history_v1': jsonEncode(<Map<String, Object>>[
        for (var i = 0; i < 25; i++)
          <String, Object>{
            'id': 'r$i',
            'created_at': now.subtract(Duration(days: i)).toIso8601String(),
            'profile_id': 'me',
            'medicines': <Object>[],
          },
      ]),
    });
  });

  testWidgets('My Health shows prescriptions ten at a time', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.runAsync(() => PrescriptionHistoryService().load());
    await tester.pumpWidget(wrap(const MyHealthScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Show more (15 left)'), findsOneWidget);

    // Scrolling near the end loads the next page by itself...
    await tester.ensureVisible(find.text('Show more (15 left)'));
    await tester.pump();
    expect(find.text('Show more (5 left)'), findsOneWidget);

    // ...and the button loads the rest.
    await tester.ensureVisible(find.text('Show more (5 left)'));
    await tester.pump();
    final button = find.textContaining('Show more');
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button);
      await tester.pump();
    }
    expect(find.textContaining('Show more'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the family member dialog, or adding one, does not crash', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(const MyHealthScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap outside the dialog.
    await tester.tap(find.text('Family member'));
    await tester.pumpAndSettle();
    expect(find.text('Add a family member'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Add a family member'), findsNothing);
    expect(tester.takeException(), isNull);

    // Fill in a name and press Add.
    await tester.tap(find.text('Family member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Mom');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(HealthProfileService().profiles.map((p) => p.name), contains('Mom'));

    await tester.runAsync(() => HealthProfileService().setActive(HealthProfileService.ownerId));
  });

  group('Body details', () {
    test('are saved with the profile and give BMI and age', () {
      final person = const HealthProfile(id: 'me', name: '').withBody(
        birthYear: DateTime.now().year - 40,
        sex: BiologicalSex.female,
        heightCm: 170,
        weightKg: 85,
      );
      final restored = HealthProfile.fromJson(jsonDecode(jsonEncode(person.toJson())) as Map<String, dynamic>)!;

      expect(restored.age, 40);
      expect(restored.sex, BiologicalSex.female);
      expect(restored.bmi, closeTo(29.4, 0.05));
      expect(bmiCategory(restored.bmi!, isArabic: false), 'Overweight');
    });

    testWidgets('a medicine page asks people over 65 to check with their doctor', (tester) async {
      await tester.runAsync(() => HealthProfileService().setBody(age: 70, weightKg: 70, heightCm: 170));
      await tester.pumpWidget(wrap(SingleChildScrollView(child: ForYouCard(medicine: medicine(), knowledge: null, isArabic: false))));

      expect(find.text('Age 70'), findsOneWidget);
      expect(find.textContaining('Check with your doctor'), findsOneWidget);
    });

    testWidgets('a weight-loss medicine is flagged for a normal BMI', (tester) async {
      await tester.runAsync(() => HealthProfileService().setBody(age: 30, weightKg: 60, heightCm: 175));
      await tester.pumpWidget(
        wrap(SingleChildScrollView(child: ForYouCard(medicine: medicine(atc: 'A08AB01'), knowledge: null, isArabic: false))),
      );

      expect(find.textContaining('weight-loss medicine'), findsOneWidget);
      await tester.runAsync(() => HealthProfileService().setBody());
    });
  });

  testWidgets('clearing the medicine search shows the whole list again', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.runAsync(() => MophMedicineService().initialize());
    await tester.pumpWidget(wrap(const MedicineSearchScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzqqxxnotamedicine');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.textContaining('No matching medicines'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.textContaining('No matching medicines'), findsNothing);
    expect(find.textContaining('No medicines found'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a closed Alternatives card stays closed after scrolling away and back', (tester) async {
    await setSize(tester, const Size(390, 800));
    await tester.runAsync(() => MophMedicineService().initialize());
    final xaviran = (await tester.runAsync(() => MophMedicineService().searchMedicines('XAVIRAN')))!
        .firstWhere((m) => m.brandName == 'XAVIRAN' && (m.strength ?? '').contains('20'));

    await tester.pumpWidget(wrap(MedicineDetailsScreen(medicine: xaviran)));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(milliseconds: 500));

    final title = find.textContaining('Alternatives (');
    await tester.scrollUntilVisible(title, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Same dose · '), findsOneWidget);

    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(find.textContaining('Same dose · '), findsNothing);

    // Far enough down that the card is dropped from the lazy list.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 8000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(title, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Same dose · '), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
