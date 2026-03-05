import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:virtual_wardrobe/models/clothing_item.dart';


class ItemProvider extends ChangeNotifier {
  List<ClothingItem>? _items;
  StreamSubscription<QuerySnapshot>? _subscription;
  bool _isLoading = true;
  String? _error;

  // Exposed getters
  List<ClothingItem>? get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Auto-subscribe when provider is created
  ItemProvider() {
    subscribe();
  }

  void subscribe() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection('clothes')
        .snapshots()
        .listen((snapshot) {
      _items = snapshot.docs
          .map((doc) => ClothingItem.fromMap(doc.data(), docId: doc.id))
          .toList();
      _isLoading = false;
      debugPrint('Loaded ${_items!.length} clothing items from Firestore');
      notifyListeners();
    }, onError: (e) {
      _error = e?.toString() ?? 'Unknown error';
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
      final snapshot = await FirebaseFirestore.instance.collection('clothes').get();
      _items = snapshot.docs
          .map((doc) => ClothingItem.fromMap(doc.data(), docId: doc.id))
          .toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
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