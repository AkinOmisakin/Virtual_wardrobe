// import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/models/canvas_entry.dart';
// import 'package:virtual_wardrobe/components/outfit.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key});

   @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  // ── Firestore stream (mirrors your ItemsPage pattern) ──
  List<ClothingItem>? _inventory;
  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribeInventory();
  }

  void _subscribeInventory() {
    _subscription = FirebaseFirestore.instance
        .collection('clothes')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _inventory = snapshot.docs
            .map((doc) => ClothingItem.fromMap(doc.data(), docId: doc.id))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(

    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      
    );
  }

}