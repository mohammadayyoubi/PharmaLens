import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/app_text.dart';
import '../models/medicine_reminder.dart';
import '../services/alarm_sound_service.dart';
import '../services/reminder_service.dart';
import '../theme/pharmalens_theme.dart';

/// The screen a medicine reminder opens: what to take now, with Taken,
/// Snooze and Skip. For alarm-mode reminders it plays the PharmaLens alarm
/// tone and, between tones, says the time and the medicine name aloud.
class DoseScreen extends StatefulWidget {
  const DoseScreen({super.key, required this.dose});

  final DueDose dose;

  static bool _open = false;

  /// Shows [dose] unless a dose screen is already open.
  static Future<void> show(NavigatorState navigator, DueDose dose) async {
    if (_open) return;
    _open = true;
    try {
      await navigator.push(
        PageRouteBuilder<void>(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (_, animation, secondaryAnimation) => DoseScreen(dose: dose),
          transitionsBuilder: (_, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(animation), child: child)),
        ),
      );
    } finally {
      _open = false;
    }
  }

  @override
  State<DoseScreen> createState() => _DoseScreenState();
}

class _DoseScreenState extends State<DoseScreen> with SingleTickerProviderStateMixin {
  static const MethodChannel _lockScreen = MethodChannel('pharmalens/lock_screen');

  /// The alarm stops ringing after this long without an answer.
  static const Duration _ringFor = Duration(minutes: 5);

  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  Timer? _cycle;
  Timer? _stopRinging;
  bool _ringing = false;
  bool _busy = false;

  DueDose get _dose => widget.dose;
  MedicineReminder get _reminder => widget.dose.reminder;
  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  @override
  void initState() {
    super.initState();
    // The system notification stops; this screen takes over the sound.
    unawaited(ReminderService().dismiss(_dose));
    if (_reminder.isAlarm) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startRinging());
    }
  }

  Future<void> _startRinging() async {
    if (!mounted) return;
    _ringing = true;
    _stopRinging = Timer(_ringFor, _silence);
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
      final language = _isArabic ? 'ar' : 'en-US';
      final available = await _tts.isLanguageAvailable(language);
      if (available == true || available == 1) await _tts.setLanguage(language);
    } catch (error) {
      debugPrint('DoseScreen: audio setup failed: $error');
    }
    unawaited(_ringOnce());
  }

  /// Tone, then the spoken reminder, then a pause; repeated until answered.
  /// On Android the tone is the one chosen for alarms (AlarmSoundService),
  /// which may be a long song: it loops, and pauses while the name is read.
  Future<void> _ringOnce() async {
    if (!_ringing || !mounted) return;
    final sounds = AlarmSoundService();
    try {
      if (sounds.canChoose) {
        await sounds.play(loop: true);
        // Without the spoken name it simply rings until answered.
        if (!_reminder.speakName) return;
        await Future<void>.delayed(const Duration(seconds: 6));
        if (!_ringing || !mounted) return;
        await sounds.stop();
        await _tts.speak(_spokenText());
      } else {
        await _player.play(AssetSource('sounds/pharmalens_alarm.wav'), volume: 1.0);
        await Future<void>.delayed(const Duration(milliseconds: 3300));
        if (!_ringing || !mounted) return;
        if (_reminder.speakName) {
          await _tts.speak(_spokenText());
        }
      }
    } catch (error) {
      debugPrint('DoseScreen: could not play the alarm: $error');
    }
    if (!_ringing || !mounted) return;
    _cycle = Timer(const Duration(seconds: 3), () => unawaited(_ringOnce()));
  }

  String _spokenText() {
    final time = MedicineReminder.formatTime(_dose.minutes);
    final note = _reminder.doseNote.trim();
    return appText(_isArabic).itIsTimeToTake(time, _reminder.medicineName, note.isEmpty ? '' : ' $note.');
  }

  Future<void> _silence() async {
    _ringing = false;
    _cycle?.cancel();
    _stopRinging?.cancel();
    try {
      await _player.stop();
      await AlarmSoundService().stop();
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _answer(Future<void> Function(DueDose dose) action, String confirmation) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _silence();
    await action(_dose);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(content: Text(confirmation)));
  }

  @override
  void dispose() {
    unawaited(_silence());
    _player.dispose();
    _pulse.dispose();
    if (!kIsWeb) {
      unawaited(_lockScreen.invokeMethod<void>('setShowWhenLocked', false).catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ReminderService();
    final time = MedicineReminder.formatTime(_dose.minutes);
    final late = DateTime.now().difference(_dose.scheduledAt).inMinutes;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) => unawaited(_silence()),
      child: Scaffold(
        backgroundColor: PharmaLensColors.deepNavy,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: PharmaLensColors.brandGradient,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactHeight = constraints.maxHeight < 640;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: IconButton(
                              tooltip: appText(_isArabic).close,
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.close_rounded, color: Colors.white70),
                            ),
                          ),
                          Center(child: _PulsingPill(animation: _pulse, size: compactHeight ? 120 : 160)),
                          SizedBox(height: compactHeight ? 18 : 28),
                          Text(
                            time,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compactHeight ? 52 : 68,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              height: 1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            appText(_isArabic).timeToTake,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _reminder.medicineName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.15),
                          ),
                          if (_reminder.doseNote.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.notes_rounded, color: PharmaLensColors.brightCyan),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _reminder.doseNote,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (late > 5) ...[
                            const SizedBox(height: 10),
                            Text(
                              appText(_isArabic).scheduledMinutesAgo(late),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                          SizedBox(height: compactHeight ? 24 : 36),
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _answer(service.markTaken, appText(_isArabic).markedAsTaken),
                            style: FilledButton.styleFrom(
                              backgroundColor: PharmaLensColors.success,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(60),
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.check_circle_rounded, size: 26),
                            label: Text(appText(_isArabic).taken),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _answer(
                                      service.snooze,
                                      appText(_isArabic).remindingYouAgainInMinutes(ReminderService.snoozeMinutes),
                                    ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                              minimumSize: const Size.fromHeight(54),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.snooze_rounded),
                            label: Text(appText(_isArabic).snoozeMin(ReminderService.snoozeMinutes)),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _busy ? null : () => _answer(service.markSkipped, appText(_isArabic).doseSkipped),
                            style: TextButton.styleFrom(foregroundColor: Colors.white70),
                            child: Text(appText(_isArabic).skipThisDose),
                          ),
                          if (_reminder.isAlarm)
                            TextButton.icon(
                              onPressed: _silence,
                              style: TextButton.styleFrom(foregroundColor: Colors.white54),
                              icon: const Icon(Icons.volume_off_rounded, size: 18),
                              label: Text(appText(_isArabic).mute),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingPill extends AnimatedWidget {
  const _PulsingPill({required Animation<double> animation, required this.size}) : super(listenable: animation);

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final offset in const <double>[0, 0.5])
            Builder(builder: (context) {
              final phase = (t + offset) % 1.0;
              return Container(
                width: size * (1 + phase * 0.5),
                height: size * (1 + phase * 0.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PharmaLensColors.brightCyan.withValues(alpha: 0.22 * (1 - phase)),
                ),
              );
            }),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [PharmaLensColors.brightCyan, PharmaLensColors.teal]),
              boxShadow: [BoxShadow(color: PharmaLensColors.brightCyan.withValues(alpha: 0.45), blurRadius: 30)],
            ),
            child: Icon(Icons.medication_rounded, color: Colors.white, size: size * 0.5),
          ),
        ],
      ),
    );
  }
}
