import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../engine/assessor.dart';
import '../../engine/stack_rules.dart';
import '../../engine/study_engine.dart';
import '../../engine/typing.dart';
import '../../services/reminders.dart';
import '../../services/speech.dart';
import '../../ui/coach.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../browse/card_detail.dart';
import '../browse/deck_browser.dart';
import '../editor/editor_sheet.dart';
import '../shell/nav_bar.dart';
import '../shell/shell.dart';
import '../today/today_screen.dart';
import 'card_face.dart';
import 'celebrate.dart';
import 'ears.dart';

class _Undo {
  _Undo(
    this.snap,
    this.deckId,
    this.cardId,
    this.mixBefore,
    this.signals,
    this.recalled,
    this.mode,
  );
  final StudySnapshot snap;
  final String deckId;
  final String cardId;
  final List<(String, String)>? mixBefore;
  final ReviewSignals signals;
  final bool recalled;
  final String mode;
}

class _Note {
  _Note(
    this.text, {
    this.undo = false,
    this.grade,
    this.rewriteCardId,
    this.ms = 5000,
  });
  final String text;
  final bool undo;

  /// Set when the grade was read automatically from a right swipe: the chip lets you change it.
  final int? grade;
  final String? rewriteCardId;
  final int ms;
  final int id = DateTime.now().microsecondsSinceEpoch;
}

