import 'package:flutter/material.dart';

/// The canvas transform for one clothing item within a saved outfit.
class OutfitCanvasItem {
  final String itemId;
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

  // Row in `outfit_items` — canvas columns only.
  Map<String, dynamic> toMap() => {
    'clothing_item_id': itemId,
    'canvas_x':        x,
    'canvas_y':        y,
    'canvas_scale':    scale,
    'canvas_rotation': rotation,
    'canvas_size':     size,
  };

  factory OutfitCanvasItem.fromMap(Map<String, dynamic> map) {
    return OutfitCanvasItem(
      itemId:   map['clothing_item_id'] as String,
      x:        (map['canvas_x']        as num).toDouble(),
      y:        (map['canvas_y']        as num).toDouble(),
      scale:    (map['canvas_scale']    as num?)?.toDouble() ?? 1.0,
      rotation: (map['canvas_rotation'] as num?)?.toDouble() ?? 0.0,
      size:     (map['canvas_size']     as num?)?.toDouble() ?? 100.0,
    );
  }

  factory OutfitCanvasItem.fromValues({
    required String itemId,
    required Offset position,
    required double scale,
    required double rotation,
    required double size,
  }) {
    return OutfitCanvasItem(
      itemId:   itemId,
      x:        position.dx,
      y:        position.dy,
      scale:    scale,
      rotation: rotation,
      size:     size,
    );
  }

  @override
  String toString() =>
      'OutfitCanvasItem{itemId: $itemId, x: $x, y: $y, '
      'scale: $scale, rotation: $rotation, size: $size}';
}

/// A saved outfit.  When fetched via the Supabase join
///   outfits.select('*, outfit_items(*)')
/// the nested `outfit_items` list is parsed here to rebuild
/// both [itemIds] (ordered) and optional [canvasItems].
class Outfit {
  final String? id;
  final String name;
  final List<String> itemIds;
  final List<OutfitCanvasItem>? canvasItems;
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

  // Insert payload for the `outfits` table only.
  // outfit_items rows are inserted separately after the outfit is created.
  Map<String, dynamic> toMap(String userId) => {
    'user_id':    userId,
    'name':       name,
    'created_at': createdAt.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  // Parses a row from `outfits` that includes an embedded `outfit_items` list
  // (from a Supabase `.select('*, outfit_items(*)')` call).
  factory Outfit.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['outfit_items'] as List<dynamic>?)
        ?.whereType<Map<String, dynamic>>()
        .toList()
      ?..sort((a, b) =>
          ((a['position'] as int?) ?? 0)
              .compareTo((b['position'] as int?) ?? 0));

    final itemIds = rawItems
        ?.map((e) => e['clothing_item_id'] as String)
        .toList() ??
        [];

    // canvasItems only exist when at least one row has canvas_x set.
    List<OutfitCanvasItem>? canvasItems;
    if (rawItems != null && rawItems.any((e) => e['canvas_x'] != null)) {
      canvasItems = rawItems
          .where((e) => e['canvas_x'] != null)
          .map(OutfitCanvasItem.fromMap)
          .toList();
    }

    return Outfit(
      id:          map['id'] as String?,
      name:        map['name'] as String? ?? 'Untitled',
      itemIds:     itemIds,
      canvasItems: canvasItems,
      createdAt:   map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt:   map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

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
      'Outfit{id: $id, name: $name, itemIds: $itemIds}';
}
