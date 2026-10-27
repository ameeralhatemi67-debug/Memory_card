import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../data/models.dart';
import '../../services/card_audio.dart';
import '../../services/media_ingest.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'card_video.dart' show clockOf;

/// What the sound sheet hands back: the side's sound from now on (null = no sound any more).
class VoiceResult {
  const VoiceResult(this.sound);
  final CardSound? sound;
}

/// Record a voice, or pick a sound file, for one side of a card. The front's sound is heard before
/// answering (like "Hear it" on language decks), the back's with the answer. Returns null when cancelled.
Future<VoiceResult?> showVoiceSheet(BuildContext context, {required bool back, CardSound? current}) =>
    showMcSheet<VoiceResult>(context, expand: false, builder: (_) => VoiceSheet(back: back, current: current));

enum _Rec { idle, recording, done }

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key, required this.back, this.current});
  final bool back;
  final CardSound? current;

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  AudioRecorder? _recorder;
  StreamSubscription<Amplitude>? _amp;
  Timer? _clock;
  _Rec _state = _Rec.idle;
  String? _path;
  int _startedAt = 0;
  int _ms = 0;

  /// Recent input levels, 0…1, newest last (the live meter).
  final List<double> _levels = [];

  /// The sound waiting to be used: a new recording or a picked file (not yet on the card).
  CardSound? _pending;
  bool _kept = false;
  bool _busy = false;

  @override
  void dispose() {
    _clock?.cancel();
    _amp?.cancel();
    final r = _recorder;
    if (r != null) unawaited(r.dispose());
    unawaited(CardAudio.i.stop());
    // A recording that was made but not used leaves no file behind.
    if (!_kept) {
      unawaited(MediaIngest.discard(_pending?.src));
      if (_state == _Rec.recording) unawaited(MediaIngest.discard(_path));
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    final r = _recorder ??= AudioRecorder();
    if (!await r.hasPermission()) {
      Toaster.i.show('Memory Card needs the microphone to record. You can allow it in the phone\'s settings.', duration: const Duration(seconds: 4));
      return;
    }
    await CardAudio.i.stop();
    final old = _pending;
    _pending = null;
    unawaited(MediaIngest.discard(old?.src));
    final path = await MediaIngest.newRecordingPath();
    try {
      await r.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000, sampleRate: 44100, numChannels: 1),
        path: path,
      );
    } catch (_) {
      Toaster.i.show('Could not start recording');
      return;
    }
    Fx.i.tap();
    _path = path;
    _startedAt = DateTime.now().millisecondsSinceEpoch;
    _levels.clear();
    _amp = r.onAmplitudeChanged(const Duration(milliseconds: 70)).listen((a) {
      // dBFS: about -50 is a quiet room, 0 is as loud as it gets.
      final v = ((a.current + 50) / 50).clamp(0.0, 1.0);
      setState(() {
        _levels.add(v.isNaN ? 0 : v);
        if (_levels.length > 40) _levels.removeAt(0);
      });
    });
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final ms = DateTime.now().millisecondsSinceEpoch - _startedAt;
      setState(() => _ms = ms);
      if (ms >= MediaIngest.maxRecordMs) _stop();
    });
    setState(() => _state = _Rec.recording);
  }

  Future<void> _stop() async {
    if (_state != _Rec.recording) return;
    _clock?.cancel();
    await _amp?.cancel();
    _amp = null;
    final ms = DateTime.now().millisecondsSinceEpoch - _startedAt;
    String? out;
    try {
      out = await _recorder?.stop();
    } catch (_) {}
    out ??= _path;
    if (out == null || ms < 400) {
      unawaited(MediaIngest.discard(out));
      setState(() => _state = _Rec.idle);
      Toaster.i.show('Hold on a little longer: that was too short');
      return;
    }
    Fx.i.pop();
    final sound = await MediaIngest.keepRecording(out, ms: ms);
    if (!mounted) {
      unawaited(MediaIngest.discard(out));
      return;
    }
    setState(() {
      _pending = sound;
      _state = _Rec.done;
    });
  }

  Future<void> _pickFile() async {
    if (_busy || _state == _Rec.recording) return;
    setState(() => _busy = true);
    try {
      final s = await MediaIngest.soundFromFile();
      if (s != null && mounted) {
        final old = _pending;
        unawaited(MediaIngest.discard(old?.src));
        setState(() {
          _pending = s;
          _state = _Rec.done;
        });
      }
    } on MediaRefused catch (e) {
      Toaster.i.show(e.message, duration: const Duration(seconds: 4));
    } catch (_) {
      Toaster.i.show('Could not bring that sound in');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _use() {
    final s = _pending;
    if (s == null) return;
    _kept = true;
    Navigator.pop(context, VoiceResult(s));
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final current = widget.current;
    final shown = _pending ?? current;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + mq.padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.back ? 'A sound for the answer' : 'A sound for the question', style: T.d(30, color: mc.ink)),
          const SizedBox(height: 4),
          Text(
            widget.back
                ? 'Heard with the answer, right after the reveal.'
                : 'Heard before answering, like "Hear it" on the language decks. The card can be only this sound.',
            style: T.t(15, w: FontWeight.w500, color: mc.muted, height: 1.3),
          ),
          const SizedBox(height: 18),
          _recordPanel(mc),
          const SizedBox(height: 14),
          if (shown != null && _state != _Rec.recording) ...[
            _Preview(sound: shown, label: _pending == null ? 'On the card now' : (_pending!.recorded ? 'Your recording' : 'Your sound file')),
            const SizedBox(height: 12),
          ],
          SoftButton(
            _busy ? 'Opening…' : 'Pick a sound file instead',
            height: 48,
            icon: McIcon(McIcons.folder, size: const Size(20, 15), color: mc.ink),
            onTap: _pickFile,
          ),
          const SizedBox(height: 10),
          if (_pending != null)
            InkButton('Use this sound', height: 54, size: 23, onTap: _use)
          else if (current != null)
            SoftButton('Remove the sound', height: 50, textColor: Mc.red, onTap: () => Navigator.pop(context, const VoiceResult(null))),
        ],
      ),
    );
  }

  Widget _recordPanel(Mc mc) {
    final recording = _state == _Rec.recording;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(18), boxShadow: mc.e1),
      child: Row(children: [
        Pressable(
          onTap: recording ? _stop : _start,
          haptic: true,
          scale: 0.92,
          label: recording ? 'Stop recording' : 'Record',
          child: AmbientClock(
            enabled: recording,
            builder: (context, ms) {
              final pulse = recording ? 1 + 0.05 * (1 + (ms % 1000 < 500 ? 1 : -1)) / 2 : 1.0;
              return Transform.scale(
                scale: pulse,
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Mc.red, shape: BoxShape.circle, boxShadow: mc.e2),
                  child: McIcon(recording ? McIcons.stop : McIcons.mic, size: Size.square(recording ? 26 : 32), color: Mc.paper),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              recording ? clockOf(_ms) : (_state == _Rec.done ? 'Record again' : 'Tap to record'),
              style: T.d(26, color: mc.ink),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              child: recording
                  ? _Meter(levels: _levels, color: Mc.red)
                  : Text('Up to ${MediaIngest.maxRecordMs ~/ 60000} minutes. Tap again to stop.',
                      style: T.t(13.5, w: FontWeight.w500, color: mc.muted)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// The live input level, as a row of bars sliding left.
class _Meter extends StatelessWidget {
  const _Meter({required this.levels, required this.color});
  final List<double> levels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      for (final v in levels.length < 40 ? [...List.filled(40 - levels.length, 0.0), ...levels] : levels)
        Expanded(
          child: Center(
            child: Container(
              width: 3,
              height: 4 + 24 * v,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.35 + 0.65 * v), borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
    ]);
  }
}

/// Play back the sound waiting to be used (or the one on the card).
class _Preview extends StatelessWidget {
  const _Preview({required this.sound, required this.label});
  final CardSound sound;
  final String label;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: CardAudio.i.playing,
      builder: (context, src, _) {
        final on = src == sound.src;
        return Pressable(
          onTap: () => on ? CardAudio.i.stop() : CardAudio.i.play(sound.src, ms: sound.ms),
          label: on ? 'Stop' : 'Play it back',
          child: Container(
            height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(14)),
            child: Stack(fit: StackFit.expand, children: [
              if (on)
                ValueListenableBuilder<double>(
                  valueListenable: CardAudio.i.progress,
                  builder: (context, p, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: p,
                    child: ColoredBox(color: Mc.red.withValues(alpha: 0.55)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  McIcon(on ? McIcons.pause : McIcons.play, size: const Size(20, 20), color: mc.canvas),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: T.t(16, w: FontWeight.w700, color: mc.canvas))),
                  if (sound.ms > 0) Text(clockOf(sound.ms), style: T.t(15, w: FontWeight.w600, color: mc.mutedOnInk)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
