import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/models/ai_handwriting_result.dart';
import 'package:pharmalens/models/medicine_price.dart';
import 'package:pharmalens/models/verified_medicine_result.dart';
import 'package:pharmalens/screens/medicine_details_screen.dart';
import 'package:pharmalens/services/gemini_client.dart';
import 'package:pharmalens/services/medicine_info_service.dart';
import 'package:pharmalens/services/moph_medicine_service.dart';
import 'package:pharmalens/theme/pharmalens_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

MedicinePrice medicine(String brand, String strength, {String form = 'Tablet, film coated'}) {
  return MedicinePrice.fromCsvRow(<String, String>{
    'medicine_id': brand,
    'brand_name': brand,
    'active_ingredients': 'Rivaroxaban',
    'strength': strength,
    'form': form,
    'pack': '30',
    'official_price_lbp': '952208',
    'currency': 'LBP',
  });
}

void main() {
  group('GeminiClient.generationConfig', () {
    test('Gemini 3 models get a low thinking level and keep their default temperature', () {
      final config = GeminiClient.generationConfig(model: 'gemini-3.5-flash-lite', maxOutputTokens: 8192);

      expect(config['thinkingConfig'], <String, dynamic>{'thinkingLevel': 'low'});
      expect(config.containsKey('temperature'), isFalse);
      expect(config['maxOutputTokens'], 8192);
    });

    test('"-latest" aliases are treated as current models', () {
      final config = GeminiClient.generationConfig(model: 'gemini-flash-latest', maxOutputTokens: 100);
      expect(config['thinkingConfig'], <String, dynamic>{'thinkingLevel': 'low'});
    });

    test('Gemini 2.5 keeps a low temperature and turns thinking off where allowed', () {
      final flash = GeminiClient.generationConfig(model: 'gemini-2.5-flash', maxOutputTokens: 100);
      final pro = GeminiClient.generationConfig(model: 'gemini-2.5-pro', maxOutputTokens: 100);

      expect(flash['temperature'], 0.0);
      expect(flash['thinkingConfig'], <String, dynamic>{'thinkingBudget': 0});
      expect(pro['thinkingConfig'], <String, dynamic>{'thinkingBudget': 128});
    });

    test('a schema switches the response to JSON', () {
      final config = GeminiClient.generationConfig(
        model: 'gemini-3.1-flash-lite',
        maxOutputTokens: 100,
        responseSchema: const <String, dynamic>{'type': 'OBJECT'},
      );
      expect(config['responseMimeType'], 'application/json');
    });

    test('JSON is recovered from fenced or padded answers', () {
      expect(GeminiClient.decodeJsonObject('```json\n{"a": 1}\n```'), <String, dynamic>{'a': 1});
      expect(GeminiClient.decodeJsonObject('Here it is: {"a": 2} done'), <String, dynamic>{'a': 2});
    });
  });

  group('MedicineInfoService.cacheKeyFor', () {
    test('brands share information, strengths and forms do not', () {
      expect(MedicineInfoService.cacheKeyFor(medicine('XAVIRAN', '20mg')), MedicineInfoService.cacheKeyFor(medicine('XARELTO', '20 mg')));
      expect(MedicineInfoService.cacheKeyFor(medicine('XAVIRAN', '20mg')), isNot(MedicineInfoService.cacheKeyFor(medicine('XAVIRAN', '15mg'))));
      expect(
        MedicineInfoService.cacheKeyFor(medicine('XAVIRAN', '20mg')),
        isNot(MedicineInfoService.cacheKeyFor(medicine('XAVIRAN', '20mg', form: 'Oral suspension'))),
      );
    });
  });

  group('MedicineDetailsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    for (final size in const <Size>[Size(390, 4200), Size(1440, 2600)]) {
      testWidgets('renders a real MOPH product without overflow at ${size.width.toInt()}px', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.runAsync(() => MophMedicineService().initialize());
        final xaviran = (await tester.runAsync(() => MophMedicineService().searchMedicines('XAVIRAN')))!
            .firstWhere((m) => m.brandName == 'XAVIRAN' && (m.strength ?? '').contains('20'));

        await tester.pumpWidget(
          MaterialApp(theme: PharmaLensTheme.dark, home: MedicineDetailsScreen(medicine: xaviran)),
        );
        await tester.pump();

        // Network calls fail inside widget tests; the page must offer a retry.
        await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Read aloud'), findsOneWidget);
        expect(find.text('Same medicine, other prices'), findsOneWidget);

        final notice = find.textContaining('Could not load the medicine information');
        await tester.scrollUntilVisible(notice, 600, scrollable: find.byType(Scrollable).first);
        expect(notice, findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }


    VerifiedMedicineResult scanned({String frequency = '', String duration = ''}) {
      return VerifiedMedicineResult(
        suggestion: AiMedicineSuggestion.fromJson(<String, dynamic>{
          'identificationStatus': 'exact_medicine',
          'exactWrittenText': 'Xaviran 20mg tab',
          'writtenFragment': 'Xaviran',
          'name': 'Xaviran',
          'strength': '20mg',
          'form': 'Tablet',
          'frequency': frequency,
          'duration': duration,
          'route': 'ORAL',
          'confidence': 'high',
        }),
        status: MedicineVerificationStatus.verified,
        candidate: medicine('XAVIRAN', '20mg'),
        knowledge: null,
        verificationScore: 1,
        candidateCount: 1,
        message: '',
      );
    }

    Future<void> pumpScanned(WidgetTester tester, VerifiedMedicineResult result) async {
      tester.view.physicalSize = const Size(1440, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() => MophMedicineService().initialize());
      await tester.pumpWidget(MaterialApp(theme: PharmaLensTheme.light, home: MedicineDetailsScreen(result: result)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets("scanned medicine shows the doctor's written directions first", (tester) async {
      await pumpScanned(tester, scanned(frequency: '1 x 1 with dinner', duration: '30 days'));

      expect(find.text('As written by your doctor'), findsOneWidget);
      expect(find.textContaining('1 x 1 with dinner'), findsOneWidget);
      expect(find.textContaining('No directions are written'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scanned medicine without directions says to ask the doctor', (tester) async {
      await pumpScanned(tester, scanned());

      expect(find.text('As written by your doctor'), findsNothing);
      expect(find.textContaining('No directions are written on the prescription'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
