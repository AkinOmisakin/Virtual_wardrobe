import 'package:flutter/material.dart';
import 'package:virtual_wardrobe/components/crop_clipper.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';

class CanvasItem {
  ClothingItem item;
  Offset position;
  double scale;
  double rotation;
  double size;

  /// Visible part of the item, as fractions of its [size] box.
  /// `LTRB(0, 0, 1, 1)` means nothing is cropped; dragging a crop handle
  /// inwards shrinks this rect, dragging it back outwards restores the pixels.
  Rect crop;

  CanvasItem({
    required this.item,
    this.position = const Offset(100, 100),
    this.scale = 1.0,
    this.rotation = 0.0,
    this.size = 150,
    this.crop = kNoCrop,
  });

  bool get isCropped => crop != kNoCrop;
}