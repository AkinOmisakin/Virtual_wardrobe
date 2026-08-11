import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only view of the caller's try-on credit balance.
///
/// `user_credits` is SELECT-only under RLS, so this can read the balance
/// directly but cannot change it. Every mutation goes through the `try-on`
/// edge function's service-role connection — see
/// supabase/migrations/20260811000000_credit_ledger.sql.
class CreditsService {
  CreditsService._();
  static final CreditsService instance = CreditsService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Current balance, or 0 when signed out or the row does not exist yet.
  Future<int> balance() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return 0;

    final row = await _db
        .from('user_credits')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();

    return (row?['balance'] as int?) ?? 0;
  }
}
