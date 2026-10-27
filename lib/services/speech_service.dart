import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum SpeechState { idle, playing, paused }

/// Reads medicine names and instructions aloud, for users who find small
/// print hard to read.
///
/// Pausing stops the engine and remembers the last word reached, and resuming
/// speaks the rest. This works the same on every platform, while native
/// pause support varies. Listen to the service to show play/pause state.
class SpeechService extends ChangeNotifier {
  SpeechService._internal();

  static final SpeechService _instance = SpeechService._internal();

  factory SpeechService() => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  SpeechState _state = SpeechState.idle;
  SpeechState get state => _state;

  /// Identifies what is being read, so only the matching button shows the
  /// playing state.
  String? _ownerId;
  String? get ownerId => _ownerId;

  String _text = '';
  bool _isArabic = false;

  /// Character offset in [_text] where the current utterance started, plus
  /// the progress reported by the engine within it.
  int _segmentStart = 0;
  int _progress = 0;

  /// Set while we stop the engine on purpose, so its cancel callback does not
  /// reset a pause.
  bool _stoppingForPause = false;

  bool isActiveFor(String id) => _ownerId == id && _state != SpeechState.idle;

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() => _setState(SpeechState.playing));
    _tts.setCompletionHandler(_finish);
    _tts.setErrorHandler((message) {
      debugPrint('SpeechService: engine error: $message');
      _finish();
    });
    _tts.setCancelHandler(() {
      if (!_stoppingForPause) _finish();
    });
    _tts.setProgressHandler((text, start, end, word) {
      _progress = start;
    });

    _configured = true;
  }

  /// Starts reading [text], or pauses/resumes it when [id] is already the one
  /// being read. Returns false when speech is not available on this device.
  Future<bool> toggle(String id, String text, {required bool isArabic}) async {
    if (_ownerId == id && _state == SpeechState.playing) {
      await pause();
      return true;
    }
    if (_ownerId == id && _state == SpeechState.paused) {
      return _speakFrom(_segmentStart + _progress);
    }

    final cleaned = text.trim();
    if (cleaned.isEmpty) return false;

    await stop();
    _ownerId = id;
    _text = cleaned;
    _isArabic = isArabic;
    return _speakFrom(0);
  }

  Future<bool> _speakFrom(int offset) async {
    try {
      await _configure();

      final language = _isArabic ? 'ar' : 'en-US';
      final available = await _tts.isLanguageAvailable(language);
      if (available == true || available == 1) {
        await _tts.setLanguage(language);
      }

      // Restart at a word boundary so the first word is not cut in half.
      var start = offset.clamp(0, _text.length);
      while (start > 0 && start < _text.length && _text[start - 1].trim().isNotEmpty) {
        start--;
      }
      if (start >= _text.length) start = 0;

      _segmentStart = start;
      _progress = 0;
      _setState(SpeechState.playing);
      await _tts.speak(_text.substring(start));
      return true;
    } catch (error) {
      debugPrint('SpeechService: could not speak: $error');
      _finish();
      return false;
    }
  }

  Future<void> pause() async {
    if (_state != SpeechState.playing) return;
    _stoppingForPause = true;
    _setState(SpeechState.paused);
    try {
      await _tts.stop();
    } catch (_) {
      // Already stopped.
    } finally {
      _stoppingForPause = false;
    }
  }

  Future<void> stop() async {
    if (_state == SpeechState.idle && _ownerId == null) return;
    _ownerId = null;
    _setState(SpeechState.idle);
    try {
      await _tts.stop();
    } catch (_) {
      // Already stopped.
    }
  }

  void _finish() {
    if (_state == SpeechState.paused) return;
    _ownerId = null;
    _segmentStart = 0;
    _progress = 0;
    _setState(SpeechState.idle);
  }

  void _setState(SpeechState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }
}
