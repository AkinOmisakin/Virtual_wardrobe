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
  final String? description;

  /// AI-generated tags, e.g. ['casual', 'summer', 'cotton']
  final List<String> tags;

  /// AI-detected colours, e.g. ['white', 'navy']
  final List<String> colours;

  /// AI-detected style, e.g. 'streetwear', 'formal', 'minimalist'
  final String? style;

  ClothingItem({
    this.id,
    required this.type,
    required this.imageUrl,
    this.description = '',
    this.tags = const [],
    this.colours = const [],
    this.style,
  });

  Map<String, dynamic> toMap(String userId) {
    return {
      'type':        type.name,
      'imageUrl':    imageUrl,
      'description': description,
      'tags':        tags,
      'colours':     colours,
      'style':       style,
      'createdAt':   DateTime.now().toIso8601String(),
      'userId': userId
    };
  }

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

  factory ClothingItem.fromMap(Map<String, dynamic> map, {String? docId}) {
    List<String> _toStringList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : [];

    return ClothingItem(
      id:          docId,
      type:        _parseClothingType(map['type']),
      imageUrl:    map['imageUrl'] as String? ?? '',
      description: map['description'] as String?,
      tags:        _toStringList(map['tags']),
      colours:     _toStringList(map['colours']),
      style:       map['style'] as String?,
    );
  }

  @override
  String toString() => 'ClothingItem{id: $id, type: $type, '
      'imageUrl: $imageUrl, tags: $tags, colours: $colours, style: $style}';
}
