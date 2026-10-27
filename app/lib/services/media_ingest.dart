import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:audioplayers/audioplayers.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../data/models.dart';
import '../data/store.dart' show uid;

/// A video that has been brought into the app: the file, a poster (a still from its start) and its shape.
class PickedVideo {
  const PickedVideo({required this.src, required this.poster, required this.aspect, required this.ms});

  /// The video file, kept in the app's own folder.
  final String src;

  /// A JPEG still, drawn wherever the video is not playing (thumbnails, previews, the blur before a reveal).
  final String poster;

  /// Width ÷ height as it plays (turned the right way up).
  final double aspect;

  /// Length, ms.
  final int ms;
}

/// Thrown for a file the app will not keep (too big, too long, not a video): [message] is said to the user.
class MediaRefused implements Exception {
  const MediaRefused(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Brings videos and sounds in from the gallery, the camera, files or the microphone, and keeps them in the
/// app's own folder (`card_media`), next to the card pictures. Videos also get a poster still.
class MediaIngest {
  const MediaIngest._();

  /// The biggest video kept on a card, and the longest.
  static const maxVideoBytes = 150 * 1024 * 1024;
  static const maxVideoMs = 3 * 60 * 1000;

  /// The biggest sound file brought in from Files.
  static const maxSoundBytes = 30 * 1024 * 1024;

  /// The longest recording; the recorder stops by itself here.
  static const maxRecordMs = 2 * 60 * 1000;

  static Future<Directory> _dir(String name) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/$name');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _ext(String path, String fallback) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return fallback;
    final ext = name.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext) ? ext : fallback;
  }

  // ---------------------------------------------------------------- video

  static Future<PickedVideo?> videoFromGallery() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    return x == null ? null : ingestVideo(x.path);
  }

  /// Films a new one with the phone's camera app (at most [maxVideoMs] long).
  static Future<PickedVideo?> videoFromCamera() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(milliseconds: maxVideoMs));
    return x == null ? null : ingestVideo(x.path);
  }

  static Future<PickedVideo?> videoFromFile() async {
    final f = await FilePicker.pickFile(type: FileType.video);
    final path = f?.path;
    return path == null ? null : ingestVideo(path);
  }

  /// Copies the video at [path] into the app, measures it and makes its poster.
  static Future<PickedVideo> ingestVideo(String path) async {
    final source = File(path);
    final bytes = await source.length();
    if (bytes > maxVideoBytes) throw MediaRefused('That video is ${(bytes / 1e6).round()} MB: cards keep videos up to 150 MB');
    final dir = await _dir('card_media');
    final id = uid('vid');
    final dest = '${dir.path}/$id.${_ext(path, 'mp4')}';
    await source.copy(dest);
    try {
      final (aspect, ms) = await _measure(dest);
      if (ms > maxVideoMs + 1500) {
        throw const MediaRefused('Cards keep videos up to 3 minutes long. Trim it first in your gallery.');
      }
      final poster = await _poster(dest, id, aspect);
      return PickedVideo(src: dest, poster: poster, aspect: aspect, ms: ms);
    } catch (_) {
      unawaited(File(dest).delete().then((_) {}, onError: (_) {}));
      rethrow;
    }
  }

  /// Shape (turned the right way up) and length, read by actually opening the video.
  static Future<(double, int)> _measure(String path) async {
    final c = VideoPlayerController.file(File(path));
    try {
      await c.initialize().timeout(const Duration(seconds: 12));
      final v = c.value;
      if (v.hasError || v.size.width <= 0) throw const MediaRefused('This phone cannot play that video');
      return (v.aspectRatio, v.duration.inMilliseconds);
    } on TimeoutException {
      throw const MediaRefused('That video took too long to open');
    } on MediaRefused {
      rethrow;
    } catch (_) {
      throw const MediaRefused('This phone cannot play that video');
    } finally {
      unawaited(c.dispose());
    }
  }

  /// A still from the start of the video, as a JPEG next to the card pictures. If the phone cannot make
  /// one, a plain dark still of the right shape stands in (the video itself still plays).
  static Future<String> _poster(String video, String id, double aspect) async {
    final dir = await _dir('card_images');
    final dest = '${dir.path}/${id}_poster.jpg';
    try {
      final ok = await FcNativeVideoThumbnail().saveThumbnailToFile(
        srcFile: video,
        destFile: dest,
        width: 1280,
        height: 1280,
        format: 'jpeg',
        quality: 86,
      );
      if (ok && await File(dest).exists()) return dest;
    } catch (e) {
      debugPrint('Memory Card: no video poster ($e)');
    }
    final w = 320, h = (320 / (aspect > 0 ? aspect : 16 / 9)).round().clamp(80, 1280);
    final still = img.Image(width: w, height: h)..clear(img.ColorRgb8(0x22, 0x22, 0x22));
    await File(dest).writeAsBytes(img.encodeJpg(still, quality: 80), flush: true);
    return dest;
  }

  // ---------------------------------------------------------------- sound

  /// Where a new recording is written (the recorder fills it; [keepRecording] adopts it).
  static Future<String> newRecordingPath() async => '${(await _dir('card_media')).path}/${uid('rec')}.m4a';

  /// A finished recording as a card sound.
  static Future<CardSound> keepRecording(String path, {int? ms}) async =>
      CardSound(src: path, ms: ms ?? await soundLength(path), recorded: true);

  /// A sound from Files: MP3, M4A, WAV, OGG, AAC…
  static Future<CardSound?> soundFromFile() async {
    final f = await FilePicker.pickFile(type: FileType.audio);
    final path = f?.path;
    if (path == null) return null;
    final source = File(path);
    final bytes = await source.length();
    if (bytes > maxSoundBytes) throw MediaRefused('That sound is ${(bytes / 1e6).round()} MB: cards keep sounds up to 30 MB');
    final dest = '${(await _dir('card_media')).path}/${uid('snd')}.${_ext(path, 'm4a')}';
    await source.copy(dest);
    final ms = await soundLength(dest);
    if (ms <= 0) {
      unawaited(File(dest).delete().then((_) {}, onError: (_) {}));
      throw const MediaRefused('This phone cannot play that sound');
    }
    return CardSound(src: dest, ms: ms);
  }

  /// How long a sound file plays, ms (0 if it cannot be opened).
  static Future<int> soundLength(String path) async {
    final p = AudioPlayer();
    try {
      await p.setSource(DeviceFileSource(path)).timeout(const Duration(seconds: 6));
      final d = await p.getDuration().timeout(const Duration(seconds: 4));
      return d?.inMilliseconds ?? 0;
    } catch (_) {
      return 0;
    } finally {
      unawaited(p.dispose());
    }
  }

  /// Removes a file the app made but no longer needs (a discarded recording). Never throws.
  static Future<void> discard(String? path) async {
    if (path == null || kIsWeb || path.startsWith('data:') || path.startsWith('asset:')) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
