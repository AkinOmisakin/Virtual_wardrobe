// import 'package:flutter/material.dart';

enum ClothingType { top, trousers, jacket, dress, shoes, accessory }


class ClothingItem {
  final ClothingType type;
  final String imageUrl;
  final String? description;

  ClothingItem({
    required this.type,
    required this.imageUrl,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'imageUrl': imageUrl,
      'description': description,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  factory ClothingItem.fromMap(Map<String, dynamic> map) {
    return ClothingItem(
      type: ClothingType.values[map['type']],
      imageUrl: map['imageUrl'],
      description: map['description']
    );
  }

  @override
  String toString() {
    return 'ClothingItem{type: $type, imageUrl: $imageUrl, description: $description}';
  }
}
