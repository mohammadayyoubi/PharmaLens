// Scrolling performance on a real phone, in profile mode:
//
//   flutter drive --profile -d <device> \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/scroll_perf_test.dart
//
// Frame timings (FrameTiming, no VM service) land in build/integration_response_data.json. Compare
// renderers by adding --no-enable-impeller.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharmalens/main.dart' as app;
import 'package:pharmalens/screens/onboarding_screen.dart';
import 'package:pharmalens/widgets/official_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Frame build and raster times while [action] runs, from the engine's own
/// FrameTiming reports (no VM service needed, so it works over wireless ADB).
Future<Map<String, Object>> measureFrames(WidgetTester tester, Future<void> Function() action) async {
  final timings = <FrameTiming>[];
  void collect(List<FrameTiming> batch) => timings.addAll(batch);
  SchedulerBinding.instance.addTimingsCallback(collect);
  await action();
  // Reports arrive in batches; let the last one come in.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  SchedulerBinding.instance.removeTimingsCallback(collect);

  double ms(Duration d) => d.inMicroseconds / 1000;
  List<double> sorted(Iterable<double> values) => values.toList()..sort();
  final build = sorted(timings.map((t) => ms(t.buildDuration)));
  final raster = sorted(timings.map((t) => ms(t.rasterDuration)));
  double avg(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  double p90(List<double> v) => v.isEmpty ? 0 : v[(v.length * 0.9).floor().clamp(0, v.length - 1)];
  const budget = 1000 / 60;
  return <String, Object>{
    'frames': timings.length,
    'build_avg': avg(build), 'build_p90': p90(build), 'build_worst': build.isEmpty ? 0 : build.last,
    'raster_avg': avg(raster), 'raster_p90': p90(raster), 'raster_worst': raster.isEmpty ? 0 : raster.last,
    'missed_build': build.where((v) => v > budget).length,
    'missed_raster': raster.where((v) => v > budget).length,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home and medicine list scroll', (tester) async {
    // Skip onboarding and the launch notice, in English, and put the
    // user's own settings back afterwards.
    final prefs = await SharedPreferences.getInstance();
    final saved = <String, Object?>{
      for (final key in <String>[OnboardingScreen.seenKey, OfficialNoticeCard.seenKey, 'pharmalens_locale']) key: prefs.get(key),
    };
    addTearDown(() async {
      for (final entry in saved.entries) {
        final value = entry.value;
        if (value == null) {
          await prefs.remove(entry.key);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else {
          await prefs.setString(entry.key, '$value');
        }
      }
    });
    await prefs.setBool(OnboardingScreen.seenKey, true);
    await prefs.setBool(OfficialNoticeCard.seenKey, true);
    await prefs.setString('pharmalens_locale', 'en');
    startupNoticeShown = true;

    app.main();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final results = <String, Object>{};
    results['home'] = await measureFrames(tester, () async {
      final home = find.byType(Scrollable).first;
      for (var i = 0; i < 3; i++) {
        await tester.fling(home, const Offset(0, -700), 3000);
        await tester.pumpAndSettle();
        await tester.fling(home, const Offset(0, 700), 3000);
        await tester.pumpAndSettle();
      }
    });

    await tester.tap(find.text('Medicines').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'pan');
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    results['medicines'] = await measureFrames(tester, () async {
      final list = find.byType(Scrollable).last;
      for (var i = 0; i < 3; i++) {
        await tester.fling(list, const Offset(0, -900), 4000);
        await tester.pumpAndSettle();
      }
      await tester.fling(list, const Offset(0, 2700), 4000);
      await tester.pumpAndSettle();
    });
    binding.reportData = results;
  });
}
