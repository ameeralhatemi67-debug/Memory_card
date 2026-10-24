import '../data/app_data.dart';
import 'study_engine.dart';

/// A wax seal: Memory Card's achievements. Pressed into the back of the membership card.
class SealDef {
  const SealDef(this.id, this.title, this.note, this.mark, this.color);
  final String id;
  final String title;
  final String note;

  /// Short text stamped in the middle of the seal.
  final String mark;

  /// 0 red · 1 blue · 2 peach · 3 green · 4 ink
  final int color;
}

/// The membership tier (Bronze · Silver · Gold · Platinum) for what you have mastered and your best streak.
String tierFor(int mastered, int best) {
  if (mastered >= 1000 || best >= 365) return 'Platinum';
  if (mastered >= 400 || best >= 100) return 'Gold';
  if (mastered >= 100 || best >= 30) return 'Silver';
  return 'Bronze';
}

class Seals {
  const Seals._();

  static const all = <SealDef>[
    SealDef('first-swipe', 'First swipe', 'Your first card. The stack has started.', '1', 0),
    SealDef('first-goal', 'Goal keeper', 'Reached the daily goal for the first time.', 'GOAL', 0),
    SealDef('streak-3', 'Three in a row', 'A 3-day streak.', '3', 2),
    SealDef('streak-7', 'One week', 'A 7-day streak.', '7', 2),
    SealDef('streak-14', 'Fortnight', 'A 14-day streak.', '14', 2),
    SealDef('streak-30', 'One month', 'A 30-day streak. That is a habit now.', '30', 0),
    SealDef('streak-100', 'Hundred days', 'A 100-day streak.', '100', 0),
    SealDef('streak-365', 'A whole year', 'A 365-day streak.', '365', 0),
    SealDef('reviews-100', 'Hundred cards', '100 swipes in total.', '100', 1),
    SealDef('reviews-1000', 'Thousand cards', '1,000 swipes in total.', '1K', 1),
    SealDef('reviews-5000', 'Five thousand', '5,000 swipes in total.', '5K', 1),
    SealDef('mastered-10', 'First ten', '10 cards mastered (stable for 3+ weeks).', 'M10', 3),
    SealDef('mastered-100', 'Hundred mastered', '100 cards mastered.', 'M100', 3),
    SealDef('flawless-25', 'Flawless', '25 cards in a row remembered.', '25', 3),
    SealDef('night-owl', 'Night owl', 'Studied after 23:00.', 'OWL', 4),
    SealDef('early-bird', 'Early bird', 'Studied before 7:00.', 'SUN', 2),
    SealDef('comeback', 'Comeback', 'Back after a week away, goal reached.', 'BACK', 1),
    SealDef('author', 'Author', 'Wrote 25 cards of your own.', 'PEN', 4),
    SealDef('polyglot', 'Polyglot', 'Studied three language decks in one day.', 'ABC', 1),
    SealDef('tuned', 'Tuned in', 'Trained the memory model on your own reviews.', 'FSRS', 3),
  ];

  static SealDef? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Awards every seal whose condition now holds; returns the new ones.
  static List<String> check(AppData data, StudyEngine engine, int now, {bool goalNow = false, bool comeback = false}) {
    final earned = <String>[];
    final p = data.profile;
    final t = data.today;
    final day = t?.day ?? 0;
    void award(String id) {
      if (p.seals.containsKey(id)) return;
      p.seals[id] = day;
      earned.add(id);
    }

    if (p.totalReviews >= 1) award('first-swipe');
    if (goalNow) award('first-goal');
    if (comeback) award('comeback');
    for (final n in const [3, 7, 14, 30, 100, 365]) {
      if (p.streak >= n) award('streak-$n');
    }
    for (final n in const [100, 1000, 5000]) {
      if (p.totalReviews >= n) award('reviews-$n');
    }
    if (t != null) {
      final hour = DateTime.fromMillisecondsSinceEpoch(now).hour;
      if (t.done >= 10 && (hour >= 23 || hour < 4)) award('night-owl');
      if (t.done >= 10 && hour >= 4 && hour < 7) award('early-bird');
      if (t.bestRun >= 25) award('flawless-25');
      final langDecks = t.decks.keys.where((id) => data.decks[id]?.category == 'lang').length;
      if (langDecks >= 3) award('polyglot');
    }
    if (p.totalReviews % 10 == 0) {
      var mastered = 0;
      for (final c in data.cards.values) {
        if (engine.isMastered(c)) mastered++;
      }
      if (mastered >= 10) award('mastered-10');
      if (mastered >= 100) award('mastered-100');
    }
    return earned;
  }

  /// Seals that depend on authoring rather than studying.
  static List<String> checkAuthoring(AppData data, int ownCards) {
    if (ownCards >= 25 && !data.profile.seals.containsKey('author')) {
      data.profile.seals['author'] = data.today?.day ?? 0;
      return ['author'];
    }
    return const [];
  }
}
