import 'dart:math' as math;

/// Typed-answer checking: forgiving about case, spacing, punctuation and (optionally) accents, and
/// accepting any of the alternatives written in the answer ("to go, to walk" / "hi / bye").
class TypedAnswer {
  const TypedAnswer._();

  static const _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e',
    'ë': 'e', 'ē': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o',
    'õ': 'o', 'ö': 'o', 'ō': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ý': 'y', 'ÿ': 'y', 'ß': 'ss',
    'ǎ': 'a', 'ě': 'e', 'ǐ': 'i', 'ǒ': 'o', 'ǔ': 'u', 'ǚ': 'u', 'ǜ': 'u', 'ǘ': 'u', 'ǖ': 'u',
  };

  static String normalize(String s, {bool ignoreAccents = true}) {
    var t = s.toLowerCase().trim();
    t = t.replaceAll(RegExp(r'\(.*?\)'), ' ');
    if (ignoreAccents) t = t.split('').map((ch) => _accents[ch] ?? ch).join();
    t = t.replaceAll(RegExp(r'''[.,!?¿¡;:"'`’“”«»\-–—_]'''), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// The answer's alternatives: split on "," "/" ";" " or ".
  static List<String> alternatives(String answer) {
    final parts = answer.split(RegExp(r'\s*[,/;]\s*|\s+or\s+')).where((p) => p.trim().isNotEmpty).toList();
    return {answer, ...parts}.toList();
  }

  /// 0…1: how close the typed text is to the best-matching alternative.
  static double similarity(String typed, String answer, {bool ignoreAccents = true}) {
    final a = normalize(typed, ignoreAccents: ignoreAccents);
    if (a.isEmpty) return 0;
    var best = 0.0;
    for (final alt in alternatives(answer)) {
      var b = normalize(alt, ignoreAccents: ignoreAccents);
      // "the apple" also accepts "apple"; "to go" also accepts "go".
      for (final article in const ['the ', 'a ', 'an ', 'to ']) {
        if (b.startsWith(article) && !a.startsWith(article)) b = b.substring(article.length);
      }
      if (b.isEmpty) continue;
      final d = _lev(a, b);
      best = math.max(best, 1 - d / math.max(a.length, b.length));
      if (best == 1) break;
    }
    return best;
  }

  /// exact (≥ 0.95) · close (≥ 0.75) · wrong.
  static String verdict(double sim) => sim >= 0.95 ? 'exact' : sim >= 0.75 ? 'close' : 'wrong';

  static int _lev(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      final t = prev;
      prev = cur;
      cur = t;
    }
    return prev[b.length];
  }
}
