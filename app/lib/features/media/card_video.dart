import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/card_layout.dart';
import '../../ui/icons.dart';
import '../../ui/theme.dart';
import '../layout/layout_face.dart' show cardImage;

/// "0:07", "1:42".
String clockOf(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// A card's video in its frame. The poster shows until the video is ready (and whenever it may not play
/// yet: blurred before the reveal, a hint not yet opened); then the video itself, cropped exactly like the
/// poster. A small round button plays, pauses and replays it.
class CardVideo extends StatefulWidget {
  const CardVideo({
    super.key,
    required this.el,
    required this.allowed,
    required this.autostart,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.controls = true,
  });

  final ImageEl el;

  /// It may play now (the card is on top and nothing holds it back).
  final bool allowed;

  /// It starts by itself as soon as it may (Settings › Study: sounds and videos play by themselves).
  final bool autostart;
  final BoxFit fit;
  final Alignment alignment;
  final bool controls;

  @override
  State<CardVideo> createState() => _CardVideoState();
}

class _CardVideoState extends State<CardVideo> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _failed = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    final path = widget.el.video;
    if (path == null || path.startsWith('data:')) {
      _failed = true;
      return;
    }
    final c = path.startsWith('http') ? VideoPlayerController.networkUrl(Uri.parse(path)) : VideoPlayerController.file(File(path));
    _c = c;
    c.addListener(_tick);
    c.initialize().then((_) async {
      if (!mounted) return;
      await c.setLooping(widget.el.loop);
      await c.setVolume(widget.el.sound ? 1 : 0);
      setState(() => _ready = true);
      if (widget.allowed && widget.autostart) _play(fromStart: true);
    }, onError: (Object e) {
      if (mounted) setState(() => _failed = true);
    });
  }

  bool _wasPlaying = false;

  void _tick() {
    final playing = _c?.value.isPlaying ?? false;
    final ended = _ended;
    if (playing != _wasPlaying || ended) {
      _wasPlaying = playing;
      if (mounted) setState(() {});
    }
  }

  bool get _ended {
    final v = _c?.value;
    if (v == null || !v.isInitialized || v.isLooping || v.duration == Duration.zero) return false;
    return !v.isPlaying && v.position >= v.duration - const Duration(milliseconds: 120);
  }

  void _play({bool fromStart = false}) {
    final c = _c;
    if (c == null || !_ready) return;
    _started = true;
    if (fromStart || _ended) unawaited(c.seekTo(Duration.zero));
    unawaited(c.play());
  }

  @override
  void didUpdateWidget(CardVideo old) {
    super.didUpdateWidget(old);
    if (old.el.video != widget.el.video) {
      _c?.removeListener(_tick);
      unawaited(_c?.dispose());
      _c = null;
      _ready = _failed = _started = false;
      _open();
      return;
    }
    if (old.el.sound != widget.el.sound) unawaited(_c?.setVolume(widget.el.sound ? 1 : 0));
    if (old.el.loop != widget.el.loop) unawaited(_c?.setLooping(widget.el.loop));
    if (widget.allowed && !old.allowed && widget.autostart) _play(fromStart: true);
    if (!widget.allowed && old.allowed) unawaited(_c?.pause());
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    unawaited(_c?.dispose());
    super.dispose();
  }

  void _toggle() {
    final c = _c;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      unawaited(c.pause());
    } else {
      _play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final showVideo = _ready && c != null && widget.allowed && (_started || c.value.position > Duration.zero);
    final playing = c?.value.isPlaying ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        cardImage(widget.el.src, fit: widget.fit, alignment: widget.alignment),
        if (showVideo)
          FittedBox(
            fit: widget.fit,
            alignment: widget.alignment,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: 100 * c.value.aspectRatio, height: 100, child: VideoPlayer(c)),
          ),
        if (widget.controls && widget.allowed && !_failed)
          Positioned(
            right: 8,
            bottom: 8,
            child: Semantics(
              button: true,
              label: playing ? 'Pause the video' : 'Play the video',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Color(0xCC222222), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: McIcon(
                    playing ? McIcons.pause : (_ended ? McIcons.replay : McIcons.play),
                    size: const Size(20, 20),
                    color: Mc.paper,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The small "▶ 0:12" tag on a video's poster where it does not play (previews, lists, the next card).
class VideoTag extends StatelessWidget {
  const VideoTag({super.key, required this.ms, this.k = 1});
  final int ms;
  final double k;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(5 * k, 2 * k, 8 * k, 2 * k),
      decoration: BoxDecoration(color: const Color(0xCC222222), borderRadius: BorderRadius.circular(9 * k)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        McIcon(McIcons.play, size: Size(12 * k, 12 * k), color: Mc.paper),
        if (ms > 0) ...[SizedBox(width: 3 * k), Text(clockOf(ms), style: T.t(11.5 * k, w: FontWeight.w700, color: Mc.paper))],
      ]),
    );
  }
}
