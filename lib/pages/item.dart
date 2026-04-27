import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ItemPage extends StatefulWidget {
  final ClothingItem? item;
  final String userId;
  final XFile? img;
  // isEditing = true  → viewing/editing an existing item (item must be non-null)
  // isEditing = false → creating a brand-new item (img may be pre-supplied)
  final bool isEditing;

  const ItemPage({super.key, this.item, this.img, this.isEditing = false, required this.userId})
      : assert(
          isEditing == false || item != null,
          'If isEditing is true, item must be provided',
        );

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  final ImagePicker _picker = ImagePicker();

  late ClothingType _selectedType;
  late TextEditingController _descController;

  /// The remote URL of the image already stored (null when adding a new item).
  String? _existingImageUrl;

  /// A newly picked local file that replaces / becomes the image.
  XFile? _pickedImage;

  bool _saving = false;

  // ── lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedType = widget.item?.type ?? ClothingType.top;
    _descController = TextEditingController(text: widget.item?.description ?? '');
    _existingImageUrl = widget.item?.imageUrl;
    // If a local image was passed in (e.g. from the camera flow) treat it as
    // the picked image so it shows immediately without a separate upload step.
    _pickedImage = widget.img;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // ── image helpers ─────────────────────────────────────────────────────────

  /// Displays a bottom sheet letting the user choose camera or gallery.
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(c).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(c).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<String> _uploadImageToSupabase(XFile img, ClothingType type) async {
    final folder = type.name.toLowerCase(); // e.g. "top", "trouser"
    final fileExt = img.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = '$folder/$fileName';
    const bucketName = 'Clothing images';

    await Supabase.instance.client.storage
        .from(bucketName)
        .upload(filePath, File(img.path));

    return Supabase.instance.client.storage
        .from(bucketName)
        .getPublicUrl(filePath);
  }

  // ── save / delete ─────────────────────────────────────────────────────────

  Future<void> _saveItem() async {
    setState(() => _saving = true);
    try {
      String? imageUrl = _existingImageUrl;

      // Upload the new image if the user picked one.
      if (_pickedImage != null) {
        imageUrl = await _uploadImageToSupabase(_pickedImage!, _selectedType);
      }

      final description = _descController.text.trim();

      if (widget.item?.id != null) {
        // ── update existing Firestore document ──
        await FirebaseFirestore.instance
            .collection('clothes')
            .doc(widget.item!.id)
            .update({
          'type': _selectedType.name,
          'imageUrl': imageUrl,
          'description': description,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        // ── create new Firestore document ──
        final newItem = ClothingItem(
          type: _selectedType,
          imageUrl: imageUrl ?? '',
          description: description,
        );
        await FirebaseFirestore.instance
            .collection('clothes')
            .add(newItem.toMap(widget.userId));
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem() async {
    if (widget.item?.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete item'),
        content: const Text(
          'Are you sure you want to delete this item? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('clothes')
          .doc(widget.item!.id)
          .delete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  static const _tabTitles = ['About', 'Stats'];

  @override
  Widget build(BuildContext context) {
    const maxExpandedHeight = 600.0;
    final minimumHeight = kToolbarHeight + 80.0;

    return DefaultTabController(
      length: _tabTitles.length,
      child: Scaffold(
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              collapsedHeight: minimumHeight,
              expandedHeight: maxExpandedHeight,
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              stretch: true,
              stretchTriggerOffset: 100,
              onStretchTrigger: () => Future<void>.value(),

              // ── appbar action buttons ──────────────────────────────────────
              actions: [
                if (widget.isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete item',
                    onPressed: _saving ? null : _deleteItem,
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: _saving ? null : _saveItem,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Save',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: Colors.black),
                          ),
                  ),
                ),
              ],

              // ── hero image in flexible space ───────────────────────────────
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final t = ((constraints.maxHeight - minimumHeight) /
                          (maxExpandedHeight - minimumHeight))
                      .clamp(0.0, 1.0);

                  return FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    collapseMode: CollapseMode.parallax,
                    background: GestureDetector(
                      onTap: _showImageSourceOptions,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── image (local pick takes priority over network) ──
                          Center(
                            child: Transform.scale(
                              scale: 0.5 + (t * 0.5),
                              child: Opacity(
                                opacity: t,
                                child: _buildHeroImage(),
                              ),
                            ),
                          ),

                          // ── "tap to change" hint ──
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: AnimatedOpacity(
                              opacity: t,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.edit, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Change photo',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── tab bar ────────────────────────────────────────────────────
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: Material(
                  elevation: 3,
                  color: Theme.of(context).appBarTheme.backgroundColor ??
                      Theme.of(context).primaryColor,
                  child: TabBar(
                    tabs: _tabTitles.map((t) => Tab(text: t)).toList(),
                    unselectedLabelStyle:
                        Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),

            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                children: [_buildAboutTab(), _buildStatsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders either the newly picked local file, the existing network image,
  /// or a placeholder — without crashing on null.
  Widget _buildHeroImage() {
    if (_pickedImage != null) {
      return Image.file(
        File(_pickedImage!.path),
        fit: BoxFit.contain,
      );
    }
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _existingImageUrl!,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
      );
    }
    // No image yet — show an inviting placeholder.
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 8),
            Text('Tap to add a photo',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── tab content ───────────────────────────────────────────────────────────

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<ClothingType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Category'),
            items: ClothingType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedType = v);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 24),
          // Prominent save button at the bottom of the form as well.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _saving ? null : _saveItem,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.isEditing ? 'Save changes' : 'Save item',
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _saving ? null : _deleteItem,
                child: const Text('Delete item'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Item stats will appear here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
