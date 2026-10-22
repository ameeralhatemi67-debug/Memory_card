import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import 'widgets.dart';
import 'theme.dart';

/// First-visit coach marks: the screen dims except for a spotlight on the control, a soft peach ring
/// breathes around it and a small note points at it. One at a time, each shown once, dismissed by a
/// tap anywhere (a tap on the control itself also goes through to it).
class CoachTarget extends StatefulWidget {
  const CoachTarget({
    super.key,
    required this.id,
    required this.text,
    required this.child,
    this.below = true,
    this.delayMs = 1400,
    this.spotlight = true,
  });

  final String id;
  final String text;
  final Widget child;
  final bool below;
  final int delayMs;

  /// Dim the rest of the screen. Off for hints over something you are about to use (the study card).
  final bool spotlight;

  /// The coach mark currently on screen.
  static final active = ValueNotifier<String?>(null);

  @override
  State<CoachTarget> createState() => _CoachTargetState();
}

class _CoachTargetState extends State<CoachTarget> with TickerProviderStateMixin {
  final _key = GlobalKey();
  OverlayEntry? _entry;
  Timer? _timer;
  late final AnimationController _pulse;
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 150),
    );
    CoachTarget.active.addListener(_maybeShow);
    _timer = Timer(Duration(milliseconds: widget.delayMs), _maybeShow);
  }

  void _maybeShow() {
    if (!mounted || _entry != null) return;
    if (_timer?.isActive ?? false) return;
    final store = context.storeRead;
    if (store.coachSeen(widget.id) || CoachTarget.active.value != null) return;
    // Only on a free screen (no sheet, dialog or pushed page on top) with the control fully in view;
    // otherwise look again shortly.
    final route = ModalRoute.of(context);
    final covered = (route != null && !route.isCurrent) || Navigator.of(context, rootNavigator: true).canPop();
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    final screen = MediaQuery.sizeOf(context);
    final inView =
        box != null &&
        box.hasSize &&
        (Offset.zero & screen).deflate(8).contains(box.localToGlobal(Offset.zero)) &&
        (Offset.zero & screen).deflate(8).contains(box.localToGlobal(box.size.bottomRight(Offset.zero)));
    if (covered || !inView) {
      _timer = Timer(const Duration(milliseconds: 1500), _maybeShow);
      return;
    }
    CoachTarget.active.value = widget.id;
    _pulse.repeat();
    _entry = OverlayEntry(builder: _bubble);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _fade.forward(from: 0);
    setState(() {});
  }

  bool _leaving = false;

  void _dismiss() {
    if (_entry == null || _leaving) return;
    _leaving = true;
    context.storeRead.markCoach(widget.id);
    _fade.reverse().whenComplete(() {
      _entry?.remove();
      _entry = null;
      _leaving = false;
      _pulse.stop();
      if (CoachTarget.active.value == widget.id) CoachTarget.active.value = null;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    CoachTarget.active.removeListener(_maybeShow);
    _entry?.remove();
    if (CoachTarget.active.value == widget.id) {
      // Let the next coach mark take over after this frame.
      scheduleMicrotask(() => CoachTarget.active.value = null);
    }
    _pulse.dispose();
    _fade.dispose();
    super.dispose();
  }

  Widget _bubble(BuildContext context) {
    final mc = Mc.of(context);
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screen = MediaQuery.of(context).size;
    final center = pos + size.center(Offset.zero);
    const bubbleW = 224.0, caret = 7.0;
    final left = (center.dx - bubbleW / 2).clamp(12.0, screen.width - bubbleW - 12);
    final top = widget.below ? pos.dy + size.height + 14 + caret : null;
    final bottom = widget.below ? null : screen.height - pos.dy + 14 + caret;
    final hole = Rect.fromCenter(center: center, width: size.width + 18, height: size.height + 18);
    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(14), boxShadow: mc.e3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: T.t(15, w: FontWeight.w700, color: mc.canvas, height: 1.25),
          ),
          const SizedBox(height: 3),
          Text(
            'Tap anywhere',
            style: T.t(12, w: FontWeight.w600, color: mc.mutedOnInk),
          ),
        ],
      ),
    );
    // The caret sits on the bubble's edge, under the control's centre.
    final caretX = (center.dx - left).clamp(18.0, bubbleW - 18.0);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            if (widget.spotlight) ...[
              // Outside the spotlight a tap only dismisses; inside it also reaches the control.
              Positioned.fill(
                child: Listener(
                  onPointerDown: (_) => _dismiss(),
                  child: CustomPaint(
                    painter: _Spotlight(
                      hole: hole,
                      color: Colors.black.withValues(alpha: mc.dark ? 0.55 : 0.32),
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: hole,
                child: Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => _dismiss()),
              ),
            ] else
              // A plain hint: any touch dismisses it and still does what it was meant to.
              Positioned.fill(
                child: Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => _dismiss()),
              ),
            Positioned(
              left: left,
              top: top,
              bottom: bottom,
              width: bubbleW,
              child: IgnorePointer(
                child: Cascade(
                  index: 0,
                  offset: widget.below ? -8 : 8,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      bubble,
                      if (widget.spotlight)
                        Positioned(
                          left: caretX - caret,
                          top: widget.below ? -caret + 1 : null,
                          bottom: widget.below ? null : -caret + 1,
                          child: Transform.rotate(
                            angle: math.pi / 4,
                            child: Container(
                              width: caret * 2,
                              height: caret * 2,
                              decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(2)),
                            ),
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
  }

  @override
  Widget build(BuildContext context) {
    final showing = _entry != null;
    return Stack(
      key: _key,
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (showing && widget.spotlight)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = _pulse.value;
                  return CustomPaint(painter: _Ring(t));
                },
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// The dimmed screen with a rounded hole around the control. Hit-testable only outside the hole, so a
/// tap on the control still reaches it.
class _Spotlight extends CustomPainter {
  _Spotlight({required this.hole, required this.color});
  final Rect hole;
  final Color color;

  RRect get _r => RRect.fromRectAndRadius(hole, Radius.circular(math.min(hole.width, hole.height) / 2));

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(_r);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool? hitTest(Offset position) => !_r.contains(position);

  @override
  bool shouldRepaint(_Spotlight old) => old.hole != hole || old.color != color;
}

class _Ring extends CustomPainter {
  _Ring(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = math.max(size.width, size.height) / 2;
    for (final k in [0.0, 0.5]) {
      final u = (t + k) % 1;
      canvas.drawCircle(
        c,
        base * (0.9 + 0.7 * u),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Mc.peach.withValues(alpha: (1 - u) * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_Ring old) => old.t != t;
}
