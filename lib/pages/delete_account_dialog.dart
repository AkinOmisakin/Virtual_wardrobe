import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:virtual_wardrobe/services/account_service.dart';
import 'package:virtual_wardrobe/utils/error_messages.dart';

/// Confirmation dialog for permanent account deletion.
///
/// Deliberately awkward: the user has to type DELETE. Everything this removes
/// is unrecoverable — there are no backups on the free tier — so a single
/// mis-tap must not be enough.
Future<void> showDeleteAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _confirmed => _controller.text.trim() == 'DELETE';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AccountService.instance.deleteAccount();
      if (!mounted) return;
      // The router's auth listener sends us to /login once the session clears.
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e,
            fallback: "Couldn't delete your account. Please try again.");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Delete account?',
        style: GoogleFonts.robotoMono(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes your wardrobe, outfits, posts, uploaded '
            'photos and any remaining try-on credits. It cannot be undone and '
            'credits are not refundable.',
            style: GoogleFonts.robotoMono(
                fontSize: 12, fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 16),
          Text(
            'Type DELETE to confirm.',
            style: GoogleFonts.robotoMono(
                fontSize: 11, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            style: GoogleFonts.robotoMono(fontSize: 13),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: Colors.red[600],
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.robotoMono(fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: (_busy || !_confirmed) ? null : _delete,
          child: Text(
            'Delete forever',
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              color: _confirmed ? Colors.red : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
