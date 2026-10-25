import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../shell/nav_bar.dart';
import 'deck_flights.dart';
import 'deck_motion.dart';
import 'deck_row.dart';

/// Move D (a stage hook hauls the deck off to the left) with the destination picked on a dealt card with a
/// fedora (canvas "Deck swipe actions": Move · D and D1). The card is dealt from the + card exactly like New deck /
/// New card, shows the folders (it keeps one height however many there are: the list scrolls inside it), and when
/// you pick one it is dealt back while a hook comes in from the left, catches the deck's near corner and hauls it
/// away in three tugs and a yank.

/// One folder the deck can go to.
class MoveFolderOption {
  const MoveFolderOption({required this.id, required this.name, required this.decks, required this.tab});
  final String id;
  final String name;
  final int decks;

  /// The folder's tab colour (its shade in the folder list).
  final Color tab;
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// The fedora, as a paper cut-out: a body in the card's inverse ink with an outline in the card's colour (so it reads
/// over the card and over the dark page alike), a blue band and a feather.
String fedoraSvg({required Color body, required Color outline, required Color under, required Color band}) {
  final b = _hex(body), o = _hex(outline), u = _hex(under), bd = _hex(band);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 72">'
      '<path d="M4 50 C4 60 32 68 60 68 C88 68 116 60 116 50 C116 57 90 63 60 63 C30 63 4 57 4 50 Z" fill="$u" stroke="$o" stroke-width="3" stroke-linejoin="round"/>'
      '<path d="M4 48 C4 38 30 33 60 33 C90 33 116 38 116 48 C116 58 90 64 60 64 C30 64 4 58 4 48 Z" fill="$b" stroke="$o" stroke-width="3" stroke-linejoin="round"/>'
      '<path d="M27 50 C22 28 30 9 50 9 C54 9 57 13 60 17 C63 13 66 9 70 9 C90 9 98 28 93 50 C80 57 40 57 27 50 Z" fill="$b" stroke="$o" stroke-width="3" stroke-linejoin="round"/>'
      '<path d="M60 17 C56 28 54 40 52 51 C58 53 62 53 68 51 C66 40 64 28 60 17 Z" fill="#000" fill-opacity=".17"/>'
      '<path d="M78 11 C92 18 98 32 93 50 C88 54 83 56 78 57 C85 42 84 24 78 11 Z" fill="#000" fill-opacity=".14"/>'
      '<path d="M33 23 C37 15 44 11 50 11 C42 16 37 26 36 40 C33 36 31 29 33 23 Z" fill="#fff" fill-opacity=".24"/>'
      '<path d="M27.4 44 C42 53 78 53 92.6 44 L93.7 35.5 C79 44 41 44 26.3 35.5 Z" fill="$bd"/>'
      '<path d="M29 38.5 C43 46 77 46 91 38.5" fill="none" stroke="#fff" stroke-opacity=".55" stroke-width="1.4" stroke-linecap="round"/>'
      '<path d="M85 43 C91 32 99 24 110 17 C106 28 99 39 89 46 Z" fill="$o" stroke="$b" stroke-width="1.4" stroke-linejoin="round"/>'
      '<path d="M88 44 C95 35 102 27 109 19" fill="none" stroke="$b" stroke-width="1" stroke-linecap="round"/>'
      '</svg>';
}

class Fedora extends StatelessWidget {
  const Fedora({super.key, this.width = 116});
  final double width;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return SvgPicture.string(
      fedoraSvg(
        body: mc.onInk,
        outline: mc.ink,
        under: mc.dark ? const Color(0xFF0B0B0B) : const Color(0xFFC4C4C4),
        band: Mc.blue,
      ),
      width: width,
      height: width * 0.6,
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// The card.

const _rowH = 54.0, _rowGap = 8.0, _listMax = 204.0, _head = 112.0, _foot = 46.0;

/// The card's size: its width follows the screen, its height follows the number of folders up to a limit (the list
/// scrolls inside it after that).
Size folderCardSize(double screenWidth, int folders) {
  final w = math.min(292.0, screenWidth - 48);
  final list = folders == 0 ? 0.0 : math.min(_listMax, folders * (_rowH + _rowGap) - _rowGap);
  return Size(w, _head + list + (folders == 0 ? 0 : 8) + _foot + 14);
}

/// The face of the card: title, the deck being moved, the folders (a scrolling list with faded edges and a thin
/// scroll bar) and "+ New folder" pinned at the bottom.
class FolderCardFace extends StatefulWidget {
  const FolderCardFace({
    super.key,
    required this.deckName,
    required this.options,
    required this.size,
    required this.reveal,
    required this.chosen,
    required this.closing,
    required this.enabled,
    required this.onPick,
    required this.onNew,
  });

  final String deckName;
  final List<MoveFolderOption> options;
  final Size size;

  /// Seconds since the card was dealt (the rows come in one after another).
  final double reveal;

  /// The picked row (or -1) and whether the card is being taken back (the others fade).
  final int chosen;
  final double closing; // seconds since it started to close, or -1
  final bool enabled;
  final ValueChanged<int> onPick;
  final VoidCallback onNew;

  @override
  State<FolderCardFace> createState() => _FolderCardFaceState();
}

class _FolderCardFaceState extends State<FolderCardFace> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final n = widget.options.length;
    final listH = n == 0 ? 0.0 : math.min(_listMax, n * (_rowH + _rowGap) - _rowGap);
    final footTop = _head + listH + 8;
    final closing = widget.closing >= 0;
    final newOp = closing ? 1 - Mo.c01(widget.closing / 0.25) : Mo.c01((widget.reveal - 0.8) / 0.3);
    return Container(
      foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(18)),
      decoration: BoxDecoration(
        color: mc.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 44, offset: Offset(0, 22))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        const Positioned(left: 0, right: 0, top: 0, height: 10, child: ColoredBox(color: Mc.blue)),
        Positioned(right: 22, top: 30, child: McIcon(McIcons.move, size: const Size(26, 18), color: Mc.blue)),
        Positioned(left: 24, top: 28, right: 64, child: Text('Move to…', maxLines: 1, style: T.d(34, color: mc.onInk, height: 1))),
        Positioned(left: 24, top: 72, child: _MiniFan(ink: mc.onInk)),
        Positioned(
          left: 56,
          top: 72,
          right: 60,
          child: Text(
            widget.deckName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.t(14, w: FontWeight.w600, color: mc.onInk.withValues(alpha: 0.66)),
          ),
        ),
        if (n > 0)
          Positioned(
            left: 20,
            right: 20,
            top: _head,
            height: listH,
            child: AnimatedBuilder(
              animation: _scroll,
              builder: (context, child) {
                final max = n * (_rowH + _rowGap) - _rowGap - listH;
                final off = _scroll.hasClients ? _scroll.offset.clamp(0.0, math.max(0.0, max)) : 0.0;
                final scrollable = max > 1;
                final a = scrollable ? Mo.c01(off / 22) * 24 / listH : 0.0;
                final b = scrollable ? Mo.c01((max - off) / 22) * 28 / listH : 0.0;
                final content = n * (_rowH + _rowGap) - _rowGap;
                final thumbH = scrollable ? math.max(30.0, listH * listH / content) : 0.0;
                final thumbTop = scrollable ? (off / max) * (listH - thumbH) : 0.0;
                return Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
                        stops: [0, a, 1 - b, 1],
                      ).createShader(r),
                      child: child,
                    ),
                  ),
                  if (scrollable)
                    Positioned(
                      right: -12,
                      top: thumbTop,
                      width: 3,
                      height: thumbH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: mc.onInk.withValues(alpha: 0.32 * Mo.c01((widget.reveal - 0.8) / 0.3)), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                ]);
              },
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: n,
                itemExtent: _rowH + _rowGap,
                itemBuilder: (context, i) => _FolderRow(
                  option: widget.options[i],
                  index: i,
                  reveal: widget.reveal,
                  chosen: widget.chosen == i,
                  closing: widget.closing,
                  anyChosen: widget.chosen >= 0,
                  enabled: widget.enabled,
                  onTap: () => widget.onPick(i),
                ),
              ),
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          top: footTop,
          height: _foot,
          child: Opacity(
            opacity: newOp.clamp(0.0, 1.0),
            child: Pressable(
              label: 'Move to a new folder',
              haptic: true,
              enabled: widget.enabled,
              onTap: widget.onNew,
              child: CustomPaint(
                painter: _DashedBox(mc.onInk),
                child: Center(child: Text('+ New folder', style: T.d(21, color: mc.onInk, height: 1))),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.option,
    required this.index,
    required this.reveal,
    required this.chosen,
    required this.closing,
    required this.anyChosen,
    required this.enabled,
    required this.onTap,
  });

  final MoveFolderOption option;
  final int index;
  final double reveal;
  final bool chosen;
  final double closing;
  final bool anyChosen;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final rp = Mo.c01((reveal - 0.55 - math.min(index, 4) * 0.07) / 0.3);
    var op = rp, ty = (1 - Mo.eo3(rp)) * 14, sc = 1.0;
    if (closing >= 0) {
      op = chosen ? 1 : 1 - Mo.c01(closing / 0.25);
      sc = chosen ? 1 - 0.03 * math.sin(math.pi * Mo.c01(closing / 0.25)) : 1;
      ty = 0;
    }
    final fg = chosen ? Mc.graphite : mc.onInk;
    return Padding(
      padding: const EdgeInsets.only(bottom: _rowGap),
      child: Opacity(
        opacity: op,
        child: Transform.translate(
          offset: Offset(0, ty),
          child: Transform.scale(
            scale: sc,
            child: Pressable(
              label: 'Move to ${option.name}',
              haptic: true,
              enabled: enabled,
              onTap: onTap,
              child: Container(
                height: _rowH,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: chosen ? Mc.blue : mc.onInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Container(width: 10, height: 26, decoration: BoxDecoration(color: option.tab, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(option.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.d(22, color: fg, height: 1))),
                  const SizedBox(width: 8),
                  Text(
                    '${option.decks} ${option.decks == 1 ? 'deck' : 'decks'}',
                    style: T.t(13, w: FontWeight.w600, color: fg.withValues(alpha: 0.62)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three little cards: the deck that is moving.
class _MiniFan extends StatelessWidget {
  const _MiniFan({required this.ink});
  final Color ink;

  @override
  Widget build(BuildContext context) {
    Widget card(double left, double top, double deg, Color c) => Positioned(
          left: left,
          top: top,
          child: Transform.rotate(
            angle: deg * math.pi / 180,
            child: Container(width: 15, height: 11, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          ),
        );
    return SizedBox(
      width: 26,
      height: 20,
      child: Stack(clipBehavior: Clip.none, children: [
        card(0, 4, -12, Mc.blue),
        card(4, 2, -5, Mc.peach),
        card(8, 0, 0, ink),
      ]),
    );
  }
}

class _DashedBox extends CustomPainter {
  const _DashedBox(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), const Radius.circular(12)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox old) => old.color != color;
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Container(
      decoration: BoxDecoration(color: mc.canvas, borderRadius: BorderRadius.circular(18), border: Border.all(color: mc.ink, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: CardBackPainter(mc.ink.withValues(alpha: 0.16), gap: 12, width: 3)),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// The hook.

/// The stage hook, drawn at [anchor] (the crook's bowl, which cups the deck's lower left corner) and turned [angle]:
/// a long pole coming from off screen, a crook, a knob. White in dark mode, dark in light mode, with an outline in the
/// page's colour so it reads over the bars.
class HookPainter extends CustomPainter {
  const HookPainter({required this.anchor, required this.angle, required this.dark});
  final Offset anchor;
  final double angle;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final hook = dark ? const Color(0xFFF1F1F1) : const Color(0xFF333333);
    final halo = dark ? const Color(0xFF151515) : const Color(0xFFF1F1F1);
    final hi = dark ? const Color(0x47151515) : const Color(0x61F1F1F1);
    final knob = dark ? const Color(0xFFBDBDBD) : const Color(0xFF6A6A6A);
    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(-970, -766)
      ..lineTo(-24, -9)
      ..cubicTo(-10, 3, 6, 13, 24, 12)
      ..cubicTo(42, 11, 52, -8, 46, -30);
    Paint stroke(double w, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.save();
    canvas.translate(0, 6);
    canvas.drawPath(path, stroke(17, const Color(0x59000000))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.restore();
    canvas.drawPath(path, stroke(17, halo));
    canvas.drawPath(path, stroke(10, hook));
    canvas.drawLine(const Offset(-970, -773), const Offset(-28, -17), stroke(2.6, hi));
    canvas.drawCircle(const Offset(46, -32), 8.5, Paint()..color = halo);
    canvas.drawCircle(const Offset(46, -32), 5.5, Paint()..color = knob);
    canvas.drawLine(const Offset(-104, -74), const Offset(-92, -64), stroke(3, halo));
    canvas.drawLine(const Offset(-130, -95), const Offset(-118, -85), stroke(3, halo));
    canvas.restore();
  }

  @override
  bool shouldRepaint(HookPainter old) => old.anchor != anchor || old.angle != angle || old.dark != dark;
}

/// Speed lines trailing the deck and two ghosts of it, drawn under the hook.
class HaulFxPainter extends CustomPainter {
  const HaulFxPainter({required this.left, required this.top, required this.width, required this.sx, required this.sy, required this.sp, required this.k, required this.ink});
  final double left, top, width, sx, sy, sp, k;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (sp <= 0.02) return;
    final right = left + width * sx;
    const offs = [-28.0, -17.0, -6.0, 8.0, 20.0, 31.0];
    for (var i = 0; i < offs.length; i++) {
      final len = (40 + 150 * sp) * (0.65 + 0.35 * ((i * 5) % 3) / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(right + 4, top + 36 + offs[i], len, 3), const Radius.circular(2)),
        Paint()..color = ink.withValues(alpha: Mo.c01(sp * 1.6) * 0.5),
      );
    }
    for (final g in [1, 2]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left + 34 * g * sp, top + 72 * (1 - sy), width * sx, 72 * sy), const Radius.circular(10)),
        Paint()..color = ink.withValues(alpha: (0.2 / g) * Mo.c01(sp * 1.5)),
      );
    }
  }

  @override
  bool shouldRepaint(HaulFxPainter old) => true;
}

// ---------------------------------------------------------------------------------------------------------------
// The flight.

class MoveFlight extends StatefulWidget {
  const MoveFlight({
    super.key,
    required this.deck,
    required this.rest,
    required this.start,
    required this.options,
    required this.onChosen,
    required this.onNewFolder,
    required this.onRelease,
    required this.onCancel,
    required this.onDone,
  });

  final FlightDeck deck;
  final Rect rest;
  final Rect start;
  final List<MoveFolderOption> options;

  /// A folder was picked: the row hides its own bar (the flight draws it) and fades its chips.
  final VoidCallback onChosen;

  /// "+ New folder": asks for a name, makes the folder and returns its id (null: cancelled).
  final Future<String?> Function() onNewFolder;

  /// The deck is gone from the screen: move it to the folder (the other decks close the gap).
  final ValueChanged<String> onRelease;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<MoveFlight> createState() => _MoveFlightState();
}

enum _Phase { open, run, cancel }

class _MoveFlightState extends State<MoveFlight> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  _Phase _phase = _Phase.open;
  double _t0 = 0; // when the current phase began
  int _choice = -1;
  String? _folderId;
  bool _released = false, _whoosh = false, _busy = false, _finished = false;

  static const _ready = 0.85;
  static const _runTotal = 2.55;

  @override
  void initState() {
    super.initState();
    Fx.i.deal();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration d) {
    final t = d.inMicroseconds / 1e6;
    final u = t - _t0;
    if (_phase == _Phase.run) {
      if (!_released && u >= 1.6) {
        _released = true;
        widget.onRelease(_folderId!);
      }
      if (!_whoosh && u >= 1.38) {
        _whoosh = true;
        Fx.i.whoosh();
      }
      if (u >= _runTotal && !_finished) _finish();
    } else if (_phase == _Phase.cancel && u >= 0.5 && !_finished) {
      widget.onCancel();
      _finish();
    }
    if (!mounted) return;
    setState(() => _t = t);
  }

  void _finish() {
    _finished = true;
    _ticker.stop();
    widget.onDone();
  }

  double get _pt => _phase == _Phase.open ? _t - _t0 : 99;
  double get _u => _phase == _Phase.open ? -1 : _t - _t0;

  void _begin(String folderId, int choice) {
    _folderId = folderId;
    _choice = choice;
    _phase = _Phase.run;
    _t0 = _t;
    Fx.i.pop();
    widget.onChosen();
  }

  void _pick(int i) {
    if (_phase != _Phase.open || _pt < _ready || _busy) return;
    _begin(widget.options[i].id, i);
  }

  Future<void> _new() async {
    if (_phase != _Phase.open || _pt < _ready || _busy) return;
    _busy = true;
    final id = await widget.onNewFolder();
    _busy = false;
    if (id == null || !mounted || _phase != _Phase.open) return;
    _begin(id, widget.options.length);
  }

  void _cancel() {
    if (_phase != _Phase.open) return;
    _phase = _Phase.cancel;
    _t0 = _t;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final reduced = MotionPrefs.reducedOf(context);
    final pt = _pt, u = _u;
    final closing = u >= 0;
    final card = folderCardSize(size.width, widget.options.length);
    final avail = size.height - NavBar.height - mq.padding.bottom;
    final cardTop = math.max(mq.padding.top + 36.0, (avail - card.height) / 2 - 10);
    final cardLeft = (size.width - card.width) / 2;
    final toCy = cardTop + card.height / 2;
    final fromCy = size.height - mq.padding.bottom - 40;

    // The card is dealt like the + card's cards, and taken back the same way round.
    final tt = closing ? 1 - Mo.c01(u / 0.4) : Mo.c01(pt / 0.56);
    final pos = reduced ? tt : McCurves.springy.transform(tt.clamp(0.0, 1.0));
    final flip = reduced ? 1.0 : Curves.easeOut.transform(tt.clamp(0.0, 1.0));
    final angleY = math.pi * (1 - flip);
    final cardOp = closing ? Mo.c01(tt * 5) : Mo.c01(tt * 5);
    final dimOp = closing ? 1 - Mo.c01(u / 0.4) : Mo.c01(pt / 0.3);
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..translateByDouble(0, (1 - pos) * (fromCy - toCy), 0, 1)
      ..rotateZ(-3 * math.pi / 180 * pos)
      ..rotateY(angleY)
      ..scaleByDouble(0.42 + 0.58 * pos, 0.42 + 0.58 * pos, 1, 1);

    // The fedora drops onto the corner once the card has turned, and tips when a folder is picked.
    final hp = pt - 0.55;
    final a = Mo.spr(hp, 0.5, 18);
    var hy = -70 * (1 - a), hr = -52 + 34 * a;
    var hop = hp <= 0 ? 0.0 : Mo.c01(hp / 0.08);
    if (reduced) {
      hy = 0;
      hr = -18;
      hop = Mo.c01(pt / 0.3);
    }
    if (closing) {
      final tp = math.sin(math.pi * Mo.c01(u / 0.4));
      hy = reduced ? 0 : -12 * tp;
      hr = -18 - (reduced ? 0 : 34 * tp);
      hop = cardOp;
    }

    final children = <Widget>[
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _cancel,
          child: ColoredBox(color: mc.canvas.withValues(alpha: 0.78 * Curves.easeOut.transform(dimOp.clamp(0.0, 1.0)))),
        ),
      ),
    ];

    // The deck hauled away.
    if (_phase == _Phase.run) {
      final k = 1 - Mo.eo3(u / 0.3);
      final h = _haul(u);
      final left = widget.rest.left + (widget.start.left - widget.rest.left) * k + h.x;
      final top = widget.rest.top + h.y;
      final face = DeckBarFace(
        id: widget.deck.id,
        name: widget.deck.name,
        meta: widget.deck.meta,
        steps: widget.deck.steps,
        pinned: widget.deck.pinned,
        skin: widget.deck.skin,
        width: widget.rest.width,
      );
      children.add(Positioned(
        left: left,
        top: top,
        width: widget.rest.width,
        height: 72,
        child: Transform(
          alignment: Alignment.bottomLeft,
          transform: Matrix4.identity()
            ..rotateZ(h.rot)
            ..multiply(Matrix4.identity()..setEntry(0, 1, math.tan(h.skew)))
            ..scaleByDouble(h.sx, h.sy, 1, 1),
          child: face,
        ),
      ));
      final sp = h.s * (u >= 1.38 ? 1 : 0.6) / 0.55;
      final off = -330 * (1 - Mo.eio(u / 0.55)) + 6 * math.sin(u * 14) * (1 - Mo.c01(u / 0.55));
      children.add(Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _Fx(
              fx: HaulFxPainter(left: left, top: top, width: widget.rest.width, sx: h.sx, sy: h.sy, sp: sp, k: 1, ink: mc.ink),
              hook: u < 1.8 ? HookPainter(anchor: Offset(left - 3 + off, top + 72 + 2), angle: -24 * math.pi / 180, dark: mc.dark) : null,
            ),
          ),
        ),
      ));
    }

    children.add(Positioned(
      left: cardLeft,
      top: cardTop,
      width: card.width,
      height: card.height,
      child: IgnorePointer(
        ignoring: _phase != _Phase.open || pt < 0.4,
        child: Opacity(
          opacity: cardOp.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: m,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: angleY > math.pi / 2
                    ? const _CardBack()
                    : FolderCardFace(
                        deckName: widget.deck.name,
                        options: widget.options,
                        size: card,
                        reveal: reduced ? 99 : math.max(0, pt),
                        chosen: _choice,
                        closing: u,
                        enabled: _phase == _Phase.open && pt >= _ready,
                        onPick: _pick,
                        onNew: _new,
                      ),
              ),
              if (angleY <= math.pi / 2)
                Positioned(
                  left: -40,
                  top: -50,
                  width: 116,
                  height: 70,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: hop.clamp(0.0, 1.0),
                      child: Transform(
                        alignment: const Alignment(-0.08, 0.84),
                        transform: Matrix4.identity()
                          ..translateByDouble(0, hy, 0, 1)
                          ..rotateZ(hr * math.pi / 180),
                        child: const Fedora(),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ));

    return Material(type: MaterialType.transparency, child: Stack(clipBehavior: Clip.none, children: children));
  }

  /// The deck's pose while it is hauled off: three tugs that it resists, then the yank (see the canvas's Move D).
  ({double x, double y, double rot, double skew, double sx, double sy, double s}) _haul(double u) {
    double xf(double t) {
      if (t < 0.78) return 0;
      const segs = [
        [0.78, 0.96, 0.0, -54.0, 1.0],
        [0.96, 1.08, -54.0, -40.0, 0.0],
        [1.08, 1.26, -40.0, -126.0, 1.0],
        [1.26, 1.38, -126.0, -108.0, 0.0],
      ];
      for (final sg in segs) {
        if (t < sg[1]) {
          final q = (t - sg[0]) / (sg[1] - sg[0]);
          return Mo.lerp(sg[2], sg[3], sg[4] == 1 ? Mo.eo3(q) : Mo.eio(q));
        }
      }
      return -108 - 620 * math.pow(Mo.c01((t - 1.38) / 0.34), 2.2).toDouble();
    }

    final x = xf(u);
    final v = -(xf(u + 0.01) - xf(u - 0.01)) / 0.02;
    final s = (v / 3600).clamp(0.0, 0.55);
    var y = 0.0, resist = 0.0;
    const tugs = [
      [0.78, 0.96, 1.0],
      [0.96, 1.08, 0.0],
      [1.08, 1.26, 1.0],
      [1.26, 1.38, 0.0],
    ];
    for (final sg in tugs) {
      if (u >= sg[0] && u < sg[1]) {
        final q = (u - sg[0]) / (sg[1] - sg[0]);
        if (sg[2] == 1) {
          y = -9 * math.sin(math.pi * q);
        } else {
          resist = math.sin(math.pi * q);
        }
      }
    }
    var rot = 0.0;
    if (u >= 0.78) {
      rot = u < 1.38 ? -5 * math.sin(22 * (u - 0.76)) * Mo.c01((u - 0.78) / 0.4) : 9 * Mo.c01((u - 1.38) / 0.3);
    }
    return (
      x: x,
      y: y,
      rot: rot * math.pi / 180,
      skew: (v / 300).clamp(0.0, 14.0) * math.pi / 180,
      sx: 1 + s - 0.05 * resist,
      sy: 1 / (1 + 0.7 * s) + 0.05 * resist,
      s: s,
    );
  }
}

class _Fx extends CustomPainter {
  const _Fx({required this.fx, this.hook});
  final HaulFxPainter fx;
  final HookPainter? hook;

  @override
  void paint(Canvas canvas, Size size) {
    fx.paint(canvas, size);
    hook?.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_Fx old) => true;
}
