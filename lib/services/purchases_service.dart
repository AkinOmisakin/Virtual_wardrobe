import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Outcome of a purchase attempt. Success only means the store took the money —
/// the credits arrive separately when RevenueCat calls our webhook, so callers
/// must still poll the balance. See [CreditsProvider.awaitTopUp].
enum PurchaseOutcome { success, cancelled, failed, unavailable }

/// Thin wrapper over the RevenueCat SDK.
///
/// Two rules this class exists to enforce:
///
///  * **The app user id must be the Supabase user id.** Otherwise RevenueCat
///    sends an anonymous `$RCAnonymousID:…` to the webhook, which has no
///    account to credit — the user is charged and gets nothing. The auth
///    subscription below keeps the two identities in lockstep.
///  * **Nothing here grants credits.** The client cannot be trusted with the
///    balance, so entitlement is decided server-side from the store's own
///    webhook. This class only starts purchases and reads the catalogue.
class PurchasesService {
  PurchasesService._();
  static final PurchasesService instance = PurchasesService._();

  bool _configured = false;

  /// False when the SDK could not be configured — no API key, or a platform
  /// the SDK does not support (web, desktop). The app stays fully usable; only
  /// the top-up sheet is hidden.
  bool get isAvailable => _configured;

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static String? get _apiKey {
    if (kIsWeb) return null;
    final key = Platform.isIOS
        ? dotenv.env['REVENUECAT_IOS_API_KEY']
        : dotenv.env['REVENUECAT_ANDROID_API_KEY'];
    return (key == null || key.isEmpty) ? null : key;
  }

  /// Safe to call on every startup. Never throws: a purchases outage must not
  /// stop the app from launching.
  Future<void> initialize() async {
    if (_configured || !_isSupportedPlatform) return;

    final apiKey = _apiKey;
    if (apiKey == null) {
      debugPrint('[Purchases] no API key configured — purchases disabled');
      return;
    }

    // RevenueCat's Test Store key bypasses the real stores entirely: shipped in
    // a release build it would let anyone mint credits for free. Refuse rather
    // than rely on remembering to swap it before handing out a build.
    if (kReleaseMode && apiKey.startsWith('test_')) {
      debugPrint('[Purchases] refusing to use a Test Store key in a release '
          'build — set the goog_ key in .env');
      return;
    }

    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);

      // Configuring with the current user id avoids ever creating an anonymous
      // RevenueCat identity for an already-signed-in user.
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = userId,
      );
      _configured = true;

      _syncIdentityWithAuth();
    } catch (e, st) {
      debugPrint('[Purchases] configure failed: $e\n$st');
    }
  }

  /// Keeps the RevenueCat identity pinned to the Supabase session for the
  /// lifetime of the process.
  void _syncIdentityWithAuth() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final userId = data.session?.user.id;
      try {
        if (userId != null) {
          await Purchases.logIn(userId);
        } else {
          await Purchases.logOut();
        }
      } on PlatformException catch (e) {
        // logOut throws if the SDK is already anonymous; harmless.
        debugPrint('[Purchases] identity sync: ${e.message}');
      }
    });
  }

  /// Credit packs from the current RevenueCat offering, or an empty list if the
  /// catalogue cannot be reached.
  Future<List<Package>> creditPacks() async {
    if (!_configured) return const [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? const [];
    } on PlatformException catch (e) {
      debugPrint('[Purchases] getOfferings failed: ${e.message}');
      return const [];
    }
  }

  Future<PurchaseOutcome> buy(Package package) async {
    if (!_configured) return PurchaseOutcome.unavailable;
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      return PurchaseOutcome.success;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      debugPrint('[Purchases] purchase failed: $code ${e.message}');
      return PurchaseOutcome.failed;
    }
  }

  /// Re-syncs past purchases with RevenueCat. Play requires a visible restore
  /// path, and it is the recovery route when a webhook was missed.
  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      await Purchases.restorePurchases();
      return true;
    } on PlatformException catch (e) {
      debugPrint('[Purchases] restore failed: ${e.message}');
      return false;
    }
  }
}
