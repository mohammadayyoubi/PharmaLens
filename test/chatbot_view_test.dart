import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/theme/pharmalens_theme.dart';
import 'package:pharmalens/widgets/chatbot_view.dart';

void main() {
  for (final size in const <Size>[Size(390, 844), Size(1440, 900)]) {
    testWidgets('assistant opens without errors at ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: PharmaLensTheme.light,
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => ChatbotView.showAsBottomSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatbotView), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
