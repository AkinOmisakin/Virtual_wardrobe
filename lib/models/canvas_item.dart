import 'package:flutter/material.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';

class CanvasItem {
  ClothingItem item;
  Offset position;
  double scale;
  double rotation;
  double size;

  CanvasItem({
    required this.item,
    this.position = const Offset(100, 100),
    this.scale = 1.0,
    this.rotation = 0.0,
    this.size = 150,
  });
}