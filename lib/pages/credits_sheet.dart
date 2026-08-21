import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:virtual_wardrobe/services/credits_provider.dart';
import 'package:virtual_wardrobe/services/purchases_service.dart';

/// Opens the top-up sheet. Resolves to true if credits actually arrived, so a
/// caller can retry whatever the user was blocked on.
Future<bool> showCreditsSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _CreditsSheet(),
  );
  return result ?? false;
}

class _CreditsSheet extends StatefulWidget {
  const _CreditsSheet();

  @override
  State<_CreditsSheet> createState() => _CreditsSheetState();
}

class _CreditsSheetState extends State<_CreditsSheet> {
  List<Package> _packs = const [];
  bool _loading = true;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final packs = await PurchasesService.instance.creditPacks();
    if (!mounted) return;
    setState(() {
      _packs = packs;
      _loading = false;
    });
  }

  Future<void> _buy(Package pack) async {
    final credits = context.read<CreditsProvider>();
    final before = credits.balance;

    setState(() {
      _busy = true;
      _status = null;
    });

    final outcome = await PurchasesService.instance.buy(pack);
    if (!mounted) return;

    switch (outcome) {
      case PurchaseOutcome.cancelled:
        setState(() => _busy = false);
        return;
      case PurchaseOutcome.unavailable:
      case PurchaseOutcome.failed:
        setState(() {
          _busy = false;
          _status = "That purchase didn't go through. You haven't been charged "
              'for anything that failed.';
        });
        return;
      case PurchaseOutcome.success:
        break;
    }

    // Paid, but the credits are granted by our webhook rather than by the app,
    // so wait for them rather than claiming success immediately.
    setState(() => _status = 'Payment received — adding your credits…');
    final arrived = await credits.awaitTopUp(previousBalance: before);
    if (!mounted) return;

    if (arrived) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _status = 'Payment received. Your credits are taking a moment to '
            'arrive — they will appear shortly.';
      });
    }
  }

  Future<void> _restore() async {
    final credits = context.read<CreditsProvider>();
    setState(() {
      _busy = true;
      _status = null;
    });

    await PurchasesService.instance.restore();
    await credits.refresh();
    if (!mounted) return;

    setState(() {
      _busy = false;
      _status = 'Purchases restored.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<CreditsProvider>().balance;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Try-on credits',
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(
                  fontSize: 18, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 6),
            Text(
              'One credit puts one garment on your photo. '
              'You have $balance.',
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2),
                ),
              )
            else if (_packs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  PurchasesService.instance.isAvailable
                      ? "Credit packs aren't available right now. "
                          'Please try again later.'
                      : 'Purchases are unavailable on this device.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoMono(
                      fontSize: 12, fontWeight: FontWeight.w300),
                ),
              )
            else
              ..._packs.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PackTile(
                      package: p,
                      enabled: !_busy,
                      onTap: () => _buy(p),
                    ),
                  )),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(
                _status!,
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoMono(
                    fontSize: 11, fontWeight: FontWeight.w300),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 14),
              const Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Google Play requires a visible restore path, and it is the
            // recovery route if a webhook was ever missed.
            TextButton(
              onPressed: _busy ? null : _restore,
              child: Text(
                'Restore purchases',
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.package,
    required this.enabled,
    required this.onTap,
  });

  final Package package;
  final bool enabled;
  final VoidCallback onTap;

  /// Play appends "(App Name)" to product titles; it is noise in a list that is
  /// already inside the app.
  String get _title =>
      package.storeProduct.title.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: Colors.black),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              _title,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.robotoMono(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            package.storeProduct.priceString,
            style: GoogleFonts.robotoMono(
                fontSize: 13, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
