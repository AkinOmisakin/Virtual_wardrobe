import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:virtual_wardrobe/services/report_service.dart';
import 'package:virtual_wardrobe/utils/error_messages.dart';

/// Opens the report sheet for a piece of generated or saved content.
///
/// [contentRef] identifies what is being reported and is also the dedupe key,
/// so the same user filing twice is quietly treated as already-reported.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportedContentType type,
  required String contentRef,
  String? contentUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ReportSheet(
      type: type,
      contentRef: contentRef,
      contentUrl: contentUrl,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.type,
    required this.contentRef,
    this.contentUrl,
  });

  final ReportedContentType type;
  final String contentRef;
  final String? contentUrl;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ReportService.instance.submit(
        type: widget.type,
        contentRef: widget.contentRef,
        contentUrl: widget.contentUrl,
        reason: reason,
        details: _details.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your report has been sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e,
            fallback: "Couldn't send your report. Please try again.");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Keeps the details field above the keyboard.
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report this image',
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoMono(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                'Tell us what is wrong with it and we will review it.',
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                // RadioGroup requires a non-null callback, so the busy guard
                // lives inside it rather than disabling the whole group.
                onChanged: (v) {
                  if (!_busy) setState(() => _reason = v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ReportReason.values
                      .map(
                        (r) => RadioListTile<ReportReason>(
                          value: r,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.black,
                          title: Text(
                            r.label,
                            style: GoogleFonts.robotoMono(
                                fontSize: 12, fontWeight: FontWeight.w400),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                enabled: !_busy,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Anything else? (optional)',
                  hintStyle: GoogleFonts.robotoMono(
                      fontSize: 11, fontWeight: FontWeight.w300),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: GoogleFonts.robotoMono(fontSize: 12),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: Colors.red[600],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (_busy || _reason == null) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Send report',
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
