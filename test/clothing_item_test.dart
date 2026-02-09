import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_wardrobe/components/clothing_item.dart';
import 'package:flutter/material.dart';

void main() {
  group('ClothingItem', () {
    test('should create a ClothingItem with given properties', () {
      final clothingItem = ClothingItem(
        type: ClothingType.top,
        image: Image.asset('assets/images/top.png'),
        description: 'A stylish top',
      );

      expect(clothingItem.type, ClothingType.top);
      expect(clothingItem.image, isA<Image>());
      expect(clothingItem.description, 'A stylish top');
    });

    test('toString should return correct string representation', () {
      final clothingItem = ClothingItem(
        type: ClothingType.dress,
        image: Image.asset('assets/images/dress.png'),
        description: 'A beautiful dress',
      );

      expect(clothingItem.toString(), 'ClothingItem{type: ClothingType.dress, description: A beautiful dress}');
    });
  });
}