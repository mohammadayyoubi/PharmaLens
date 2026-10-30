import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/app/app_shell.dart';
import 'package:pharmalens/l10n/app_localizations.dart';
import 'package:pharmalens/models/medicine_reminder.dart';
import 'package:pharmalens/screens/dose_screen.dart';
import 'package:pharmalens/screens/onboarding_screen.dart';
import 'package:pharmalens/theme/pharmalens_theme.dart';
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
    SharedPreferences.setMockInitialValues(<String, Object>{});
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

      for (var page = 0; page < 3; page++) {
        expect(tester.takeException(), isNull, reason: 'page $page');
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
    });
  }

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
