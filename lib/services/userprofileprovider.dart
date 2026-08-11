import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/models/user_post.dart';
import 'package:virtual_wardrobe/utils/error_messages.dart';

class UserProfile {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? bio;

  /// Private full-body photo used for AI try-on.
  final String? modelPhotoUrl;
  final String? modelPhotoPath;

  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.modelPhotoUrl,
    this.modelPhotoPath,
  });

  Map<String, dynamic> toMap() => {
    'name':             name,
    'username':         username,
    'avatar_url':       avatarUrl,
    'bio':              bio,
    'model_photo_url':  modelPhotoUrl,
    'model_photo_path': modelPhotoPath,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id:             map['id']               as String,
      name:           map['name']             as String? ?? 'Cher user',
      username:       map['username']         as String? ?? 'username',
      avatarUrl:      map['avatar_url']       as String?,
      bio:            map['bio']              as String?,
      modelPhotoUrl:  map['model_photo_url']  as String?,
      modelPhotoPath: map['model_photo_path'] as String?,
    );
  }

  UserProfile copyWith({
    String? name,
    String? username,
    String? avatarUrl,
    String? bio,
    String? modelPhotoUrl,
    String? modelPhotoPath,
  }) => UserProfile(
    id:             id,
    name:           name           ?? this.name,
    username:       username       ?? this.username,
    avatarUrl:      avatarUrl      ?? this.avatarUrl,
    bio:            bio            ?? this.bio,
    modelPhotoUrl:  modelPhotoUrl  ?? this.modelPhotoUrl,
    modelPhotoPath: modelPhotoPath ?? this.modelPhotoPath,
  );
}

class UserProfileProvider extends ChangeNotifier {
  UserProfileProvider({required this.userId}) {
    _subscribeProfile();
    _subscribePosts();
  }

  final String userId;
  static const _modelBucket = 'user-models';

  UserProfile? _profile;
  List<UserPost> _posts = [];
  bool _isLoading = true;
  String? _error;

  UserProfile? get profile => _profile;
  List<UserPost> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<List<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<List<Map<String, dynamic>>>? _postsSub;

  // ── subscriptions ──────────────────────────────────────────────────────────

  void _subscribeProfile() {
    _profileSub = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen(
          (rows) {
            if (rows.isNotEmpty) {
              _profile = UserProfile.fromMap(rows.first);
            }
            _isLoading = false;
            notifyListeners();
          },
          onError: (e, st) {
            _error = friendlyError(e,
                fallback: "Couldn't load your profile. Please try again.",
                stackTrace: st);
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  void _subscribePosts() {
    _postsSub = Supabase.instance.client
        .from('posts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            _posts = rows.map(UserPost.fromMap).toList();
            notifyListeners();
          },
          onError: (e, st) {
            _error = friendlyError(e,
                fallback: "Couldn't load your posts. Please try again.",
                stackTrace: st);
            notifyListeners();
          },
        );
  }

  // ── profile mutations ──────────────────────────────────────────────────────

  Future<void> updateProfile({
    String? name,
    String? username,
    String? avatarUrl,
    String? bio,
  }) async {
    final updated = <String, dynamic>{
      if (name != null)      'name':       name,
      if (username != null)  'username':   username,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (bio != null)       'bio':        bio,
    };
    await Supabase.instance.client
        .from('profiles')
        .update(updated)
        .eq('id', userId);
  }

  // ── model photo ────────────────────────────────────────────────────────────

  Future<void> uploadModelPhoto(File photo) async {
    final ext  = photo.path.split('.').last;
    final path = '$userId/model.$ext';

    final storage = Supabase.instance.client.storage.from(_modelBucket);
    await storage.upload(path, photo, fileOptions: const FileOptions(upsert: true));

    final signedUrl = await storage.createSignedUrl(path, 60 * 60 * 24 * 365);

    await Supabase.instance.client
        .from('profiles')
        .update({'model_photo_url': signedUrl, 'model_photo_path': path})
        .eq('id', userId);
  }

  Future<void> removeModelPhoto() async {
    final base = '$userId/model';
    try {
      await Supabase.instance.client.storage
          .from(_modelBucket)
          .remove(['$base.jpg', '$base.jpeg', '$base.png']);
    } catch (_) {}

    await Supabase.instance.client
        .from('profiles')
        .update({'model_photo_url': null, 'model_photo_path': null})
        .eq('id', userId);
  }

  Future<String?> freshModelPhotoUrl() async {
    final data = await Supabase.instance.client
        .from('profiles')
        .select('model_photo_path')
        .eq('id', userId)
        .single();

    final path = data['model_photo_path'] as String?;
    if (path == null) return _profile?.modelPhotoUrl;

    return Supabase.instance.client.storage
        .from(_modelBucket)
        .createSignedUrl(path, 60 * 60);
  }

  // ── post mutations ─────────────────────────────────────────────────────────

  Future<void> deletePost(String postId) async {
    await Supabase.instance.client
        .from('posts')
        .delete()
        .eq('id', postId);
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _postsSub?.cancel();
    super.dispose();
  }
}
