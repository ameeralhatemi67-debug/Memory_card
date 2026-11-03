import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../engine/make24.dart';
import '../../ui/fx.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';

/// A Make 24 card, played on the card (canvas "Ways · A — Build it on the card"). Tap a number, a sign, then
/// another number: the two merge into one card showing the result, until one card is left. If it says 24,
/// the way is matched to the card's ways and goes to [onBuilt]: a new one counts (it unlocks a right swipe);
/// one found on an earlier turn, or one Stuck? has shown in full, does not. Stuck? shows the simplest way not
/// found yet one step at a time: the first step, the next, then the whole way.
class MakeBoard extends StatefulWidget {
  const MakeBoard({
    super.key,
    required this.card,
    required this.numbers,
    required this.picked,
    required this.onBuilt,
    required this.onHint,
    this.compact = false,
  });

  final CardItem card;
  final List<int> numbers;

  /// The ways found this turn (kept by the study screen).
  final Set<int> picked;

  /// A finished 24 was built: the index of the way when it is a new one, null when it does not count.
  final ValueChanged<int?> onBuilt;

  /// Stuck? showed a step: how many of a way's three steps are out (3 = the whole way).
  final ValueChanged<int> onHint;
  final bool compact;

  @override
  State<MakeBoard> createState() => _MakeBoardState();
}

class _Tile {
  const _Tile(this.id, this.value, this.expr, this.top);
  final int id;
  final Frac value;
  final Expr expr;

  /// The coloured top a dealt number has (merged cards have none).
  final Color? top;
}

enum _Strip { found, old, again, shown, hint }

class _MakeBoardState extends State<MakeBoard> {
  static const _tops = [Mc.blue, Mc.green, Mc.peach, Mc.red];

  late List<_Tile> _tiles;
  final List<(List<_Tile>, List<String>)> _hist = [];
  List<String> _steps = [];
  int _nextId = 0;
  int? _sel;
  String? _op;
  bool _done = false;

  _Strip? _strip;
  int _stripWay = 0;
  String _note = '';

  /// The way Stuck? is showing, how many of its steps are out, and the ways it has shown in full (they no
  /// longer count when built).
  int? _hintWay;
  int _hintLevel = 0;
  final Set<int> _shown = {};

