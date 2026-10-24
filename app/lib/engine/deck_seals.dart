import '../data/models.dart';
import 'study_engine.dart';

/// A moment in a deck's life that can press one of its seals.
class DeckMilestone {
  const DeckMilestone(this.id, this.label, this.note);
  final String id;

  /// Short name for pickers ("Every card seen").
  final String label;

  /// What it means, for the gallery ("Every card of the deck answered at least once").
  final String note;
}

class DeckMilestones {
  const DeckMilestones._();

  static const all = <DeckMilestone>[
    DeckMilestone('start', 'First 10 swipes', 'Ten swipes in this deck.'),
    DeckMilestone('seen', 'Every card seen', 'Every card of the deck answered at least once.'),
    DeckMilestone('half', 'Half the deck strong', 'Half of the cards above 90 % recall.'),
    DeckMilestone('mastered', 'Deck mastered', 'Every card above 90 % recall.'),
    DeckMilestone('reviews', '100 swipes', 'A hundred swipes in this deck.'),
  ];

  static DeckMilestone of(String id) => all.firstWhere((m) => m.id == id, orElse: () => all[3]);

  /// Whether [d] has reached milestone [id] (decks need 3 cards before seen / half / mastered count).
  static bool reached(String id, Deck d, DeckStats s) => switch (id) {
        'start' => d.reviews >= 10,
        'reviews' => d.reviews >= 100,
        'seen' => s.total >= 3 && s.fresh == 0,
        'half' => s.total >= 3 && s.strong * 2 >= s.total,
        _ => s.total >= 3 && (d.masteredAt != null || s.steps == 5),
      };

  /// Presses every seal of [seals] whose milestone [d] has now reached; returns the new ones.
  static List<DeckSeal> check(Deck d, List<DeckSeal> seals, DeckStats s, int now) {
    final out = <DeckSeal>[];
    for (final seal in seals) {
      if (d.sealsEarned.containsKey(seal.id) || !reached(seal.when, d, s)) continue;
      d.sealsEarned[seal.id] = now;
      out.add(seal);
    }
    return out;
  }
}
