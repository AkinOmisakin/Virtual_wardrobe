import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/services/credits_service.dart';
import 'package:virtual_wardrobe/utils/user_facing_exception.dart';

/// Progress callback so the UI can show which garment is being applied.
typedef TryOnProgress = void Function(int currentStep, int totalSteps, String label);

class TryOnService {
  TryOnService._();
  static final TryOnService instance = TryOnService._();

  // The Replicate token and pinned model version now live in the `try-on`
  // edge function — the client only ever talks to Supabase.
  String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  /// Try-on spends credits, so it is billed to a real account. There is no
  /// publishable-key fallback any more — the edge function rejects anything
  /// that is not a user session with 401.
  String _requireAccessToken() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const UserFacingException(
        'Sign in to use try-on.',
        code: 'unauthenticated',
      );
    }
    return token;
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${_requireAccessToken()}',
        'Content-Type': 'application/json',
      };

  // ── public entry point ──────────────────────────────────────────────────────

  /// Applies every garment in [items] onto [personImageUrl], one at a time,
  /// feeding each result back in as the human image for the next garment.
  ///
  /// Returns the URL of the final composited image, or throws on failure.
  Future<String> tryOnOutfit({
    required String personImageUrl,
    required List<ClothingItem> items,
    TryOnProgress? onProgress,
  }) async {
    if (_supabaseUrl.isEmpty) {
      throw Exception('SUPABASE_URL not set in .env');
    }
    if (items.isEmpty) {
      throw Exception('No items to try on.');
    }

    _requireAccessToken();

    // Order matters for layering: bottoms first, then tops, then outerwear,
    // so outer layers visually sit on top. Dresses replace top+bottom.
    final ordered = orderForLayering(items);

    // Each garment is a separate paid prediction. Check the whole outfit is
    // affordable before starting, otherwise the user pays for the first two
    // layers and then hits a 402 on the third with nothing usable to show.
    // Advisory only — the edge function is still the authority.
    final billable = ordered.where((i) => categoryFor(i.type) != null).length;
    if (billable == 0) {
      throw const UserFacingException(
        "None of those items can be tried on yet — try-on supports tops, "
        "bottoms, outerwear and dresses.",
      );
    }
    final credits = await CreditsService.instance.balance();
    if (credits < billable) {
      throw UserFacingException(
        credits == 0
            ? "You're out of try-on credits."
            : 'That outfit needs $billable credits and you have $credits.',
        code: 'insufficient_credits',
      );
    }

    String currentHuman = personImageUrl;
    final total = ordered.length;

    for (var i = 0; i < ordered.length; i++) {
      final item = ordered[i];
      final category = categoryFor(item.type);

      // Skip items IDM-VTON can't place (e.g. accessories, headwear, shoes).
      if (category == null) {
        debugPrint('[TryOn] Skipping ${item.type.name} — unsupported category');
        continue;
      }

      onProgress?.call(i + 1, total, 'Applying ${item.type.displayName}…');

      currentHuman = await _runSingleTryOn(
        humanImageUrl: currentHuman,
        garmentImageUrl: item.imageUrl,
        category: category,
        garmentDescription: _describe(item),
      );
    }

    return currentHuman;
  }

  // ── single garment try-on (one Replicate prediction, via edge function) ─────

  Future<String> _runSingleTryOn({
    required String humanImageUrl,
    required String garmentImageUrl,
    required String category,
    required String garmentDescription,
  }) async {
    final url = '$_supabaseUrl/functions/v1/try-on';

    // 1. Create the prediction. The edge function holds the Replicate token
    // and the pinned model version, and returns just the prediction id.
    final createResp = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode({
        'action':      'create',
        'human_img':   humanImageUrl,
        'garm_img':    garmentImageUrl,
        'category':    category,
        'garment_des': garmentDescription,
      }),
    );

    if (createResp.statusCode != 200) {
      throw _mapError(createResp, 'Try-on create failed');
    }

    final created = jsonDecode(createResp.body) as Map<String, dynamic>;
    final id = created['id'] as String?;
    if (id == null) throw Exception('Try-on create returned no id');

    // 2. Poll until the prediction is done.
    return _pollPrediction(url, id);
  }

  Future<String> _pollPrediction(String url, String id) async {
    const maxAttempts = 60;          // ~60 × 2s = up to 2 minutes
    const interval = Duration(seconds: 2);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(interval);

      final resp = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({'action': 'poll', 'id': id}),
      );

      if (resp.statusCode != 200) {
        throw _mapError(resp, 'Try-on poll failed');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = data['status'] as String;

      switch (status) {
        case 'succeeded':
          final output = data['output'];
          // Output is a single URL string (or occasionally a list).
          if (output is String) return output;
          if (output is List && output.isNotEmpty) return output.first as String;
          throw Exception('Try-on returned empty output');
        case 'failed':
        case 'canceled':
          throw Exception('Try-on failed: ${data['error'] ?? status}');
        default:
          // 'starting' or 'processing' — keep polling.
          break;
      }
    }
    throw Exception('Try-on timed out. Please try again.');
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// The edge function returns `{error, code}` for the cases a user can act on
  /// (out of credits, signed out, daily cap). Those messages are written for
  /// display, so they are passed through; anything else stays generic.
  Exception _mapError(http.Response resp, String fallback) {
    String? message;
    String? code;
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      message = body['error'] as String?;
      code = body['code'] as String?;
    } on FormatException {
      // Non-JSON body (e.g. a gateway error page) — fall through to generic.
    }

    switch (resp.statusCode) {
      case 401:
      case 402:
      case 503:
        return UserFacingException(
          message ?? 'Try-on is unavailable right now.',
          code: code,
        );
      default:
        return Exception('$fallback: ${resp.body}');
    }
  }

  /// Maps a ClothingType to an IDM-VTON category, or null if unsupported.
  /// Public + static so it can be unit-tested without a network call.
  @visibleForTesting
  static String? categoryFor(ClothingType type) {
    switch (type) {
      case ClothingType.top:
      case ClothingType.outwear:
        return 'upper_body';
      case ClothingType.trouser:
        return 'lower_body';
      case ClothingType.dress:
        return 'dresses';
      case ClothingType.shoe:
      case ClothingType.accessory:
      case ClothingType.headwear:
        return null; // IDM-VTON only handles body garments
    }
  }

  /// Layering order: lower body → upper body → outerwear.
  /// Dresses are treated as a single full-body layer applied first.
  /// Public + static so it can be unit-tested without a network call.
  @visibleForTesting
  static List<ClothingItem> orderForLayering(List<ClothingItem> items) {
    int rank(ClothingType t) {
      switch (t) {
        case ClothingType.dress:   return 0;
        case ClothingType.trouser: return 1;
        case ClothingType.top:     return 2;
        case ClothingType.outwear: return 3;
        default:                   return 4; // unsupported, skipped anyway
      }
    }
    final sorted = [...items]..sort((a, b) => rank(a.type).compareTo(rank(b.type)));
    return sorted;
  }

  /// Builds a garment description from the item's AI tags for better results.
  String _describe(ClothingItem item) {
    final parts = <String>[
      ...item.colours,
      item.style ?? '',
      item.type.displayName.toLowerCase(),
    ].where((s) => s.isNotEmpty);
    final desc = parts.join(' ').trim();
    return desc.isEmpty ? item.type.displayName : desc;
  }
}
