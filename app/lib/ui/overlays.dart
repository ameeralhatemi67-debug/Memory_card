import 'dart:async';

import 'package:flutter/material.dart';

import 'fx.dart';
import 'icons.dart';
import 'motion.dart';
import 'textures.dart';
import 'theme.dart';
import 'widgets.dart';

// ------------------------------------------------------------------ toasts

class ToastData {
  ToastData(this.text, {this.action, this.actionLabel = 'Undo', this.icon}) : id = DateTime.now().microsecondsSinceEpoch;
  final String text;
  final VoidCallback? action;
  final String actionLabel;
  final String? icon;
  final int id;
}

/// One toast at a time, above the nav bar. Undo toasts stay 3.6 s, plain ones 2 s.
class Toaster {
  Toaster._();
  static final i = Toaster._();

  final ValueNotifier<ToastData?> current = ValueNotifier(null);
  Timer? _timer;

  void show(String text, {VoidCallback? undo, String actionLabel = 'Undo', Duration? duration, String? icon}) {
    _timer?.cancel();
    current.value = ToastData(text, action: undo, actionLabel: actionLabel, icon: icon);
    _timer = Timer(duration ?? Duration(milliseconds: undo != null ? 3600 : 2000), hide);
  }

  void hide() {
    _timer?.cancel();
    current.value = null;
  }
}

class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.bottom});
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ToastData?>(
      valueListenable: Toaster.i.current,
      builder: (context, t, _) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: IgnorePointer(
            ignoring: t == null,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                reverseDuration: const Duration(milliseconds: 160),
                switchInCurve: McCurves.out,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.45), end: Offset.zero).animate(anim),
                    child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(anim), child: child),
                  ),
                ),
                child: t == null ? const SizedBox.shrink(key: ValueKey('none')) : _Toast(key: ValueKey(t.id), data: t),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({super.key, required this.data});
  final ToastData data;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 100) Toaster.i.hide();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: EdgeInsets.fromLTRB(16, 5, data.action != null ? 5 : 16, 5),
        decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(19), boxShadow: mc.e2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.icon != null) ...[McIcon(data.icon!, size: const Size(16, 16), color: mc.canvas), const SizedBox(width: 8)],
            Flexible(
              child: Text(data.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: T.t(15, w: FontWeight.w700, color: mc.canvas)),
            ),
            if (data.action != null) ...[
              const SizedBox(width: 10),
              Pressable(
                haptic: true,
                onTap: () {
                  final a = data.action!;
                  Toaster.i.hide();
                  Fx.i.undo();
                  a();
                },
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: mc.canvas, borderRadius: BorderRadius.circular(14)),
                  child: Text(data.actionLabel, style: T.t(14, w: FontWeight.w700, color: mc.ink)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ sheets

/// A bottom sheet in the design's style: dims the screen, rounded 26px top, grip, drag down to close.
Future<R?> showMcSheet<R>(BuildContext context, {required WidgetBuilder builder, double top = 96, bool expand = true}) {
  Fx.i.whoosh();
  return Navigator.of(context, rootNavigator: true).push<R>(_SheetRoute<R>(builder: builder, top: top, expand: expand));
}

class _SheetRoute<R> extends PopupRoute<R> {
  _SheetRoute({required this.builder, required this.top, required this.expand});

  final WidgetBuilder builder;
  final double top;
  final bool expand;

  @override
  Color? get barrierColor => const Color(0x8C141414);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _SheetFrame(route: this, top: top, expand: expand, child: Builder(builder: builder));
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: McCurves.drawer, reverseCurve: Curves.easeInCubic);
    return SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved), child: child);
  }
}

class _SheetFrame extends StatefulWidget {
  const _SheetFrame({required this.route, required this.top, required this.expand, required this.child});
  final _SheetRoute route;
  final double top;
  final bool expand;
  final Widget child;

  @override
  State<_SheetFrame> createState() => _SheetFrameState();
}

class _SheetFrameState extends State<_SheetFrame> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final sheet = Container(
      decoration: BoxDecoration(
        color: mc.canvas,
        image: texImage(context, 'sheets'),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: mc.sheet,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(0, 2000)),
            onVerticalDragEnd: (d) {
              if (_drag > 110 || (d.primaryVelocity ?? 0) > 700) {
                Navigator.of(context).pop();
              } else {
                setState(() => _drag = 0);
              }
            },
            child: const Padding(padding: EdgeInsets.only(top: 10, bottom: 8), child: Grip()),
          ),
          if (widget.expand) Expanded(child: widget.child) else Flexible(child: widget.child),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: widget.expand ? mq.padding.top + widget.top - 24 : 0, bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: _drag == 0 ? const Duration(milliseconds: 280) : Duration.zero,
          curve: McCurves.springy,
          transform: Matrix4.translationValues(0, _drag, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(type: MaterialType.transparency, child: sheet),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ dialogs

/// A centred dialog card that scales up from 92 % (never from 0).
Future<R?> showMcDialog<R>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return Navigator.of(context, rootNavigator: true).push<R>(PageRouteBuilder<R>(
    opaque: false,
    barrierDismissible: dismissible,
    barrierColor: const Color(0x99141414),
    barrierLabel: 'Close',
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, a, b) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(type: MaterialType.transparency, child: Builder(builder: builder)),
          ),
        ),
      ),
    ),
    transitionsBuilder: (context, a, b, child) {
      final c = CurvedAnimation(parent: a, curve: McCurves.springy, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(c), child: child),
      );
    },
  ));
}

