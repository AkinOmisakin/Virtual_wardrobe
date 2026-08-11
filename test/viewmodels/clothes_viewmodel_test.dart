import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/pages/storage.dart';

ClothingItem _item(ClothingType type) =>
    ClothingItem(type: type, imageUrl: 'https://example.com/${type.name}.png');

void main() {
  group('ClothesViewModel.categorizeItems', () {
    test('groups items by type and honours the preferred order', () {
      final categories = ClothesViewModel.categorizeItems([
        _item(ClothingType.shoe),
        _item(ClothingType.top),
        _item(ClothingType.headwear),
        _item(ClothingType.trouser),
      ]);

      expect(
        categories.map((c) => c.title),
        ['Headwear', 'Tops', 'Trousers', 'Shoes'],
      );
    });

    test('collects multiple items of the same type into one category', () {
      final categories = ClothesViewModel.categorizeItems([
        _item(ClothingType.top),
        _item(ClothingType.top),
        _item(ClothingType.trouser),
      ]);

      final tops = categories.firstWhere((c) => c.title == 'Tops');
      expect(tops.items.length, 2);
    });

    test('omits categories with no items', () {
      final categories = ClothesViewModel.categorizeItems([
        _item(ClothingType.top),
      ]);

      expect(categories.map((c) => c.title), ['Tops']);
    });

    test('excludes types with no display group (e.g. accessories)', () {
      final categories = ClothesViewModel.categorizeItems([
        _item(ClothingType.accessory),
        _item(ClothingType.top),
      ]);

      final titles = categories.map((c) => c.title);
      expect(titles, isNot(contains('Accessories')));
      expect(titles, contains('Tops'));
    });

    test('returns an empty list for no items', () {
      expect(ClothesViewModel.categorizeItems([]), isEmpty);
    });
  });
}
