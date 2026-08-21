import 'package:flutter/foundation.dart';

import 'package:virtual_wardrobe/services/credits_service.dart';

/// Reactive view of the try-on credit balance.
///
/// The balance is owned by the server; this only mirrors it. Nothing here
/// writes a balance locally, because an optimistic client-side number would
/// disagree with the ledger the moment anything failed.
class CreditsProvider extends ChangeNotifier {
  int _balance = 0;
  bool _loading = false;
  bool _disposed = false;

  int get balance => _balance;
  bool get isLoading => _loading;

  Future<void> refresh() async {
    if (_disposed) return;
    _loading = true;
    _safeNotify();
    try {
      _balance = await CreditsService.instance.balance();
    } catch (e) {
      // A failed read leaves the last known balance in place; try-on is gated
      // server-side regardless, so a stale number here is cosmetic.
      debugPrint('[Credits] refresh failed: $e');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  /// Waits for credits bought in the store to appear.
  ///
  /// The store confirms the purchase to the app, but the credits are granted
  /// out-of-band when RevenueCat calls our webhook — usually within a second or
  /// two, occasionally longer. Polling here is what stops the user seeing "0
  /// credits" immediately after paying.
  ///
  /// Returns true once the balance rises above [previousBalance]. A false
  /// return means the grant is late, not lost: it will land whenever the
  /// webhook is delivered, and RevenueCat retries failures.
  Future<bool> awaitTopUp({
    required int previousBalance,
    Duration timeout = const Duration(seconds: 25),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (!_disposed && DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);
      if (_disposed) return false;

      try {
        final latest = await CreditsService.instance.balance();
        if (latest > previousBalance) {
          _balance = latest;
          _safeNotify();
          return true;
        }
      } catch (e) {
        debugPrint('[Credits] poll failed: $e');
      }
    }
    return false;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
