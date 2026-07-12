enum PostType {
  selfie,
  aiTryOn,
  canvas,
}

class UserPost {
  final String id;
  final PostType type;
  final String imageUrl;
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

  // Insert payload for the `posts` table (snake_case).
  Map<String, dynamic> toMap(String userId) => {
    'user_id':    userId,
    'type':       type.name,
    'image_url':  imageUrl,
    'caption':    caption,
    'created_at': createdAt.toIso8601String(),
    'likes':      likes,
  };

  // Parses a row from the Supabase `posts` table.
  factory UserPost.fromMap(Map<String, dynamic> map) {
    final PostType resolvedType = switch (map['type'] as String?) {
      'aiTryOn' => PostType.aiTryOn,
      'canvas'  => PostType.canvas,
      _         => PostType.selfie,
    };
    return UserPost(
      id:        map['id'] as String,
      type:      resolvedType,
      imageUrl:  map['image_url'] as String? ?? '',
      caption:   map['caption'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      likes: (map['likes'] as num?)?.toInt() ?? 0,
    );
  }
}
