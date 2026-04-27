import 'package:flutter/material.dart';

/// The canvas transform for one clothing item within a saved outfit.
/// Mirrors the mutable fields of [CanvasItem] but is fully serialisable.
class OutfitCanvasItem {
  final String itemId;   // Firestore doc-id of the ClothingItem
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final double size;

  const OutfitCanvasItem({
    required this.itemId,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.size = 100,
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
    'size': size,
  };

  factory OutfitCanvasItem.fromMap(Map<String, dynamic> map) {
    return OutfitCanvasItem(
      itemId:   map['itemId']   as String,
      x:        (map['x']       as num).toDouble(),
      y:        (map['y']       as num).toDouble(),
      scale:    (map['scale']   as num?)?.toDouble() ?? 1.0,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0.0,
      size:     (map['size']    as num?)?.toDouble() ?? 100.0,
    );
  }

  /// Convenience: rebuild from a live CanvasItem (avoids importing CanvasItem
  /// into this model — pass the fields you need instead).
  factory OutfitCanvasItem.fromValues({
    required String itemId,
    required Offset position,
    required double scale,
    required double rotation,
    required double size,
  }) {
    return OutfitCanvasItem(
      itemId: itemId,
      x: position.dx,
      y: position.dy,
      scale: scale,
      rotation: rotation,
      size: size,
    );
  }

  @override
  String toString() =>
      'OutfitCanvasItem{itemId: $itemId, x: $x, y: $y, '
      'scale: $scale, rotation: $rotation, size: $size}';
}

/// A saved outfit: a name, an ordered list of item IDs, and optional canvas
/// state so the exact layout can be restored later.
class Outfit {
  final String? id;          // Firestore doc-id (null before first save)
  final String name;
  final List<String> itemIds;                    // ordered clothing item IDs
  final List<OutfitCanvasItem>? canvasItems;     // null = canvas state not saved
  final DateTime createdAt;
  final DateTime? updatedAt;

  Outfit({
    this.id,
    required this.name,
    required this.itemIds,
    this.canvasItems,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ── serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap(String userId) {
    return {
      'name': name,
      'itemIds': itemIds,
      if (canvasItems != null)
        'canvasItems': canvasItems!.map((c) => c.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'userId': userId,
    };
  }

  factory Outfit.fromMap(Map<String, dynamic> map, {String? docId}) {
    // itemIds — stored as List<dynamic> in Firestore
    final rawIds = map['itemIds'];
    final itemIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : <String>[];

    // canvasItems — optional
    final rawCanvas = map['canvasItems'];
    final canvasItems = rawCanvas is List
        ? rawCanvas
            .whereType<Map<String, dynamic>>()
            .map(OutfitCanvasItem.fromMap)
            .toList()
        : null;

    return Outfit(
      id:          docId,
      name:        map['name'] as String? ?? 'Untitled',
      itemIds:     itemIds,
      canvasItems: canvasItems,
      createdAt:   map['createdAt'] != null
                     ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
                     : DateTime.now(),
      updatedAt:   map['updatedAt'] != null
                     ? DateTime.tryParse(map['updatedAt'] as String)
                     : null,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Returns a copy with updated fields — useful for edits before re-saving.
  Outfit copyWith({
    String? id,
    String? name,
    List<String>? itemIds,
    List<OutfitCanvasItem>? canvasItems,
    DateTime? updatedAt,
  }) {
    return Outfit(
      id:          id          ?? this.id,
      name:        name        ?? this.name,
      itemIds:     itemIds     ?? this.itemIds,
      canvasItems: canvasItems ?? this.canvasItems,
      createdAt:   createdAt,
      updatedAt:   updatedAt   ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'Outfit{id: $id, name: $name, '
      'itemIds: $itemIds, canvasItems: $canvasItems}';
}