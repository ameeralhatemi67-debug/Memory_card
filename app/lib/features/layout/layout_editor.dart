import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/card_layout.dart';
import '../../services/image_ingest.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/routes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'layout_face.dart';
import 'pick_picture.dart';

/// What the layout editor hands back. A null layout means "plain text card" (nothing to store).
class LayoutResult {
  const LayoutResult(this.layout);
  final SideLayout? layout;
}

/// Opens the full-screen layout editor for one side of a card. Returns null when cancelled.
Future<LayoutResult?> showLayoutEditor(
  BuildContext context, {
  required bool back,
  required SideLayout? initial,
  required TextEditingController main,
  required TextEditingController example,
  required TextEditingController hook,
  required String label,
  bool code = false,
  String? legacyPicture,
}) {
  return Navigator.of(context, rootNavigator: true).push<LayoutResult>(McPageRoute(
    builder: (_) => LayoutEditorScreen(
      back: back,
      initial: initial,
      main: main,
      example: example,
      hook: hook,
      label: label,
      code: code,
      legacyPicture: legacyPicture,
    ),
  ));
}

enum _Drag { none, move, resize, pan }

/// Arrange one side of a card: pick a guided layout (structured) or place every picture and text
/// yourself (free canvas): move, resize, crop, zoom, restyle.
class LayoutEditorScreen extends StatefulWidget {
  const LayoutEditorScreen({
    super.key,
    required this.back,
    required this.initial,
    required this.main,
    required this.example,
    required this.hook,
    required this.label,
    this.code = false,
    this.legacyPicture,
  });

  final bool back;
  final SideLayout? initial;
  final TextEditingController main;
  final TextEditingController example;
  final TextEditingController hook;
  final String label;
  final bool code;
  final String? legacyPicture;

