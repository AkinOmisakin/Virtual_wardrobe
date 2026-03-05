// outfit.dart
class Outfit {
  final String? id;
  final String? topId;
  final String? bottomId;
  final String? shoesId;
  final String? accessoryId;
  final String? name;
  final DateTime createdAt;

  Outfit({
    this.id,
    this.topId,
    this.bottomId,
    this.shoesId,
    this.accessoryId,
    this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'topId': topId,
      'bottomId': bottomId,
      'shoesId': shoesId,
      'accessoryId': accessoryId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Outfit.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Outfit(
      id: docId,
      topId: map['topId'],
      bottomId: map['bottomId'],
      shoesId: map['shoesId'],
      accessoryId: map['accessoryId'],
      name: map['name'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}