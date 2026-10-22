import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/store_scope.dart';
import '../../services/reminders.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../shell/shell.dart';
import '../shop/shop_tile.dart';
import '../study/celebrate.dart';
import '../study/ears.dart';
import 'tutorial_deck.dart';

/// First launch: a tour you do with your thumb (every page is a card you swipe, so the gestures are
/// learned by doing them), then a minute of setup, ending with your card and a wax seal.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key, this.replay = false});

  /// From Settings: only the tour, nothing is changed.
  final bool replay;

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> with TickerProviderStateMixin {
  int _step = 0;
  double _dx = 0;
  bool _dragging = false;
  bool _revealed = false;
  bool _flying = false;
  bool _reinserting = false;
  String? _hint;

  // Setup choices.
  final Set<String> _cats = {'lang'};
  final Set<String> _decks = {};
  int _goal = 20;
  Pace _pace = Pace.balanced;
  bool _remind = false;
  int _remindAt = 19 * 60;
  final _name = TextEditingController();
  bool _tutorial = true;

  static const _cardSteps = 5;
  int get _total => widget.replay ? _cardSteps : 10;

  @override
  void initState() {
    super.initState();
    _decks.addAll(const ['es-basics', 'it-basics']);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_step + 1 >= _total) {
      if (widget.replay) {
        Navigator.of(context).pop();
        return;
      }
    }
    setState(() {
      _step = math.min(_step + 1, _total - 1);
      _dx = 0;
      _revealed = false;
      _hint = null;
      _flying = false;
    });
  }

  // ---------------------------------------------------------------- the swipe cards

  /// Which way the card on this step must go (null = either / button only).
  bool? get _wants => switch (_step) { 2 => false, _ => true };

  bool get _needsReveal => _step == 1 || _step == 2;

  void _onStart(DragStartDetails d) {
    if (_flying) return;
    _dragging = true;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final was = _dx.abs() >= 0.6 * 276;
    setState(() => _dx += d.delta.dx);
    final now = _dx.abs() >= 0.6 * 276;
    if (now && !was) Fx.i.lock();
  }

  void _onEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final v = d.velocity.pixelsPerSecond.dx;
    final go = _dx.abs() >= 0.6 * 276 || (v.abs() > 900 && _dx.abs() > 60 && v.sign == _dx.sign);
    if (!go) {
      _back();
      return;
    }
    _commit(_dx > 0);
  }

  void _back() {
    final from = _dx;
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    c.addListener(() => setState(() => _dx = from * (1 - McCurves.springy.transform(c.value))));
    c.forward().whenComplete(c.dispose);
  }

  Future<void> _commit(bool right) async {
    if (_needsReveal && !_revealed) {
      _back();
      Fx.i.warn();
      setState(() => _hint = 'Tap the card first: try to remember, then check.');
      return;
    }
    final want = _wants;
    if (want != null && want != right) {
      _back();
      Fx.i.warn();
      setState(() => _hint = want ? 'This time you knew it: swipe right.' : "This time you didn't: swipe left.");
      return;
    }
    _flying = true;
    if (right) {
      Fx.i.remembered();
    } else {
      Fx.i.missed();
    }
    final w = MediaQuery.of(context).size.width;
    final from = _dx;
    final to = (right ? 1 : -1) * (w + 160.0);
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    c.addListener(() => setState(() => _dx = from + (to - from) * McCurves.paper.transform(c.value)));
    await c.forward();
    c.dispose();
    if (!mounted) return;
    if (_step == 2) {
      setState(() {
        _reinserting = true;
        _dx = 0;
      });
      await Future.delayed(const Duration(milliseconds: 2300));
      if (!mounted) return;
      setState(() => _reinserting = false);
    }
    _next();
  }

  void _reveal() {
    if (!_needsReveal || _revealed) return;
    Fx.i.reveal();
    setState(() {
      _revealed = true;
      _hint = null;
    });
  }

  // ---------------------------------------------------------------- finishing

  Future<void> _finish({bool study = true}) async {
    final store = context.storeRead;
    store.updateSettings((s) {
      s.goal = _goal;
      s.pace = _pace;
      s.remind = _remind;
      s.remindMinutes = _remindAt;
      s.name = _name.text.trim();
    });
    String? first;
    if (_tutorial) {
      final f = store.createFolder('Start here');
      final d = store.createDeck(name: tutorialDeckName, folderId: f.id, mono: '?', category: 'custom', description: 'Learn the app by using it.');
      d.pace = 'intense';
      store.importRows(d.id, tutorialCards, newDeck: true);
      first = d.id;
    }
    final folders = <String, String>{};
    for (final id in _decks) {
      final cd = store.catalog.byId(id);
      if (cd == null) continue;
      final fid = folders[cd.folder] ??=
          (store.data.folders.where((f) => f.name == cd.folder).firstOrNull ?? store.createFolder(cd.folder, atTop: false)).id;
      final d = store.addCatalogDeck(id, fid, reverse: false);
      first ??= d.id;
    }
    if (store.data.folders.isEmpty) store.createFolder('Library');
    final firstFolder = first == null ? store.data.folders.first.id : store.data.folderOf(first)!.id;
    store.touchFolder(firstFolder);
    if (_remind) unawaited(Reminders.i.reschedule(store));
    store.setOnboarded();
    if (study && first != null) {
      final target = first;
      Future.delayed(const Duration(milliseconds: 700), () => Shell.current?.study(target));
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final cardStep = _step < _cardSteps;
    return Scaffold(
      backgroundColor: mc.canvas,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            reverseDuration: const Duration(milliseconds: 160),
            switchInCurve: McCurves.out,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a), child: child),
            ),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: cardStep ? _cardStage(context) : _setupStage(context),
            ),
          ),
        ),
        // Progress and skip.
        Positioned(
          left: 22,
          right: 12,
          top: mq.padding.top + 14,
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 4,
                  child: Stack(children: [
                    Positioned.fill(child: ColoredBox(color: mc.soft)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: (_step + 1) / _total),
                      duration: const Duration(milliseconds: 380),
                      curve: McCurves.out,
                      builder: (context, v, _) => FractionallySizedBox(widthFactor: v, child: ColoredBox(color: mc.ink)),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.replay || _step < _cardSteps)
              Pressable(
                onTap: () {
                  if (widget.replay) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _step = _cardSteps;
                      _dx = 0;
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(widget.replay ? 'Close' : 'Skip', style: T.t(15, w: FontWeight.w700, color: mc.muted)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- tour (cards)

  Widget _cardStage(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final cardW = math.min(276.0, w * 0.72);
      final cardH = math.min(cardW * 384 / 276, h * 0.5);
      final cardTop = mq.padding.top + math.max(96.0, (h - cardH) * 0.36);
      final cardLeft = (w - cardW) / 2;
      final dx = _dx;
      final p = math.min(1.0, dx.abs() / cardW);
      final rot = (dx * 0.09).clamp(-28.0, 28.0) * math.pi / 180;
      final dy = math.min(140.0, dx * dx * 0.0005);
      final inL = dx < 0 ? math.min(1.0, -dx / (0.4 * cardW)) : 0.0;
      final inR = dx > 0 ? math.min(1.0, dx / (0.4 * cardW)) : 0.0;
      final earsTop = math.min(cardTop + cardH + 30, h - 150);

      Widget layer(double t, Color c, {Gradient? g}) => Positioned(
            left: cardLeft,
            top: t,
            width: cardW,
            height: cardH,
            child: DecoratedBox(decoration: BoxDecoration(color: g == null ? c : null, gradient: g, borderRadius: BorderRadius.circular(18))),
          );

      final instruction = _hint ??
          switch (_step) {
            0 => 'Swipe the card right to begin',
            1 => _revealed ? 'Knew it? Swipe right.' : 'Think of the answer, then tap the card.',
            2 => _reinserting ? '' : (_revealed ? "Didn't know it? Swipe left. That's normal for a new card." : 'Try this one. Then tap to check.'),
            3 => 'Swipe right to continue',
            _ => 'Swipe right when you are ready',
          };

      return Stack(children: [
        for (final k in [3, 2, 1]) layer(cardTop + 17 * k, mc.below[k - 1]),
        for (final k in [4, 3, 2, 1])
          layer(
            cardTop - 17 * k,
            mc.above[k - 1][1],
            g: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [mc.above[k - 1][0], mc.above[k - 1][1], mc.above[k - 1][1]],
              stops: [0, 17 / cardH, 1],
            ),
          ),
        Positioned(
          left: cardLeft,
          top: cardTop,
          width: cardW,
          height: cardH,
          child: DecoratedBox(decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(18))),
        ),
        if (!_reinserting)
          Positioned(
            left: cardLeft,
            top: cardTop,
            width: cardW,
            height: cardH,
            child: GestureDetector(
              onHorizontalDragStart: _onStart,
              onHorizontalDragUpdate: _onUpdate,
              onHorizontalDragEnd: _onEnd,
              onTap: _reveal,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(dx, dy, 0, 1)
                  ..rotateZ(rot)
                  ..scaleByDouble(1 - 0.14 * p, 1 - 0.14 * p, 1, 1),
                child: Container(
                  decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(18), boxShadow: mc.cardShadow),
                  padding: const EdgeInsets.all(20),
                  child: _cardContent(context, cardH),
                ),
              ),
            ),
          )
        else
          Positioned(left: 16, right: 16, top: cardTop + cardH * 0.3, child: const _Reinsertion()),
        Positioned(left: 0, top: earsTop, child: Ear(right: false, amount: inL, committed: dx < -0.6 * cardW, dragging: _dragging, onTap: () => _commit(false))),
        Positioned(right: 0, top: earsTop, child: Ear(right: true, amount: inR, committed: dx > 0.6 * cardW, dragging: _dragging, onTap: () => _commit(true))),
        Positioned(
          left: 28,
          right: 28,
          top: cardTop - 74 - 17 * 4,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              instruction,
              key: ValueKey(instruction),
              textAlign: TextAlign.center,
              style: T.t(17, w: FontWeight.w700, color: _hint != null ? Mc.red : mc.ink, height: 1.3),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: mq.padding.bottom + 26,
          child: Center(
            child: _step == 0 || _step >= 3
                ? _NudgeArrow(onTap: () => _commit(true))
                : const SizedBox(height: 40),
          ),
        ),
      ]);
    });
  }

  Widget _cardContent(BuildContext context, double cardH) {
    final mc = Mc.of(context);
    Widget answer(String a) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _revealed
              ? Container(
                  key: const ValueKey('a'),
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(12)),
                  child: Text(a, style: T.d(28, color: Mc.graphite)),
                )
              : Container(
                  key: const ValueKey('r'),
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: mc.pill, borderRadius: BorderRadius.circular(12)),
                  child: Text('Tap to reveal', style: T.t(17, w: FontWeight.w600, color: Mc.graphite)),
                ),
        );
    switch (_step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('WELCOME', style: T.caps(12, color: mc.mutedOnInk)),
          const Spacer(),
          Center(child: McIcon(McIcons.logo, size: const Size(62, 80), color: mc.onInk)),
          const SizedBox(height: 18),
          Text('Memory Card', textAlign: TextAlign.center, style: T.d(40, color: mc.onInk)),
          const SizedBox(height: 8),
          Text('Remember anything,\none swipe at a time.',
              textAlign: TextAlign.center, style: T.t(18, w: FontWeight.w500, color: mc.mutedOnInk, height: 1.3)),
          const Spacer(),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('CAPITAL CITY', style: T.caps(12, color: mc.mutedOnInk)),
          const SizedBox(height: 6),
          Text('The capital of Australia?', style: T.d(32, color: mc.onInk, height: 1.05)),
          const SizedBox(height: 8),
          Text('Not the biggest city.', style: T.t(17, w: FontWeight.w500, color: mc.mutedOnInk)),
          const Spacer(),
          answer('Canberra'),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('NOUN · MASCULINE', style: T.caps(12, color: mc.mutedOnInk))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Mc.peach, borderRadius: BorderRadius.circular(8)),
              child: Text('NEW', style: T.caps(11, color: Mc.graphite, spacing: 1)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('der Schmetterling', style: T.d(34, color: mc.onInk, height: 1.05)),
          const SizedBox(height: 8),
          Text('Ein Schmetterling sitzt auf der Blume.', style: T.t(17, w: FontWeight.w500, color: mc.mutedOnInk, height: 1.3)),
          const Spacer(),
          answer('the butterfly'),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('HOW IT WORKS', style: T.caps(12, color: mc.mutedOnInk)),
          const SizedBox(height: 6),
          Text('We read how you answer', style: T.d(30, color: mc.onInk, height: 1.05)),
          const SizedBox(height: 14),
          _GradeRow(color: Mc.green, title: 'Quick and sure', note: 'Easy · back much later', fill: 0.92),
          _GradeRow(color: mc.onInk, title: 'Steady', note: 'Good · to the back', fill: 0.6),
          _GradeRow(color: Mc.peach, title: 'Slow or unsure', note: 'Hard · back sooner', fill: 0.3),
          const Spacer(),
          Text('A phone call never counts as hesitation. You can change any grade.',
              style: T.t(14, w: FontWeight.w600, color: mc.mutedOnInk, height: 1.3)),
        ]);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('YOUR MEMORY, MEASURED', style: T.caps(12, color: mc.mutedOnInk)),
          const SizedBox(height: 6),
          Text('Cards come back just in time', style: T.d(30, color: mc.onInk, height: 1.05)),
          const SizedBox(height: 12),
          const _FanDemo(),
          const Spacer(),
          Text('Every swipe teaches a memory model (FSRS-6) that predicts when you would forget. '
              'Weak cards return sooner, strong ones rest.',
              style: T.t(14.5, w: FontWeight.w600, color: mc.mutedOnInk, height: 1.35)),
        ]);
    }
  }

  // ---------------------------------------------------------------- setup

  Widget _setupStage(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final store = context.storeRead;
    Widget page({required String title, required String sub, required List<Widget> body, required Widget action, Widget? secondary}) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: mq.padding.top + 44),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            children: [
              Text(title, style: T.d(40, color: mc.ink, height: 1.02)),
              const SizedBox(height: 8),
              Text(sub, style: T.t(17, w: FontWeight.w500, color: mc.muted, height: 1.35)),
              const SizedBox(height: 22),
              ...body,
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(22, 6, 22, mq.padding.bottom + 18),
          child: Column(children: [action, if (secondary != null) ...[const SizedBox(height: 10), secondary]]),
        ),
      ]);
    }

    switch (_step) {
      case 5:
        final picks = <CatalogDeck>[
          for (final c in CatalogCategory.all)
            if (_cats.contains(c.id)) ...store.catalog.decks.where((d) => d.category == c.id).take(8),
        ];
        final cards = _decks.fold<int>(0, (a, id) => a + (store.catalog.byId(id)?.cards.length ?? 0));
        return page(
          title: 'What do you want to remember?',
          sub: 'Pick a few decks to start. There are ${store.catalog.decks.length} in the shop, and you can write your own.',
          body: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in CatalogCategory.all)
                Chip2(c.name,
                    height: 36,
                    dot: Color(c.color),
                    selected: _cats.contains(c.id),
                    onTap: () => setState(() => _cats.contains(c.id) ? _cats.remove(c.id) : _cats.add(c.id))),
            ]),
            const SizedBox(height: 18),
            if (picks.isEmpty)
              Text('Choose a topic above.', style: T.t(16, w: FontWeight.w600, color: mc.muted))
            else
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
                children: [
                  for (final d in picks) _PickTile(deck: d, on: _decks.contains(d.id), onTap: () {
                    Fx.i.tap();
                    setState(() => _decks.contains(d.id) ? _decks.remove(d.id) : _decks.add(d.id));
                  }),
                ],
              ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Include the 2-minute tutorial deck', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                  Text('Ten cards about the app itself', style: T.t(14, w: FontWeight.w500, color: mc.muted)),
                ]),
              ),
              McSwitch(value: _tutorial, onChanged: (v) => setState(() => _tutorial = v)),
            ]),
          ],
          action: InkButton(
            _decks.isEmpty ? (_tutorial ? 'Start with the tutorial' : 'Start with an empty library') : 'Continue · ${_decks.length} ${_decks.length == 1 ? 'deck' : 'decks'}, $cards cards',
            onTap: _next,
          ),
        );
      case 6:
        const options = [(10, 'Light'), (20, 'Steady'), (40, 'Serious'), (80, 'Intense')];
        return page(
          title: 'A small daily goal',
          sub: 'Reach it and the day counts toward your streak. The stack keeps going if you want more.',
          body: [
            for (final (n, name) in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Pressable(
                  haptic: true,
                  onTap: () => setState(() => _goal = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _goal == n ? mc.ink : mc.soft,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _goal == n ? mc.e2 : mc.e1,
                    ),
                    child: Row(children: [
                      Text('$n', style: T.d(34, color: _goal == n ? mc.canvas : mc.ink)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: T.d(22, color: _goal == n ? mc.canvas : mc.ink)),
                          Text('cards a day · about ${(n * 6 / 60).ceil()} min',
                              style: T.t(14, w: FontWeight.w600, color: _goal == n ? mc.mutedOnInk : mc.muted)),
                        ]),
                      ),
                      if (_goal == n) McIcon(McIcons.done, size: const Size(24, 24), color: mc.canvas),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text('Pace', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
            const SizedBox(height: 8),
            Seg<Pace>(
              options: Pace.values,
              value: _pace,
              background: mc.soft,
              labelOf: (p) => switch (p) { Pace.relaxed => 'Relaxed', Pace.balanced => 'Balanced', Pace.intense => 'Intense' },
              onPick: (p) => setState(() => _pace = p),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_pace) {
                Pace.relaxed => 'New cards join only while you remember about 80%. Calm and steady.',
                Pace.balanced => 'New cards join while you remember about 75%. Recommended.',
                Pace.intense => 'Every card is in the stack from day one. Most ground, more misses.',
              },
              style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.35),
            ),
          ],
          action: InkButton('Continue', onTap: _next),
        );
      case 7:
        final at = '${(_remindAt ~/ 60).toString().padLeft(2, '0')}:${(_remindAt % 60).toString().padLeft(2, '0')}';
        return page(
          title: 'A nudge each day?',
          sub: 'One quiet reminder, only about the cards that are slipping. Nothing else, ever.',
          body: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                McIcon(McIcons.logo, size: const Size(26, 34), color: mc.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Spanish · Basics: 12 cards are slipping', style: T.t(15, w: FontWeight.w700, color: mc.ink)),
                    Text('About 2 min saves them, and your streak.', style: T.t(14, w: FontWeight.w500, color: mc.muted)),
                  ]),
                ),
                Text(at, style: T.t(13, w: FontWeight.w600, color: mc.muted)),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text('Remind me at', style: T.t(17, w: FontWeight.w700, color: mc.ink))),
              Pressable(
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: _remindAt ~/ 60, minute: _remindAt % 60),
                    builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
                  );
                  if (t != null) setState(() => _remindAt = t.hour * 60 + t.minute);
                },
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(12), boxShadow: mc.e1),
                  child: Text(at, style: T.d(26, color: mc.ink)),
                ),
              ),
            ]),
          ],
          action: InkButton('Remind me', onTap: () async {
            final ok = await Reminders.i.requestPermission();
            setState(() => _remind = ok || !Reminders.i.supported ? true : false);
            if (!ok && Reminders.i.supported) Toaster.i.show('You can turn reminders on later in Settings');
            _next();
          }),
          secondary: SoftButton('Not now', onTap: () {
            setState(() => _remind = false);
            _next();
          }),
        );
      case 8:
        return page(
          title: 'Your card',
          sub: 'Your membership card shows your progress. Its numbers are your stats, never a payment.',
          body: [
            McField(controller: _name, hint: 'Your name (optional)', display: true, size: 24, onChanged: (_) => setState(() {})),
            const SizedBox(height: 22),
            _MemberPreview(name: _name.text.trim().isEmpty ? 'Guest Learner' : _name.text.trim()),
          ],
          action: InkButton('Continue', onTap: () {
            FocusScope.of(context).unfocus();
            _next();
          }),
        );
      default:
        final n = _decks.length + (_tutorial ? 1 : 0);
        final cards = _decks.fold<int>(0, (a, id) => a + (store.catalog.byId(id)?.cards.length ?? 0)) + (_tutorial ? tutorialCards.length : 0);
        return page(
          title: 'Your library is ready',
          sub: n == 0
              ? 'An empty library: add decks from the shop or write your own with the +.'
              : '$n ${n == 1 ? 'deck' : 'decks'} and $cards cards. Swipe a few, and the engine starts learning how you remember.',
          body: [
            const SizedBox(height: 8),
            Center(child: StampedSeal(size: 180, label: 'WELCOME', delayMs: 250, onLand: () => Fx.i.fanfare())),
            const SizedBox(height: 24),
            Center(
              child: Text('Goal $_goal a day · ${_pace.name} pace${_remind ? ' · reminder at ${(_remindAt ~/ 60).toString().padLeft(2, '0')}:${(_remindAt % 60).toString().padLeft(2, '0')}' : ''}',
                  textAlign: TextAlign.center, style: T.t(15, w: FontWeight.w600, color: mc.muted)),
            ),
          ],
          action: InkButton(n == 0 ? 'Open my library' : 'Start my first stack', size: 26, onTap: () => _finish(study: n > 0)),
          secondary: n == 0 ? null : SoftButton('Look around first', onTap: () => _finish(study: false)),
        );
    }
  }
}