  @override
  State<LayoutEditorScreen> createState() => _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends State<LayoutEditorScreen> {
  static const _faceAspect = 276 / 384;

  late SideLayout _l;
  String? _sel;
  bool _crop = false;
  bool _lockShape = true;
  final List<String> _undo = [];

  // Gesture state.
  _Drag _drag = _Drag.none;
  int? _handle;
  Rect _start = Rect.zero;
  Offset _raw = Offset.zero;
  double _startZoom = 1;
  double _startSize = 0;
  Offset _grab = Offset.zero;
  double? _guideX, _guideY;
  bool _snappedX = false, _snappedY = false;

  bool get _canvas => _l.mode == LayoutMode.canvas;
  LayoutEl? get _selected => _sel == null ? null : _l.els.where((e) => e.id == _sel).firstOrNull;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _l = init.copy();
    } else if (widget.legacyPicture != null && widget.legacyPicture!.isNotEmpty) {
      _l = SideLayout.forPicture(Tpl.below, back: widget.back, src: widget.legacyPicture!, blur: widget.back);
    } else {
      _l = SideLayout.template(Tpl.text, back: widget.back);
    }
    for (final e in [widget.main, widget.example, widget.hook]) {
      e.addListener(_textChanged);
    }
    _measureMissing();
  }

  @override
  void dispose() {
    for (final e in [widget.main, widget.example, widget.hook]) {
      e.removeListener(_textChanged);
    }
    super.dispose();
  }

  void _textChanged() {
    if (mounted) setState(() {});
  }

  /// Pictures made before shapes were stored get measured once so panning feels right.
  Future<void> _measureMissing() async {
    for (final img in _l.images.where((i) => i.aspect <= 0).toList()) {
      final a = await measureAspect(img.src);
      if (a != null && mounted) setState(() => img.aspect = a);
    }
  }

  // ------------------------------------------------------------------ undo & edits

  String _snapshot() => jsonEncode(_l.toJson());

  void _pushUndo() {
    _undo.add(_snapshot());
    if (_undo.length > 40) _undo.removeAt(0);
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    final back = SideLayout.fromJson(jsonDecode(_undo.removeLast()));
    if (back == null) return;
    Fx.i.undo();
    setState(() {
      _l = back;
      if (_selected == null) _sel = null;
    });
  }

  void _edit(VoidCallback change) {
    _pushUndo();
    setState(change);
  }

  LayoutTexts get _texts => LayoutTexts(
        main: widget.main.text,
        example: widget.example.text,
        hook: widget.hook.text,
        code: widget.code,
      );

  // ------------------------------------------------------------------ pictures

  Future<void> _addPicture() async {
    final p = await pickPicture(context);
    if (p == null || !mounted) return;
    _edit(() {
      if (_canvas) {
        final el = _l.dropImage(src: p.src, aspect: p.aspect, alpha: p.alpha, faceAspect: _faceAspect);
        el.blur = widget.back;
        _sel = el.id;
      } else {
        _applyStructuredPicture(p);
      }
    });
  }

  /// Structured mode: the picture goes into the template's slot (a picture template if there is none yet).
  void _applyStructuredPicture(PickedImage p) {
    final tpl = _l.tpl == Tpl.text ? Tpl.below : _l.tpl;
    final contain = tpl == Tpl.only || p.alpha;
    final img = ImageEl(
      x: 0,
      y: 0,
      w: 1,
      h: 1,
      src: p.src,
      aspect: p.aspect,
      alpha: p.alpha,
      contain: contain,
      blur: widget.back,
      plate: '',
      outline: tpl == Tpl.only,
    );
    final next = SideLayout.template(tpl, back: widget.back, image: img, keepTexts: _l.texts.where((t) => !t.isCustom).toList());
    _l.els
      ..clear()
      ..addAll(next.els);
    _l.tpl = tpl;
    _sel = _l.firstImage?.id;
  }

  Future<void> _replacePicture(ImageEl el) async {
    final p = await pickPicture(context);
    if (p == null || !mounted) return;
    _edit(() {
      el
        ..src = p.src
        ..aspect = p.aspect
        ..alpha = p.alpha
        ..zoom = 1
        ..panX = 0.5
        ..panY = 0.5;
    });
  }

  void _removeElement(LayoutEl el) {
    _edit(() {
      if (_canvas) {
        _l.els.remove(el);
        _sel = null;
      } else if (el is ImageEl) {
        _l.applyTemplate(Tpl.text, back: widget.back);
        _sel = null;
      }
    });
  }

  Future<void> _chooseTemplate(Tpl t) async {
    if (t == _l.tpl) return;
    if (t != Tpl.text && !_l.hasImage) {
      final p = await pickPicture(context);
      if (p == null || !mounted) return;
      _edit(() {
        _l.tpl = t;
        _applyStructuredPicture(p);
      });
      return;
    }
    _edit(() {
      _l.applyTemplate(t, back: widget.back);
      _sel = _l.firstImage?.id;
    });
  }

  void _setMode(LayoutMode m) {
    if (m == _l.mode) return;
    _edit(() {
      if (m == LayoutMode.canvas) {
        _l.mode = m;
      } else {
        // Back to the guided layout: re-place everything from the template.
        _l.mode = m;
        final keepCustom = _l.texts.where((t) => t.isCustom).length;
        _l.applyTemplate(_l.tpl, back: widget.back);
        if (keepCustom > 0) Toaster.i.show('Extra text boxes were dropped');
      }
      _sel = _l.firstImage?.id;
      _crop = false;
    });
  }

  // ------------------------------------------------------------------ text

  Future<void> _editText(TextEl el) async {
    final controller = switch (el.source) {
      'main' => widget.main,
      'example' => widget.example,
      'hook' => widget.hook,
      _ => TextEditingController(text: el.text),
    };
    final title = switch (el.source) {
      'main' => widget.back ? 'The answer' : 'The prompt',
      'example' => 'Hint',
      'hook' => 'Memory hook',
      _ => 'Your text',
    };
    final mc = Mc.of(context);
    final ctrl = TextEditingController(text: controller.text);
    final saved = await showMcDialog<String>(
      context,
      builder: (ctx) => DialogCard(children: [
        Text(title, textAlign: TextAlign.center, style: T.d(30, color: mc.ink)),
        const SizedBox(height: 14),
        McField(controller: ctrl, autofocus: true, maxLines: 5, minLines: 2, display: el.source == 'main'),
        const SizedBox(height: 16),
        InkButton('Save', height: 52, onTap: () => Navigator.pop(ctx, ctrl.text)),
      ]),
    );
    if (saved == null || !mounted) return;
    if (el.isCustom) {
      _edit(() => el.text = saved);
    } else {
      controller.text = saved;
      if (saved.trim().isNotEmpty && !el.visible) _edit(() => el.visible = true);
    }
  }

  // ------------------------------------------------------------------ gestures

  Rect _rect(LayoutEl e, Size face) => Rect.fromLTWH(e.x * face.width, e.y * face.height, e.w * face.width, e.h * face.height);

  bool _drawn(LayoutEl e) => e is ImageEl || (e is TextEl && e.visible && _textOf(e).trim().isNotEmpty);

  String _textOf(TextEl e) => switch (e.source) {
        'main' => widget.main.text,
        'example' => widget.example.text,
        'hook' => widget.hook.text,
        _ => e.text,
      };

  /// Where the whole picture lies, in face pixels, once its fit, zoom and pan are applied. It mirrors how
  /// the frame draws it: fitted into the frame, then scaled about the pan point.
  Rect? _pictureRect(ImageEl el, Size face) {
    if (el.aspect <= 0) return null;
    final fw = el.w * face.width, fh = el.h * face.height;
    final frameWider = fw / fh > el.aspect;
    final double bw, bh;
    if (el.contain == frameWider) {
      bh = fh;
      bw = fh * el.aspect;
    } else {
      bw = fw;
      bh = fw / el.aspect;
    }
    final offX = (fw - bw) * el.panX, offY = (fh - bh) * el.panY;
    final ptX = el.panX * fw, ptY = el.panY * fh;
    final z = el.zoom;
    return Rect.fromLTWH(
      el.x * face.width + ptX + (offX - ptX) * z,
      el.y * face.height + ptY + (offY - ptY) * z,
      bw * z,
      bh * z,
    );
  }

  /// 0 top-left · 1 top-right · 2 bottom-left · 3 bottom-right
  int? _handleAt(Offset p, Rect r) {
    final corners = [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight];
    for (var i = 0; i < 4; i++) {
      if ((corners[i] - p).distance <= 26) return i;
    }
    return null;
  }

  int _pointers = 0;

  void _touchDown(Offset p, Size face) {
    _handle = null;
    final sel = _selected;
    if (_canvas && sel != null) {
      final h = _handleAt(p, _rect(sel, face));
      if (h != null) {
        _handle = h;
        return;
      }
    }
    if (!_canvas) {
      final img = _l.firstImage;
      setState(() => _sel = img != null && _rect(img, face).contains(p) ? img.id : null);
      return;
    }
    LayoutEl? hit;
    for (final e in _l.els.reversed) {
      if (_drawn(e) && _rect(e, face).inflate(4).contains(p)) {
        hit = e;
        break;
      }
    }
    setState(() {
      _sel = hit?.id;
      if (hit is! ImageEl) _crop = false;
    });
  }

  void _onScaleStart(ScaleStartDetails d, Size face) {
    final el = _selected;
    _guideX = _guideY = null;
    _snappedX = _snappedY = false;
    if (el == null) {
      _drag = _Drag.none;
      return;
    }
    _pushUndo();
    _start = Rect.fromLTWH(el.x, el.y, el.w, el.h);
    _raw = _start.topLeft;
    _grab = Offset.zero;
    _startZoom = el is ImageEl ? el.zoom : 1;
    _startSize = el is TextEl ? (el.size == 0 ? termSize(_textOf(el), false) : el.size) : 0;
    if (_handle != null && _canvas) {
      _drag = _Drag.resize;
    } else if (el is ImageEl && (_crop || !_canvas)) {
      _drag = _Drag.pan;
    } else {
      _drag = _canvas ? _Drag.move : _Drag.none;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size face) {
    final el = _selected;
    if (el == null || _drag == _Drag.none) return;
    // Two fingers: zoom a picture's content, or scale a text's size.
    if (d.pointerCount >= 2 && (d.scale - 1).abs() > 0.005) {
      setState(() {
        if (el is ImageEl) {
          el.zoom = (_startZoom * d.scale).clamp(1.0, 8.0);
        } else if (el is TextEl) {
          el.size = (_startSize * d.scale).clamp(10.0, 90.0);
        }
      });
      return;
    }
    final delta = d.focalPointDelta;
    switch (_drag) {
      case _Drag.move:
        _raw += Offset(delta.dx / face.width, delta.dy / face.height);
        var nx = _raw.dx.clamp(0.0, 1 - el.w);
        var ny = _raw.dy.clamp(0.0, 1 - el.h);
        // Snap the centre lines (and the margins) with a gentle tick.
        final cx = nx + el.w / 2, cy = ny + el.h / 2;
        _guideX = null;
        _guideY = null;
        if ((cx - 0.5).abs() < 0.015) {
          nx = 0.5 - el.w / 2;
          _guideX = 0.5;
        } else if ((nx - SideLayout.padX).abs() < 0.012) {
          nx = SideLayout.padX;
          _guideX = SideLayout.padX;
        } else if ((nx + el.w - (1 - SideLayout.padX)).abs() < 0.012) {
          nx = 1 - SideLayout.padX - el.w;
          _guideX = 1 - SideLayout.padX;
        }
        if ((cy - 0.5).abs() < 0.015) {
          ny = 0.5 - el.h / 2;
          _guideY = 0.5;
        }
        if ((_guideX != null) != _snappedX || (_guideY != null) != _snappedY) {
          if (_guideX != null || _guideY != null) Fx.i.tap();
          _snappedX = _guideX != null;
          _snappedY = _guideY != null;
        }
        setState(() {
          el.x = nx;
          el.y = ny;
        });
      case _Drag.resize:
        _resize(el, delta, face);
      case _Drag.pan:
        if (el is ImageEl) _panPicture(el, delta, face);
      case _Drag.none:
        break;
    }
  }

  void _resize(LayoutEl el, Offset delta, Size face) {
    _grab += Offset(delta.dx / face.width, delta.dy / face.height);
    final h = _handle!;
    final left = h == 0 || h == 2, top = h == 0 || h == 1;
    final anchor = Offset(left ? _start.right : _start.left, top ? _start.bottom : _start.top);
    final moving = Offset((left ? _start.left : _start.right) + _grab.dx, (top ? _start.top : _start.bottom) + _grab.dy);
    var r = Rect.fromPoints(anchor, moving);
    const minW = 0.08, minH = 0.04;
    var w = math.max(r.width, minW), hh = math.max(r.height, minH);
    if (_lockShape && el is ImageEl) {
      // Keep the frame's shape: the larger pull wins.
      final ratio = _start.height / _start.width * face.height / face.width * (face.width / face.height);
      final byW = w, byH = hh / ratio;
      w = math.max(byW, byH);
      hh = w * ratio;
    }
    final nx = left ? anchor.dx - w : anchor.dx;
    final ny = top ? anchor.dy - hh : anchor.dy;
    final x = nx.clamp(0.0, 1 - w);
    final y = ny.clamp(0.0, 1 - hh);
    setState(() {
      el
        ..x = x
        ..y = y
        ..w = math.min(w, 1)
        ..h = math.min(hh, 1);
    });
  }

  /// Dragging inside a picture moves the picture behind its frame (crop).
  void _panPicture(ImageEl el, Offset delta, Size face) {
    final fw = el.w * face.width, fh = el.h * face.height;
    final a = el.aspect > 0 ? el.aspect : 1.0;
    final frameAspect = fw / fh;
    final double iw, ih;
    if (el.contain) {
      iw = frameAspect > a ? fh * a : fw;
      ih = frameAspect > a ? fh : fw / a;
    } else {
      iw = frameAspect > a ? fw : fh * a;
      ih = frameAspect > a ? fw / a : fh;
    }
    final dx = iw * el.zoom - fw, dy = ih * el.zoom - fh;
    setState(() {
      if (dx.abs() > 1) el.panX = (el.panX - delta.dx / dx).clamp(0.0, 1.0);
      if (dy.abs() > 1) el.panY = (el.panY - delta.dy / dy).clamp(0.0, 1.0);
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    setState(() {
      _drag = _Drag.none;
      _guideX = _guideY = null;
    });
  }

  // ------------------------------------------------------------------ leaving

  Future<void> _cancel() async {
    if (_undo.isNotEmpty) {
      final ok = await confirm(context,
          title: 'Discard your changes?', message: 'This side goes back to how it was.', yes: 'Discard', no: 'Keep editing');
      if (!ok || !mounted) return;
    }
    Navigator.pop(context);
  }

  void _done() {
    Fx.i.pop();
    Navigator.pop(context, LayoutResult(_l.isPlain ? null : _l));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: mc.canvas,
        resizeToAvoidBottomInset: false,
        body: Wall(
          child: Column(
            children: [
              SizedBox(height: mq.padding.top),
              _header(mc),
              Expanded(child: LayoutBuilder(builder: (context, box) => _preview(mc, box))),
              _panel(mc, mq),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Mc mc) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 0),
        child: Row(children: [
          IconTap(icon: McIcons.back, size: const Size(26, 26), label: 'Back', onTap: _cancel),
          const SizedBox(width: 6),
          Expanded(
            child: Text(widget.back ? 'Back side' : 'Front side', style: T.d(30, color: mc.ink)),
          ),
          Pressable(
            onTap: _undo.isEmpty ? null : _undoLast,
            enabled: _undo.isNotEmpty,
            label: 'Undo',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: McIcon(McIcons.undo, size: const Size(22, 22), color: mc.ink),
            ),
          ),
          const SizedBox(width: 4),
          Pressable(
            onTap: _done,
            haptic: true,
            label: 'Done',
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(14), boxShadow: mc.e1),
              child: Text('Done', style: T.d(22, color: mc.canvas)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _preview(Mc mc, BoxConstraints box) {
    var w = box.maxWidth - 48;
    var h = w / _faceAspect;
    final maxH = box.maxHeight - 10;
    if (h > maxH) {
      h = maxH;
      w = h * _faceAspect;
    }
    final face = Size(math.max(w, 120), math.max(h, 160));
    final k = face.width / 276;
    final sel = _selected;
    return Center(
      child: SizedBox(
        width: face.width,
        height: face.height,
        // The finger's first touch picks the thing under it right away (a fast drag would otherwise start
        // before a tap is recognised); the gesture then moves, resizes, crops or zooms it.
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            if (_pointers++ == 0) _touchDown(e.localPosition, face);
          },
          onPointerUp: (_) => _pointers = math.max(0, _pointers - 1),
          onPointerCancel: (_) => _pointers = math.max(0, _pointers - 1),
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) => _onScaleStart(d, face),
          onScaleUpdate: (d) => _onScaleUpdate(d, face),
          onScaleEnd: _onScaleEnd,
          child: Container(
            clipBehavior: Clip.antiAlias,
            foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(18 * k)),
            decoration: BoxDecoration(
              color: widget.back ? Mc.peach : mc.ink,
              borderRadius: BorderRadius.circular(18 * k),
              boxShadow: mc.cardShadow,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // While cropping, the rest of the picture shows faintly outside its frame.
                if (sel is ImageEl && (_crop || !_canvas) && _pictureRect(sel, face) != null)
                  Positioned.fromRect(
                    rect: _pictureRect(sel, face)!,
                    child: IgnorePointer(child: Opacity(opacity: 0.38, child: cardImage(sel.src, fit: BoxFit.fill))),
                  ),
                LayoutFace(layout: _l, texts: _texts, back: widget.back),
                IgnorePointer(child: _ghost(mc, k)),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _EditPainter(
                      rects: [for (final e in _l.els) if (_canvas && e.id != _sel && _drawn(e)) _rect(e, face)],
                      selected: sel == null || (!_canvas && sel is! ImageEl) ? null : _rect(sel, face),
                      handles: _canvas && sel != null,
                      guideX: _guideX == null ? null : _guideX! * face.width,
                      guideY: _guideY == null ? null : _guideY! * face.height,
                      emptyText: sel is TextEl && !_drawn(sel),
                      mutedColor: widget.back ? Mc.graphite : mc.onInk,
                      accent: Mc.blue,
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

  /// What the real card puts over the layout (label, reveal button), drawn faintly so you can leave room.
  Widget _ghost(Mc mc, double k) {
    final c = widget.back ? Mc.graphite : mc.onInk;
    return Opacity(
      opacity: 0.5,
      child: Padding(
        padding: EdgeInsets.all(20 * k),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.back ? 'ANSWER' : widget.label.toUpperCase(),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caps(12 * k, color: c.withValues(alpha: 0.8))),
          const Spacer(),
          if (!widget.back)
            Container(
              height: 56 * k,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: mc.pill.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12 * k)),
              child: Text('Tap to reveal', style: T.t(17 * k, w: FontWeight.w600, color: Mc.graphite)),
            ),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------------ panel

  Widget _panel(Mc mc, MediaQueryData mq) {
    final maxH = mq.size.height * 0.42;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: mc.soft,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: mc.sheet,
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 16 + mq.padding.bottom),
        shrinkWrap: true,
        children: [
          Seg<LayoutMode>(
            options: LayoutMode.values,
            value: _l.mode,
            height: 36,
            fontSize: 15,
            background: mc.well,
            labelOf: (m) => m == LayoutMode.structured ? 'Structured' : 'Free canvas',
            onPick: _setMode,
          ),
          const SizedBox(height: 4),
          Text(
            _canvas
                ? 'Drag to move, pull a corner to resize, pinch to zoom. Everything stays where you put it.'
                : 'A guided layout: pick a shape, then drag inside the picture to crop it.',
            style: T.t(13.5, w: FontWeight.w500, color: mc.muted, height: 1.3),
          ),
          const SizedBox(height: 10),
          if (_canvas) ..._canvasTools(mc) else ..._structuredTools(mc),
        ],
      ),
    );
  }

  Widget _label(Mc mc, String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text.toUpperCase(), style: T.caps(12, color: mc.muted)),
      );

  Widget _seg<V>(List<V> options, V value, String Function(V) labelOf, ValueChanged<V> onPick) => Seg<V>(
        options: options,
        value: value,
        height: 32,
        fontSize: 13.5,
        background: Mc.of(context).well,
        labelOf: labelOf,
        onPick: onPick,
      );

  Widget _switchRow(Mc mc, String title, String note, bool value, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.t(15.5, w: FontWeight.w700, color: mc.ink)),
              if (note.isNotEmpty) Text(note, style: T.t(13.5, w: FontWeight.w500, color: mc.muted, height: 1.25)),
            ]),
          ),
          const SizedBox(width: 12),
          McSwitch(value: value, onChanged: onChanged, label: title),
        ]),
      );

  Widget _sliderRow(Mc mc, String title, double value, double min, double max, ValueChanged<double> onChanged, String shown) => Row(
        children: [
          SizedBox(width: 62, child: Text(title, style: T.t(14, w: FontWeight.w600, color: mc.muted))),
          Expanded(child: McSlider(value: value, min: min, max: max, onChanged: onChanged, onChangeStart: _pushUndo)),
          SizedBox(width: 44, child: Text(shown, textAlign: TextAlign.right, style: T.t(14, w: FontWeight.w700, color: mc.ink))),
        ],
      );

  // -------------------------------------------------------------- structured

  List<Widget> _structuredTools(Mc mc) {
    final img = _l.firstImage;
    return [
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final t in Tpl.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip2(t.label, height: 34, selected: _l.tpl == t, onTap: () => _chooseTemplate(t)),
              ),
          ],
        ),
      ),
      if (img == null) ...[
        const SizedBox(height: 12),
        SoftButton('Add a picture', height: 46, color: mc.well, icon: McIcon(McIcons.plus, size: const Size(18, 18), color: mc.ink), onTap: _addPicture),
      ] else
        ..._pictureTools(mc, img, structured: true),
    ];
  }

  // -------------------------------------------------------------- canvas

  List<Widget> _canvasTools(Mc mc) {
    final sel = _selected;
    var pics = 0, texts = 0;
    String nameOf(LayoutEl e) {
      if (e is ImageEl) return 'Picture ${++pics}';
      final t = e as TextEl;
      return switch (t.source) {
        'main' => widget.back ? 'Answer' : 'Prompt',
        'example' => 'Hint',
        'hook' => 'Memory hook',
        _ => 'Text ${++texts}',
      };
    }

    final names = {for (final e in _l.els) e.id: nameOf(e)};
    return [
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip2('+ Picture', height: 34, onTap: _addPicture),
        Chip2('+ Text', height: 34, onTap: () => _edit(() => _sel = _l.dropText().id)),
        Chip2('Guided layout', height: 34, onTap: () => _setMode(LayoutMode.structured)),
      ]),
      _label(mc, 'On this side'),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final e in _l.els.reversed)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip2(
                  names[e.id]!,
                  height: 34,
                  selected: e.id == _sel,
                  onTap: () => setState(() {
                    _sel = e.id;
                    if (e is! ImageEl) _crop = false;
                  }),
                ),
              ),
          ],
        ),
      ),
      if (sel == null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Tap something on the card, or pick it above, to change it.', style: T.t(14, w: FontWeight.w500, color: mc.muted)),
        )
      else ...[
        if (sel is ImageEl) ..._pictureTools(mc, sel, structured: false),
        if (sel is TextEl) ..._textTools(mc, sel),
        _label(mc, 'Order'),
        Wrap(spacing: 8, children: [
          Chip2('Bring forward', height: 34, onTap: () => _edit(() => _l.step(sel, 1))),
          Chip2('Send back', height: 34, onTap: () => _edit(() => _l.step(sel, -1))),
          if (sel is ImageEl || (sel is TextEl && sel.isCustom))
            Chip2('Delete', height: 34, color: Mc.delete, textColor: Mc.graphite, onTap: () => _removeElement(sel)),
        ]),
      ],
    ];
  }

  List<Widget> _pictureTools(Mc mc, ImageEl el, {required bool structured}) {
    final radius = el.radius <= 0 ? 0 : (el.radius < 24 ? 1 : 2);
    return [
      _label(mc, 'Picture'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip2('Replace', height: 34, onTap: () => _replacePicture(el)),
        if (!structured) Chip2(_crop ? 'Cropping: drag to pan' : 'Crop', height: 34, selected: _crop, onTap: () => setState(() => _crop = !_crop)),
        if (structured) Chip2('Remove', height: 34, color: Mc.delete, textColor: Mc.graphite, onTap: () => _removeElement(el)),
        if (!structured)
          Chip2(_lockShape ? 'Shape locked' : 'Free shape', height: 34, selected: _lockShape, onTap: () => setState(() => _lockShape = !_lockShape)),
      ]),
      const SizedBox(height: 10),
      _seg<bool>(const [false, true], el.contain, (v) => v ? 'Show whole' : 'Fill the frame', (v) => _edit(() => el.contain = v)),
      const SizedBox(height: 8),
      _sliderRow(mc, 'Zoom', el.zoom, 1, 4, (v) => setState(() => el.zoom = v), '${el.zoom.toStringAsFixed(1)}×'),
      if (!structured) ...[
        _label(mc, 'Corners'),
        _seg<int>(const [0, 1, 2], radius, (v) => const ['Square', 'Soft', 'Round'][v], (v) => _edit(() => el.radius = const [0.0, 12.0, 60.0][v])),
      ],
      _label(mc, 'Behind it'),
      _seg<String>(const ['', 'paper', 'ink'], el.plate, (v) => v.isEmpty ? 'Nothing' : (v == 'paper' ? 'Paper' : 'Dark'), (v) => _edit(() => el.plate = v)),
      if (el.alpha || el.plate.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              el.alpha ? 'This picture has a see-through background: a plate keeps dark or pale drawings readable.' : 'A plate behind the picture.',
              style: T.t(13, w: FontWeight.w500, color: mc.muted, height: 1.25)),
        ),
      _switchRow(mc, 'Thin outline', 'Helps pale pictures stand out', el.outline, (v) => _edit(() => el.outline = v)),
      _switchRow(mc, 'Blur until revealed', 'How much is set in Settings › Study', el.blur, (v) => _edit(() => el.blur = v)),
    ];
  }

  List<Widget> _textTools(Mc mc, TextEl el) {
    final size = el.size == 0 ? termSize(_textOf(el), false) : el.size;
    return [
      _label(mc, 'Text'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip2('Edit the words', height: 34, onTap: () => _editText(el)),
        if (!el.isCustom) Chip2(el.visible ? 'Hide' : 'Show', height: 34, onTap: () => _edit(() => el.visible = !el.visible)),
      ]),
      const SizedBox(height: 10),
      _sliderRow(mc, 'Size', size, 10, 80, (v) => setState(() => el.size = v), '${size.round()}'),
      const SizedBox(height: 4),
      _seg<int>(const [0, 1, 2], el.align, (v) => const ['Left', 'Centre', 'Right'][v], (v) => _edit(() => el.align = v)),
      const SizedBox(height: 8),
      _seg<String>(const ['display', 'plain'], el.font, (v) => v == 'display' ? 'Display font' : 'Plain font', (v) => _edit(() => el.font = v)),
      _label(mc, 'Colour'),
      _seg<String>(const ['auto', 'light', 'dark', 'peach', 'red'], el.color,
          (v) => const {'auto': 'Auto', 'light': 'White', 'dark': 'Dark', 'peach': 'Peach', 'red': 'Red'}[v]!, (v) => _edit(() => el.color = v)),
      _label(mc, 'Behind the words'),
      _seg<String>(const ['none', 'dark', 'light', 'peach'], el.bg,
          (v) => const {'none': 'Nothing', 'dark': 'Dark', 'light': 'Light', 'peach': 'Peach'}[v]!, (v) => _edit(() => el.bg = v)),
    ];
  }
}

