import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/app/app_shell.dart';
import 'package:pharmalens/l10n/app_localizations.dart';
import 'package:pharmalens/theme/pharmalens_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app({Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: PharmaLensTheme.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
    ],
    home: const AppShell(),
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

  testWidgets('phone layout uses bottom navigation', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Read your prescription'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet layout uses a navigation rail', (tester) async {
    await setSize(tester, const Size(900, 1000));
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop layout shows the sidebar and switches sections', (tester) async {
    await setSize(tester, const Size(1440, 900));
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Medicine safety assistant'), findsOneWidget);

    await tester.tap(find.text('My health').first);
    await tester.pumpAndSettle();

    expect(find.text('Scanned prescriptions'), findsOneWidget);
    expect(find.text('Medicine reminders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const <Size>[Size(390, 844), Size(1440, 900)]) {
    testWidgets('sections render without overflow at ${size.width.toInt()}px', (tester) async {
      await setSize(tester, size);
      await tester.pumpWidget(app());
      await tester.pump();

      for (final label in <String>['Doctors', 'Medicines', 'My health']) {
        await tester.tap(find.text(label).last);
        // Doctors and medicines load bundled CSVs in background isolates.
        await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull, reason: '$label at $size');
      }
    });
  }

  testWidgets('Arabic phone layout renders right-to-left without overflow', (tester) async {
    await setSize(tester, const Size(360, 780));
    await tester.pumpWidget(app(locale: const Locale('ar')));
    await tester.pump();

    expect(find.text('اقرأ وصفتك الطبية'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(AppShell))), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}
