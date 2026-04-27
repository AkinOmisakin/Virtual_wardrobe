enum PostType {
  selfie,
  aiTryOn,
  canvas,
}

class UserPost {
  final String id;
  final PostType type;
  final String imageUrl;       // rendered image for the grid
  final String? caption;
  final DateTime createdAt;
  final int likes;

  const UserPost({
    required this.id,
    required this.type,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
    this.likes = 0,
  });

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'imageUrl': imageUrl,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
    'likes': likes,
  };

  factory UserPost.fromMap(Map<String, dynamic> map, {required String docId}) {
    PostType resolvedType;
    switch (map['type'] as String?) {
      case 'aiTryOn':
        resolvedType = PostType.aiTryOn;
        break;
      case 'canvas':
        resolvedType = PostType.canvas;
        break;
      default:
        resolvedType = PostType.selfie;
    }
    return UserPost(
      id: docId,
      type: resolvedType,
      imageUrl: map['imageUrl'] as String? ?? '',
      caption: map['caption'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      likes: (map['likes'] as num?)?.toInt() ?? 0,
    );
  }
}