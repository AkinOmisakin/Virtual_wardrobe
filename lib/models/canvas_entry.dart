// import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────
class CanvasEntry {
  final String uid;
  final ClothingItem clothingItem;
  Offset position;
  double scale;
  double rotation;
  bool isSelected;
 
  CanvasEntry({
    required this.uid,
    required this.clothingItem,
    this.position = const Offset(180, 260),
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isSelected = false,
  });
 
  CanvasEntry copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    bool? isSelected,
  }) =>
      CanvasEntry(
        uid: uid,
        clothingItem: clothingItem,
        position: position ?? this.position,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        isSelected: isSelected ?? this.isSelected,
      );
}
