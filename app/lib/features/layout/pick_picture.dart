import 'package:flutter/material.dart';

import '../../services/image_ingest.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Asks where the picture comes from (photos, a file, the camera), brings it in, and returns it saved.
/// PNGs keep their transparent background. null = cancelled or it could not be read.
Future<PickedImage?> pickPicture(BuildContext context) async {
  final mc = Mc.of(context);
  final choice = await showMcSheet<String>(
    context,
    expand: false,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a picture', style: T.d(30, color: mc.ink)),
          const SizedBox(height: 4),
          Text('PNG, JPG and WebP all work. PNGs with a see-through background stay see-through.',
              style: T.t(15, w: FontWeight.w500, color: mc.muted, height: 1.3)),
          const SizedBox(height: 14),
          for (final (id, name, note) in const [
            ('photos', 'Photos', 'Pick from your gallery'),
            ('files', 'Files', 'A PNG, JPG or WebP from your phone'),
            ('camera', 'Camera', 'Take a new photo'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                onTap: () => Navigator.pop(ctx, id),
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
    ),
  );
  if (choice == null || !context.mounted) return null;
  try {
    return switch (choice) {
      'files' => await ImageIngest.fromFile(),
      'camera' => await ImageIngest.fromCamera(),
      _ => await ImageIngest.fromGallery(),
    };
  } catch (_) {
    Toaster.i.show('Could not add that picture');
    return null;
  }
}
