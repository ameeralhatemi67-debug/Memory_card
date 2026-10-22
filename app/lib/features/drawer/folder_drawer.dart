import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/shapes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../settings/settings_screen.dart';
import '../shell/shell.dart';

// Motion from text_Mockup §2, replayed by a clock (canvas Drawer.dc.html).
const _pillUp = Keyframes(450, [
  [0, 90, 0],
  [0.6, -10, 1],
  [0.85, 2, 1],
  [1, 0, 1],
]);
const _pillDown = Keyframes(450, [
  [0, 0, 1],
  [0.3, -4, 1],
  [0.7, 65, 0.7],
  [1, 110, 0],
]);
const _pillJump = Keyframes(400, [
  [0, 0, 1],
  [0.4, -12, 1],
  [0.75, -2, 1],
  [1, 0, 1],
]);
const _folderIn = Keyframes(600, [
  [0, -381, -5, 0],
  [0.6, 14, 1, 1],
  [0.82, -3, -0.3, 1],
  [1, 0, 0, 1],
]);
const _bounce = Keyframes(450, [
  [0, 0, 1],
  [0.35, -9, 1.012],
  [0.7, 2, 0.996],
  [1, 0, 1],
]);
const _excite = Keyframes(600, [
  [0, 0, 1],
  [0.3, -7, 1.01],
  [0.6, 2, 1],
  [1, 0, 1],
]);
const _recoil = Keyframes(400, [
  [0, 0, 0, 1, 1],
  [0.35, -6, -4, 1.1, 0.9],
  [1, 0, 60, 0.4, 0],
]);

const _tabColors = [
  [Mc.blue, Mc.peach, Mc.red],
  [Mc.peach, Mc.red, Mc.blue],
  [Mc.red, Mc.blue, Mc.peach],
];

const _top = 84.0;
const _step = 65.0;
const _folderH = 175.0;
const _span = 36.0;

class _Anim {
  _Anim(this.keys, this.t);
  final Keyframes keys;
  final double t;
}

/// The folder drawer (canvas Drawer.dc.html): stacked paper folders with their tab heads, the last three
/// you touched showing their decks as pills peeking out of the pocket.
class FolderDrawer extends StatefulWidget {
  const FolderDrawer({super.key, required this.open, required this.onClose});
  final bool open;
  final VoidCallback onClose;

  @override
  State<FolderDrawer> createState() => _FolderDrawerState();
}

