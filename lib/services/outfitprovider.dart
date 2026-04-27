import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:virtual_wardrobe/models/outfit.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// An [Outfit] paired with the resolved [ClothingItem] objects for its items.
/// This is what [OutfitProvider] exposes to the UI — no extra Firestore reads
/// needed at display time.
class ResolvedOutfit {
  final Outfit outfit;
  final List<ClothingItem> items; // same order as outfit.itemIds

  const ResolvedOutfit({required this.outfit, required this.items});
}

class OutfitProvider extends ChangeNotifier {
  final String? userId = FirebaseAuth.instance.currentUser!.uid;
  OutfitProvider({required this.allItems}) {
    _subscribe();
  }

  /// The full catalogue of clothing items, kept in sync by [ItemProvider].
  /// Call [updateItems] whenever [ItemProvider] rebuilds its list.
  List<ClothingItem> allItems;

  List<ResolvedOutfit> _outfits = [];
  StreamSubscription<QuerySnapshot>? _subscription;
  bool _isLoading = true;
  String? _error;

  List<ResolvedOutfit> get outfits => _outfits;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── subscription ──────────────────────────────────────────────────────────

  void _subscribe() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection('outfits')
        .where('userId', isEqualTo: userId)
        // .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        final raw = snapshot.docs
            .map((doc) => Outfit.fromMap(doc.data(), docId: doc.id))
            .toList();
        _outfits = _resolve(raw);
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Called by the parent widget when [ItemProvider] delivers a new item list,
  /// so resolved outfits stay up to date without re-fetching from Firestore.
  void updateItems(List<ClothingItem> items) {
    allItems = items;
    // Re-resolve with the fresh item catalogue
    final raw = _outfits.map((r) => r.outfit).toList();
    _outfits = _resolve(raw);
    notifyListeners();
  }

  // ── resolution ─────────────────────────────────────────────────────────────

  /// Matches each outfit's itemIds against the in-memory item catalogue.
  /// Items that no longer exist in the catalogue are silently skipped —
  /// this handles deleted clothing gracefully.
  List<ResolvedOutfit> _resolve(List<Outfit> outfits) {
    final itemById = {
      for (final item in allItems)
        if (item.id != null) item.id!: item,
    };

    return outfits.map((outfit) {
      final resolved = outfit.itemIds
          .map((id) => itemById[id])
          .whereType<ClothingItem>() // drops nulls (deleted items)
          .toList();
      return ResolvedOutfit(outfit: outfit, items: resolved);
    }).toList();
  }

  // ── mutations ──────────────────────────────────────────────────────────────

  Future<void> deleteOutfit(String outfitId) async {
    await FirebaseFirestore.instance
        .collection('outfits')
        .doc(outfitId)
        .delete();
    // Stream will update _outfits automatically
  }

  Future<void> renameOutfit(String outfitId, String newName) async {
    await FirebaseFirestore.instance
        .collection('outfits')
        .doc(outfitId)
        .update({
      'name': newName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
