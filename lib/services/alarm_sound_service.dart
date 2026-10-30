import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A sound medicine alarms can ring with. An empty [uri] is the PharmaLens
/// tone that ships with the app.
class AlarmSound {
  const AlarmSound({this.uri = '', this.title = ''});

  final String uri;
  final String title;

  bool get isDefault => uri.isEmpty;
}

/// The tone alarm-mode reminders ring with, chosen from the phone's alarm
/// tones or from any audio file on the device (Android; elsewhere alarms
/// keep the PharmaLens tone). See android/.../AlarmSound.kt.
///
/// ReminderService listens and moves scheduled alarms to a notification
/// channel with the new sound, since Android fixes a channel's sound when
/// the channel is created.
class AlarmSoundService extends ChangeNotifier {
  AlarmSoundService._internal();

  static final AlarmSoundService _instance = AlarmSoundService._internal();

  factory AlarmSoundService() => _instance;

  static const MethodChannel _channel = MethodChannel('pharmalens/alarm_sound');
  static const String _uriKey = 'pharmalens_alarm_sound_uri';
  static const String _titleKey = 'pharmalens_alarm_sound_title';

  AlarmSound _sound = const AlarmSound();
  bool _loaded = false;

  AlarmSound get sound => _sound;

  /// Choosing a sound, and playing it from the app, works on Android only.
  bool get canChoose => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _sound = AlarmSound(uri: prefs.getString(_uriKey) ?? '', title: prefs.getString(_titleKey) ?? '');
      if (!_sound.isDefault) notifyListeners();
    } catch (error) {
      debugPrint('AlarmSoundService: could not load the alarm sound: $error');
    }
  }

  /// The phone's alarm tones. Returns false when the user backed out.
  Future<bool> pickPhoneTone({required String pickerTitle}) =>
      _pick('pickTone', <String, Object>{'current': _sound.uri, 'title': pickerTitle});

  /// Any audio file on the device (a song, a recording...).
  Future<bool> pickFile() => _pick('pickFile', const <String, Object>{});

  Future<void> useDefault() => _set(const AlarmSound());

  Future<bool> _pick(String method, Map<String, Object> arguments) async {
    if (!canChoose) return false;
    await load();
    await stop();
    try {
      final picked = await _channel.invokeMapMethod<String, String>(method, arguments);
      final uri = picked?['uri'] ?? '';
      if (uri.isEmpty) return false;
      await _set(AlarmSound(uri: uri, title: picked?['title'] ?? ''));
      return true;
    } catch (error) {
      debugPrint('AlarmSoundService: $method failed: $error');
      return false;
    }
  }

  Future<void> _set(AlarmSound sound) async {
    if (sound.uri == _sound.uri) return;
    _sound = sound;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (sound.isDefault) {
        await prefs.remove(_uriKey);
        await prefs.remove(_titleKey);
      } else {
        await prefs.setString(_uriKey, sound.uri);
        await prefs.setString(_titleKey, sound.title);
      }
    } catch (error) {
      debugPrint('AlarmSoundService: could not save the alarm sound: $error');
    }
  }

  /// Plays the chosen sound (Android). Falls back to the PharmaLens tone if
  /// the file is gone.
  Future<void> play({bool loop = true}) async {
    if (!canChoose) return;
    await load();
    try {
      await _channel.invokeMethod<void>('play', <String, Object>{'uri': _sound.uri, 'loop': loop});
    } catch (error) {
      debugPrint('AlarmSoundService: could not play: $error');
    }
  }

  Future<void> stop() async {
    if (!canChoose) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
