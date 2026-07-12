import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:virtual_wardrobe/models/clothing_item.dart';

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

  const AiImageResult({
    required this.processedFile,
    this.cutoutFile,
    this.detectedType,
    this.tags = const [],
    this.colours = const [],
    this.style,
    this.description,
  });
}

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  // In-memory cache: file-stat key → tag result. Avoids re-calling Claude
  // when the user uploads the same image more than once in a session.
  final Map<String, AiImageResult> _tagCache = {};

  // Keys are read from .env — never hard-code them.
  String get _anthropicKey =>
      dotenv.env['ANTHROPIC_API_KEY'] ?? '';

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
      processedFile: displayFile,
      cutoutFile:    cutoutFile,
      detectedType:  tags?.detectedType,
      tags:          tags?.tags    ?? [],
      colours:       tags?.colours ?? [],
      style:         tags?.style,
      description:   tags?.description,
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

  /// Sends the image to Claude and asks it to return structured JSON tags.
  Future<AiImageResult?> _tagWithClaude(File imageFile) async {
    if (_anthropicKey.isEmpty) {
      debugPrint('[AiService] ANTHROPIC_API_KEY not set — skipping tagging');
      return null;
    }

    // Cache key: size + last-modified avoids re-calling Claude for the same file.
    final stat = await imageFile.stat();
    final cacheKey = '${stat.size}_${stat.modified.millisecondsSinceEpoch}';
    if (_tagCache.containsKey(cacheKey)) {
      debugPrint('[AiService] Tag cache hit — skipping Claude call');
      return _tagCache[cacheKey];
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Detect mime type from magic bytes — extension is unreliable because
      // the edge function fallback returns JPEG bytes in a .png-named file.
      final mediaType = (imageBytes.length >= 4 &&
              imageBytes[0] == 0x89 &&
              imageBytes[1] == 0x50 &&
              imageBytes[2] == 0x4E &&
              imageBytes[3] == 0x47)
          ? 'image/png'
          : 'image/jpeg';

      final body = jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 256,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type':       'base64',
                  'media_type': mediaType,
                  'data':       base64Image,
                },
              },
              {
                'type': 'text',
                'text': '''You are a fashion tagging assistant. 
Analyse this clothing item image and respond ONLY with a valid JSON object — no markdown, no explanation, just raw JSON.

Return exactly this structure:
{
  "type": "<one of: top | trouser | outwear | dress | shoe | accessory | headwear>",
  "colours": ["<primary colour>", "<secondary colour if present>"],
  "tags": ["<tag1>", "<tag2>", "<tag3>"],
  "style": "<one short style label e.g. casual | formal | streetwear | athleisure | minimalist | vintage | preppy>",
  "description": "<one sentence describing the item>"
}

Rules:
- colours: use simple English colour names (e.g. "navy blue", "off-white")
- tags: 2–5 short lowercase words (material, occasion, season, fit, etc.)
- style: single word or short phrase
- description: max 15 words, factual'''
              },
            ],
          }
        ],
      });

      final response = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'Content-Type':      'application/json',
              'x-api-key':         _anthropicKey,
              'anthropic-version': '2023-06-01',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[AiService] Claude error ${response.statusCode}: ${response.body}');
        return null;
      }

      final decoded     = jsonDecode(response.body) as Map<String, dynamic>;
      final contentList = decoded['content'] as List<dynamic>;
      final rawText     = (contentList.first as Map<String, dynamic>)['text'] as String;

      // Strip any accidental markdown fences before parsing.
      final jsonText = rawText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final Map<String, dynamic> parsed =
          jsonDecode(jsonText) as Map<String, dynamic>;

      List<String> toStringList(dynamic v) =>
          v is List ? v.map((e) => e.toString()).toList() : [];

      final detectedType = _parseType(parsed['type'] as String?);

      debugPrint('[AiService] Claude tags: $parsed');

      final result = AiImageResult(
        processedFile: imageFile,
        detectedType:  detectedType,
        colours:       toStringList(parsed['colours']),
        tags:          toStringList(parsed['tags']),
        style:         parsed['style'] as String?,
        description:   parsed['description'] as String?,
      );
      _tagCache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('[AiService] Claude tagging failed: $e');
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
