import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/utils/user_facing_exception.dart';

/// What is being reported.
enum ReportedContentType {
  tryOnResult('tryon_result'),
  post('post');

  const ReportedContentType(this.wire);
  final String wire;
}

/// Report categories. `minor` is kept separate rather than folded into
/// `sexual` so those reports can be triaged first — for an app that renders
/// clothing onto photos of people it is the highest-severity case.
enum ReportReason {
  sexual('sexual', 'Sexually explicit'),
  minor('minor', 'Involves a minor'),
  violent('violent', 'Violent or graphic'),
  hateful('hateful', 'Hateful or harassing'),
  likeness("likeness", "Uses someone's likeness without consent"),
  other('other', 'Something else');

  const ReportReason(this.wire, this.label);
  final String wire;
  final String label;
}

/// Files reports of offensive AI-generated content.
///
/// Required by Google Play's generative-AI policy: an app that generates
/// content must let users flag it from inside the app. Rows are insert-only
/// under RLS — see supabase/migrations/20260811000300_content_reports.sql.
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  Future<void> submit({
    required ReportedContentType type,
    required String contentRef,
    required ReportReason reason,
    String? contentUrl,
    String? details,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const UserFacingException('Sign in to report content.');
    }

    try {
      await Supabase.instance.client.from('content_reports').insert({
        'reporter_id': userId,
        'content_type': type.wire,
        'content_ref': contentRef,
        'content_url': contentUrl,
        'reason': reason.wire,
        'details': (details == null || details.trim().isEmpty)
            ? null
            : details.trim(),
      });
    } on PostgrestException catch (e) {
      // Unique violation on (reporter_id, content_ref) — the dedupe index doing
      // its job. Reporting twice is not an error worth alarming anyone about.
      if (e.code == '23505') {
        throw const UserFacingException(
          "You've already reported this. Thanks — we're looking at it.",
        );
      }
      throw const UserFacingException(
        "Couldn't send your report. Please try again.",
      );
    }
  }
}
