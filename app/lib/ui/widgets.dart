import 'package:flutter/material.dart';

import 'fx.dart';
import 'icons.dart';
import 'motion.dart';
import 'theme.dart';

/// Anything pressable: shrinks to 97 % under the finger and springs back (Emil's rule: the interface
/// must feel like it heard you).
/// A canvas-coloured fade under buttons pinned to the bottom of a scrolling screen, so the rows
/// scrolling beneath them don't show through the gaps.
class BottomFade extends StatelessWidget {
  const BottomFade({super.key, required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Mc.of(context).canvas;
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.withValues(alpha: 0), c.withValues(alpha: 0.94), c],
            stops: const [0, 0.5, 1],
          ),
        ),
      ),
    );
  }
}

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = false,
    this.label,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final String? label;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down() {
    if (!widget.enabled) return;
    _c.forward();
  }

  void _up() => _c.reverse();

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    return Semantics(
      button: true,
      enabled: active,
      label: widget.label,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: active ? (_) => _down() : null,
        onTapUp: active ? (_) => _up() : null,
        onTapCancel: active ? _up : null,
        onTap: active
            ? () {
                if (widget.haptic) Fx.i.tap();
                widget.onTap?.call();
              }
            : null,
        onLongPress: active ? widget.onLongPress : null,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_c.value);
            return Transform.scale(scale: 1 - (1 - widget.scale) * t, child: child);
          },
          child: Opacity(opacity: widget.enabled ? 1 : 0.45, child: widget.child),
        ),
      ),
    );
  }
}

/// The dark primary button with a display-font label ("Keep going", "Save & next").
class InkButton extends StatelessWidget {
  const InkButton(this.label, {super.key, this.onTap, this.height = 56, this.size = 24, this.icon, this.enabled = true});

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double size;
  final Widget? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      onTap: onTap,
      enabled: enabled,
      haptic: true,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(16), boxShadow: mc.e2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 8)],
            Flexible(
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: T.d(size, color: mc.canvas)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The soft secondary button ("Back to decks", "Create a deck").
class SoftButton extends StatelessWidget {
  const SoftButton(this.label, {super.key, this.onTap, this.height = 50, this.icon, this.color, this.textColor});

  final String label;
  final VoidCallback? onTap;
  final double height;
  final Widget? icon;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: color ?? mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 8)],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.t(17, w: FontWeight.w600, color: textColor ?? mc.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's switch: 52×32, the knob slides 20px.
class McSwitch extends StatelessWidget {
  const McSwitch({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        onTap: () {
          Fx.i.tap();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: McCurves.paper,
          width: 52,
          height: 32,
          decoration: BoxDecoration(color: value ? mc.ink : mc.offBg, borderRadius: BorderRadius.circular(16)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: McCurves.springy,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(4),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? mc.canvas : mc.knobOff,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control with a sliding ink thumb.
class Seg<V> extends StatelessWidget {
  const Seg({
    super.key,
    required this.options,
    required this.value,
    required this.onPick,
    required this.labelOf,
    this.height = 36,
    this.fontSize = 14,
    this.background,
  });

  final List<V> options;
  final V value;
  final ValueChanged<V> onPick;
  final String Function(V) labelOf;
  final double height;
  final double fontSize;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final index = options.indexOf(value).clamp(0, options.length - 1);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: background ?? mc.well, borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / options.length;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: McCurves.springy,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(9), boxShadow: mc.e1),
                ),
              ),
              Row(
                children: [
                  for (final o in options)
                    Expanded(
                      child: Semantics(
                        selected: o == value,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (o != value) {
                              Fx.i.tap();
                              onPick(o);
                            }
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: T.t(fontSize, w: FontWeight.w700, color: o == value ? mc.canvas : mc.ink),
                              child: Text(labelOf(o), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Uppercase section label ("STUDY", "START HERE").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.size = 13});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: T.caps(size, color: Mc.of(context).muted));
}

/// The grey grip at the top of a sheet.
class Grip extends StatelessWidget {
  const Grip({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(color: Mc.of(context).line, borderRadius: BorderRadius.circular(3)),
        ),
      );
}

/// Header icon button (44×44 hit area).
class IconTap extends StatelessWidget {
  const IconTap({super.key, required this.icon, this.onTap, required this.label, this.size = const Size(28, 36), this.color});

  final String icon;
  final VoidCallback? onTap;
  final String label;
  final Size size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        label: label,
        scale: 0.9,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: McIcon(icon, size: size, color: color ?? Mc.of(context).ink)),
        ),
      );
}

/// A pill chip ("Separator: Tab", category chips).
class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.color, this.textColor, this.dot, this.onTap, this.selected = false, this.height = 30});

  final String text;
  final Color? color;
  final Color? textColor;
  final Color? dot;
  final VoidCallback? onTap;
  final bool selected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final bg = color ?? (selected ? mc.ink : mc.soft);
    final fg = textColor ?? (selected ? mc.canvas : mc.ink);
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height / 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 7),
          ],
          Text(text, style: T.t(14.5, w: FontWeight.w700, color: fg)),
        ],
      ),
    );
    return onTap == null ? child : Pressable(onTap: onTap, haptic: true, child: child);
  }
}

/// Tiles of numbers ("40 reviewed").
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.valueSize = 36});

  final String value;
  final String label;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14), boxShadow: mc.e1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: T.d(valueSize))),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.t(14, w: FontWeight.w600, color: mc.muted)),
        ],
      ),
    );
  }
}

/// A text field in the editor style: 2px line border, 12 radius.
class McField extends StatelessWidget {
  const McField({
    super.key,
    required this.controller,
    this.hint,
    this.display = false,
    this.maxLines = 1,
    this.minLines,
    this.mono = false,
    this.autofocus = false,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.size,
  });

  final TextEditingController controller;
  final String? hint;
  final bool display;
  final int? maxLines;
  final int? minLines;
  final bool mono;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final style = mono
        ? T.mono(size ?? 15, color: mc.ink, w: FontWeight.w500, height: 1.4)
        : display
            ? T.d(size ?? 24, color: mc.ink, height: 1.15)
            : T.t(size ?? 18, w: FontWeight.w600, color: mc.ink, height: 1.3);
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: 2));
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: style,
      cursorColor: mc.ink,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: style.copyWith(color: mc.muted.withValues(alpha: 0.7)),
        filled: true,
        fillColor: mc.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: border(mc.line),
        focusedBorder: border(mc.ink),
        border: border(mc.line),
      ),
    );
  }
}

/// Labelled form row ("Front", "Back").
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, required this.child, this.trailing});
  final String text;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(text, style: T.t(14, w: FontWeight.w700, color: Mc.of(context).muted))),
              ?trailing,
            ],
          ),
          const SizedBox(height: 5),
          child,
        ],
      );
}

/// Fades and lifts children in one after another (30–60 ms apart), once.
class Cascade extends StatefulWidget {
  const Cascade({super.key, required this.index, required this.child, this.delayMs = 45, this.offset = 14, this.baseMs = 0});
  final int index;
  final Widget child;
  final int delayMs;
  final double offset;
  final int baseMs;

  @override
  State<Cascade> createState() => _CascadeState();
}

class _CascadeState extends State<Cascade> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    final delay = widget.baseMs + widget.index.clamp(0, 12) * widget.delayMs;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionPrefs.reducedOf(context)) {
      return FadeTransition(opacity: _c, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = McCurves.out.transform(_c.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, widget.offset * (1 - t)), child: child),
        );
      },
      child: widget.child,
    );
  }
}
