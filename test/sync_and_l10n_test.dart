import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/l10n/app_text.dart';
import 'package:pharmalens/services/moph_medicine_service.dart';
import 'package:pharmalens/widgets/sync_progress.dart';

void main() {
  group('Sync progress widgets', () {
    final progress = MophMedicineService().progress;
    tearDown(() => progress.value = MophSyncProgress.idle);

    Widget host(Widget child) => MaterialApp(home: Scaffold(body: Column(children: <Widget>[child])));

    testWidgets('the sync button shows the percentage and cannot be pressed while busy', (tester) async {
      var presses = 0;
      await tester.pumpWidget(host(MophSyncButton(tooltip: 'Sync', onPressed: () => presses++)));

      await tester.tap(find.byType(IconButton));
      expect(presses, 1);

      progress.value = const MophSyncProgress(MophSyncStage.downloading, 0.42);
      await tester.pump();
      expect(find.byType(IconButton), findsNothing);
      expect(find.text('42'), findsOneWidget);
      await tester.tap(find.byType(MophSyncButton));
      expect(presses, 1);

      progress.value = MophSyncProgress.idle;
      await tester.pump();
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('the progress line names the stage and is hidden when idle', (tester) async {
      await tester.pumpWidget(host(const MophSyncProgressLine(isArabic: false)));
      expect(find.byType(LinearProgressIndicator), findsNothing);

      progress.value = const MophSyncProgress(MophSyncStage.checking, 0.1);
      await tester.pumpAndSettle();
      expect(find.text('Checking for new data…'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('Translations', () {
    Map<String, dynamic> arb(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

    test('every English string has an Arabic one with the same placeholders', () {
      final en = arb('app_en.arb');
      final ar = arb('app_ar.arb');
      final placeholder = RegExp(r'\{(\w+)\}');
      for (final key in en.keys.where((k) => !k.startsWith('@'))) {
        expect(ar.containsKey(key), isTrue, reason: '$key is missing in Arabic');
        final enNames = placeholder.allMatches(en[key] as String).map((m) => m.group(1)).toSet();
        final arNames = placeholder.allMatches(ar[key] as String).map((m) => m.group(1)).toSet();
        expect(arNames, enNames, reason: '$key placeholders differ');
      }
    });

    test('appText follows the language flag it is given', () {
      expect(appText(false).checkingForNewData, 'Checking for new data…');
      expect(appText(true).checkingForNewData, 'جارٍ التحقق من بيانات جديدة…');
    });
  });
}
