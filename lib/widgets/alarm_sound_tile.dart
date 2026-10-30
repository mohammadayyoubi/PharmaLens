import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../services/alarm_sound_service.dart';
import '../theme/pharmalens_theme.dart';

/// The sound medicine alarms ring with, with a preview and a way to change
/// it. Shows nothing where the sound cannot be chosen (see
/// AlarmSoundService.canChoose).
class AlarmSoundTile extends StatefulWidget {
  const AlarmSoundTile({super.key, required this.isArabic});

  final bool isArabic;

  @override
  State<AlarmSoundTile> createState() => _AlarmSoundTileState();
}

class _AlarmSoundTileState extends State<AlarmSoundTile> {
  final AlarmSoundService _sounds = AlarmSoundService();
  bool _previewing = false;
  Timer? _previewEnd;

  @override
  void initState() {
    super.initState();
    unawaited(_sounds.load());
  }

  @override
  void dispose() {
    _previewEnd?.cancel();
    if (_previewing) unawaited(_sounds.stop());
    super.dispose();
  }

  Future<void> _togglePreview() async {
    _previewEnd?.cancel();
    if (_previewing) {
      setState(() => _previewing = false);
      await _sounds.stop();
      return;
    }
    setState(() => _previewing = true);
    await _sounds.play(loop: false);
    // Songs can be long; a preview stops by itself.
    _previewEnd = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _previewing = false);
      unawaited(_sounds.stop());
    });
  }

  Future<void> _change() async {
    _previewEnd?.cancel();
    if (_previewing) {
      setState(() => _previewing = false);
      await _sounds.stop();
    }
    if (!mounted) return;
    final text = appText(widget.isArabic);
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final palette = PharmaLensTheme.paletteOf(sheetContext);
        final current = _sounds.sound;
        Widget option(int value, IconData icon, String title, String subtitle, {bool selected = false}) {
          return ListTile(
            leading: Icon(icon, color: PharmaLensColors.teal),
            title: Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
            trailing: selected ? const Icon(Icons.check_circle_rounded, color: PharmaLensColors.teal) : null,
            onTap: () => Navigator.of(sheetContext).pop(value),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  text.alarmSound,
                  style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              option(0, Icons.notifications_active_rounded, text.pharmalensTone, text.theAppSOwnShortTone,
                  selected: current.isDefault),
              option(1, Icons.alarm_rounded, text.phoneAlarmTones, text.theTonesYourPhoneUsesFor),
              option(2, Icons.library_music_rounded, text.musicOrAudioFile, text.anySongOrRecordingOnThis),
            ],
          ),
        );
      },
    );

    switch (choice) {
      case 0:
        await _sounds.useDefault();
      case 1:
        await _sounds.pickPhoneTone(pickerTitle: text.alarmSound);
      case 2:
        await _sounds.pickFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_sounds.canChoose) return const SizedBox.shrink();
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(widget.isArabic);

    return ListenableBuilder(
      listenable: _sounds,
      builder: (context, _) {
        final sound = _sounds.sound;
        final name = sound.isDefault ? text.pharmalensTone : (sound.title.isEmpty ? text.customSound : sound.title);

        return Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
          decoration: BoxDecoration(
            color: palette.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.music_note_rounded, color: PharmaLensColors.teal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text.alarmSound, style: TextStyle(color: palette.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _previewing ? text.stop : text.listen,
                onPressed: _togglePreview,
                icon: Icon(_previewing ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded),
                color: PharmaLensColors.teal,
              ),
              TextButton(onPressed: _change, child: Text(text.change)),
            ],
          ),
        );
      },
    );
  }
}
