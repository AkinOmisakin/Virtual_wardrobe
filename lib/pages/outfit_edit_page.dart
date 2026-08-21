import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/pages/canvas.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';

/// Full-screen editor for an outfit that has already been saved.
///
/// This is the canvas screen in a different mode rather than a second copy of
/// it: same gestures, same crop handles, same inventory sheet along the bottom.
/// What changes is that the canvas opens pre-loaded with [resolved], saving
/// overwrites that outfit instead of creating a new one, and there is no app
/// bar or bottom navigation — the X in the top right corner is the way out.
class OutfitEditPage extends StatelessWidget {
  const OutfitEditPage({super.key, required this.resolved});

  final ResolvedOutfit resolved;

  @override
  Widget build(BuildContext context) {
    // Only the create path writes user_id, so an empty string here is never
    // sent anywhere — editing works off the outfit's existing row.
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    return CanvasScreen(userId: userId, editing: resolved);
  }
}
