enum ClothingType {
  top('tops'),
  trouser('trousers'),
  outwear('Outwear'), // Maybe change to outwear?
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

  ClothingItem({
    this.id,
    required this.type,
    required this.imageUrl,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name, // Changed from type.index to type.name (saves 'top', 'shoes', etc.)
      'imageUrl': imageUrl,
      'description': description,
      'createdAt': DateTime.now().toIso8601String(),
    };

  }

  static ClothingType _parseClothingType(dynamic input) {
    if (input == null) return ClothingType.top; // fallback
    final s = input.toString().trim();

    // exact byName (throws if not found)
    try {
      return ClothingType.values.byName(s);
    } catch (_) {}

    // case-insensitive match against enum name
    for (final t in ClothingType.values) {
      if (t.name.toLowerCase() == s.toLowerCase()) return t;
    }

    // case-insensitive match against displayName (e.g. "Shoes", "Jackets")
    for (final t in ClothingType.values) {
      if (t.displayName.toLowerCase() == s.toLowerCase()) return t;
    }

    // try singular/plural variants (remove trailing 's')
    final singular = s.toLowerCase().replaceAll(RegExp(r's$'), '');
    for (final t in ClothingType.values) {
      if (t.name.toLowerCase() == singular) return t;
      if (t.displayName.toLowerCase() == singular) return t;
    }

    // final fallback
    return ClothingType.top;
  }

  factory ClothingItem.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ClothingItem(
      id: docId,
      type: _parseClothingType(map['type']),
      imageUrl: map['imageUrl'],
      description: map['description']
    );
  }

  @override
  String toString() {
    return 'ClothingItem{id: $id, type: $type, imageUrl: $imageUrl, description: $description}';
  }
}