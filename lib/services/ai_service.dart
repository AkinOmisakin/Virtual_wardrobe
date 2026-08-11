import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/utils/image_utils.dart';

/// Result returned after AI processing an image.
class AiImageResult {
  /// White-background version — used for wardrobe display and storage.
  final File processedFile;

  /// Transparent PNG cutout — used for the canvas outfit builder.
  /// Null when background removal fell back to the original image.
  final File? cutoutFile;

  final ClothingType? detectedType;
  final List<String> tags;
  final List<String> colours;
  final String? style;
  final String? description;

  /// True when background removal produced a transparent cutout; false when it
  /// fell back to the original image (so the item won't work in the canvas).
  final bool backgroundRemoved;

  /// True when AI tagging completed; false when it failed or was skipped, so
  /// the tag / colour / style fields are empty and the user must fill them in.
  final bool taggingSucceeded;

  const AiImageResult({
    required this.processedFile,
    this.cutoutFile,
    this.detectedType,
    this.tags = const [],
    this.colours = const [],
    this.style,
    this.description,
    this.backgroundRemoved = false,
    this.taggingSucceeded = false,
  });
}

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  // In-memory cache: file-stat key → tag result. Avoids re-calling Claude
  // when the user uploads the same image more than once in a session.
  final Map<String, AiImageResult> _tagCache = {};

  // ── Public entry point ────────────────────────────────────────────────────

  /// Processes [imageFile]:
  ///   1. Removes the background via remove.bg
  ///   2. Sends the result to Claude for tagging
  ///
  /// Always returns an [AiImageResult] — partial results are fine if one
  /// step fails; the caller still gets whatever succeeded.
  Future<AiImageResult> processClothingImage(File imageFile) async {
    // Step 1 — background removal (returns transparent PNG or original on fallback)
    final File bgRemoved = await _removeBackground(imageFile);

    // Step 2 — transparent PNG is stored as-is; white background is applied
    // at render time in the wardrobe UI widgets. Canvas uses the same file
    // and renders it without a background so items layer naturally.
    final rawBytes = await bgRemoved.readAsBytes();
    final isTruePng = rawBytes.length >= 4 &&
        rawBytes[0] == 0x89 && rawBytes[1] == 0x50 &&
        rawBytes[2] == 0x4E && rawBytes[3] == 0x47;

    final File displayFile = bgRemoved;
    final File? cutoutFile = isTruePng ? bgRemoved : null;
    debugPrint('[AiService] bg removed: $isTruePng');

    // Step 3 — Claude vision tagging
    final AiImageResult? tags = await _tagWithClaude(displayFile);

    return AiImageResult(
      processedFile:     displayFile,
      cutoutFile:        cutoutFile,
      backgroundRemoved: cutoutFile != null,
      taggingSucceeded:  tags != null,
      detectedType:      tags?.detectedType,
      tags:              tags?.tags    ?? [],
      colours:           tags?.colours ?? [],
      style:             tags?.style,
      description:       tags?.description,
    );
  }

  // ── Background removal ────────────────────────────────────────────────────

  /// Calls the Supabase edge function which runs @imgly/background-removal.
  /// Falls back to the original file on any error.
  Future<File> _removeBackground(File imageFile) async {
    final supabaseUrl  = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseKey  = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    final url = '$supabaseUrl/functions/v1/remove-background';

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $supabaseKey'
        ..files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));

      // 60s timeout — first call downloads the ONNX model (~20s cold start).
      final response = await request.send().timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        final contentType = response.headers['content-type'] ?? 'unknown';
        final isPng = bytes.length >= 4 &&
            bytes[0] == 0x89 && bytes[1] == 0x50 &&
            bytes[2] == 0x4E && bytes[3] == 0x47;
        debugPrint('[AiService] Edge function OK — content-type: $contentType, '
            'bytes: ${bytes.length}, '
            'format: ${isPng ? "PNG (bg removed)" : "JPEG (fallback — bg NOT removed)"}');
        final outFile = await _writeTempFile(bytes, 'bg_removed.png');
        debugPrint('[AiService] Processed file written: ${outFile.path}');
        return outFile;
      } else {
        final body = await response.stream.bytesToString();
        debugPrint('[AiService] Edge function error ${response.statusCode}: $body');
        return imageFile;
      }
    } catch (e) {
      debugPrint('[AiService] Background removal failed: $e');
      return imageFile;
    }
  }

  // ── Claude vision tagging ─────────────────────────────────────────────────

  /// Uploads the image to the `tag-clothing` edge function, which runs the
  /// Claude vision call server-side and returns structured JSON tags.
  /// The Anthropic key never leaves the server.
  Future<AiImageResult?> _tagWithClaude(File imageFile) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    if (supabaseUrl.isEmpty) {
      debugPrint('[AiService] SUPABASE_URL not set — skipping tagging');
      return null;
    }

    // Cache key: size + last-modified avoids re-calling the function for the
    // same file within a session.
    final stat = await imageFile.stat();
    final cacheKey = '${stat.size}_${stat.modified.millisecondsSinceEpoch}';
    if (_tagCache.containsKey(cacheKey)) {
      debugPrint('[AiService] Tag cache hit — skipping tag call');
      return _tagCache[cacheKey];
    }

    try {
      final url = '$supabaseUrl/functions/v1/tag-clothing';
      // Prefer the signed-in user's access token so the function can verify
      // the caller; fall back to the anon key (also a valid Supabase JWT).
      final token = Supabase.instance.client.auth.currentSession?.accessToken ??
          dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
          dotenv.env['SUPABASE_ANON_KEY'] ??
          '';

      // Downscale before upload — tagging doesn't need full resolution, and a
      // smaller image cuts the upload, the base64 payload, and vision tokens.
      // The edge function detects the real mime from magic bytes, so the
      // filename here is only a hint.
      final rawBytes = await imageFile.readAsBytes();
      final bytes = await downscaleImage(rawBytes, maxDimension: 1024);

      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes(
          'image_file',
          bytes,
          filename: 'item.png',
        ));

      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        debugPrint(
            '[AiService] tag-clothing error ${response.statusCode}: ${response.body}');
        return null;
      }

      final parsed = jsonDecode(response.body) as Map<String, dynamic>;

      List<String> toStringList(dynamic v) =>
          v is List ? v.map((e) => e.toString()).toList() : [];

      debugPrint('[AiService] tags: $parsed');

      final result = AiImageResult(
        processedFile: imageFile,
        detectedType:  _parseType(parsed['type'] as String?),
        colours:       toStringList(parsed['colours']),
        tags:          toStringList(parsed['tags']),
        style:         parsed['style'] as String?,
        description:   parsed['description'] as String?,
      );
      _tagCache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('[AiService] tagging failed: $e');
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ClothingType? _parseType(String? raw) {
    if (raw == null) return null;
    try { return ClothingType.values.byName(raw.trim().toLowerCase()); }
    catch (_) { return null; }
  }

  Future<File> _writeTempFile(Uint8List bytes, String name) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name');
    await file.writeAsBytes(bytes);
    return file;
  }
}
