import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/models/outfit.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/utils/error_messages.dart';

/// An [Outfit] paired with the resolved [ClothingItem] objects for its items.
class ResolvedOutfit {
  final Outfit outfit;
  final List<ClothingItem> items; // same order as outfit.itemIds

  const ResolvedOutfit({required this.outfit, required this.items});
}

class OutfitProvider extends ChangeNotifier {
  final String? userId = Supabase.instance.client.auth.currentUser?.id;

  OutfitProvider({required this.allItems}) {
    _subscribe();
  }

  /// The full clothing catalogue, kept in sync by [ItemProvider].
  /// Call [updateItems] whenever [ItemProvider] delivers a new list.
  List<ClothingItem> allItems;

  List<ResolvedOutfit> _outfits = [];
  RealtimeChannel? _channel;
  bool _isLoading = true;
  String? _error;

  List<ResolvedOutfit> get outfits => _outfits;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── subscription ──────────────────────────────────────────────────────────

  void _subscribe() {
    if (userId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Do an initial fetch then watch both tables for changes.
    _fetchOutfits();

    _channel = Supabase.instance.client
        .channel('outfits_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'outfits',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId!,
          ),
          callback: (_) => _fetchOutfits(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'outfit_items',
          callback: (_) => _fetchOutfits(),
        )
        .subscribe();
  }

  Future<void> _fetchOutfits() async {
    try {
      final data = await Supabase.instance.client
          .from('outfits')
          .select('*, outfit_items(*)')
          .eq('user_id', userId!)
          .order('created_at', ascending: false);

      final raw = (data as List)
          .map((e) => Outfit.fromMap(e as Map<String, dynamic>))
          .toList();
      _outfits = _resolve(raw);
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      _error = friendlyError(e,
          fallback: "Couldn't load your outfits. Please try again.",
          stackTrace: st);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called by the parent widget when [ItemProvider] delivers a new item list,
  /// so resolved outfits stay up to date without re-fetching from Supabase.
  void updateItems(List<ClothingItem> items) {
    allItems = items;
    final raw = _outfits.map((r) => r.outfit).toList();
    _outfits = _resolve(raw);
    notifyListeners();
  }

  // ── resolution ─────────────────────────────────────────────────────────────

  List<ResolvedOutfit> _resolve(List<Outfit> outfits) {
    final itemById = {
      for (final item in allItems)
        if (item.id != null) item.id!: item,
    };

    return outfits.map((outfit) {
      final resolved = outfit.itemIds
          .map((id) => itemById[id])
          .whereType<ClothingItem>()
          .toList();
      return ResolvedOutfit(outfit: outfit, items: resolved);
    }).toList();
  }

  // ── mutations ──────────────────────────────────────────────────────────────

  Future<void> deleteOutfit(String outfitId) async {
    await Supabase.instance.client
        .from('outfits')
        .delete()
        .eq('id', outfitId);
    // Realtime channel triggers _fetchOutfits automatically.
  }

  Future<void> renameOutfit(String outfitId, String newName) async {
    await Supabase.instance.client
        .from('outfits')
        .update({
          'name': newName,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', outfitId);
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }
}
