import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/models/clothing_item.dart';

/// Single place for clothing-image uploads. Both the add-item flow and the
/// edit-item flow go through here, so the bucket name and path scheme can't
/// drift apart between call sites.
class ClothingStorage {
  ClothingStorage._();

  /// Must match the Storage bucket id exactly — it contains a space and a
  /// capital letter. Do not "clean" this string or uploads will 404.
  static const bucket = 'Clothing images';

  static final _random = Random();

  /// Uploads [file] for a garment of [type] and returns its public URL.
  ///
  /// [suffix] distinguishes multiple images for one item (e.g. 'cutout').
  /// The path is scoped by user and given a collision-resistant name, and the
  /// content type is set explicitly so the served image has the right headers.
  static Future<String> uploadImage(
    File file,
    ClothingType type, {
    String? suffix,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    final folder = type.name.toLowerCase(); // e.g. "top", "trouser"
    final ext = extensionOf(file.path);
    final name = '${_uniqueId()}${suffix != null ? '_$suffix' : ''}.$ext';
    final path = '$userId/$folder/$name';

    final storage = Supabase.instance.client.storage.from(bucket);
    await storage.upload(
      path,
      file,
      fileOptions: FileOptions(contentType: contentTypeFor(ext)),
    );
    return storage.getPublicUrl(path);
  }

  /// Timestamp + random suffix — unique even for two uploads in the same
  /// millisecond (which a bare timestamp could collide on).
  static String _uniqueId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${ts}_$rand';
  }

  /// Safe lowercase extension: strips any query/fragment, falls back to 'jpg'
  /// when there is none, and rejects anything that isn't a short alnum token
  /// (e.g. a dot that was actually part of a folder name).
  ///
  /// Public because avatar uploads need the same rules — two copies of this
  /// would be two chances to disagree about what a valid extension is.
  static String extensionOf(String path) {
    final clean = path.split('?').first.split('#').first;
    final dot = clean.lastIndexOf('.');
    if (dot == -1 || dot == clean.length - 1) return 'jpg';
    final ext = clean.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : 'jpg';
  }

  static String contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
