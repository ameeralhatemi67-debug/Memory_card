import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../services/updates.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'nav_bar.dart';

/// The update card (nav canvas "Updates · The card opening", variant A): a gold-topped card leaves the + card face
/// down, turns over in the air and fills the screen with the new version, three lines of what changed and two
/// buttons. [anim] runs 0 → 1 as it is dealt and back as it returns to the + card (Later).
class UpdateCardLayer extends StatefulWidget {
  const UpdateCardLayer({super.key, required this.anim, required this.info, required this.installed, required this.onLater});
  final Animation<double> anim;
  final UpdateInfo info;

  /// The running version ("1.5.0").
  final String installed;

  /// Later: the card goes back into the + fan.
  final VoidCallback onLater;

  @override
  State<UpdateCardLayer> createState() => _UpdateCardLayerState();
}

class _UpdateCardLayerState extends State<UpdateCardLayer> {
  /// The notes ("Update now" not pressed yet) or the three steps in the browser.
  bool _steps = false;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reduced = MotionPrefs.reducedOf(context);
    final navH = NavBar.height + mq.padding.bottom;
    final w = math.min(310.0, mq.size.width - 56);
    final lo = mq.padding.top + 36;
    final hi = mq.size.height - navH - 20;
    final h = math.min(452.0, hi - lo);
    final top = lo + (hi - lo - h) / 2;
    // Where the + card's face is, to leave from and return to.
    final dy = (mq.size.height - mq.padding.bottom - 31) - (top + h / 2);
    final small = NavBar.cardW / w;
    return AnimatedBuilder(
      animation: widget.anim,
      builder: (context, _) {
        final v = widget.anim.value;
        final pos = reduced ? v : McCurves.springy.transform(v);
        final flip = reduced ? 1.0 : Curves.easeOut.transform(v);
        final angleY = math.pi * (1 - flip);
        final s = lerpDouble(small, 1, pos)!;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translateByDouble(0, dy * (1 - pos), 0, 1)
          ..rotateY(angleY)
          ..scaleByDouble(s, s, 1, 1);
        return Stack(children: [
          Positioned(
            left: (mq.size.width - w) / 2,
            top: top,
            width: w,
            height: h,
            child: IgnorePointer(
              ignoring: v < 0.95,
              child: Opacity(
                opacity: (v * 8).clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: m,
                  child: angleY > math.pi / 2 ? const _Back() : _Front(info: widget.info, installed: widget.installed, steps: _steps, onLater: widget.onLater, onSteps: (v) => setState(() => _steps = v)),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Container(
      decoration: BoxDecoration(
        color: mc.canvas,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: mc.ink, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 44, offset: Offset(0, 20))],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: CardBackPainter(mc.ink.withValues(alpha: 0.16), gap: 12, width: 3)),
    );
  }
}

class _Front extends StatelessWidget {
  const _Front({required this.info, required this.installed, required this.steps, required this.onLater, required this.onSteps});
  final UpdateInfo info;
  final String installed;
  final bool steps;
  final VoidCallback onLater;
  final ValueChanged<bool> onSteps;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final muted = mc.onInk.withValues(alpha: 0.62);
    return Container(
      foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(22)),
      decoration: BoxDecoration(
        color: mc.ink,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 22))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        const Positioned(left: 0, right: 0, top: 0, height: 12, child: ColoredBox(color: Mc.peach)),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
          child: steps ? _stepsPage(context, mc, muted) : _notesPage(context, mc, muted),
        ),
      ]),
    );
  }

  Widget _eyebrow(String text, Color muted) => Text(text, style: T.t(13, w: FontWeight.w800, color: muted, spacing: 1.6));

  Widget _bullet(String text, Mc mc) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: Mc.peach, shape: BoxShape.circle, border: Border.all(color: mc.onInk, width: 1.5)),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: T.t(15, w: FontWeight.w600, color: mc.onInk, height: 1.3))),
        ]),
      );

  Widget _button(Mc mc, String label, VoidCallback onTap, {bool primary = false}) => Pressable(
        label: label,
        haptic: true,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? mc.onInk : mc.onInk.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(22),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: T.t(16, w: FontWeight.w700, color: primary ? mc.ink : mc.onInk))),
        ),
      );

  /// The two buttons side by side, the main one wider; their labels shrink before anything overflows.
  Widget _buttons(Mc mc, String main, VoidCallback onMain, String other, VoidCallback onOther) => Row(children: [
        Expanded(flex: 3, child: _button(mc, main, onMain, primary: true)),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _button(mc, other, onOther)),
      ]);

  Widget _notesPage(BuildContext context, Mc mc, Color muted) {
    final have = ['You have $installed', if (info.megabytes.isNotEmpty) info.megabytes, 'Wi-Fi is kind'].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow(info.important ? 'IMPORTANT UPDATE' : 'NEW VERSION', muted),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(info.version, style: T.d(64, color: mc.onInk, height: 0.95))),
      Text(have, style: T.t(14, w: FontWeight.w600, color: muted)),
      const SizedBox(height: 12),
      Expanded(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final n in info.notes) _bullet(n, mc),
            if (info.notes.isEmpty) _bullet('Open the release page to see what changed.', mc),
          ]),
        ),
      ),
      _buttons(mc, 'Update now', () => onSteps(true), 'Later', onLater),
      const SizedBox(height: 10),
      Pressable(
        label: 'See every change',
        onTap: () => Updates.i.openNotes(),
        child: Text('See every change', style: T.t(14, w: FontWeight.w700, color: mc.onInk).copyWith(decoration: TextDecoration.underline, decorationColor: mc.onInk)),
      ),
      const SizedBox(height: 6),
      Text('Installs over this version. Your cards, streak and settings stay.', style: T.t(13, w: FontWeight.w600, color: muted, height: 1.3)),
    ]);
  }

  Widget _stepsPage(BuildContext context, Mc mc, Color muted) {
    final size = info.megabytes.isEmpty ? '' : ' (about ${info.megabytes})';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow('DOWNLOAD IN YOUR BROWSER', muted),
      const SizedBox(height: 4),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Three taps, then done', style: T.d(38, color: mc.onInk, height: 0.95))),
      const SizedBox(height: 14),
      Expanded(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bullet('Your browser downloads MemoryCard.apk$size.', mc),
            _bullet('When it finishes, tap Open.', mc),
            _bullet('Tap Install. Android may ask once to allow this source.', mc),
          ]),
        ),
      ),
      _buttons(mc, 'Open GitHub', () async {
        final ok = await Updates.i.openDownload();
        if (!ok) Toaster.i.show('Could not open the browser');
      }, 'Back', () => onSteps(false)),
      const SizedBox(height: 10),
      Text('Same signing key as your current app, so it installs over it.', style: T.t(13, w: FontWeight.w600, color: muted, height: 1.3)),
    ]);
  }
}