  int? _shakeId;
  int _shakeN = 0;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    _tiles = [for (var i = 0; i < widget.numbers.length; i++) _Tile(i, Frac(widget.numbers[i]), Expr.num(widget.numbers[i]), _tops[i % 4])];
    _nextId = widget.numbers.length;
    _hist.clear();
    _steps = [];
    _sel = null;
    _op = null;
    _done = false;
  }

  List<String> get _ways => widget.card.ways;

  void _shake(int id, String note) {
    Fx.i.warn();
    setState(() {
      _shakeId = id;
      _shakeN++;
      _note = note;
    });
  }

  void _tapTile(_Tile t) {
    if (_done) return;
    Fx.i.tap();
    if (_sel == null || _op == null) {
      setState(() {
        _sel = _sel == t.id ? null : t.id;
        _note = '';
      });
      return;
    }
    if (_sel == t.id) return;
    _merge(_tiles.firstWhere((x) => x.id == _sel), _op!, t);
  }

  void _tapOp(String op) {
    if (_done) return;
    Fx.i.tap();
    if (_sel == null) {
      setState(() => _note = 'Pick a number first.');
      return;
    }
    setState(() {
      _op = _op == op ? null : op;
      _note = '';
    });
  }

  void _merge(_Tile a, String op, _Tile b) {
    if (op == '-' && a.value.compareTo(b.value) < 0) return _shake(b.id, 'That goes below zero. Take the bigger number first.');
    final v = op == '/' ? a.value.div(b.value) : (op == '+' ? a.value + b.value : op == '-' ? a.value - b.value : a.value * b.value);
    if (v == null) return _shake(b.id, 'Nothing can be divided by 0.');
    Fx.i.pop();
    final merged = _Tile(_nextId++, v, Expr.join(op, a.expr, b.expr), null);
    setState(() {
      _hist.add((_tiles, _steps));
      final tiles = [..._tiles];
      tiles[tiles.indexOf(a)] = merged;
      tiles.remove(b);
      _tiles = tiles;
      _steps = [..._steps, '${a.value} ${opSign(op)} ${b.value} = $v'];
      _sel = merged.id;
      _op = null;
      _note = '';
      _strip = _strip == _Strip.hint ? _Strip.hint : null;
    });
    if (_tiles.length > 1) return;
    _sel = null;
    if (v != Frac.target) return _shake(merged.id, 'That makes $v, not 24. Undo a step, or start over.');
    _judge(wayOf(merged.expr));
  }

  /// A finished 24: which of the card's ways it is, and whether it counts.
  void _judge(String way) {
    final i = _ways.indexOf(way);
    final idx = i < 0 ? -1 : i;
    setState(() {
      _done = true;
      _stripWay = idx;
      if (idx < 0) {
        // Not one of the listed ways (should not happen): it still makes 24, so it counts as found.
        _strip = _Strip.found;
      } else if (widget.card.found.contains(idx)) {
        _strip = _Strip.old;
      } else if (widget.picked.contains(idx)) {
        _strip = _Strip.again;
      } else if (_shown.contains(idx)) {
        _strip = _Strip.shown;
      } else {
        _strip = _Strip.found;
      }
    });
    final counts = _strip == _Strip.found && idx >= 0;
    if (!counts) Fx.i.warn();
    widget.onBuilt(counts ? idx : null);
  }

  void _undo() {
    if (_hist.isEmpty) return;
    Fx.i.tap();
    setState(() {
      final (tiles, steps) = _hist.removeLast();
      _tiles = tiles;
      _steps = steps;
      _sel = null;
      _op = null;
      _done = false;
      _note = '';
      if (_strip != _Strip.hint) _strip = null;
    });
  }

  void _again() {
    Fx.i.tap();
    setState(() {
      _deal();
      _note = '';
      if (_strip != _Strip.hint) _strip = null;
    });
  }

  /// The simplest way not found yet and not shown in full: the next one Stuck? shows.
  int? get _nextHint {
    for (var i = 0; i < _ways.length; i++) {
      if (!widget.card.found.contains(i) && !widget.picked.contains(i) && !_shown.contains(i)) return i;
    }
    return null;
  }

  /// Stuck?: one more step of a way, starting a new way once the last one is out in full.
  void _stuck() {
    if (_hintWay == null || _hintLevel >= 3) {
      final next = _nextHint;
      if (next == null) {
        setState(() => _note = 'There is no way left to show.');
        return;
      }
      _hintWay = next;
      _hintLevel = 0;
    }
    Fx.i.tap();
    setState(() {
      _hintLevel++;
      if (_hintLevel >= 3) _shown.add(_hintWay!);
      _strip = _Strip.hint;
      _stripWay = _hintWay!;
      _note = '';
    });
    widget.onHint(_hintLevel);
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final reduced = MotionPrefs.reducedOf(context);
    final c = widget.compact;
    final n = _ways.length, before = widget.card.found.length, now = widget.picked.length;
    final progress = now > 0
        ? '$now new this turn · ${before + now} of $n found'
        : before > 0
            ? '$before of $n found · build a new one'
            : (n == 1 ? 'One way · each number once' : '$n ways · each number once');

    Widget button(String label, {VoidCallback? onTap, bool on = false, bool main = false, double size = 22}) {
      final enabled = onTap != null;
      return Expanded(
        child: Semantics(
          container: true,
          button: true,
          enabled: enabled,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: enabled ? 1 : 0.4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? Mc.blue : (main ? mc.onInk : mc.pill),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(label, maxLines: 1, style: T.t(size, w: FontWeight.w700, color: main ? mc.ink : Mc.graphite)),
              ),
            ),
          ),
        ),
      );
    }

    final hintLabel = _hintWay == null || _hintLevel >= 3 ? 'Stuck?' : (_hintLevel == 2 ? 'Show all' : 'More');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('MAKE 24', style: T.caps(12, color: mc.mutedOnInk)),
        const Spacer(),
        Semantics(
          label: '$n ways, ${before + now} found',
          child: Row(children: [
            for (var i = 0; i < n; i++)
              Container(
                width: 9,
                height: 13,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: widget.picked.contains(i)
                      ? Mc.green
                      : widget.card.found.contains(i)
                          ? mc.mutedOnInk
                          : (_shown.contains(i) ? null : mc.mutedOnInk.withValues(alpha: 0.28)),
                  border: _shown.contains(i) && !widget.picked.contains(i) ? Border.all(color: mc.mutedOnInk, width: 1.5) : null,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ]),
        ),
      ]),
      SizedBox(height: c ? 8 : 10),
      SizedBox(
        height: c ? 54 : 62,
        child: Row(children: [
          for (var i = 0; i < _tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _MergeTile(
                key: ValueKey(_tiles[i].id),
                tile: _tiles[i],
                selected: _sel == _tiles[i].id,
                win: _done && _tiles.length == 1 && (_strip == _Strip.found || _strip == _Strip.again),
                fresh: _tiles[i].id >= widget.numbers.length,
                shake: _shakeId == _tiles[i].id ? _shakeN : 0,
                reduced: reduced,
                compact: c,
                onTap: _done ? null : () => _tapTile(_tiles[i]),
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 6),
      Text(progress, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.t(14, w: FontWeight.w600, color: mc.mutedOnInk)),
      SizedBox(height: c ? 6 : 8),
      SizedBox(
        height: c ? 36 : 40,
        child: Row(children: [
          for (final op in const ['+', '-', '*', '/']) ...[
            if (op != '+') const SizedBox(width: 8),
            button(opSign(op), on: _op == op, onTap: _done ? null : () => _tapOp(op)),
          ],
        ]),
      ),
      SizedBox(height: c ? 6 : 8),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final s in _steps) Text(s, style: T.t(15, w: FontWeight.w700, color: mc.onInk, height: 1.3)),
                  if (_note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_note, style: T.t(14, w: FontWeight.w700, color: mc.onInk, height: 1.3)),
                    ),
                ]),
                if (_strip != null) ...[const SizedBox(height: 6), _stripBox(mc)],
              ]),
            ),
          ),
        ),
      ),
      SizedBox(height: c ? 6 : 8),
      SizedBox(
        height: c ? 36 : 40,
        child: Row(children: [
          button('Undo', size: 15, onTap: _hist.isEmpty || (_done && _strip == _Strip.found) ? null : _undo),
          const SizedBox(width: 8),
          button(_done ? 'Another' : 'Start over', size: 15, main: _done, onTap: _hist.isEmpty && !_done ? null : _again),
          const SizedBox(width: 8),
          button(hintLabel, size: 15, onTap: (_hintWay == null || _hintLevel >= 3) && _nextHint == null ? null : _stuck),
        ]),
      ),
    ]);
  }

  Widget _stripBox(Mc mc) {
    final way = _stripWay >= 0 && _stripWay < _ways.length ? _ways[_stripWay] : '';
    final n = _ways.length;
    final found = widget.card.found.length + widget.picked.length;
    final (label, bg) = switch (_strip!) {
      _Strip.found => ('NEW WAY · $found OF $n FOUND', Mc.green),
      _Strip.old => ('FOUND ON AN EARLIER TURN · BUILD ANOTHER', Mc.peach),
      _Strip.again => ('ALREADY FOUND THIS TURN', Mc.peach),
      _Strip.shown => ('STUCK? SHOWED THIS ONE · NOT COUNTED', Mc.peach),
      _Strip.hint => (_hintLevel >= 3 ? 'STUCK? · THE WHOLE WAY · NOT COUNTED' : 'STUCK? · STEP $_hintLevel OF 3', Mc.peach),
    };
    final hintSteps = _strip == _Strip.hint && _hintLevel < 3 ? Expr.parse(way).steps.take(_hintLevel).toList() : const <String>[];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caps(10.5, color: Mc.graphite.withValues(alpha: 0.7))),
        const SizedBox(height: 2),
        if (hintSteps.isNotEmpty)
          for (final s in hintSteps) Text(s, style: T.t(16, w: FontWeight.w700, color: Mc.graphite, height: 1.25))
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(way, style: T.d(23, color: Mc.graphite, height: 1.1)),
          ),
      ]),
    );
  }
}