class _NudgeArrow extends StatelessWidget {
  const _NudgeArrow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      onTap: onTap,
      label: 'Continue',
      child: AmbientClock(
        builder: (context, ms) => Transform.translate(
          offset: Offset(6 * math.sin(ms / 420), 0),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(22), boxShadow: mc.e1),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('or tap here', style: T.t(15, w: FontWeight.w700, color: mc.ink)),
              const SizedBox(width: 6),
              McIcon(McIcons.chevron, size: const Size(18, 18), color: mc.ink),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.color, required this.title, required this.note, required this.fill});
  final Color color;
  final String title;
  final String note;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: T.t(16, w: FontWeight.w700, color: mc.onInk))),
          Text(note, style: T.t(13, w: FontWeight.w600, color: mc.mutedOnInk)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Stack(children: [
              Positioned.fill(child: ColoredBox(color: mc.onInk.withValues(alpha: 0.15))),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fill),
                duration: const Duration(milliseconds: 900),
                curve: McCurves.out,
                builder: (context, v, _) => FractionallySizedBox(widthFactor: v, child: ColoredBox(color: color)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// A deck bar whose fan fills step by step while the health number counts up.
class _FanDemo extends StatelessWidget {
  const _FanDemo();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return AmbientClock(builder: (context, ms) {
      final t = ((ms % 6000) / 4200).clamp(0.0, 1.0);
      final steps = (t * 5.2).floor().clamp(0, 5);
      final health = (40 + 52 * easeOutCubic(t)).round();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 72,
          decoration: BoxDecoration(color: mc.onInk, borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            for (var i = 0; i < 5; i++)
              Positioned(
                right: -10 + (4 - i) * 15.0,
                bottom: -40 + i * 8.0,
                child: Transform.rotate(
                  alignment: Alignment.bottomRight,
                  angle: (-16 + i * 3) * math.pi / 180,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: 54,
                    height: 80,
                    decoration: BoxDecoration(
                      color: i < steps ? Mc.light.fanOn[i] : Mc.light.fanOff,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
            Positioned(left: 14, top: 10, child: Text('Spanish · Basics', style: T.d(21, color: mc.ink))),
            Positioned(left: 14, bottom: 10, child: Text('$health% health · ${5 - steps} slipping', style: T.t(13, w: FontWeight.w600, color: mc.muted))),
          ]),
        ),
      ]);
    });
  }
}

/// The re-insertion diagram: a missed card slides 8 cards back into the stack.
class _Reinsertion extends StatefulWidget {
  const _Reinsertion();

  @override
  State<_Reinsertion> createState() => _ReinsertionState();
}

class _ReinsertionState extends State<_Reinsertion> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = McCurves.inOut.transform(_c.value);
        return Column(children: [
          SizedBox(
            height: 70,
            child: LayoutBuilder(builder: (context, box) {
              const n = 12;
              final gap = box.maxWidth / n;
              return Stack(children: [
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: i * gap + (i >= 8 ? gap * 0.5 * t : 0) - (i < 8 ? gap * 0.5 * t : 0) + gap * 0.5 * t,
                    top: 18,
                    child: Container(
                      width: gap * 0.7,
                      height: 44,
                      decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(6), border: Border.all(color: mc.line)),
                    ),
                  ),
                Positioned(
                  left: (8 * gap) * t,
                  top: 18 - 18 * math.sin(t * math.pi),
                  child: Container(
                    width: gap * 0.7,
                    height: 44,
                    decoration: BoxDecoration(color: Mc.red, borderRadius: BorderRadius.circular(6), boxShadow: mc.e2),
                  ),
                ),
              ]);
            }),
          ),
          const SizedBox(height: 14),
          Opacity(
            opacity: t,
            child: Text('Back in 8 cards: far enough that the next try is a real recall.',
                textAlign: TextAlign.center, style: T.t(17, w: FontWeight.w700, color: mc.ink, height: 1.3)),
          ),
        ]);
      },
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.deck, required this.on, required this.onTap});
  final CatalogDeck deck;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      onTap: onTap,
      label: '${deck.name}${on ? ', selected' : ''}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: on ? mc.ink : mc.soft,
          borderRadius: BorderRadius.circular(16),
          boxShadow: on ? mc.e2 : mc.e1,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Center(child: StackArt(mono: deck.mono, tab: Color(CatalogCategory.of(deck.category).color), scale: 0.6)),
              if (on)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: Mc.green, shape: BoxShape.circle),
                    child: Center(child: McIcon(McIcons.done, size: const Size(13, 13), color: Mc.graphite)),
                  ),
                ),
            ]),
          ),
          Text(deck.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.d(15, color: on ? mc.canvas : mc.ink, height: 1.05)),
          const SizedBox(height: 2),
          Text('${deck.cards.length} cards', style: T.t(12, w: FontWeight.w600, color: on ? mc.mutedOnInk : mc.muted)),
        ]),
      ),
    );
  }
}

class _MemberPreview extends StatelessWidget {
  const _MemberPreview({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return AspectRatio(
      aspectRatio: 1.6,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          color: mc.ink,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: mc.dark ? 0.6 : 0.24), blurRadius: 36, offset: const Offset(0, 16))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Mc.tier, borderRadius: BorderRadius.circular(13)),
              child: Text('BRONZE TIER', style: T.caps(12, color: Mc.graphite)),
            ),
            const Spacer(),
            McIcon(McIcons.logo, size: const Size(30, 40), color: mc.onInk),
          ]),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(name, key: ValueKey(name), style: T.d(34, color: mc.onInk)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            for (final (v, l) in [('0000', 'mastered'), ('0000', 'streak'), ('----', 'health %'), ('${DateTime.now().year}', 'since')])
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: T.d(28, color: mc.digits, spacing: 1))),
                  Text(l.toUpperCase(), style: T.caps(10, color: mc.mutedOnInk, spacing: 1)),
                ]),
              ),
          ]),
        ]),
      ),
    );
  }
}
