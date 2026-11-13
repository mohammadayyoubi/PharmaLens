import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/app/app_shell.dart';
import 'package:pharmalens/l10n/app_localizations.dart';
import 'package:pharmalens/models/medicine_reminder.dart';
import 'package:pharmalens/screens/dose_screen.dart';
import 'package:pharmalens/screens/my_health_screen.dart';
import 'package:pharmalens/services/health_profile_service.dart';
import 'package:pharmalens/screens/onboarding_screen.dart';
import 'package:pharmalens/theme/pharmalens_theme.dart';
import 'package:pharmalens/widgets/official_notice.dart';
import 'package:pharmalens/widgets/reminder_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(Widget home, {Locale locale = const Locale('en'), double textScale = 1}) {
  return MaterialApp(
    theme: PharmaLensTheme.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{OfficialNoticeCard.seenKey: true});
    startupNoticeShown = true;
  });

  testWidgets('home fits a small phone with large text', (tester) async {
    await setSize(tester, const Size(320, 640));
    await tester.pumpWidget(wrap(const AppShell(), textScale: 1.6));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Read your prescription'), findsOneWidget);
    // The header is just the logo and Settings.
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('CHECKED WITH MOPH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('onboarding pages render in ${locale.languageCode}', (tester) async {
      await setSize(tester, const Size(360, 680));
      await tester.pumpWidget(wrap(OnboardingScreen(onDone: () {}), locale: locale));
      await tester.pump(const Duration(seconds: 1));

      for (var page = 0; page < 4; page++) {
        expect(tester.takeException(), isNull, reason: 'page $page');
        // RTL pages scroll the other way.
        await tester.drag(find.byType(PageView), Offset(locale.languageCode == 'ar' ? 400 : -400, 0));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('onboarding says the app is not the MOPH app', (tester) async {
    await setSize(tester, const Size(360, 680));
    await tester.pumpWidget(wrap(OnboardingScreen(onDone: () {})));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Not an official MOPH app'), findsOneWidget);
    expect(find.text('An individual initiative'), findsOneWidget);
  });

  testWidgets('health tab shows the new conditions and the BMI scale on a narrow phone', (tester) async {
    await setSize(tester, const Size(320, 700));
    await tester.runAsync(() async {
      await HealthProfileService().load();
      // 98 kg at 170 cm: BMI 33.9, obesity class I.
      await HealthProfileService().setBody(age: 40, heightCm: 170, weightKg: 98);
    });
    MyHealthScreen.requestedTab.value = 2;
    await tester.pumpWidget(wrap(const MyHealthScreen(), textScale: 1.3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Asthma'), findsOneWidget);
    expect(find.text('Cancer'), findsOneWidget);
    expect(find.text('Other…'), findsOneWidget);
    expect(find.textContaining('Obesity class I'), findsOneWidget);
    expect(find.bySemanticsLabel('BMI scale'), findsOneWidget);
    // The colored bands must actually have height (they once were 0 px).
    final band = tester.getSize(find.byKey(const ValueKey<String>('bmi-band-18.5')));
    expect(band.height, greaterThan(10));
    expect(band.width, greaterThan(20));
    expect(tester.takeException(), isNull);
  });

  test('BMI classes follow the WHO bands', () {
    expect(bmiCategory(24.9, isArabic: false), 'Healthy weight');
    expect(bmiCategory(32, isArabic: false), 'Obesity class I');
    expect(bmiCategory(37, isArabic: false), 'Obesity class II');
    expect(bmiCategory(41, isArabic: false), 'Obesity class III');
    expect(bmiCategory(41, isArabic: true), 'سمنة من الدرجة الثالثة');
  });

  testWidgets('dose screen shows Taken and Snooze', (tester) async {
    await setSize(tester, const Size(360, 640));
    final dose = DueDose(
      reminder: const MedicineReminder(id: 1, medicineName: 'AUGMENTIN 1g', times: [480], doseNote: '1 tablet after food'),
      minutes: 480,
      day: DateTime.now(),
    );
    await tester.pumpWidget(wrap(DoseScreen(dose: dose)));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('AUGMENTIN 1g'), findsOneWidget);
    expect(find.text('Taken'), findsOneWidget);
    expect(find.textContaining('Snooze'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reminder editor offers notification or alarm and takes the course from the directions', (tester) async {
    await setSize(tester, const Size(360, 780));
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showReminderEditor(context, medicineName: 'X', doseNote: '1 tab twice daily for 7 days'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Notification'), findsOneWidget);
    expect(find.text('Alarm'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
