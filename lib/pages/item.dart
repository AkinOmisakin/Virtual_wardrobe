// ...existing code...
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';

class ItemPage extends StatefulWidget {
  // optional positional item: keep compatibility with existing call sites
  final ClothingItem? item;
  final XFile? img;
  final bool isEditing; // true = editing mode (item must be non-null), false = adding new item/ saving item for the first time (item can be empty)
  const ItemPage({super.key, this.item, this.img, this.isEditing = false}):
    assert(isEditing == false || item != null, 'If isEditing is true, item must be provided');

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  // fields to hold form state
  late ClothingType _selectedType;
  late TextEditingController _descController;
  String? _existingImageUrl;
  String? _pickedImagePath;
  bool _saving = false; // whether a save operation is in progress

  @override
  void initState() {
    super.initState();
    _selectedType = widget.item?.type ?? ClothingType.top; // if editing is enabled, use item's type, otherwise default to top
    _descController = TextEditingController(text: widget.item?.description ?? ''); // if editing is enabled, use item's description
    _existingImageUrl = widget.item?.imageUrl; // if editing is enabled, use item's imageUrl, otherwise start with empty string
    _pickedImagePath = widget.img?.path;
    _saving = widget.isEditing ? widget.img?.path != null ? true : false : false; // if editing, we can consider the item "saved" until user makes changes, otherwise start with false
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  final List<String> _tabTitles = ['About', 'Stats'];

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;
    final maxExpandedHeight = 600.0; // max height for the flexible space when fully expanded
    final minimumHeight = kToolbarHeight + 80; // minimum height for the flexible space when collapsed (toolbar + some extra for image)

    return DefaultTabController(
      length: _tabTitles.length,

      child: Scaffold(
        body: CustomScrollView(

          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),

          // App bar with flexible space for item image and tabs for details/stats/etc.
          slivers: <Widget>[
            
            SliverAppBar(
              // title: Center(
              //   child: Text(
              //     isEditing ? 'Edit Item' : 'Add Item', // if editing is enabled, show "Edit Item", otherwise show "Add Item"
              //     style: Theme.of(context).textTheme.titleMedium,
              //   ),
              // ),

              pinned: true, // keeps app bar visible when scrolling
              elevation: 0,
              collapsedHeight: minimumHeight,
              expandedHeight: maxExpandedHeight,
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              stretch: true,
              stretchTriggerOffset: 100,
              onStretchTrigger: () => Future<void>.value(),

              // Flexible space to show the item image, with a semi-transparent overlay for better text visibility
              flexibleSpace: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double maxHeight = maxExpandedHeight;   // same as expandedHeight
                  final double minHeight = minimumHeight; // collapsed height area
                  final double currentHeight = constraints.maxHeight;

                  // Normalize scale between 0 and 1
                  double t = (currentHeight - minHeight) / (maxHeight - minHeight);
                  t = t.clamp(0.0, 1.0);

                  return FlexibleSpaceBar(
                    stretchModes: [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    collapseMode: CollapseMode.parallax,
                    background: Center(
                      child: Transform.scale(
                        scale: 0.5 + (t * 0.5), // scales from 0.5 → 1.0
                        child: Opacity( 
                          opacity: t, // fades out as it collapses
                          child: CachedNetworkImage(
                            imageUrl: _existingImageUrl!,
                            fit: BoxFit.contain,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      )
                    ),
                  );
                },
              ),

              // Widgets to display in a row after the [title] widget.
              actions: [
              ],

              // customized bottom section for tabs - wrapped in Material to give it a shadow and background color
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: Material(
                  elevation: 3,
                  // give the tab bar an opaque background so the flexibleSpace
                  color: Theme.of(context).appBarTheme.backgroundColor ??
                       Theme.of(context).primaryColor, //sets color of tabbar
                  child: TabBar(
                    tabs: [
                      Tab(text: _tabTitles[0]),
                      Tab(text: _tabTitles[1]),
                    ],
                    unselectedLabelStyle: 
                        Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),

            ),

            // TabBarView to show content for each tab - wrapped in SliverFillRemaining to take up remaining space below the app bar
            SliverFillRemaining(
              /* hasScrollBody: true lets the tab content scroll independently
              within the remaining space rather than overflowing into the app bar */
              hasScrollBody: true,
              child: TabBarView(
                children: [
                  // About tab: description and category controls
                  about(),
                  // Stats tab: placeholder for any item stats you want to add
                  stats(),

                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
  
  Widget about() {
    return SingleChildScrollView(
      // Restore normal scrolling — SliverFillRemaining with hasScrollBody: true
      // contains the scroll correctly so it no longer bleeds under the app bar
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

          TextFormField(
            controller: _descController,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Description'),
          ),

        ],
      ),
    );
  }

  Widget stats() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Item stats will appear here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  // Future<void> _pickImage(ImageSource source) async {
  //   final XFile? picked = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600);
  //   if (picked != null) {
  //     setState(() {
  //       _pickedImage = picked;
  //     });
  //   }
  // }

  // Future<String> _uploadImageToSupabase(XFile img, ClothingType type) async {
  //   final folder = type.displayName.toLowerCase();
  //   final fileExt = img.path.split('.').last;
  //   final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
  //   final filePath = '$folder/$fileName';
  //   final File imageFile = File(img.path);
  //   final bucketName = 'Clothing images';

  //   await Supabase.instance.client.storage.from(bucketName).upload(filePath, imageFile);
  //   final publicUrl = Supabase.instance.client.storage.from(bucketName).getPublicUrl(filePath);
  //   return publicUrl;
  // }

  // Future<void> _saveItem() async {
  //   setState(() => _saving = true);
  //   try {
  //     String? imageUrl = _existingImageUrl;

  //     // Upload new image if user picked one
  //     if (_pickedImage != null) {
  //       imageUrl = await _uploadImageToSupabase(_pickedImage!, _selectedType);
  //     }

  //     final description = _descController.text.trim();

  //     if (widget.item?.id != null) {
  //       // update existing document
  //       final data = {
  //         'type': _selectedType.name,
  //         'imageUrl': imageUrl,
  //         'description': description,
  //         'updatedAt': DateTime.now().toIso8601String(),
  //       };
  //       await FirebaseFirestore.instance.collection('clothes').doc(widget.item!.id).update(data);
  //     } else {
  //       // create new document
  //       final newItem = ClothingItem(
  //         type: _selectedType,
  //         imageUrl: imageUrl ?? '',
  //         description: description,
  //       );
  //       await FirebaseFirestore.instance.collection('clothes').add(newItem.toMap());
  //     }

  //     if (mounted) Navigator.of(context).pop(true);
  //   } catch (e) {
  //     // simple error handling - show snackbar
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
  //     }
  //   } finally {
  //     if (mounted) setState(() => _saving = false);
  //   }
  // }

  // Future<void> _deleteItem() async {
  //   if (widget.item?.id == null) return;
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (c) => AlertDialog(
  //       title: const Text('Delete item'),
  //       content: const Text('Are you sure you want to delete this item? This cannot be undone.'),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
  //         TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
  //       ],
  //     ),
  //   );
  //   if (confirm != true) return;

  //   try {
  //     await FirebaseFirestore.instance.collection('clothes').doc(widget.item!.id).delete();
  //     if (mounted) Navigator.of(context).pop(true);
  //   } catch (e) {
  //     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
  //   }
  // }


  // Widget about(){

  // }

  // @override
  // Widget build(BuildContext context) {
  //   final isEditing = widget.item?.id != null;
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: Text(isEditing ? 'Edit Item' : 'Add Item'),
  //       actions: [
  //         if (isEditing)
  //           IconButton(
  //             icon: const Icon(Icons.delete_outline),
  //             onPressed: _saving ? null : _deleteItem,
  //           ),
  //         TextButton(
  //           onPressed: _saving ? null : _saveItem,
  //           child: _saving
  //               ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
  //               : const Text('Save', style: TextStyle(color: Colors.white)),
  //         ),
  //       ],
  //     ),
  //     body: SingleChildScrollView(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         children: [
  //           GestureDetector(
  //             onTap: () => _showImageSourceOptions(),
  //             child: ClipRRect(
  //               borderRadius: BorderRadius.circular(12),
  //               child: AspectRatio(
  //                 aspectRatio: 1,
  //                 child: _pickedImage != null
  //                     ? Image.file(File(_pickedImage!.path), fit: BoxFit.cover)
  //                     : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
  //                         ? CachedNetworkImage(
  //                             imageUrl: _existingImageUrl!,
  //                             fit: BoxFit.cover,
  //                             placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
  //                             errorWidget: (c, u, e) => const Icon(Icons.broken_image, size: 48),
  //                           )
  //                         : Container(
  //                             color: Colors.grey[200],
  //                             child: const Center(child: Icon(Icons.photo, size: 56, color: Colors.grey)),
  //                           ),
  //               ),
  //             ),
  //           ),
  //           const SizedBox(height: 8),
  //           TextButton.icon(
  //             onPressed: () => _showImageSourceOptions(),
  //             icon: const Icon(Icons.edit),
  //             label: const Text('Change image'),
  //           ),
  //           const SizedBox(height: 12),
  //           DropdownButtonFormField<ClothingType>(
  //             value: _selectedType,
  //             decoration: const InputDecoration(labelText: 'Category'),
  //             items: ClothingType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
  //             onChanged: (v) {
  //               if (v != null) setState(() => _selectedType = v);
  //             },
  //           ),
  //           const SizedBox(height: 12),
  //           TextFormField(
  //             controller: _descController,
  //             maxLines: null,
  //             decoration: const InputDecoration(labelText: 'Description'),
  //           ),
  //           const SizedBox(height: 20),
  //           ElevatedButton(
  //             onPressed: _saving ? null : _saveItem,
  //             child: const Text('Save'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // void _showImageSourceOptions() {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (c) => SafeArea(
  //       child: Wrap(
  //         children: [
  //           ListTile(
  //             leading: const Icon(Icons.photo_library),
  //             title: const Text('Choose from gallery'),
  //             onTap: () {
  //               Navigator.of(c).pop();
  //               _pickImage(ImageSource.gallery);
  //             },
  //           ),
  //           ListTile(
  //             leading: const Icon(Icons.camera_alt),
  //             title: const Text('Take a photo'),
  //             onTap: () {
  //               Navigator.of(c).pop();
  //               _pickImage(ImageSource.camera);
  //             },
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}
//