/// The study stack (canvas Study.dc.html): an endless stack you swipe through. Right = remembered,
/// left = not yet. The engine reads how you answered (RES-48) and decides where each card goes.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, required this.deckId});

  /// null = the cross-deck daily mix.
  final String? deckId;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AppStore store = context.storeRead;
  late final AnimationController _settle = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  final _focus = FocusNode();
  final _typed = TextEditingController();

  // The card on top.
  String? _deckId;
  String? _cardId;
  List<(String, String)> _mix = [];
  bool get _isMix => widget.deckId == null;

  // Gesture.
  double _dx = 0;
  bool _dragging = false;
  bool _busy = false;
  bool _revealed = false;
  bool _focusL = false, _focusR = false;
  bool _locked = false;

  // Signals for the assessor.
  int _shownAt = 0;
  int? _revealAt;
  int? _dragStartAt;
  int _reversals = 0;
  int _crossings = 0;
  int _lastSign = 0;
  double _signTravel = 0;
  double _maxLeft = 0, _maxRight = 0;
  bool _interrupted = false;
  double? _typedSim;
  String? _typedResult;

  // Session.
  final List<_Undo> _undo = [];
  final List<bool> _results = [];
  _Note? _note;
  Timer? _noteTimer;
  bool _speaking = false;
  bool _gradePicker = false;
  int _warm = 0;
  bool _goalOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settle.addListener(_onSettle);
    if (_isMix) {
      _mix = store.buildMix(max: math.max(20, store.settings.goal));
    } else {
      _warm = store.prepare(widget.deckId!, notify: false);
      WidgetsBinding.instance.addPostFrameCallback((_) => store.ping());
    }
    _loadTop();
    if (_warm > 0) {
      _showNote(_Note('Warm-up: your $_warm weakest cards first', ms: 4200));
    } else if (_isMix && _mix.isNotEmpty) {
      _showNote(
        _Note('${_mix.length} slipping cards, most urgent first', ms: 3200),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settle.dispose();
    _flip.dispose();
    _focus.dispose();
    _typed.dispose();
    _noteTimer?.cancel();
    Speech.i.stop();
    Reminders.i.reschedule(store);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _interrupted = true;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  Deck? get _deck => _deckId == null ? null : store.data.decks[_deckId];
  CardItem? get _card => _cardId == null ? null : store.data.cards[_cardId];

  void _loadTop() {
    if (_isMix) {
      _mix = _mix
          .where(
            (e) =>
                store.data.cards.containsKey(e.$2) &&
                store.data.decks.containsKey(e.$1),
          )
          .toList();
      if (_mix.isEmpty) {
        _deckId = null;
        _cardId = null;
      } else {
        _deckId = _mix.first.$1;
        _cardId = _mix.first.$2;
      }
    } else {
      _deckId = widget.deckId;
      _cardId = store.top(widget.deckId!);
    }
    _resetCardState();
    final c = _card, d = _deck;
    if (c != null && d?.lang != null && store.settings.autoSpeak) {
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted && _cardId == c.id) _speak();
      });
    }
  }

  void _resetCardState() {
    _dx = 0;
    _revealed = false;
    _flip.value = 0;
    _shownAt = _now();
    _revealAt = null;
    _dragStartAt = null;
    _reversals = 0;
    _crossings = 0;
    _lastSign = 0;
    _signTravel = 0;
    _maxLeft = 0;
    _maxRight = 0;
    _interrupted = false;
    _typedSim = null;
    _typedResult = null;
    _typed.clear();
    _locked = false;
    _gradePicker = false;
  }

  RevealMode get _mode => store.settings.reveal;
  bool get _typing => _deck?.typing ?? false;

  bool get _needsReveal => !_revealed && (_typing || _mode != RevealMode.front);

  // ------------------------------------------------------------------ notes

  void _showNote(_Note n) {
    _noteTimer?.cancel();
    setState(() {
      _note = n;
      _gradePicker = false;
    });
    _noteTimer = Timer(Duration(milliseconds: n.ms), () {
      if (mounted && _note?.id == n.id) setState(() => _note = null);
    });
  }

  // ------------------------------------------------------------------ reveal & speech

  void _reveal() {
    if (_revealed || _busy) return;
    Fx.i.reveal();
    _revealAt = _now();
    setState(() {
      _revealed = true;
      if (_note?.text.startsWith('Tap') ?? false) _note = null;
    });
    if (_mode == RevealMode.flip && !_typing) {
      _flip.animateTo(1, curve: McCurves.springy);
    }
  }

  void _submitTyped() {
    final c = _card;
    if (c == null || _revealed) return;
    final sim = TypedAnswer.similarity(
      _typed.text,
      c.back,
      ignoreAccents: store.settings.ignoreAccents,
    );
    _typedSim = sim;
    _typedResult = TypedAnswer.verdict(sim);
    FocusScope.of(context).unfocus();
    _reveal();
  }

  Future<void> _speak() async {
    final c = _card, d = _deck;
    if (c == null || d?.lang == null) return;
    setState(() => _speaking = true);
    await Speech.i.speak(
      c.isReverse ? c.back : c.front,
      d!.lang!,
      onDone: () {
        if (mounted) setState(() => _speaking = false);
      },
    );
  }

  // ------------------------------------------------------------------ dragging

  double _cardW = 276;

  void _onPanStart(DragStartDetails d) {
    if (_busy || _card == null) return;
    _settle.stop();
    _springing = false;
    _dragging = true;
    _dragStartAt ??= _now();
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final dx = _dx + d.delta.dx;
    // Direction changes that travelled at least 12px count as a reversal (indecision).
    final sign = d.delta.dx.sign.toInt();
    if (sign != 0) {
      if (sign == _lastSign) {
        _signTravel += d.delta.dx.abs();
      } else {
        if (_lastSign != 0 && _signTravel >= 12) _reversals++;
        _lastSign = sign;
        _signTravel = d.delta.dx.abs();
      }
    }
    final commit = 0.6 * _cardW;
    final wasLocked = _locked;
    final nowLocked = dx.abs() >= commit;
    if (nowLocked != wasLocked) {
      _crossings++;
      if (nowLocked) Fx.i.lock();
    }
    _locked = nowLocked;
    _maxLeft = math.max(_maxLeft, -dx);
    _maxRight = math.max(_maxRight, dx);
    setState(() => _dx = dx);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final v = d.velocity.pixelsPerSecond.dx;
    final commit = _dx.abs() >= 0.6 * _cardW;
    final fling =
        v.abs() > 950 && _dx.abs() > 0.22 * _cardW && v.sign == _dx.sign;
    if (commit || fling) {
      _commit(_dx > 0, velocity: v.abs());
    } else {
      _springBack();
    }
  }

  bool _springing = false;

  void _springBack() {
    _springing = true;
    _settle.value = _dx;
    _settle.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 520, damping: 32),
        _dx,
        0,
        0,
      ),
    );
    _locked = false;
  }

  void _onSettle() {
    if (_springing && mounted) setState(() => _dx = _settle.value);
  }

  // ------------------------------------------------------------------ committing

  Future<void> _commit(
    bool recalled, {
    bool viaButton = false,
    double velocity = 0,
    int? forcedGrade,
  }) async {
    final card = _card, deck = _deck;
    if (_busy || card == null || deck == null) return;
    if (_needsReveal) {
      _springBack();
      Fx.i.warn();
      _showNote(
        _Note(
          _typing
              ? 'Type your answer first'
              : _mode == RevealMode.flip
              ? 'Flip the card to check first'
              : _mode == RevealMode.icon
              ? 'Show the answer to check first'
              : 'Tap the card to check first',
          ms: 2200,
        ),
      );
      return;
    }
    _busy = true;
    _settle.stop();
    _springing = false;
    final now = _now();
    final shown = _shownAt;
    final revealAt = _revealAt;
    final startAt = _dragStartAt;
    final think = (revealAt ?? startAt ?? now) - shown;
    final signals = ReviewSignals(
      thinkMs: math.max(0, think),
      verifyMs: revealAt == null
          ? null
          : math.max(0, (startAt ?? now) - revealAt),
      dragMs: startAt == null ? 0 : math.max(0, now - startAt),
      reversals: _reversals,
      crossings: _crossings,
      hesitation: ((recalled ? _maxLeft : _maxRight) / _cardW).clamp(0.0, 1.0),
      velocity: velocity,
      viaButton: viaButton,
      interrupted: _interrupted,
      promptChars: card.front.length,
      typedSimilarity: _typedSim,
    );

    // Fly the card off-screen.
    final w = MediaQuery.of(context).size.width;
    final reduced = MotionPrefs.reducedOf(context);
    final from = _dx;
    final to = (recalled ? 1 : -1) * (w + 160.0);
    if (recalled) {
      Fx.i.remembered();
    } else {
      Fx.i.missed();
    }
    final c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: reduced ? 150 : 230),
    );
    c.addListener(() {
      if (mounted) {
        setState(
          () => _dx = from + (to - from) * McCurves.paper.transform(c.value),
        );
      }
    });
    await c.forward();
    c.dispose();
    if (!mounted) return;
    _apply(deck.id, card.id, recalled, signals, forcedGrade: forcedGrade);
  }

  void _apply(
    String deckId,
    String cardId,
    bool recalled,
    ReviewSignals signals, {
    int? forcedGrade,
  }) {
    final snap = store.snapshot(deckId, cardId);
    final mixBefore = _isMix ? [..._mix] : null;
    final mode = _isMix
        ? 'mix'
        : (_warm > 0 && _results.length < _warm ? 'warmup' : 'flow');
    final out = store.swipe(
      deckId: deckId,
      cardId: cardId,
      recalled: recalled,
      signals: signals,
      mode: mode,
      forcedGrade: forcedGrade,
      mood: SessionMood.of(_results),
      snapshot: snap,
    );
    _undo.add(_Undo(snap, deckId, cardId, mixBefore, signals, recalled, mode));
    if (_undo.length > 30) _undo.removeAt(0);
    _results.add(out.grade > 1);

    if (_isMix) {
      final rest = _mix.sublist(1);
      if (out.grade == 1) {
        final c = store.data.cards[cardId]!;
        final pos = StackRules.failGap(
          successRate: c.successRate,
          stabilityBefore: out.log.sBefore,
          lapses: c.lapses,
          kind: out.assessment.kind,
          restLength: rest.length,
        );
        rest.insert(pos.clamp(0, rest.length), (deckId, cardId));
      }
      _mix = rest;
    }

    _busy = false;
    _loadTop();
    setState(() {});

    final note = _noteFor(out);
    _showNote(note);

    if (out.goalNow && !_goalOpen) {
      _goalOpen = true;
      Future.delayed(const Duration(milliseconds: 180), () async {
        if (!mounted) return;
        final r = await showGoalDialog(
          context,
          done: store.data.today?.done ?? 0,
          streak: store.engine.liveStreak(),
          seals: out.seals,
        );
        _goalOpen = false;
        if (r == 'summary' && mounted) {
          Navigator.of(context, rootNavigator: true).push(TodayScreen.route());
        }
      });
    } else if (out.seals.isNotEmpty) {
      announceSeals(context, out.seals);
    }
  }

  _Note _noteFor(SwipeOutcome out) {
    final a = out.assessment;
    final smart = store.settings.smartGrading && store.settings.showGrade;
    if (out.leechNow) {
      return _Note(
        'This card keeps slipping',
        rewriteCardId: out.cardId,
        ms: 7000,
      );
    }
    if (out.pausedNew) {
      return _Note('Tough patch · new cards paused', undo: true, ms: 4200);
    }
    final where = out.toEnd
        ? 'to the back'
        : 'back in ${out.reinsertAt} ${out.reinsertAt == 1 ? 'card' : 'cards'}';
    final intro = out.introduced.isNotEmpty
        ? ' · ${out.introduced.length == 1 ? 'new card in' : '${out.introduced.length} new cards in'}'
        : '';
    if (!a.recalled) {
      final lead = a.kind == RecallKind.nearMiss && smart ? 'Almost · ' : '';
      return _Note(
        '$lead${out.toEnd ? 'Back at the end' : 'Back in ${out.reinsertAt} cards'}$intro',
        undo: true,
      );
    }
    if (!smart) return _Note('Sent to the back$intro', undo: true);
    final g = Assessment.gradeName(a.grade);
    return _Note(
      '$g · $where$intro',
      undo: true,
      grade: a.automatic ? a.grade : null,
    );
  }

  void _undoLast() {
    if (_busy) return;
    if (_undo.isEmpty) {
      _showNote(_Note('Nothing to undo', ms: 1600));
      return;
    }
    final u = _undo.removeLast();
    if (_results.isNotEmpty) _results.removeLast();
    store.restore(u.snap);
    if (u.mixBefore != null) _mix = u.mixBefore!;
    Fx.i.undo();
    setState(() {
      if (_isMix) {
        _loadTop();
      } else {
        _deckId = u.deckId;
        _cardId = u.cardId;
        _resetCardState();
      }
      _revealed = true;
      if (_mode == RevealMode.flip) _flip.value = 1;
      _revealAt = _now();
    });
    _showNote(_Note('Undone', ms: 1600));
  }

  /// Change the grade the engine read: undo the swipe and apply it again with your grade.
  void _regrade(int grade) {
    if (_undo.isEmpty || _busy) return;
    final u = _undo.removeLast();
    if (_results.isNotEmpty) _results.removeLast();
    store.restore(u.snap);
    if (u.mixBefore != null) _mix = u.mixBefore!;
    Fx.i.tap();
    _apply(u.deckId, u.cardId, grade > 1, u.signals, forcedGrade: grade);
  }

  // ------------------------------------------------------------------ menu

  void _menu() {
    final card = _card, deck = _deck;
    final nav = Navigator.of(context, rootNavigator: true);
    showMcMenu(context, [
      if (card != null)
        MenuItemData(
          'Why this card?',
          () => nav.push(CardDetail.route(card.id)),
          icon: McIcons.chart,
        ),
      if (card != null)
        MenuItemData(
          'Edit this card',
          () => showEditor(context, editCardId: card.id),
          icon: McIcons.list,
        ),
      if (deck != null)
        MenuItemData(
          'Add a card here',
          () => showEditor(context, deckId: deck.id),
          icon: McIcons.plus,
        ),
      MenuItemData(
        'Undo last swipe',
        _undoLast,
        icon: McIcons.undo,
        enabled: _undo.isNotEmpty,
      ),
      if (deck != null)
        MenuItemData(
          deck.typing ? 'Stop typing answers' : 'Type the answers',
          () {
            deck.typing = !deck.typing;
            store.saveDeck(deck);
            setState(_resetCardState);
          },
          icon: McIcons.keyboard,
        ),
      if (deck != null && !_isMix)
        MenuItemData(
          'Browse this deck',
          () => nav.push(DeckBrowser.route(deck.id)),
          icon: McIcons.list,
        ),
      MenuItemData(
        'Pace',
        () => _pacePicker(),
        hint: _paceName(deck),
        icon: McIcons.sparkle,
      ),
      MenuItemData(
        "Today's progress",
        () => nav.push(TodayScreen.route()),
        icon: McIcons.done,
      ),
    ]);
  }

  String _paceName(Deck? d) {
    final p = d?.pace ?? store.settings.pace.name;
    return p[0].toUpperCase() + p.substring(1);
  }

  Future<void> _pacePicker() async {
    final deck = _deck;
    final mc = Mc.of(context);
    final current = deck?.pace ?? store.settings.pace.name;
    final picked = await showMcSheet<String>(
      context,
      expand: false,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pace', style: T.d(30, color: mc.ink)),
            const SizedBox(height: 4),
            Text(
              deck == null ? 'For every deck' : 'For ${deck.name}',
              style: T.t(15, w: FontWeight.w600, color: mc.muted),
            ),
            const SizedBox(height: 14),
            for (final (id, name, note) in const [
              (
                'relaxed',
                'Relaxed',
                'New cards join while you remember about 80% — calm, steady sessions.',
              ),
              (
                'balanced',
                'Balanced',
                'New cards join while you remember about 75%. The default.',
              ),
              (
                'intense',
                'Intense',
                'Every card is in the stack from day one. Covers most ground, fails more often.',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Pressable(
                  onTap: () => Navigator.pop(ctx, id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: id == current ? mc.ink : mc.soft,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: mc.e1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: T.d(
                            22,
                            color: id == current ? mc.canvas : mc.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          note,
                          style: T.t(
                            14,
                            w: FontWeight.w500,
                            color: id == current ? mc.mutedOnInk : mc.muted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (deck != null) {
      deck.pace = picked == store.settings.pace.name ? null : picked;
      if (picked == 'intense' && deck.reservoir.isNotEmpty) {
        deck.stack = [...deck.stack, ...deck.reservoir];
        deck.reservoir = [];
      }
      store.saveDeck(deck);
    } else {
      store.updateSettings(
        (s) => s.pace = Pace.values.firstWhere((p) => p.name == picked),
      );
    }
    Toaster.i.show('Pace: ${picked[0].toUpperCase()}${picked.substring(1)}');
    setState(() {});
  }

  // ------------------------------------------------------------------ keys

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight) {
      _commit(true, viaButton: true);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _commit(false, viaButton: true);
    } else if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      _reveal();
    } else if (k == LogicalKeyboardKey.keyZ ||
        k == LogicalKeyboardKey.backspace) {
      _undoLast();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final reduced = MotionPrefs.reducedOf(context);
    final deck = _deck;
    final card = _card;
    final today = store.today;
    final goal = store.settings.goal;
    final stackSize = _isMix ? _mix.length : (deck?.stack.length ?? 0);
    final waiting = _isMix ? 0 : (deck?.reservoir.length ?? 0);
    final title = _isMix ? 'Daily mix' : (deck?.name ?? '');

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: mc.canvas,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final top = mq.padding.top;
            final navH = NavBar.height + mq.padding.bottom;
            // Fit the card between the header and the ears (design: 276 × 384 on 390 × 844).
            var cardW = math.min(276.0, w * 0.71);
            var cardH = cardW * 384 / 276;
            const headerSpace = 160.0;
            const earsSpace = 32 + 112.0;
            final avail = h - navH - top;
            final need = headerSpace + cardH + earsSpace;
            if (need > avail) {
              cardH = math.max(280, avail - headerSpace - earsSpace + 16);
              cardW = math.min(cardW, cardH * 276 / 384 * 1.04);
            }
            _cardW = cardW;
            final slack = math.max(
              0.0,
              avail - (headerSpace + cardH + earsSpace),
            );
            final cardTop = top + headerSpace - 6 + slack * 0.3;
            final cardLeft = (w - cardW) / 2;
            final earsTop = math.min(cardTop + cardH + 30, h - navH - 100);
            final compact = cardH < 360;

            final dx = _dx;
            final p = math.min(1.0, dx.abs() / cardW);
            final rot = (dx * 0.09).clamp(-28.0, 28.0) * math.pi / 180;
            final dy = math.min(140.0, dx * dx * 0.0005);
            final sc = 1 - 0.14 * p;
            final inL = _focusL
                ? 1.0
                : (dx < 0 ? math.min(1.0, -dx / (0.4 * cardW)) : 0.0);
            final inR = _focusR
                ? 1.0
                : (dx > 0 ? math.min(1.0, dx / (0.4 * cardW)) : 0.0);
            final commitL = dx <= -0.6 * cardW;
            final commitR = dx >= 0.6 * cardW;
            final suggestRight =
                _typedResult != null && _typedResult != 'wrong';
            final suggestLeft = _typedResult == 'wrong';

            final nextId = _isMix
                ? (_mix.length > 1 ? _mix[1].$2 : null)
                : (deck == null
                      ? null
                      : store.engine.peekNext(deck, store.now()));
            final next = nextId == null ? null : store.data.cards[nextId];

            Widget layer(double t, Decoration dec) => Positioned(
              left: cardLeft,
              top: t,
              width: cardW,
              height: cardH,
              child: DecoratedBox(decoration: dec),
            );

            final layers = <Widget>[
              for (final k in [3, 2, 1])
                if (k < stackSize)
                  layer(
                    cardTop + 17 * k,
                    BoxDecoration(
                      color: mc.below[k - 1],
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
              for (final k in [4, 3, 2, 1])
                if (k < stackSize)
                  layer(
                    cardTop - 17 * k,
                    BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          mc.above[k - 1][0],
                          mc.above[k - 1][1],
                          mc.above[k - 1][1],
                        ],
                        stops: [0, 17 / cardH, 1],
                      ),
                    ),
                  ),
            ];

            Widget topCard() {
              if (card == null || deck == null) return const SizedBox.shrink();
              final face = CardFront(
                card: card,
                deck: deck,
                revealed: _revealed,
                mode: _typing ? RevealMode.tap : _mode,
                compact: compact,
                speaking: _speaking,
                onReveal: _reveal,
                onSpeak: deck.lang == null ? null : _speak,
                typedResult: _typedResult,
                typing: _typing
                    ? _TypeField(controller: _typed, onSubmit: _submitTyped)
                    : null,
              );
              final flipMode = _mode == RevealMode.flip && !_typing;
              Widget body = flipMode
                  ? AnimatedBuilder(
                      animation: _flip,
                      builder: (context, _) {
                        final a = _flip.value * math.pi;
                        final back = a > math.pi / 2;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(a),
                          child: back
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..rotateY(math.pi),
                                  child: CardBack(
                                    card: card,
                                    compact: compact,
                                    speaking: _speaking,
                                    onSpeak: deck.lang == null ? null : _speak,
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: mc.ink,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: face,
                                ),
                        );
                      },
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: mc.ink,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: mc.cardShadow,
                      ),
                      child: face,
                    );
              final transform = reduced
                  ? (Matrix4.identity()..translateByDouble(dx, 0, 0, 1))
                  : (Matrix4.identity()
                      ..translateByDouble(dx, dy, 0, 1)
                      ..rotateZ(rot)
                      ..scaleByDouble(sc, sc, 1, 1));
              return Positioned(
                key: ValueKey('top-${card.id}'),
                left: cardLeft,
                top: cardTop,
                width: cardW,
                height: cardH,
                child: Semantics(
                  label:
                      'Card: ${card.front}${_revealed ? '. Answer: ${card.back}' : ''}',
                  customSemanticsActions: {
                    const CustomSemanticsAction(label: 'Remembered'): () =>
                        _commit(true, viaButton: true),
                    const CustomSemanticsAction(label: "Didn't remember"): () =>
                        _commit(false, viaButton: true),
                  },
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    onTap: () {
                      if (_mode == RevealMode.tap || _mode == RevealMode.flip) {
                        _reveal();
                      }
                    },
                    child: Transform(
                      alignment: Alignment.center,
                      transform: transform,
                      child: Opacity(
                        opacity: reduced ? (1 - p * 0.7) : 1,
                        child: body,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Stack(
              children: [
                ...layers,
                // The next card waits underneath; its prompt surfaces as you drag the top one away.
                if (card != null)
                  Positioned(
                    left: cardLeft,
                    top: cardTop,
                    width: cardW,
                    height: cardH,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: mc.ink,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: next == null
                          ? null
                          : Opacity(
                              opacity: p,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (next.label.isEmpty ? 'card' : next.label)
                                        .toUpperCase(),
                                    style: T.caps(12, color: mc.mutedOnInk),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    next.front,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        (store.data.decks[next.deckId]?.kind ==
                                                'code' &&
                                            !next.isReverse)
                                        ? T.mono(
                                            termSize(next.front, true),
                                            color: mc.onInk,
                                          )
                                        : T.d(
                                            termSize(next.front, false),
                                            color: mc.onInk,
                                            height: 1.05,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                if (card == null)
                  Positioned(
                    left: cardLeft,
                    top: cardTop,
                    width: cardW,
                    height: cardH,
                    child: _EmptyCard(
                      mix: _isMix,
                      onAdd: deck == null && !_isMix
                          ? null
                          : () => showEditor(context, deckId: widget.deckId),
                      onHome: () => Shell.of(context).goHome(),
                    ),
                  ),
                topCard(),
                // Ears.
                Positioned(
                  left: 0,
                  top: earsTop,
                  child: Focus(
                    onFocusChange: (f) => setState(() => _focusL = f),
                    child: Ear(
                      right: false,
                      amount: inL,
                      committed: commitL,
                      dragging: _dragging,
                      suggest: suggestLeft && _revealed,
                      onTap: () => _commit(false, viaButton: true),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: earsTop,
                  child: Focus(
                    onFocusChange: (f) => setState(() => _focusR = f),
                    child: Ear(
                      right: true,
                      amount: inR,
                      committed: commitR,
                      dragging: _dragging,
                      suggest: suggestRight && _revealed,
                      onTap: () => _commit(true, viaButton: true),
                    ),
                  ),
                ),
                // Header and the goal bar.
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  child: _StudyHeader(
                    title: title,
                    subtitle:
                        'Today ${math.min(today.done, goal)} / $goal · ${_isMix ? '$stackSize left' : 'stack of $stackSize'}${waiting > 0 ? ' · $waiting waiting' : ''}',
                    onBack: () => Shell.of(context).goHome(),
                    onMenu: _menu,
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  top: top + 72,
                  height: 4,
                  child: _GoalBar(
                    value: goal == 0 ? 0 : math.min(1.0, today.done / goal),
                  ),
                ),
                // The note chip under the card.
                Positioned(
                  left: 12,
                  right: 12,
                  top: math.min(earsTop + 76, h - navH - 44),
                  child: Center(child: _noteChip(mc)),
                ),
                if (card != null && store.data.profile.totalReviews < 3)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: cardTop - 86,
                    child: Center(
                      child: CoachTarget(
                        id: 'study-swipe',
                        spotlight: false,
                        text: _revealed
                            ? 'Swipe right if you knew it, left if not'
                            : 'Try to remember, then tap the card',
                        child: const SizedBox(width: 10, height: 10),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _noteChip(Mc mc) {
    final n = _note;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 140),
      switchInCurve: McCurves.out,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(a),
          child: c,
        ),
      ),
      child: n == null
          ? const SizedBox(key: ValueKey('none'), height: 34)
          : Column(
              key: ValueKey(n.id),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_gradePicker && n.grade != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final g in const [2, 3, 4])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Chip2(
                              Assessment.gradeName(g),
                              selected: g == n.grade,
                              height: 32,
                              onTap: g == n.grade
                                  ? () => setState(() => _gradePicker = false)
                                  : () => _regrade(g),
                            ),
                          ),
                      ],
                    ),
                  ),
                Container(
                  height: 34,
                  padding: EdgeInsets.only(
                    left: 12,
                    right: n.undo || n.rewriteCardId != null ? 4 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: mc.soft,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: mc.e2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: n.grade == null
                              ? null
                              : () {
                                  _noteTimer?.cancel();
                                  setState(() => _gradePicker = !_gradePicker);
                                },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  n.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.t(
                                    14,
                                    w: FontWeight.w600,
                                    color: mc.ink,
                                  ),
                                ),
                              ),
                              if (n.grade != null) ...[
                                const SizedBox(width: 2),
                                Icon(
                                  _gradePicker
                                      ? Icons.expand_more
                                      : Icons.expand_less,
                                  size: 18,
                                  color: mc.muted,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (n.undo) ...[
                        const SizedBox(width: 6),
                        _ChipButton(
                          label: 'Undo',
                          icon: McIcons.undo,
                          onTap: _undoLast,
                        ),
                      ],
                      if (n.rewriteCardId != null) ...[
                        const SizedBox(width: 6),
                        _ChipButton(
                          label: 'Rewrite it',
                          onTap: () =>
                              showEditor(context, editCardId: n.rewriteCardId),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: mc.ink,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              McIcon(icon!, size: const Size(15, 15), color: mc.canvas),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: T.t(13, w: FontWeight.w700, color: mc.canvas),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyHeader extends StatelessWidget {
  const _StudyHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onMenu,
  });
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 0),
        child: Row(
          children: [
            IconTap(icon: McIcons.logo, label: 'Back to decks', onTap: onBack),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.d(23, color: mc.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.t(13, w: FontWeight.w600, color: mc.muted),
                  ),
                ],
              ),
            ),
            IconTap(
              icon: McIcons.dots,
              label: 'Menu',
              size: const Size(8, 26),
              onTap: onMenu,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Semantics(
      label: 'Daily goal',
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: mc.soft)),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                heightFactor: 1,
                child: ColoredBox(color: mc.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeField extends StatelessWidget {
  const _TypeField({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            style: T.t(18, w: FontWeight.w600, color: Mc.graphite),
            cursorColor: Mc.graphite,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Type the answer',
              hintStyle: T.t(
                17,
                w: FontWeight.w500,
                color: Mc.graphite.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: mc.pill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Pressable(
          onTap: onSubmit,
          label: 'Check',
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Mc.peach,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: McIcon(
                McIcons.done,
                size: const Size(26, 26),
                color: Mc.graphite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.mix,
    required this.onAdd,
    required this.onHome,
  });
  final bool mix;
  final VoidCallback? onAdd;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: mc.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: mc.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            mix ? 'All caught up' : 'No cards yet',
            style: T.d(34, color: mc.onInk, height: 1.05),
          ),
          const SizedBox(height: 8),
          Text(
            mix
                ? 'Nothing is slipping right now. Your memory is in good shape.'
                : 'Write the first one and it joins this stack.',
            style: T.t(
              16,
              w: FontWeight.w500,
              color: mc.mutedOnInk,
              height: 1.35,
            ),
          ),
          const Spacer(),
          Pressable(
            onTap: mix ? onHome : onAdd,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: mc.pill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                mix ? 'Back to decks' : 'Add a card',
                style: T.t(17, w: FontWeight.w600, color: Mc.graphite),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
