import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';


class ItemProvider extends ChangeNotifier {
  final String? collection;
  ItemProvider({this.collection}) {
    // Auto-subscribe when provider is created
    subscribe();
  }

  List<ClothingItem> _items = [];
  StreamSubscription<QuerySnapshot>? _subscription;
  bool _isLoading = true;
  String? _error;

  // Exposed getters
  List<ClothingItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Return the collection name or default to 'clothes'
  String get collectionName => collection ?? 'clothes';

  void subscribe() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection(collectionName)
        .snapshots()
        .listen((snapshot) {
      _items = snapshot.docs
          .map((doc) => ClothingItem.fromMap(doc.data(), docId: doc.id))
          .toList();
      _isLoading = false;
      debugPrint('Loaded ${_items.length} clothing items from Firestore');
      // Use a proper logging mechanism in production, or remove this line.
      // Example: logger.info('Loaded ${_items.length} clothing items from Firestore');
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  void unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  // Optional: one-shot refresh
  Future<void> refresh() async {
    try {
      _isLoading = true;
      notifyListeners();
      final snapshot = await FirebaseFirestore.instance.collection(collectionName).get();
      _items = snapshot.docs
          .map((doc) => ClothingItem.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error refreshing items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}