class _FolderDrawerState extends State<FolderDrawer> with TickerProviderStateMixin {
  late final AnimationController _panel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 260),
  );
  late final Ticker _ticker = createTicker((d) => setState(() => _now = d.inMicroseconds / 1000));
  double _now = 0;
  double _t0 = 0;
  final Map<String, _Anim> _pillAnim = {};
  final Map<String, _Anim> _folderAnim = {};
  double _exciteT = -1e9;
  bool _fear = false;
  String? _floating;
  String? _deleting;
  String? _pressed;
  String? _exitFolder;
  Timer? _hold;
  Offset? _downAt;
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(FolderDrawer old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) {
      _fear = false;
      if (!_ticker.isActive) {
        _now = 0;
        _ticker.start();
      }
      _t0 = _now;
      _exciteT = -1e9;
      _pillAnim.clear();
      _folderAnim.clear();
      _panel.forward();
    } else if (!widget.open && old.open) {
      _panel.reverse().whenComplete(() {
        if (!widget.open && _ticker.isActive) _ticker.stop();
      });
    }
  }

  @override
  void dispose() {
    _panel.dispose();
    _ticker.dispose();
    _hold?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ---- actions ----

  void _select(AppStore store, Folder f) {
    final recent = store.data.recentFolders;
    _folderAnim[f.id] = _Anim(_bounce, _now);
    if (recent.isNotEmpty && recent.first == f.id) {
      // Second tap on the open folder: go to its decks.
      _pillAnim[f.id] = _Anim(_pillJump, _now);
      Fx.i.pop();
      store.touchFolder(f.id);
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted) Shell.of(context).goHome();
      });
      return;
    }
    final next = [f.id, ...recent.where((x) => x != f.id)];
    final dropped = next.length > 3 ? next[3] : null;
    _pillAnim[f.id] = _Anim(_pillUp, _now);
    if (dropped != null) {
      _pillAnim[dropped] = _Anim(_pillDown, _now);
      _exitFolder = dropped;
      Future.delayed(const Duration(milliseconds: 620), () {
        if (mounted) setState(() => _exitFolder = null);
      });
    }
    Fx.i.pop();
    store.touchFolder(f.id);
  }

  void _delete(AppStore store, Folder f) {
    _folderAnim[f.id] = _Anim(_recoil, _now);
    setState(() => _deleting = f.id);
    Fx.i.missed();
    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      final n = f.deckIds.length;
      final undo = store.deleteFolder(f.id);
      setState(() => _deleting = null);
      Toaster.i.show('Deleted ${f.name}${n > 0 ? ' · $n ${n == 1 ? 'deck' : 'decks'}' : ''}',
          undo: undo, duration: Duration(milliseconds: n > 0 ? 6000 : 3600));
    });
  }

  Future<void> _newFolder(AppStore store) async {
    final name = await promptText(context, title: 'Name the folder', initial: 'New folder', action: 'Create');
    if (name == null || !mounted) return;
    final f = store.createFolder(name);
    _exciteT = _now;
    _fear = false;
    Fx.i.pop();
    store.touchFolder(f.id);
    _pillAnim[f.id] = _Anim(_pillUp, _now);
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: McCurves.out);
  }

  void _down(PointerDownEvent e, AppStore store, Folder f) {
    if (_deleting != null) return;
    _hold?.cancel();
    _pressed = f.id;
    _downAt = e.position;
    if (_fear) return;
    _hold = Timer(const Duration(milliseconds: 350), () {
      Fx.i.tap();
      setState(() => _floating = f.id);
    });
  }

  void _move(PointerMoveEvent e, AppStore store, double panelTop) {
    if (_floating == null) {
      if (_downAt != null && (e.position - _downAt!).distance > 8) {
        _hold?.cancel();
        _pressed = null;
      }
      return;
    }
    final scrollY = _scroll.hasClients ? _scroll.offset : 0.0;
    final y = e.position.dy - panelTop + scrollY - _top;
    final list = store.data.folders;
    final from = list.indexWhere((f) => f.id == _floating);
    final to = ((y + 20) / _step).floor().clamp(0, list.length - 1);
    if (from >= 0 && to != from) {
      Fx.i.tap();
      store.moveFolder(from, to);
    }
  }

  void _up(AppStore store) {
    _hold?.cancel();
    _pressed = null;
    if (_floating != null) {
      setState(() => _floating = null);
      Toaster.i.show('New order saved');
    }
  }

  // ---- motion ----

  ({double x, double y, double rot, double sc, double op}) _folderMotion(Folder f, int i) {
    var x = 0.0, y = 0.0, rot = 0.0, sc = 1.0, op = 1.0;
    final fa = _folderAnim[f.id];
    final sinceOpen = _now - _t0;
    if (_deleting == f.id && fa != null && fa.keys == _recoil) {
      final v = _recoil.sample(_now - fa.t);
      x = v[0];
      y = v[1];
      sc = v[2];
      op = v[3];
    } else if (_floating == f.id) {
      final w = (1 - math.cos(_now / 1700 * math.pi * 2)) / 2;
      sc = 1 + 0.03 * w;
      y = -6 - 3 * w;
    } else if (_fear) {
      final ph = _now / 350 * math.pi + i * 0.9;
      x = 2 * math.sin(ph);
      y = math.sin(ph * 1.3 + 1);
      rot = 2.6 * math.sin(ph + 0.4) - 0.6;
    } else if (_now - _exciteT < _excite.ms + i * 35) {
      final v = _excite.sample(_now - _exciteT - i * 35);
      y = v[0];
      sc = v[1];
    } else if (fa != null && fa.keys == _bounce && _now - fa.t < _bounce.ms) {
      final v = _bounce.sample(_now - fa.t);
      y = v[0];
      sc = v[1];
    } else if (sinceOpen < _folderIn.ms + i * 55) {
      final v = _folderIn.sample(sinceOpen - i * 55);
      x = v[0];
      rot = v[1];
      op = v[2];
    }
    if (_pressed == f.id && _floating == null && !_fear) sc *= 0.985;
    return (x: x, y: y, rot: rot, sc: sc, op: op);
  }

  ({double y, double op}) _pillMotion(Folder f, int i, int k, bool reduced) {
    if (reduced) return (y: 0, op: 1);
    final pa = _pillAnim[f.id];
    final sinceOpen = _now - _t0;
    var y = 0.0, op = 1.0;
    if (pa != null && _now - pa.t < pa.keys.ms + 120) {
      final v = pa.keys.sample(_now - pa.t - k * 40);
      y = v[0];
      op = v[1];
    } else if (sinceOpen < 360 + i * 55 + k * 45 + _pillUp.ms) {
      final v = _pillUp.sample(sinceOpen - (360 + i * 55 + k * 45));
      y = v[0];
      op = v[1];
    } else if (!_fear && _floating == null) {
      y = -2.5 * (1 - math.cos(_now / 2800 * math.pi * 2 + i * 0.95 + k * 0.6));
    }
    return (y: y, op: op);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final reduced = MotionPrefs.reducedOf(context);
    return AnimatedBuilder(
      animation: _panel,
      builder: (context, _) {
        if (_panel.isDismissed) return const SizedBox.shrink();
        final t = McCurves.drawer.transform(_panel.value);
        final panelW = math.min(340.0, mq.size.width - 50);
        final panelTop = mq.padding.top + 64;
        final folders = store.data.folders;
        final recent = store.data.recentFolders;
        final contentH = _top + folders.length * _step + _folderH + 240;
        return Stack(
          children: [
            // Backdrop: the deck list, greyed, with the logo and menu in the backdrop ink.
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                onHorizontalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < -300) widget.onClose();
                },
                child: Opacity(
                  opacity: t,
                  child: ColoredBox(
                    color: mc.backdrop,
                    child: Stack(children: [
                      Positioned(
                        left: 22,
                        top: mq.padding.top + 20,
                        child: McIcon(McIcons.logo, size: const Size(28, 36), color: mc.backdropInk),
                      ),
                      Positioned(
                        right: 22,
                        top: mq.padding.top + 26,
                        child: McIcon(McIcons.dots, size: const Size(8, 26), color: mc.backdropInk),
                      ),
                      for (var i = 0; i < 7; i++)
                        Positioned(
                          left: panelW - 40,
                          top: mq.padding.top + 88 + i * 84.0,
                          child: Container(
                            width: 160,
                            height: 72,
                            decoration: BoxDecoration(color: mc.backdropBar, borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
            // The panel.
            Positioned(
              left: 0,
              top: panelTop,
              bottom: 0,
              width: panelW,
              child: Transform.translate(
                offset: Offset(-panelW * (1 - t) - 30 * (1 - t), 0),
                child: Listener(
                  onPointerMove: (e) => _move(e, store, panelTop),
                  onPointerUp: (_) => _up(store),
                  onPointerCancel: (_) => _up(store),
                  child: Container(
                    decoration: BoxDecoration(
                      color: mc.canvas,
                      image: texImage(context, 'sheets'),
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(24)),
                      boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 24, offset: Offset(8, 0))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: SingleChildScrollView(
                            controller: _scroll,
                            physics: _floating != null ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                            child: SizedBox(
                              height: math.max(contentH, mq.size.height - panelTop),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (var i = 0; i < folders.length; i++)
                                    _folder(context, store, folders[i], i, recent, panelW, reduced),
                                  if (folders.isEmpty)
                                    Positioned(
                                      left: 24,
                                      right: 24,
                                      top: 160,
                                      child: Column(children: [
                                        Text('Empty mind', style: T.d(40, color: mc.ink)),
                                        const SizedBox(height: 8),
                                        Text('Make a folder to start.', style: T.t(16, w: FontWeight.w500, color: mc.muted)),
                                      ]),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          top: 16,
                          child: Pressable(
                            label: 'Settings',
                            scale: 0.9,
                            onTap: () {
                              widget.onClose();
                              Navigator.of(context, rootNavigator: true).push(SettingsScreen.route());
                            },
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(child: McIcon(McIcons.gear, size: const Size(30, 34), color: mc.ink)),
                            ),
                          ),
                        ),
                        // Fade above the buttons.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 220,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [mc.canvasClear, mc.canvas],
                                  stops: const [0, 0.7],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          bottom: 32 + mq.padding.bottom,
                          child: Pressable(
                            haptic: true,
                            onTap: () => setState(() => _fear = !_fear),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(color: _fear ? Mc.delete : mc.soft, borderRadius: BorderRadius.circular(22)),
                              child: Row(children: [
                                McIcon(McIcons.x, size: const Size(13, 13), color: _fear ? Mc.graphite : mc.ink),
                                const SizedBox(width: 8),
                                Text(_fear ? 'Done' : 'Delete',
                                    style: T.t(15, w: FontWeight.w700, color: _fear ? Mc.graphite : mc.ink)),
                              ]),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 22,
                          bottom: 26 + mq.padding.bottom,
                          child: Pressable(
                            label: 'New folder',
                            haptic: true,
                            onTap: () => _newFolder(store),
                            child: McIcon(McIcons.newFolder, size: const Size(76, 56), color: mc.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _folder(BuildContext context, AppStore store, Folder f, int i, List<String> recent, double w, bool reduced) {
    final mc = Mc.of(context);
    final tw = math.min(FolderShape.tabWidth(f.name), w - 110);
    final sh = folderShade(i, mc.dark);
    final m = reduced ? (x: 0.0, y: 0.0, rot: 0.0, sc: 1.0, op: 1.0) : _folderMotion(f, i);
    final showPills = recent.contains(f.id) || _exitFolder == f.id;
    final isOpen = !_fear && recent.isNotEmpty && recent.first == f.id;
    final decks = store.decksIn(f).take(3).toList();
    final floating = _floating == f.id;
    final count = '${f.deckIds.length} ${f.deckIds.length == 1 ? 'deck' : 'decks'}';
    return Positioned(
      key: ValueKey(f.id),
      left: 0,
      top: _top + i * _step,
      width: w,
      height: _folderH,
      child: Transform.translate(
        offset: Offset(m.x, m.y),
        child: Transform.rotate(
          angle: m.rot * math.pi / 180,
          alignment: const Alignment(0, -0.4),
          child: Transform.scale(
            scale: m.sc,
            child: Opacity(
              opacity: m.op.clamp(0.0, 1.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (showPills)
                    for (var k = 0; k < decks.length; k++)
                      Builder(builder: (context) {
                        final pm = _pillMotion(f, i, k, reduced);
                        return Positioned(
                          left: tw + _span - 16 + k * 53,
                          top: 15 + pm.y,
                          child: Opacity(
                            opacity: pm.op.clamp(0.0, 1.0),
                            child: Pressable(
                              label: 'Study ${decks[k].name}',
                              onTap: () => Shell.of(context).study(decks[k].id),
                              child: Container(
                                width: 65,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: _tabColors[i % 3][k],
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(decks[k].monogram,
                                    maxLines: 1, overflow: TextOverflow.clip, style: T.d(16, color: Mc.graphite)),
                              ),
                            ),
                          ),
                        );
                      }),
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: (e) => _down(e, store, f),
                      child: GestureDetector(
                        onTap: () {
                          if (_deleting != null) return;
                          if (_fear) {
                            _delete(store, f);
                          } else if (_floating == null) {
                            _select(store, f);
                          }
                        },
                        child: CustomPaint(
                          painter: _FolderHit(
                            tabWidth: tw,
                            painter: FolderPainter(tabWidth: tw, c1: sh.c1, c2: sh.c2, shadowAlpha: mc.folderShadow, lifted: floating),
                          ),
                          // Kraft (or the chosen texture) inside the folder's outline.
                          foregroundPainter: texPainter(context, 'folders', (s) => FolderShape.path(s.width, s.height, tw)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 26,
                    top: 6,
                    height: 42,
                    width: tw - 10,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.d(26, color: sh.text)),
                      ),
                    ),
                  ),
                  if (isOpen)
                    Positioned(
                      right: 16,
                      top: 54,
                      child: Pressable(
                        onTap: () {
                          store.touchFolder(f.id);
                          Shell.of(context).goHome();
                        },
                        child: Row(children: [
                          Text('Open $count', style: T.t(14, w: FontWeight.w700, color: sh.text)),
                          const SizedBox(width: 4),
                          Text('›', style: T.t(16, w: FontWeight.w700, color: sh.text)),
                        ]),
                      ),
                    )
                  else if (!_fear)
                    Positioned(
                      right: 18,
                      top: 56,
                      child: IgnorePointer(child: Text(count, style: T.t(13, w: FontWeight.w600, color: sh.meta))),
                    ),
                  if (_fear)
                    Positioned(
                      right: 16,
                      top: 49,
                      child: IgnorePointer(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(color: Mc.delete, shape: BoxShape.circle),
                          child: Center(child: McIcon(McIcons.x, size: const Size(11, 11), color: Mc.graphite)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the folder and hit-tests on its real silhouette, so the pills and the folder above stay tappable.
class _FolderHit extends CustomPainter {
  _FolderHit({required this.tabWidth, required this.painter});
  final double tabWidth;
  final FolderPainter painter;

  Size _size = const Size(340, _folderH);

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    painter.paint(canvas, size);
  }

  @override
  bool? hitTest(Offset position) => FolderShape.path(_size.width, _size.height, tabWidth).contains(position);

  @override
  bool shouldRepaint(_FolderHit old) => painter.shouldRepaint(old.painter) || old.tabWidth != tabWidth;
}
