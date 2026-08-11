import 'dart:typed_data';
import 'dart:ui' as ui;

/// Downscales [bytes] so its longest edge is at most [maxDimension], re-encoding
/// as PNG (which preserves transparency for cutouts). Returns the original bytes
/// unchanged when the image is already small enough or if decoding fails.
///
/// Used to shrink an image before sending it for AI tagging: classification
/// doesn't need full resolution, and a smaller image means a smaller upload,
/// smaller base64 payload, and fewer vision tokens.
Future<Uint8List> downscaleImage(
  Uint8List bytes, {
  int maxDimension = 1024,
}) async {
  try {
    // Peek at the dimensions first.
    final probe = await ui.instantiateImageCodec(bytes);
    final probeFrame = await probe.getNextFrame();
    final width = probeFrame.image.width;
    final height = probeFrame.image.height;
    probeFrame.image.dispose();

    final longest = width > height ? width : height;
    if (longest <= maxDimension) return bytes; // already small enough

    final scale = maxDimension / longest;
    final targetWidth = (width * scale).round();
    final targetHeight = (height * scale).round();

    final resizeCodec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final resizeFrame = await resizeCodec.getNextFrame();
    final data =
        await resizeFrame.image.toByteData(format: ui.ImageByteFormat.png);
    resizeFrame.image.dispose();

    if (data == null) return bytes;
    return data.buffer.asUint8List();
  } catch (_) {
    return bytes; // never block tagging on a resize failure
  }
}
