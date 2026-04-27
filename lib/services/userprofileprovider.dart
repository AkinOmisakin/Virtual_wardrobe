import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:virtual_wardrobe/models/user_post.dart';

class UserProfile {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? bio;

  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.bio,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'username': username,
    'avatarUrl': avatarUrl,
    'bio': bio,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map, {required String docId}) {
    return UserProfile(
      id: docId,
      name: map['name'] as String? ?? 'Your Name',
      username: map['username'] as String? ?? 'username',
      avatarUrl: map['avatarUrl'] as String?,
      bio: map['bio'] as String?,
    );
  }

  UserProfile copyWith({
    String? name,
    String? username,
    String? avatarUrl,
    String? bio,
  }) => UserProfile(
    id: id,
    name: name ?? this.name,
    username: username ?? this.username,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
  );
}

class UserProfileProvider extends ChangeNotifier {
  /// Pass the Firestore user document id for the signed-in user.
  UserProfileProvider({required this.userId}) {
    _subscribeProfile();
    _subscribePosts();
  }

  final String userId;

  UserProfile? _profile;
  List<UserPost> _posts = [];
  bool _isLoading = true;
  String? _error;

  UserProfile? get profile => _profile;
  List<UserPost> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<DocumentSnapshot>? _profileSub;
  StreamSubscription<QuerySnapshot>? _postsSub;

  // ── subscriptions ──────────────────────────────────────────────────────────

  void _subscribeProfile() {
    _profileSub = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists && doc.data() != null) {
          _profile =
              UserProfile.fromMap(doc.data()!, docId: doc.id);
        }
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _subscribePosts() {
    _postsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _posts = snapshot.docs
            .map((doc) => UserPost.fromMap(doc.data(), docId: doc.id))
            .toList();
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  // ── mutations ──────────────────────────────────────────────────────────────

  Future<void> updateProfile({
    String? name,
    String? username,
    String? avatarUrl,
    String? bio,
  }) async {
    final updated = {
      if (name != null) 'name': name,
      if (username != null) 'username': username,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (bio != null) 'bio': bio,
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set(updated, SetOptions(merge: true));
    // Stream will update _profile automatically.
  }

  Future<void> deletePost(String postId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('posts')
        .doc(postId)
        .delete();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _postsSub?.cancel();
    super.dispose();
  }
}