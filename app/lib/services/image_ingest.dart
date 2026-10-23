import 'dart:convert';
import 'dart:io' show Directory, File;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/store.dart' show uid;

/// A picture that has been brought into the app and saved.
class PickedImage {
  const PickedImage(this.src, this.aspect, this.alpha);

  /// File path (phone) or data URI (web).
  final String src;

  /// Width ÷ height.
  final double aspect;

  /// Has transparent areas (a PNG cut-out, a logo).
  final bool alpha;
}

/// The outcome of preparing picture bytes: what to write, and what we learned about it.
class PreparedImage {
  const PreparedImage(this.bytes, this.ext, this.aspect, this.alpha);
  final Uint8List bytes;
  final String ext;
  final double aspect;
  final bool alpha;
}

/// Brings pictures in from the gallery, the camera or a file, keeps transparency (PNG cut-outs stay
/// cut out) and keeps them a sensible size on the phone.
class ImageIngest {
  const ImageIngest._();

  /// The longest side a stored picture keeps.
  static const maxSide = 1600;

  static Future<PickedImage?> fromGallery() => _fromXFile(ImagePicker().pickImage(source: ImageSource.gallery));

  static Future<PickedImage?> fromCamera() => _fromXFile(ImagePicker().pickImage(source: ImageSource.camera));

  /// From any file: PNG, JPEG, WebP, GIF, BMP.
  static Future<PickedImage?> fromFile() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp']);
    if (f == null) return null;
    return fromBytes(await f.xFile.readAsBytes());
  }

  static Future<PickedImage?> _fromXFile(Future<XFile?> pick) async {
    final x = await pick;
    if (x == null) return null;
    return fromBytes(await x.readAsBytes());
  }

  /// Prepares [bytes] and stores the result.
  static Future<PickedImage> fromBytes(Uint8List bytes) async {
    PreparedImage out;
    try {
      out = await compute(prepare, bytes);
    } catch (_) {
      out = await _viaEngine(bytes); // formats the pure-Dart decoder lacks (HEIC…): the phone's own codec
    }
    if (kIsWeb) {
      final mime = out.ext == 'png' ? 'image/png' : 'image/jpeg';
      return PickedImage('data:$mime;base64,${base64Encode(out.bytes)}', out.aspect, out.alpha);
    }
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/card_images');
    if (!await folder.exists()) await folder.create(recursive: true);
    final path = '${folder.path}/${uid('img')}.${out.ext}';
    await File(path).writeAsBytes(out.bytes, flush: true);
    return PickedImage(path, out.aspect, out.alpha);
  }

  /// The pure part, kept apart so tests (and an isolate) can run it:
  /// decode → honour the camera's rotation → shrink to [maxSide] → keep transparency as PNG, photos as JPEG.
  static PreparedImage prepare(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('unreadable picture');
    var im = img.bakeOrientation(decoded);
    final long = math.max(im.width, im.height);
    final shrunk = long > maxSide;
    if (shrunk) {
      im = img.copyResize(
        im,
        width: im.width >= im.height ? maxSide : null,
        height: im.height > im.width ? maxSide : null,
        interpolation: img.Interpolation.average,
      );
    }
    final alpha = hasTransparency(im);
    final aspect = im.width / im.height;
    if (alpha) return PreparedImage(Uint8List.fromList(img.encodePng(im)), 'png', aspect, true);
    final jpegIn = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    if (jpegIn && !shrunk && decoded.width == im.width && decoded.height == im.height) {
      return PreparedImage(bytes, 'jpg', aspect, false); // already a fine JPEG: do not recompress
    }
    // A flat PNG that is small stays PNG (screenshots, flags); photos go to JPEG.
    final pngIn = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
    if (pngIn && bytes.length < 400 * 1024 && !shrunk) return PreparedImage(bytes, 'png', aspect, false);
    return PreparedImage(Uint8List.fromList(img.encodeJpg(im, quality: 88)), 'jpg', aspect, false);
  }

  /// Any pixel noticeably see-through.
  static bool hasTransparency(img.Image im) {
    if (!im.hasAlpha) return false;
    final max = im.maxChannelValue;
    for (final p in im) {
      if (p.a < max * 0.98) return true;
    }
    return false;
  }

  static Future<PreparedImage> _viaEngine(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    var image = frame.image;
    final long = math.max(image.width, image.height);
    if (long > maxSide) {
      final c2 = await ui.instantiateImageCodec(
        bytes,
        targetWidth: image.width >= image.height ? maxSide : null,
        targetHeight: image.height > image.width ? maxSide : null,
      );
      image = (await c2.getNextFrame()).image;
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return PreparedImage(data!.buffer.asUint8List(), 'png', image.width / image.height, false);
  }
}
