import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/services/tryon_service.dart';

ClothingItem _item(ClothingType type) =>
    ClothingItem(type: type, imageUrl: 'https://example.com/${type.name}.png');

void main() {
  group('TryOnService.categoryFor', () {
    test('maps tops and outerwear to upper_body', () {
      expect(TryOnService.categoryFor(ClothingType.top), 'upper_body');
      expect(TryOnService.categoryFor(ClothingType.outwear), 'upper_body');
    });

    test('maps trousers to lower_body and dresses to dresses', () {
      expect(TryOnService.categoryFor(ClothingType.trouser), 'lower_body');
      expect(TryOnService.categoryFor(ClothingType.dress), 'dresses');
    });

    test('returns null for garments IDM-VTON cannot place', () {
      expect(TryOnService.categoryFor(ClothingType.shoe), isNull);
      expect(TryOnService.categoryFor(ClothingType.accessory), isNull);
      expect(TryOnService.categoryFor(ClothingType.headwear), isNull);
    });
  });

  group('TryOnService.orderForLayering', () {
    List<ClothingType> orderOf(List<ClothingType> input) =>
        TryOnService.orderForLayering(input.map(_item).toList())
            .map((i) => i.type)
            .toList();

    test('orders dress → trouser → top → outerwear', () {
      expect(
        orderOf([
          ClothingType.outwear,
          ClothingType.top,
          ClothingType.trouser,
          ClothingType.dress,
        ]),
        [
          ClothingType.dress,
          ClothingType.trouser,
          ClothingType.top,
          ClothingType.outwear,
        ],
      );
    });

    test('places unsupported types last', () {
      final ordered = orderOf([ClothingType.shoe, ClothingType.top]);
      expect(ordered.first, ClothingType.top);
      expect(ordered.last, ClothingType.shoe);
    });

    test('does not mutate the input list', () {
      final input = [_item(ClothingType.outwear), _item(ClothingType.dress)];
      TryOnService.orderForLayering(input);
      expect(input.first.type, ClothingType.outwear); // original order intact
    });
  });
}
