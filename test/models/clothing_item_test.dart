import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';

void main() {
  group('ClothingType parsing (via ClothingItem.fromMap)', () {
    ClothingType typeFor(dynamic raw) =>
        ClothingItem.fromMap({'type': raw, 'image_url': ''}).type;

    test('matches the exact enum name', () {
      expect(typeFor('trouser'), ClothingType.trouser);
      expect(typeFor('headwear'), ClothingType.headwear);
    });

    test('matches the display name, case-insensitively', () {
      expect(typeFor('Tops'), ClothingType.top);
      expect(typeFor('Accessories'), ClothingType.accessory);
      expect(typeFor('outwear'), ClothingType.outwear);
    });

    test('matches a pluralised value by stripping a trailing "s"', () {
      expect(typeFor('shoes'), ClothingType.shoe);
      expect(typeFor('trousers'), ClothingType.trouser);
    });

    test('falls back to top for null or unknown values', () {
      expect(typeFor(null), ClothingType.top);
      expect(typeFor('spaceship'), ClothingType.top);
      expect(typeFor(''), ClothingType.top);
    });
  });

  group('ClothingItem.fromMap', () {
    test('reads all fields and coerces list columns', () {
      final item = ClothingItem.fromMap({
        'id': 'abc-123',
        'type': 'top',
        'image_url': 'https://example.com/shirt.png',
        'cutout_url': 'https://example.com/shirt-cutout.png',
        'description': 'A blue shirt',
        'tags': ['cotton', 'casual'],
        'colours': ['blue'],
        'style': 'casual',
      });

      expect(item.id, 'abc-123');
      expect(item.type, ClothingType.top);
      expect(item.imageUrl, 'https://example.com/shirt.png');
      expect(item.cutoutUrl, 'https://example.com/shirt-cutout.png');
      expect(item.description, 'A blue shirt');
      expect(item.tags, ['cotton', 'casual']);
      expect(item.colours, ['blue']);
      expect(item.style, 'casual');
    });

    test('defaults missing image_url and list columns safely', () {
      final item = ClothingItem.fromMap({'type': 'dress'});

      expect(item.imageUrl, '');
      expect(item.tags, isEmpty);
      expect(item.colours, isEmpty);
      expect(item.cutoutUrl, isNull);
    });
  });

  group('ClothingItem.toMap', () {
    test('produces the snake_case insert payload with the user id', () {
      final item = ClothingItem(
        type: ClothingType.trouser,
        imageUrl: 'https://example.com/jeans.png',
        description: 'Blue jeans',
        tags: ['denim'],
        colours: ['blue'],
        style: 'casual',
      );

      final map = item.toMap('user-42');

      expect(map['user_id'], 'user-42');
      expect(map['type'], 'trouser'); // enum .name, not displayName
      expect(map['image_url'], 'https://example.com/jeans.png');
      expect(map['tags'], ['denim']);
      expect(map['colours'], ['blue']);
      expect(map['style'], 'casual');
    });

    test('round-trips through fromMap', () {
      final original = ClothingItem(
        id: 'id-1',
        type: ClothingType.outwear,
        imageUrl: 'https://example.com/coat.png',
        tags: ['wool', 'winter'],
        colours: ['grey'],
        style: 'formal',
      );

      // toMap omits id (insert payload); simulate the DB echoing it back.
      final restored = ClothingItem.fromMap({
        ...original.toMap('user-1'),
        'id': original.id,
      });

      expect(restored.type, original.type);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.tags, original.tags);
      expect(restored.colours, original.colours);
      expect(restored.style, original.style);
    });
  });
}
