import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:virtual_wardrobe/services/userprofileprovider.dart';

/// A profile section that lets the user add / view / change / remove their
/// private model photo used for AI try-on.
///
/// Drop this into the profile page body, e.g. below the header:
///   const ModelPhotoSection(),
class ModelPhotoSection extends StatefulWidget {
  const ModelPhotoSection({super.key});

  @override
  State<ModelPhotoSection> createState() => _ModelPhotoSectionState();
}

class _ModelPhotoSectionState extends State<ModelPhotoSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProfileProvider>(context);
    final photoUrl = provider.profile?.modelPhotoUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.accessibility_new, size: 18),
              const SizedBox(width: 8),
              Text('Try-on photo',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, size: 13, color: Colors.grey[500]),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Private to you. Used only to show how outfits look on you.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontStyle: FontStyle.normal, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),

          if (_busy)
            _buildBox(
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (photoUrl != null)
            _buildPhotoState(context, provider, photoUrl)
          else
            _buildEmptyState(context, provider),
        ],
      ),
    );
  }

  Widget _buildBox({required Widget child}) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: child,
    );
  }

  Widget _buildEmptyState(
      BuildContext context, UserProfileProvider provider) {
    return GestureDetector(
      onTap: () => _pickAndUpload(provider),
      child: _buildBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 36, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              'Add a full-body photo',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Front-facing, standing — works best',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontStyle: FontStyle.normal, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoState(
      BuildContext context, UserProfileProvider provider, String url) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: Colors.grey[100]),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[100],
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Change'),
                onPressed: () => _pickAndUpload(provider),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _confirmRemove(provider),
              child: const Icon(Icons.delete_outline, size: 18),
            ),
          ],
        ),
      ],
    );
  }

  // ── actions ─────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(UserProfileProvider provider) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1200, maxHeight: 1600);
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      await provider.uploadModelPhoto(File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove(UserProfileProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo'),
        content: const Text('Remove your try-on photo? You can add a new one anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await provider.removeModelPhoto();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
