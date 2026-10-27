import 'package:flutter/material.dart';

import '../../services/media_ingest.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// A video picked for a card, and the part it plays there.
class VideoChoice {
  const VideoChoice(this.video, {this.hint = false});
  final PickedVideo video;

  /// Front side only: kept back as a hint (blurred until tapped) instead of being the question itself.
  final bool hint;
}

/// Asks where the video comes from (gallery, camera, files) and, on the front, whether it is the question or
/// a hint; brings it in and returns it. On the back it is part of the answer: blurred until the reveal, like
/// the answer's pictures. null = cancelled or it could not be read.
Future<VideoChoice?> pickVideo(BuildContext context, {required bool back, bool askRole = true}) async {
  final picked = await showMcSheet<(String, bool)>(
    context,
    expand: false,
    builder: (ctx) => _VideoSheet(back: back, askRole: askRole && !back),
  );
  if (picked == null || !context.mounted) return null;
  final (source, hint) = picked;
  final mc = Mc.of(context);
  // Copying, measuring and the poster take a moment for a long video: say so instead of looking stuck.
  var open = true;
  showMcDialog<void>(
    context,
    dismissible: false,
    builder: (ctx) => DialogCard(children: [
      Center(child: SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3.5, color: mc.ink))),
      const SizedBox(height: 16),
      Text('Getting the video ready…', textAlign: TextAlign.center, style: T.d(24, color: mc.ink)),
    ]),
  ).whenComplete(() => open = false);
  void close() {
    if (open && context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  try {
    final v = await switch (source) {
      'camera' => MediaIngest.videoFromCamera(),
      'files' => MediaIngest.videoFromFile(),
      _ => MediaIngest.videoFromGallery(),
    };
    close();
    return v == null ? null : VideoChoice(v, hint: hint);
  } on MediaRefused catch (e) {
    close();
    Toaster.i.show(e.message, duration: const Duration(seconds: 4));
    return null;
  } catch (_) {
    close();
    Toaster.i.show('Could not add that video');
    return null;
  }
}

class _VideoSheet extends StatefulWidget {
  const _VideoSheet({required this.back, required this.askRole});
  final bool back;
  final bool askRole;

  @override
  State<_VideoSheet> createState() => _VideoSheetState();
}

class _VideoSheetState extends State<_VideoSheet> {
  bool _hint = false;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a video', style: T.d(30, color: mc.ink)),
          const SizedBox(height: 4),
          Text(
            widget.back
                ? 'Part of the answer: it stays blurred until the reveal, like the answer\'s pictures, then plays.'
                : 'Up to 3 minutes. It plays on the card; a hint stays blurred until you tap it.',
            style: T.t(15, w: FontWeight.w500, color: mc.muted, height: 1.3),
          ),
          if (widget.askRole) ...[
            const SizedBox(height: 14),
            Seg<bool>(
              options: const [false, true],
              value: _hint,
              background: mc.soft,
              labelOf: (v) => v ? 'A hint' : 'The question',
              onPick: (v) => setState(() => _hint = v),
            ),
            const SizedBox(height: 6),
            Text(
              _hint
                  ? 'Blurred until you tap it. Remembering with the hint counts as Hard.'
                  : 'Plays as the card appears: what you see is what you answer.',
              style: T.t(13.5, w: FontWeight.w500, color: mc.muted, height: 1.3),
            ),
          ],
          const SizedBox(height: 14),
          for (final (id, name, note) in const [
            ('gallery', 'Gallery', 'Pick a video you already have'),
            ('camera', 'Camera', 'Film a new one'),
            ('files', 'Files', 'An MP4, MOV or WebM from your phone'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                onTap: () => Navigator.pop(context, (id, _hint)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14), boxShadow: mc.e1),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: T.d(22, color: mc.ink)),
                        Text(note, style: T.t(14, w: FontWeight.w500, color: mc.muted)),
                      ]),
                    ),
                    McIcon(McIcons.chevron, size: const Size(16, 16), color: mc.muted),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