/// One card on the board: a dealt number with its coloured top, or a merged result. It lifts when picked,
/// pops in when it is made, and shakes when a move is refused.
class _MergeTile extends StatelessWidget {
  const _MergeTile({
    super.key,
    required this.tile,
    required this.selected,
    required this.win,
    required this.fresh,
    required this.shake,
    required this.reduced,
    required this.compact,
    this.onTap,
  });

  final _Tile tile;
  final bool selected, win, fresh, reduced, compact;
  final int shake;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final v = tile.value;
    final big = compact ? 32.0 : 36.0;
    final size = !v.whole ? big * 0.62 : (v.n.abs() >= 100 ? big * 0.72 : (v.n.abs() >= 10 ? big * 0.86 : big));
    Widget face = AnimatedContainer(
      duration: Duration(milliseconds: reduced ? 0 : 180),
      curve: McCurves.out,
      transform: Matrix4.translationValues(0, selected ? -7 : 0, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: win ? Mc.peach : mc.onInk,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (selected) const BoxShadow(color: Mc.blue, spreadRadius: 3),
          BoxShadow(color: const Color(0x33000000), blurRadius: selected ? 14 : 4, offset: Offset(0, selected ? 8 : 2)),
        ],
      ),
      child: Stack(children: [
        if (tile.top != null) Positioned(left: 0, right: 0, top: 0, height: 5, child: ColoredBox(color: tile.top!)),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('$v', style: T.d(size, color: win ? Mc.graphite : mc.ink, height: 1)),
            ),
          ),
        ),
      ]),
    );
    if (fresh && !reduced) {
      // A merged card pops in where the first of the two was.
      face = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutBack,
        builder: (context, s, child) => Transform.scale(scale: s, child: Opacity(opacity: s.clamp(0.0, 1.0), child: child)),
        child: face,
      );
    }
    if (shake > 0 && !reduced) {
      face = TweenAnimationBuilder<double>(
        key: ValueKey('shake-$shake'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        builder: (context, t, child) => Transform.translate(offset: Offset(math.sin(t * math.pi * 4) * 6 * (1 - t), 0), child: child),
        child: face,
      );
    }
    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: 'Number $v',
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: face),
    );
  }
}
