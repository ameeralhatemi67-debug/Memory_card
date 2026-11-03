import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ui/fx.dart';

/// Buzzes with a strength, for scratching an answer. On Android the vibrator runs at the asked amplitude
/// (memorycard/haptics); elsewhere, or if that fails, a strong buzz is a light impact and a weak one a click.
class Haptics {
  Haptics._();
  static final Haptics i = Haptics._();

  static const _channel = MethodChannel('memorycard/haptics');
  bool _native = defaultTargetPlatform == TargetPlatform.android;
  int _lastMs = 0;

  /// One buzz of [ms] at [strength] (0…1, already scaled by the setting). Buzzes closer than [gapMs]
  /// to the last one are dropped, so a fast scratch stays a texture instead of a drone.
  void pulse(double strength, {int ms = 12, int gapMs = 0}) {
    if (!Fx.i.haptics || kIsWeb || strength <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (gapMs > 0 && now - _lastMs < gapMs) return;
    _lastMs = now;
    final amp = (strength.clamp(0.0, 1.0) * 255).round().clamp(1, 255);
    if (_native) {
      unawaited(_channel.invokeMethod<void>('pulse', {'ms': ms, 'amp': amp}).catchError((Object _) {
        _native = false;
      }));
      return;
    }
    unawaited((strength > 0.6 ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick()).catchError((Object _) {}));
  }
}
