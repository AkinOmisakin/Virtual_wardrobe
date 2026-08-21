import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/utils/user_facing_exception.dart';

/// Account-level operations that need server privileges.
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  /// Permanently deletes the signed-in account: every garment, outfit, post,
  /// uploaded photo, and the credit ledger, then the login itself.
  ///
  /// Both stores require this to be reachable from inside the app. It cannot be
  /// done client-side — removing an auth user needs the service role — so it
  /// goes through the `delete-account` edge function, which owns the ordering
  /// and refuses to close the account if the images could not be removed first.
  ///
  /// Signs out on success. Throws [UserFacingException] with a displayable
  /// message on failure, leaving the account intact and retryable.
  Future<void> deleteAccount() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (supabaseUrl.isEmpty || token == null) {
      throw const UserFacingException('Sign in again to delete your account.');
    }

    final resp = await http.post(
      Uri.parse('$supabaseUrl/functions/v1/delete-account'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      // Matches CONFIRM_TOKEN in the edge function. The user types this into
      // the confirmation dialog; it is not sent on their behalf.
      body: jsonEncode({'confirm': 'DELETE'}),
    );

    if (resp.statusCode != 200) {
      String? message;
      try {
        message = (jsonDecode(resp.body) as Map<String, dynamic>)['error'] as String?;
      } on FormatException {
        // Non-JSON body — fall through to the generic message.
      }
      throw UserFacingException(
        message ?? "Couldn't delete your account. Please try again.",
      );
    }

    // The account is gone; clear local credentials so the router sends the user
    // to /login rather than leaving a session pointing at a deleted user.
    try {
      await Supabase.instance.client.auth.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[Account] sign-out after deletion failed: $e');
    }
  }
}
