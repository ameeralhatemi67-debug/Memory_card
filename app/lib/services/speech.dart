import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// "Hear it": the phone's own text-to-speech (offline, free, every language the phone has).
class Speech {
  Speech._();
  static final i = Speech._();

  FlutterTts? _tts;
  VoidCallback? _onDone;

  FlutterTts get _engine {
    final t = _tts ??= FlutterTts();
    t.setCompletionHandler(() => _finish());
    t.setCancelHandler(() => _finish());
    t.setErrorHandler((_) => _finish());
    return t;
  }

  void _finish() {
    final f = _onDone;
    _onDone = null;
    f?.call();
  }

  /// Latin has no voices; Italian reads it closest to classroom pronunciation.
  static String voiceFor(String lang) => switch (lang) { 'la' => 'it-IT', _ => lang };

  Future<void> speak(String text, String lang, {VoidCallback? onDone, double slow = 1}) async {
    _finish();
    _onDone = onDone;
    final clean = text.replaceAll(RegExp(r'\s·\s.*$'), '').replaceAll(RegExp(r'[()]'), '');
    try {
      final t = _engine;
      await t.stop();
      await t.setLanguage(voiceFor(lang));
      await t.setSpeechRate((kIsWeb ? 0.9 : 0.46) * slow);
      await t.setPitch(1.0);
      final r = await t.speak(clean);
      if (r != 1 && r != null) _finish();
    } catch (_) {
      _finish();
    }
    // Some engines never call back; never leave the button stuck on "Playing…".
    Future.delayed(const Duration(seconds: 6), _finish);
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    _finish();
  }
}
