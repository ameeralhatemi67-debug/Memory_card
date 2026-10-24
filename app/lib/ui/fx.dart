import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sound and haptics. Every effect is short and quiet, mixes with your music instead of pausing it,
/// and respects the silent switch on iOS.
class Fx {
  Fx._();
  static final Fx i = Fx._();

  bool sounds = true;
  bool haptics = true;

  /// How loud every sound is, 0…1 (Settings › Feel).
  double volume = 0.8;

  /// What picking a tab in the nav bar sounds like: card · soft · off.
  String navSound = 'card';
  final Map<String, _Voice> _voices = {};
  bool _ready = false;

  static const _names = ['tick', 'flip', 'good', 'easy', 'again', 'pop', 'stamp', 'whoosh', 'undo', 'fanfare', 'seal', 'card', 'soft', 'deal'];

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      if (!kIsWeb) {
        await AudioPlayer.global.setAudioContext(AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
          respectSilence: true,
        ).build());
      }
      for (final n in _names) {
        final count = n == 'tick' || n == 'pop' || n == 'good' || n == 'card' ? 3 : (n == 'fanfare' ? 1 : 2);
        final players = <AudioPlayer>[];
        for (var k = 0; k < count; k++) {
          final p = AudioPlayer();
          if (!kIsWeb) await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('sounds/$n.wav'));
          players.add(p);
        }
        _voices[n] = _Voice(players);
      }
    } catch (e) {
      debugPrint('Memory Card sound unavailable: $e');
    }
  }

  void _play(String name, [double volume = 1]) {
    if (!sounds || this.volume <= 0) return;
    final v = _voices[name];
    if (v == null) return;
    final p = v.players[v.next];
    v.next = (v.next + 1) % v.players.length;
    unawaited(() async {
      try {
        await p.stop();
        await p.setVolume((volume * this.volume).clamp(0.0, 1.0));
        await p.resume();
      } catch (_) {}
    }());
  }

  void _haptic(Future<void> Function() f) {
    if (!haptics || kIsWeb) return;
    unawaited(f().catchError((_) {}));
  }

  /// The swipe crossed the commit line.
  void lock() {
    _play('tick', 0.45);
    _haptic(HapticFeedback.selectionClick);
  }

  void tap() => _haptic(HapticFeedback.selectionClick);

  /// A tab picked in the nav bar: a card drawn from the hand.
  void nav() {
    if (navSound == 'card') _play('card', 0.7);
    if (navSound == 'soft') _play('soft', 0.6);
    _haptic(HapticFeedback.selectionClick);
  }

  /// The + card deals New deck / New card.
  void deal() => _play('deal', 0.6);

  void reveal() {
    _play('flip', 0.7);
    _haptic(HapticFeedback.lightImpact);
  }

  void remembered({bool easy = false}) {
    _play(easy ? 'easy' : 'good', 0.55);
    _haptic(HapticFeedback.mediumImpact);
  }

  void missed() {
    _play('again', 0.6);
    _haptic(HapticFeedback.lightImpact);
  }

  void pop() => _play('pop', 0.45);
  void whoosh() => _play('whoosh', 0.4);

  void undo() {
    _play('undo', 0.5);
    _haptic(HapticFeedback.selectionClick);
  }

  void stamp() {
    _play('stamp', 0.9);
    _haptic(HapticFeedback.heavyImpact);
  }

  void fanfare() => _play('fanfare', 0.7);

  void seal() {
    _play('seal', 0.6);
    _haptic(HapticFeedback.mediumImpact);
  }

  void warn() => _haptic(HapticFeedback.vibrate);
}

class _Voice {
  _Voice(this.players);
  final List<AudioPlayer> players;
  int next = 0;
}
