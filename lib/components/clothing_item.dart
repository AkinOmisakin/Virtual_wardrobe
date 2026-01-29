enum ClothingType { top, trousers, jacket, dress, shoes, accessory }

class ClothingItem {
  final int? id;
  final String path;
  final ClothingType type;
  final DateTime createdAt;
  String description;

  ClothingItem({
    required this.id,
    required this.path,
    required this.type,
    required this.createdAt,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'type': type.index,
      'createdAt': createdAt.toIso8601String(),
      'description': description,
    };
  }

  factory ClothingItem.fromMap(Map<String, dynamic> map) {
    return ClothingItem(
      id: map['id'],
      path: map['path'],
      type: ClothingType.values[map['type']],
      createdAt: DateTime.parse(map['createdAt']),
      description: map['description']
    );
  }

  @override
  String toString() {
    return 'ClothingItem{id: $id, path: $path, type: $type, createdAt: $createdAt, description: $description}';
  }
}