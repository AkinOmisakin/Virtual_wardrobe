import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// components
import 'package:virtual_wardrobe/components/Expandable_FAB.dart';

// pages
import 'package:virtual_wardrobe/pages/fits.dart';
import 'package:virtual_wardrobe/pages/storage.dart';
import 'package:virtual_wardrobe/pages/canvas.dart';

// models
import 'package:virtual_wardrobe/models/clothing_item.dart';

// services
import 'package:virtual_wardrobe/services/itemprovider.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const OutfitsPage(),
      const ItemsPage(),
      const CanvasScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ItemProvider(),
      child: _OutfitProviderBridge(
        child: DefaultTabController(
          length: _pages.length,
          child: Scaffold(
            appBar: AppBar(
              bottom: const TabBar(
                tabs: [
                  Tab(icon: ImageIcon(AssetImage('assets/icons/outfit.png'))),
                  Tab(icon: ImageIcon(AssetImage('assets/icons/clothing_carousel.png'))),
                  Tab(icon: ImageIcon(AssetImage('assets/icons/hanger_sparkle_filled.png'))),
                ],
              ),
              title: Center(
                child: Text(
                  'Wardrobe',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            floatingActionButton: ExpandableFab(
              initialOpen: false,
              distance: 110,
              children: [
                ActionButton(
                  onPressed: () => _onAddClothing(),
                  icon: const Icon(Icons.photo_camera_back_outlined),
                ),
              ],
            ),
            body: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: _pages,
            ),
          ),
        ),
      ),
    );
  }

  // ── add clothing (unchanged) ───────────────────────────────────────────────

  void _onAddClothing() {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.only(
              bottom: 24.0, left: 16.0, right: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => _selectPhotoFromCamera(picker),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photos'),
                onTap: () => _selectPhotosFromGallery(picker),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Close',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectPhotosFromGallery(ImagePicker picker) async {
    Navigator.of(context).pop();
    final List<ClothingItem?> clothingItems = [];
    final selectedImages = await getImagesFromGallery(picker);
    if (selectedImages == null || selectedImages.isEmpty) return;
    for (var img in selectedImages) {
      clothingItems.add(await _buildClothingItemForm(img));
    }
    for (var item in clothingItems) {
      if (item != null) _saveClothingItem(item);
    }
  }

  Future<List<XFile>?> getImagesFromGallery(ImagePicker picker) async {
    final List<XFile> selectedImages = await picker.pickMultiImage();
    if (selectedImages.isEmpty) return null;
    return selectedImages;
  }

  void _selectPhotoFromCamera(ImagePicker picker) async {
    Navigator.of(context).pop();
    final XFile? selectedImage = await getImageFromCamera(picker);
    if (selectedImage == null) return;
    final ClothingItem? savedItem =
        await _buildClothingItemForm(selectedImage);
    if (savedItem != null) _saveClothingItem(savedItem);
  }

  Future<XFile?> getImageFromCamera(ImagePicker picker) async {
    final XFile? capturedImage =
        await picker.pickImage(source: ImageSource.camera);
    if (capturedImage == null) return null;
    return capturedImage;
  }

  Future<ClothingItem?> _buildClothingItemForm(XFile image) async {
    ClothingType selectedType = ClothingType.top;
    final descController = TextEditingController();
    final result = await showModalBottomSheet<ClothingItem?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(image.path),
                            fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ClothingType>(
                      initialValue: selectedType,
                      items: const [
                        DropdownMenuItem(
                            value: ClothingType.top, child: Text('Top')),
                        DropdownMenuItem(
                            value: ClothingType.trouser,
                            child: Text('Trouser')),
                        DropdownMenuItem(
                            value: ClothingType.shoe, child: Text('Shoe')),
                        DropdownMenuItem(
                            value: ClothingType.outwear,
                            child: Text('Outwear')),
                        DropdownMenuItem(
                            value: ClothingType.dress,
                            child: Text('Dress')),
                        DropdownMenuItem(
                            value: ClothingType.accessory,
                            child: Text('Accessory')),
                      ],
                      onChanged: (v) =>
                          setModalState(() => selectedType = v ?? ClothingType.top),
                      decoration:
                          const InputDecoration(labelText: 'type'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'e.g. Red Hoodie',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final uploadedUrl =
                                  await _uploadImageToSupabase(
                                      image, selectedType);
                              final savedItem = ClothingItem(
                                type: selectedType,
                                imageUrl: uploadedUrl,
                                description: descController.text.trim(),
                              );
                              Navigator.of(ctx).pop(savedItem);
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    return result;
  }

  Future<String> _uploadImageToSupabase(
      XFile img, ClothingType type) async {
    final folder = type.displayName.toLowerCase();
    final fileExt = img.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = '$folder/$fileName';
    const bucketName = 'Clothing images';
    final File imageFile = File(img.path);
    await Supabase.instance.client.storage
        .from(bucketName)
        .upload(filePath, imageFile);
    return Supabase.instance.client.storage
        .from(bucketName)
        .getPublicUrl(filePath);
  }

  void _saveClothingItem(ClothingItem item) async {
    try {
      await FirebaseFirestore.instance
          .collection('clothes')
          .add(item.toMap());
    } catch (e) {
      // handle/log error as appropriate
    }
  }
}

// ── bridge widget ─────────────────────────────────────────────────────────────
//
// Creates OutfitProvider with the initial item list from ItemProvider, then
// calls updateItems() whenever ItemProvider notifies — keeping resolved outfits
// in sync without a second Firestore subscription for clothing items.

class _OutfitProviderBridge extends StatefulWidget {
  const _OutfitProviderBridge({required this.child});
  final Widget child;

  @override
  State<_OutfitProviderBridge> createState() =>
      _OutfitProviderBridgeState();
}

class _OutfitProviderBridgeState extends State<_OutfitProviderBridge> {
  OutfitProvider? _outfitProvider;

  @override
  Widget build(BuildContext context) {
    final itemProvider = Provider.of<ItemProvider>(context);

    if (_outfitProvider == null) {
      // First build: create OutfitProvider with whatever items are available.
      _outfitProvider = OutfitProvider(allItems: itemProvider.items);
    } else {
      // Subsequent builds: keep the item list fresh.
      _outfitProvider!.updateItems(itemProvider.items);
    }

    return ChangeNotifierProvider<OutfitProvider>.value(
      value: _outfitProvider!,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _outfitProvider?.dispose();
    super.dispose();
  }
}
