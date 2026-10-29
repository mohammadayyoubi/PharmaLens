import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/screens/pharmacies_map_screen.dart';
import 'package:pharmalens/theme/pharmalens_theme.dart';
import 'package:pharmalens/widgets/universal_map_view.dart';

void main() {
  // Phones used Google's map SDK, which needs a billing account; every
  // platform now draws the keyless OpenStreetMap view.
  testWidgets('pharmacies map uses OpenStreetMap on phones', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(theme: PharmaLensTheme.light, home: const PharmaciesMapScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(UniversalHealthcareMapView), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Leave no timers behind (location lookups, map animations).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.mobile());
}
