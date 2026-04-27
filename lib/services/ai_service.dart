import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:virtual_wardrobe/models/clothing_item.dart';

/// Result returned after AI processing an image.
class AiImageResult {
  /// The background-removed image written to a temp file.
  /// Will be the original image if background removal fails.
  final File processedFile;

  /// Detected clothing type (may be null if detection fails).
  final ClothingType? detectedType;

  /// Short descriptive tags, e.g. ['casual', 'cotton', 'summer'].
  final List<String> tags;

  /// Detected colours, e.g. ['white', 'navy blue'].
  final List<String> colours;

  /// Broad style label, e.g. 'streetwear'.
  final String? style;

  /// Auto-generated description sentence.
  final String? description;

  const AiImageResult({
    required this.processedFile,
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

  // Keys are read from .env — never hard-code them.
  String get _removeBgKey =>
      dotenv.env['REMOVE_BG_API_KEY'] ?? '';
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
    // Step 1 — background removal
    final File processedFile = await _removeBackground(imageFile);

    // Step 2 — Claude vision tagging (send the bg-removed image)
    final AiImageResult? tags = await _tagWithClaude(processedFile);

    return AiImageResult(
      processedFile: processedFile,
      detectedType:  tags?.detectedType,
      tags:          tags?.tags          ?? [],
      colours:       tags?.colours       ?? [],
      style:         tags?.style,
      description:   tags?.description,
    );
  }

  // ── Background removal ────────────────────────────────────────────────────

  /// Calls remove.bg and writes the result PNG to the temp directory.
  /// Falls back to the original file on any error.
  Future<File> _removeBackground(File imageFile) async {
    if (_removeBgKey.isEmpty) {
      debugPrint('[AiService] REMOVE_BG_API_KEY not set — skipping bg removal');
      return imageFile;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      )
        ..headers['X-Api-Key'] = _removeBgKey
        ..fields['size'] = 'auto'
        ..files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));

      final response = await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        final outFile = await _writeTempFile(bytes, 'bg_removed.png');
        debugPrint('[AiService] Background removed successfully');
        return outFile;
      } else {
        final body = await response.stream.bytesToString();
        debugPrint('[AiService] remove.bg error ${response.statusCode}: $body');
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

    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Detect mime type from file extension.
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final body = jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 512,
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

      return AiImageResult(
        processedFile: imageFile,
        detectedType:  detectedType,
        colours:       toStringList(parsed['colours']),
        tags:          toStringList(parsed['tags']),
        style:         parsed['style'] as String?,
        description:   parsed['description'] as String?,
      );
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
