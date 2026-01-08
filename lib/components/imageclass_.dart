class ImageItem {
  final int? id;
  final String path;
  final String createdAt;
  ImageItem({this.id, required this.path, required this.createdAt});
  Map<String, Object?> toMap() => {'id': id, 'path': path, 'createdAt': createdAt};
  static ImageItem fromMap(Map<String, Object?> m) => ImageItem(id: m['id'] as int?, path: m['path'] as String, createdAt: m['createdAt'] as String);
}