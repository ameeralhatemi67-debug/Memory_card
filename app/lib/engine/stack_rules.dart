import 'dart:math' as math;

import 'assessor.dart';

/// Where cards go in the endless stack (RES-47 §5.1, extended).
///
/// - Missed: back in 8–20 cards, beyond working memory, so the next try is a real retrieval.
///   A card that used to be strong comes back a little later (it recovers fast); one you keep failing
///   comes back a little sooner; "almost had it" waits longer than "no idea".
/// - Recalled but shaky (Hard): back after ~40 % of the stack instead of the very end.
/// - Recalled (Good / Easy): to the back of the stack.
/// - Reverse siblings never sit within 10 cards of each other.
class StackRules {
  const StackRules._();

  static const workingMemory = 5;
  static const failMin = 8;
  static const failMax = 20;
  static const siblingGap = 10;
  static const hardMin = 12;

  /// Index in the *remaining* stack (0 = next card) where a missed card goes back in.
  static int failGap({
    required double successRate,
    required double? stabilityBefore,
    required int lapses,
    required RecallKind kind,
    required int restLength,
  }) {
    if (restLength < 6) return restLength;
    var n = (8 + 12 * successRate).round();
    if ((stabilityBefore ?? 0) >= 7) n += 3;
    if (lapses >= 3) n -= 2;
    if (kind == RecallKind.nearMiss) n += 2;
    if (kind == RecallKind.blank) n -= 2;
    n = n.clamp(failMin, failMax);
    return n.clamp(workingMemory, restLength);
  }

  /// Index for a card recalled with low confidence.
  static int hardGap(int restLength) {
    if (restLength < hardMin) return restLength;
    return math.max(hardMin, (restLength * 0.4).round()).clamp(hardMin, restLength);
  }

  /// Moves [pos] so the card lands at least [siblingGap] cards from its sibling, when the stack allows.
  static int awayFromSibling(List<String> rest, int pos, String? siblingId) {
    if (siblingId == null) return pos;
    final si = rest.indexOf(siblingId);
    if (si < 0) return pos;
    if ((si - pos).abs() >= siblingGap) return pos;
    final after = si + siblingGap;
    if (after <= rest.length) return after;
    final before = si - siblingGap + 1;
    if (before >= workingMemory) return before;
    return rest.length;
  }

  /// Warm-up after a break (RES-47 §5.3): the weakest active cards move to the top, weakest first.
  /// [recall] gives predicted recall per card (null = never reviewed, left in place).
  static (List<String>, int) warmUp(List<String> stack, double? Function(String id) recall,
      {int count = 20, String? Function(String id)? siblingOf}) {
    final scored = <MapEntry<String, double>>[];
    for (final id in stack) {
      final r = recall(id);
      if (r != null) scored.add(MapEntry(id, r));
    }
    if (scored.isEmpty) return (stack, 0);
    scored.sort((a, b) => a.value.compareTo(b.value));
    final weak = <String>[];
    for (final e in scored) {
      if (weak.length >= count) break;
      // Keep reverse siblings apart: the stronger of the two stays where it is.
      final sib = siblingOf?.call(e.key);
      if (sib != null && weak.contains(sib)) continue;
      weak.add(e.key);
    }
    final chosen = {...weak};
    final rest = stack.where((id) => !chosen.contains(id)).toList();
    return ([...weak, ...rest], weak.length);
  }

  /// Inserts [id] at [pos] (clamped) and returns the new list.
  static List<String> insertAt(List<String> rest, String id, int pos) {
    final out = [...rest];
    out.insert(pos.clamp(0, out.length), id);
    return out;
  }
}
