import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_wardrobe/components/clothing_item.dart';

void main() {
  group('ClothingItem', () {
    test('should create a ClothingItem with given properties', () {
      final clothingItem = ClothingItem(
        type: ClothingType.top,
        imageUrl: 'assets/icon/bussiness-man.png',
        description: 'A stylish top',
      );

      expect(clothingItem.type, ClothingType.top);
      expect(clothingItem.imageUrl, 'assets/icon/business-man.png');
      expect(clothingItem.description, 'A stylish top');
    });

    test('toString should return correct string representation', () {
      final clothingItem = ClothingItem(
        type: ClothingType.trousers,
        imageUrl: 'assets/icon/trousers.png',
        description: 'A beautiful pair of trousers',
      );

      expect(clothingItem.toString(), 'ClothingItem{type: ClothingType.trousers, imageUrl: assets/icon/trousers.png, description: A beautiful pair of trousers}');
    });
  });
}