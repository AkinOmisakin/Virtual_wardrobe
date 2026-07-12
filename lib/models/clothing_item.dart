enum ClothingType {
  top('tops'),
  trouser('trousers'),
  outwear('Outwear'),
  dress('Dresses'),
  shoe('Shoes'),
  accessory('Accessories'),
  headwear('Headwear');

  final String displayName;
  const ClothingType(this.displayName);
}

class ClothingItem {
  final String? id;
  final ClothingType type;
  final String imageUrl;
  final String? cutoutUrl;
  final String? description;
  final List<String> tags;
  final List<String> colours;
  final String? style;

  ClothingItem({
    this.id,
    required this.type,
    required this.imageUrl,
    this.cutoutUrl,
    this.description = '',
    this.tags = const [],
    this.colours = const [],
    this.style,
  });

  // Supabase insert payload — snake_case to match the DB schema.
  Map<String, dynamic> toMap(String userId) => {
    'user_id':     userId,
    'type':        type.name,
    'image_url':   imageUrl,
    'cutout_url':  cutoutUrl,
    'description': description,
    'tags':        tags,
    'colours':     colours,
    'style':       style,
  };

  static ClothingType _parseClothingType(dynamic input) {
    if (input == null) return ClothingType.top;
    final s = input.toString().trim();
    try { return ClothingType.values.byName(s); } catch (_) {}
    for (final t in ClothingType.values) {
      if (t.name.toLowerCase() == s.toLowerCase()) return t;
    }
    for (final t in ClothingType.values) {
      if (t.displayName.toLowerCase() == s.toLowerCase()) return t;
    }
    final singular = s.toLowerCase().replaceAll(RegExp(r's$'), '');
    for (final t in ClothingType.values) {
      if (t.name.toLowerCase() == singular) return t;
      if (t.displayName.toLowerCase() == singular) return t;
    }
    return ClothingType.top;
  }

  // Parses a row from the Supabase `clothing_items` table (snake_case).
  factory ClothingItem.fromMap(Map<String, dynamic> map) {
    List<String> toStringList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : [];

    return ClothingItem(
      id:          map['id'] as String?,
      type:        _parseClothingType(map['type']),
      imageUrl:    map['image_url'] as String? ?? '',
      cutoutUrl:   map['cutout_url'] as String?,
      description: map['description'] as String?,
      tags:        toStringList(map['tags']),
      colours:     toStringList(map['colours']),
      style:       map['style'] as String?,
    );
  }

  @override
  String toString() => 'ClothingItem{id: $id, type: $type, '
      'imageUrl: $imageUrl, tags: $tags, colours: $colours, style: $style}';
}
