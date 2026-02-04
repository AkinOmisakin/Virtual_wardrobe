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

      expect(clothingItem.toString(),
          'ClothingItem{type: ClothingType.dress, description: A beautiful dress}');
    });

    test('default description is empty string when omitted', () {
      final item = ClothingItem(
        type: ClothingType.shoes,
        image: Image.asset('assets/images/shoes.png'),
      );

      expect(item.description, '');
      expect(item.toString(),
          'ClothingItem{type: ClothingType.shoes, description: }');
    });

    test('two items with same properties produce same toString but are distinct instances', () {
      final a = ClothingItem(
        type: ClothingType.jacket,
        image: Image.asset('assets/images/jacket.png'),
        description: 'Warm jacket',
      );
      final b = ClothingItem(
        type: ClothingType.jacket,
        image: Image.asset('assets/images/jacket.png'),
        description: 'Warm jacket',
      );

      expect(a.toString(), b.toString());
      expect(identical(a, b), isFalse);
      expect(a == b, isFalse); // Equality not overridden, so should be false
    });

    test('ClothingType enum has expected values and indices', () {
      expect(ClothingType.values.length, 6);
      expect(ClothingType.top.index, 0);
      expect(ClothingType.trousers.index, 1);
      expect(ClothingType.jacket.index, 2);
      expect(ClothingType.dress.index, 3);
      expect(ClothingType.shoes.index, 4);
      expect(ClothingType.accessory.index, 5);
    });
  });
}