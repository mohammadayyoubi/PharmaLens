import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/app/app_shell.dart';
import 'package:pharmalens/l10n/app_localizations.dart';
import 'package:pharmalens/theme/pharmalens_theme.dart';
import 'package:pharmalens/widgets/official_notice.dart';
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
    // The launch notices are tested on their own below.
    SharedPreferences.setMockInitialValues(<String, Object>{OfficialNoticeCard.seenKey: true});
    startupNoticeShown = true;
  });

  testWidgets('phone layout uses the bottom bar with a Scan button', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byKey(const Key('phone-nav')), findsOneWidget);
    expect(find.byKey(const Key('scan-button')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Read your prescription'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the assistant button stays above the bottom bar', (tester) async {
    await setSize(tester, const Size(390, 844));
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 1));

    final assistant = tester.getRect(find.byTooltip('AI assistant').first);
    final bar = tester.getRect(find.byKey(const Key('phone-nav')));
    // The bar's widget starts with the space for the raised Scan button
    // (20 px); its flat top is below that.
    expect(assistant.bottom, lessThanOrEqualTo(bar.top + 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Scan button asks for camera or gallery', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pumpAndSettle();

    expect(find.text('Scan a prescription'), findsWidgets);
    expect(find.text('Who is this prescription for?'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom bar labels stay on one line on a narrow phone with large text', (tester) async {
    await setSize(tester, const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(app(locale: const Locale('ar')));
    await tester.pump();

    final bar = find.byKey(const Key('phone-nav'));
    final labels = find.descendant(of: bar, matching: find.byType(Text));
    expect(labels, findsNWidgets(5));
    for (final element in labels.evaluate()) {
      final height = tester.getSize(find.byWidget(element.widget)).height;
      expect(height, lessThan(30), reason: '${(element.widget as Text).data} wrapped ($height px)');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('each launch starts with the "AI can make mistakes" acknowledgement', (tester) async {
    startupNoticeShown = false;
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Before you start'), findsOneWidget);
    expect(find.textContaining('AI can make mistakes'), findsWidgets);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(find.text('Before you start'), findsNothing);
  });

  testWidgets('the bottom bar hides while the keyboard is open', (tester) async {
    await setSize(tester, const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byKey(const Key('phone-nav')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing users see the "not the MOPH app" notice once', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    startupNoticeShown = false;
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Not an official MOPH app'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(find.text('Not an official MOPH app'), findsNothing);
    expect((await SharedPreferences.getInstance()).getBool(OfficialNoticeCard.seenKey), isTrue);
  });

  testWidgets('tablet layout uses a navigation rail', (tester) async {
    await setSize(tester, const Size(900, 1000));
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const Key('phone-nav')), findsNothing);
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
