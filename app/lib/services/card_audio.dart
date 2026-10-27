import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a card's own recordings (the question you hear, the answer you hear). One at a time: starting a
/// sound stops the one before. [playing] and [progress] drive the "Hear it" button.
class CardAudio {
  CardAudio._();
  static final i = CardAudio._();

  AudioPlayer? _player;
  final List<StreamSubscription<Object?>> _subs = [];
  VoidCallback? _onDone;
  int _ms = 0;

  /// The sound playing now (its src), or null.
  final ValueNotifier<String?> playing = ValueNotifier(null);

  /// 0…1 through the sound playing now.
  final ValueNotifier<double> progress = ValueNotifier(0);

  AudioPlayer _make() {
    final p = AudioPlayer();
    _subs
      ..add(p.onDurationChanged.listen((d) => _ms = d.inMilliseconds))
      ..add(p.onPositionChanged.listen((pos) {
        if (_ms > 0 && playing.value != null) progress.value = (pos.inMilliseconds / _ms).clamp(0.0, 1.0);
      }))
      ..add(p.onPlayerComplete.listen((_) => _finish()));
    return p;
  }

  /// Plays [src] (a file path or a data URI) from the start. [ms] is its known length, if any.
  Future<void> play(String src, {int ms = 0, VoidCallback? onDone}) async {
    await stop();
    _onDone = onDone;
    _ms = ms;
    playing.value = src;
    progress.value = 0;
    try {
      final p = _player ??= _make();
      final Source source = src.startsWith('data:')
          ? BytesSource(Uri.parse(src).data!.contentAsBytes())
          : (kIsWeb ? UrlSource(src) : DeviceFileSource(src));
      // A file the phone cannot open must not leave the button saying "Playing…" for ever.
      await () async {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.play(source, volume: 1);
      }().timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('Memory Card: could not play a card sound ($e)');
      _finish();
    }
  }

  void _finish() {
    playing.value = null;
    progress.value = 0;
    final f = _onDone;
    _onDone = null;
    f?.call();
  }

  Future<void> stop() async {
    if (playing.value == null) return;
    try {
      await _player?.stop();
    } catch (_) {}
    _finish();
  }
}