/// The dialog card itself.
class DialogCard extends StatelessWidget {
  const DialogCard({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 22)});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: mc.canvas,
        image: texImage(context, 'sheets'),
        borderRadius: BorderRadius.circular(22),
        boxShadow: mc.e3,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// A two-button question ("Delete this deck?").
Future<bool> confirm(BuildContext context,
    {required String title, required String message, String yes = 'Delete', String no = 'Keep', bool danger = true}) async {
  final mc = Mc.of(context);
  final r = await showMcDialog<bool>(
    context,
    builder: (ctx) => DialogCard(children: [
      Text(title, textAlign: TextAlign.center, style: T.d(30, color: mc.ink, height: 1.05)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: T.t(16, color: mc.muted, height: 1.35)),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: SoftButton(no, height: 50, onTap: () => Navigator.pop(ctx, false))),
        const SizedBox(width: 10),
        Expanded(
          child: Pressable(
            haptic: true,
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: danger ? Mc.delete : mc.ink, borderRadius: BorderRadius.circular(16), boxShadow: mc.e2),
              child: Text(yes, style: T.t(17, w: FontWeight.w700, color: danger ? Mc.graphite : mc.canvas)),
            ),
          ),
        ),
      ]),
    ]),
  );
  return r ?? false;
}

/// Asks for a name ("Name the folder").
Future<String?> promptText(BuildContext context, {required String title, String initial = '', String hint = '', String action = 'Save'}) {
  final mc = Mc.of(context);
  final ctrl = TextEditingController(text: initial)..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  return showMcDialog<String>(
    context,
    builder: (ctx) => DialogCard(children: [
      Text(title, textAlign: TextAlign.center, style: T.d(30, color: mc.ink)),
      const SizedBox(height: 16),
      McField(
        controller: ctrl,
        hint: hint,
        display: true,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(ctx, v.trim().isEmpty ? null : v.trim()),
      ),
      const SizedBox(height: 16),
      InkButton(action, height: 52, onTap: () {
        final v = ctrl.text.trim();
        Navigator.pop(ctx, v.isEmpty ? null : v);
      }),
    ]),
  );
}

// ------------------------------------------------------------------ menus

class MenuItemData {
  const MenuItemData(this.label, this.onTap, {this.hint, this.icon, this.danger = false, this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final String? hint;
  final String? icon;
  final bool danger;
  final bool enabled;
}

/// A popover menu that grows from the ⋮ button (origin-aware, top-right).
Future<void> showMcMenu(BuildContext context, List<MenuItemData> items, {double top = 64, double right = 14}) {
  final mc = Mc.of(context);
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    opaque: false,
    barrierDismissible: true,
    barrierColor: const Color(0x33000000),
    barrierLabel: 'Close menu',
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (ctx, a, b) {
      final pad = MediaQuery.of(ctx).padding.top;
      return Stack(children: [
        Positioned(
          top: pad + top,
          right: right,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 250,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: mc.canvas, borderRadius: BorderRadius.circular(18), boxShadow: mc.e3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final it in items)
                    Pressable(
                      enabled: it.enabled,
                      onTap: () {
                        Navigator.pop(ctx);
                        Fx.i.tap();
                        it.onTap();
                      },
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          if (it.icon != null) ...[
                            McIcon(it.icon!, size: const Size(19, 19), color: it.danger ? Mc.red : mc.ink),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(it.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.t(16, w: FontWeight.w600, color: it.danger ? Mc.red : mc.ink)),
                          ),
                          if (it.hint != null) Text(it.hint!, style: T.t(14, w: FontWeight.w600, color: mc.muted)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ]);
    },
    transitionsBuilder: (ctx, a, b, child) {
      final c = CurvedAnimation(parent: a, curve: McCurves.out, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: c,
        child: ScaleTransition(alignment: Alignment.topRight, scale: Tween(begin: 0.9, end: 1.0).animate(c), child: child),
      );
    },
  ));
}
