import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/seals.dart';
import '../../ui/fx.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/shapes.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// The wax-seal stamp entrance: drops in big and tilted, overshoots small on impact, settles; then a calm
/// idle float, sway and breath, with the scalloped rim turning once every 30 s (canvas Goal.dc.html).
const stampKeys = Keyframes(700, [
  [0, 1.5, -22, 0],
  [0.45, 0.92, -2, 1],
  [0.7, 1.04, 1, 1],
  [1, 1, 0, 1],
]);

class StampedSeal extends StatefulWidget {
  const StampedSeal({super.key, required this.size, this.label = 'DONE', this.color = Mc.red, this.delayMs = 0, this.check = false, this.onLand});
  final double size;
  final String label;
  final Color color;
  final int delayMs;
  final bool check;
  final VoidCallback? onLand;

  @override
  State<StampedSeal> createState() => _StampedSealState();
}

class _StampedSealState extends State<StampedSeal> {
  bool _landed = false;

  @override
  Widget build(BuildContext context) {
    return AmbientClock(
      builder: (context, ms) {
        final since = ms - widget.delayMs;
        if (since < 0) return SizedBox(width: widget.size, height: widget.size);
        final reduced = MotionPrefs.reducedOf(context);
        var v = reduced ? const [1.0, 0.0, 1.0] : stampKeys.sample(since);
        if (!_landed && since >= 300) {
          _landed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Fx.i.stamp();
            widget.onLand?.call();
          });
        }
        var s = v[0], rot = v[1];
        final op = v[2];
        final y = 2 * math.sin(since / 3600 * math.pi * 2);
        rot += 2.5 * math.sin(since / 5200 * math.pi * 2);
        s *= 1 + 0.01 * math.sin(since / 3600 * math.pi * 2 + 1);
        return Opacity(
          opacity: op.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, y),
            child: Transform.rotate(
              angle: rot * math.pi / 180,
              child: Transform.scale(
                scale: s,
                child: WaxSeal(
                  size: widget.size,
                  color: widget.color,
                  spin: since / 30000 * math.pi * 2,
                  check: widget.check,
                  child: widget.check
                      ? null
                      : Transform.rotate(
                          angle: -12 * math.pi / 180,
                          child: SizedBox(
                            width: widget.size * 0.58,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(widget.label, maxLines: 1, style: T.d(widget.size * 0.18, color: Mc.paper, spacing: 1)),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paper confetti for streak milestones (7, 30, 100…): a short burst of small cards.
class Confetti extends StatelessWidget {
  const Confetti({super.key});

  @override
  Widget build(BuildContext context) {
    if (MotionPrefs.reducedOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AmbientClock(builder: (context, ms) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(ms))),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.ms);
  final double ms;
  static final _rand = math.Random(7);
  static final _bits = List.generate(46, (i) => (
        x: _rand.nextDouble(),
        vx: (_rand.nextDouble() - 0.5) * 0.9,
        vy: -0.7 - _rand.nextDouble() * 0.9,
        spin: (_rand.nextDouble() - 0.5) * 12,
        w: 6 + _rand.nextDouble() * 6,
        c: [Mc.red, Mc.blue, Mc.peach, Mc.green, const Color(0xFFF1F1F1)][i % 5],
      ));

  @override
  void paint(Canvas canvas, Size size) {
    final t = ms / 1000;
    if (t > 2.6) return;
    for (final b in _bits) {
      final x = size.width * (0.5 + (b.x - 0.5) * 0.3) + b.vx * size.width * t;
      final y = size.height * 0.42 + b.vy * size.height * 0.55 * t + 0.5 * 1.4 * size.height * t * t * 0.55;
      final op = (1 - (t - 1.6).clamp(0.0, 1.0)).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.w, height: b.w * 1.4), const Radius.circular(1.5)),
        Paint()..color = b.c.withValues(alpha: op),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.ms != ms;
}

/// "Today's goal — done" (canvas Study.dc.html dialog), with any seals earned on the way.
Future<String?> showGoalDialog(BuildContext context, {required int done, required int streak, required List<String> seals}) {
  Fx.i.fanfare();
  final milestone = const {3, 7, 14, 30, 50, 100, 200, 365}.contains(streak);
  return showMcDialog<String>(
    context,
    builder: (ctx) {
      final mc = Mc.of(ctx);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          DialogCard(children: [
            const Center(child: StampedSeal(size: 96, check: true, delayMs: 120)),
            const SizedBox(height: 14),
            Text("Today's goal — done", textAlign: TextAlign.center, style: T.d(34, color: mc.ink, height: 1.05)),
            const SizedBox(height: 8),
            Text(
              '$done cards reviewed · streak $streak ${streak == 1 ? 'day' : 'days'}. The stack keeps going if you do.',
              textAlign: TextAlign.center,
              style: T.t(16, color: mc.muted, height: 1.35),
            ),
            if (seals.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [for (final id in seals) SealChip(id: id)],
              ),
            ],
            const SizedBox(height: 20),
            InkButton('Keep going', height: 52, onTap: () => Navigator.pop(ctx, 'keep')),
            const SizedBox(height: 10),
            Pressable(
              onTap: () => Navigator.pop(ctx, 'summary'),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14)),
                child: Text("See today's summary", style: T.t(16, w: FontWeight.w600, color: mc.ink)),
              ),
            ),
          ]),
          if (milestone) const Positioned.fill(child: Confetti()),
        ],
      );
    },
  );
}

/// A small earned seal with its name.
class SealChip extends StatelessWidget {
  const SealChip({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final def = Seals.byId(id);
    if (def == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(22)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SealBadge(def: def, size: 34),
        const SizedBox(width: 8),
        Text(def.title, style: T.t(14, w: FontWeight.w700, color: mc.ink)),
      ]),
    );
  }
}

Color sealColor(int i, Mc mc) => [Mc.red, Mc.blue, Mc.peach, Mc.green, mc.ink][i % 5];

class SealBadge extends StatelessWidget {
  const SealBadge({super.key, required this.def, required this.size, this.earned = true});
  final SealDef def;
  final double size;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final color = earned ? sealColor(def.color, mc) : mc.soft;
    final ink = earned ? (def.color == 4 ? mc.canvas : (def.color == 0 ? Mc.paper : Mc.graphite)) : mc.muted;
    return WaxSeal(
      size: size,
      color: color,
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        child: FittedBox(child: Text(def.mark, style: T.d(size * 0.3, color: ink))),
      ),
    );
  }
}

/// A seal earned outside a goal moment slides in from the top.
void announceSeals(BuildContext context, List<String> ids) {
  if (ids.isEmpty) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) => _SealBanner(ids: ids, onDone: () => entry.remove()));
  overlay.insert(entry);
  Fx.i.seal();
}

class _SealBanner extends StatefulWidget {
  const _SealBanner({required this.ids, required this.onDone});
  final List<String> ids;
  final VoidCallback onDone;

  @override
  State<_SealBanner> createState() => _SealBannerState();
}

class _SealBannerState extends State<_SealBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3200), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final def = Seals.byId(widget.ids.first);
    if (def == null) return const SizedBox.shrink();
    final top = MediaQuery.of(context).padding.top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = McCurves.springy.transform(_c.value);
          return Opacity(
            opacity: _c.value.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, -40 * (1 - t)), child: child),
          );
        },
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
              decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(30), boxShadow: mc.e3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SealBadge(def: def, size: 46),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('New seal · ${def.title}', style: T.d(21, color: mc.canvas)),
                      Text(def.note, maxLines: 2, style: T.t(13, w: FontWeight.w600, color: mc.mutedOnInk)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