/// Selection outline with corner handles, the thin outlines of the other things, and snap guides.
class _EditPainter extends CustomPainter {
  _EditPainter({
    required this.rects,
    required this.selected,
    required this.handles,
    required this.guideX,
    required this.guideY,
    required this.emptyText,
    required this.mutedColor,
    required this.accent,
  });

  final List<Rect> rects;
  final Rect? selected;
  final bool handles;
  final double? guideX, guideY;
  final bool emptyText;
  final Color mutedColor;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = mutedColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in rects) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), thin);
    }
    if (guideX != null || guideY != null) {
      final g = Paint()
        ..color = const Color(0xFFFF5A8A)
        ..strokeWidth = 1;
      if (guideX != null) canvas.drawLine(Offset(guideX!, 0), Offset(guideX!, size.height), g);
      if (guideY != null) canvas.drawLine(Offset(0, guideY!), Offset(size.width, guideY!), g);
    }
    final s = selected;
    if (s == null) return;
    final line = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (emptyText) {
      final dash = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final path = Path()..addRRect(RRect.fromRectAndRadius(s, const Radius.circular(6)));
      for (final m in path.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 10) {
          canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), dash);
        }
      }
      final tp = TextPainter(
        text: TextSpan(text: 'Empty · tap "Edit the words"', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: s.width);
      tp.paint(canvas, s.topLeft + const Offset(6, 4));
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(s, const Radius.circular(3)), line);
    }
    if (handles) {
      final fill = Paint()..color = Colors.white;
      final ring = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      for (final c in [s.topLeft, s.topRight, s.bottomLeft, s.bottomRight]) {
        canvas.drawCircle(c, 9, fill);
        canvas.drawCircle(c, 9, ring);
      }
    }
  }

  @override
  bool shouldRepaint(_EditPainter old) => true;
}
