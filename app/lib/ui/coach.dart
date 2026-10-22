import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import 'widgets.dart';
import 'theme.dart';

/// First-visit coach marks: a soft peach ring breathes around the control and a small note explains it.
/// One at a time, each shown once, dismissed by a tap anywhere.
class CoachTarget extends StatefulWidget {
  const CoachTarget({super.key, required this.id, required this.text, required this.child, this.below = true, this.delayMs = 1400});

  final String id;
  final String text;
  final Widget child;
  final bool below;
  final int delayMs;

  /// The coach mark currently on screen.
  static final active = ValueNotifier<String?>(null);

  @override
  State<CoachTarget> createState() => _CoachTargetState();
}

class _CoachTargetState extends State<CoachTarget> with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  OverlayEntry? _entry;
  Timer? _timer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    CoachTarget.active.addListener(_maybeShow);
    _timer = Timer(Duration(milliseconds: widget.delayMs), _maybeShow);
  }

  void _maybeShow() {
    if (!mounted || _entry != null) return;
    if (_timer?.isActive ?? false) return;
    final store = context.storeRead;
    if (store.coachSeen(widget.id) || CoachTarget.active.value != null) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    CoachTarget.active.value = widget.id;
    _pulse.repeat();
    _entry = OverlayEntry(builder: _bubble);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() {});
  }

  void _dismiss() {
    if (_entry == null) return;
    context.storeRead.markCoach(widget.id);
    _entry?.remove();
    _entry = null;
    _pulse.stop();
    if (CoachTarget.active.value == widget.id) CoachTarget.active.value = null;
    if (mounted) setState(() {});
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
    const bubbleW = 220.0;
    final left = (center.dx - bubbleW / 2).clamp(12.0, screen.width - bubbleW - 12);
    final top = widget.below ? pos.dy + size.height + 12 : null;
    final bottom = widget.below ? null : screen.height - pos.dy + 12;
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _dismiss(),
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              bottom: bottom,
              width: bubbleW,
              child: Cascade(
                index: 0,
                offset: widget.below ? -8 : 8,
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                    decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(14), boxShadow: mc.e2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.text, style: T.t(15, w: FontWeight.w700, color: mc.canvas, height: 1.25)),
                        const SizedBox(height: 3),
                        Text('Tap anywhere', style: T.t(12, w: FontWeight.w600, color: mc.mutedOnInk)),
                      ],
                    ),
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
        if (showing)
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
