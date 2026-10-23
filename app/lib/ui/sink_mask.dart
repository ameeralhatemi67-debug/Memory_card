import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [ShaderMask] (dstIn) that can be switched off without changing the widget tree.
///
/// A plain ShaderMask that is added and removed as an animation starts and ends re-parents its child, so
/// Flutter rebuilds the whole subtree on the very first frame of the animation: a hitch exactly when a
/// swipe begins. This keeps the child where it is and only decides, at paint time, whether to put it
/// through the mask. With the callback null it costs nothing (no offscreen layer).
class SinkMask extends SingleChildRenderObjectWidget {
  const SinkMask({super.key, required this.shaderCallback, super.child});

  /// null = no mask.
  final ShaderCallback? shaderCallback;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSinkMask(shaderCallback);

  @override
  void updateRenderObject(BuildContext context, covariant RenderProxyBox renderObject) {
    (renderObject as _RenderSinkMask).shaderCallback = shaderCallback;
  }
}

class _RenderSinkMask extends RenderProxyBox {
  _RenderSinkMask(this._callback);

  ShaderCallback? _callback;

  set shaderCallback(ShaderCallback? value) {
    final wasOn = _callback != null;
    _callback = value;
    if (wasOn != (value != null)) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _callback != null;

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) {
      layer = null;
      return;
    }
    final callback = _callback;
    if (callback == null) {
      layer = null;
      context.paintChild(c, offset);
      return;
    }
    layer ??= ShaderMaskLayer();
    layer!
      ..shader = callback(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(layer!, super.paint, offset);
  }
}
