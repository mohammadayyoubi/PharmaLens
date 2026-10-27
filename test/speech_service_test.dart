import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final spoken = <String>[];

  setUp(() {
    spoken.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'speak') spoken.add('${call.arguments is List ? (call.arguments as List).first : call.arguments}');
      if (call.method == 'isLanguageAvailable') return true;
      return 1;
    });
  });

  tearDown(() async {
    await SpeechService().stop();
    messenger.setMockMethodCallHandler(channel, null);
  });

  /// Sends a callback from the "engine" to the plugin.
  Future<void> engine(String method, [Object? arguments]) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }

  const text = 'XAVIRAN. 20mg. Tablet. Used for: preventing blood clots.';

  test('pressing again pauses, and the next press resumes from the word reached', () async {
    final speech = SpeechService();

    await speech.toggle('a', text, isArabic: false);
    expect(speech.state, SpeechState.playing);
    expect(speech.isActiveFor('a'), isTrue);
    expect(spoken.single, text);

    // The engine has reached "Tablet".
    await engine('speak.onProgress', <String, Object>{'text': text, 'start': 15, 'end': 21, 'word': 'Tablet'});

    await speech.toggle('a', text, isArabic: false);
    expect(speech.state, SpeechState.paused);

    // Stopping the engine for the pause must not reset it.
    await engine('speak.onCancel');
    expect(speech.state, SpeechState.paused);

    await speech.toggle('a', text, isArabic: false);
    expect(speech.state, SpeechState.playing);
    expect(spoken.last, startsWith('Tablet.'));
  });

  test('finishing returns to idle, and another medicine starts fresh', () async {
    final speech = SpeechService();

    await speech.toggle('a', text, isArabic: false);
    await engine('speak.onComplete');
    expect(speech.state, SpeechState.idle);
    expect(speech.isActiveFor('a'), isFalse);

    await speech.toggle('a', text, isArabic: false);
    await speech.toggle('b', 'CONCOR. 5mg.', isArabic: false);
    expect(speech.isActiveFor('b'), isTrue);
    expect(speech.isActiveFor('a'), isFalse);
    expect(spoken.last, 'CONCOR. 5mg.');
  });
}
