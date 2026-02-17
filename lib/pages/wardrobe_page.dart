// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:virtual_wardrobe/components/clothing_item.dart';
import 'package:virtual_wardrobe/pages/outfits_page.dart';
import 'package:virtual_wardrobe/pages/items_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {

  int currentPageIndex = 1; // Tracks the currently selected page index

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const OutfitsPage(),
      const ItemsPage(),
    ];
  }

  void _handleBottomBarTap(int index) {
    // Outfits and Wardrobe navigation
    if (index == 0 || index == 1) {
      setState(() {
        currentPageIndex = index;
      });
    }
    _onButton3Pressed(index);
  }

  void _onButton3Pressed(int index) {
    if (currentPageIndex == 0 && index == 2) {
      // On Outfits Page and Add Outfit button pressed
      // set currentPageIndex to 3 to unlock the Create Outfit page in the bottom navigation bar
      // this works because this method is only accessed when currentPageIndex is 0 or 1 and can change back to 0 and 1 so doesn't get stuck on 3
      // This is gonna be the version of create outfit where they have to use a mannequin or canvas to build outfits
      null;
      
    }
    if (currentPageIndex == 1 && index == 2) {
      // On Wardrobe Page and 'Insert' button pressed
      _onAddClothing();
    }
  }

  void _onAddClothing() {
    final ImagePicker picker = ImagePicker();
    // Menu popup window for adding clothing
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to expand based on content
      showDragHandle: false,      // Adds the centered pill-shaped handle

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),

      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Hugs content tightly
            children: [
              const SizedBox(height: 16),
              // Add Photo from camera option
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => _selectPhotoFromCamera(picker),
              ),
              // Add Photo from gallery option
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photos'),
                onTap: () => _selectPhotosFromGallery(picker),
              ),
              // Close button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: InkWell(
                  onTap: () => Navigator.pop(context), // Close the modal
                  borderRadius: BorderRadius.circular(30), // Pill shape for ripple effect
                  child: Container(
                    width: double.infinity, // Wide button style
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[200], // Or use Theme.of(context).cardColor for dark mode
                      borderRadius: BorderRadius.circular(30), // Distinctive pill shape
                    ),
                    child: const Text(
                      'Close',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
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
    Navigator.of(context).pop(); // Close the bottom sheet

    // initialise list of possible clothign items to select from gallery
    final List<ClothingItem?> clothingItems = [];
    //import them from gallery as list
    final selectedImages = await getImagesFromGallery(picker);
    if (selectedImages == null || selectedImages.isEmpty) {
      return;
    }
    for (var img in selectedImages) {
      //for each image selected create a clothing item object
      clothingItems.add(await _buildClothingItemForm(img));
    }
    print(clothingItems);
    for (var item in clothingItems) {
      if (item != null) {
        // if item is 
        _saveClothingItem(item);
      }
    }
    print(clothingItems);
  }

  Future<List<XFile>?> getImagesFromGallery(ImagePicker picker) async {
    //get images from gallery
    final List<XFile> selectedImages = await picker.pickMultiImage();
    if (selectedImages.isEmpty) return null;
    return selectedImages;
  }


  void _selectPhotoFromCamera(ImagePicker picker) async {
    Navigator.of(context).pop(); // Close the bottom sheet
    final XFile? selectedImage = await getImageFromCamera(picker);
    if (selectedImage == null) {
        return;
    }
    final ClothingItem? savedItem = await _buildClothingItemForm(selectedImage);
    if (savedItem != null) {
        _saveClothingItem(savedItem);
    }
  }
  
  Future<XFile?> getImageFromCamera(ImagePicker picker) async {
    //get image from camera
    final XFile? capturedImage = await picker.pickImage(source: ImageSource.camera);
    if (capturedImage == null) return null;
    return capturedImage;
  }

  Future<ClothingItem?> _buildClothingItemForm(XFile image)  async {
    ClothingType selectedType = ClothingType.top;
    final descController = TextEditingController();
    ClothingItem? savedItem;
    // Build form for clothing item details
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
                    // image preview
                    SizedBox(
                      height: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(image.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // clothing type dropdown
                    DropdownButtonFormField<ClothingType>(
                      initialValue: selectedType,
                      items: const [
                        DropdownMenuItem(value: ClothingType.top, child: Text('Top')),
                        DropdownMenuItem(value: ClothingType.trousers, child: Text('Trousers')),
                        DropdownMenuItem(value: ClothingType.jacket, child: Text('Jacket')),
                        DropdownMenuItem(value: ClothingType.dress, child: Text('Dress')),
                        DropdownMenuItem(value: ClothingType.shoes, child: Text('Shoes')),
                        DropdownMenuItem(value: ClothingType.accessory, child: Text('Accessory')),
                      ],
                      onChanged: (v) => setModalState(() => selectedType = v ?? ClothingType.top),
                      decoration: const InputDecoration(labelText: 'type'),
                    ),

                    const SizedBox(height: 8),

                    // description input
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'e.g. Red Hoodie',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // save clothing item button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                // await the upload here (properly typed)
                                final uploadedUrl = await _uploadImageToSupabase(image, selectedType);
                                savedItem = ClothingItem(
                                  type: selectedType,
                                  imageUrl: uploadedUrl, 
                                  description: descController.text.trim(),
                                );
                                Navigator.of(ctx).pop(savedItem);
                              } catch (e) {
                                rethrow;
                              }
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


  Future<String> _uploadImageToSupabase(XFile img, ClothingType type) async {
    // Uploads the provided image file to the Supabase bucket "clothing images"
    // and returns a public URL for that file.
    // create a unique path/name for this file in the bucket
    // https://zmnhdlrwnxsqcrcrzvje.supabase.co/storage/v1/object/public/Clothing%20images/tops/bear_t.png
    // https://zmnhdlrwnxsqcrcrzvje.supabase.co/storage/v1/object/public/Clothing%20images/shoes/blue_laces_shoe.png

    // generate file path
    final folder = type.displayName.toLowerCase(); // e.g. tops folder store top type clothing images
    final fileExt = img.path.split('.').last; // .png .jpg
    final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
    final filePath = '$folder/$fileName'; // optionally prefix with user id or folder

    // convert xfile to file
    final File imageFile = File(img.path);

    // get bucketName
    final bucketName = 'Clothing images'; // hardcoded for now


    try {
      // final bytes = await img.readAsBytes();
      await Supabase.instance.client.storage
          .from(bucketName)
          .upload(
            filePath,
            imageFile
          );

      // get the url of the image
      final publicUrl = Supabase.instance.client.storage.from(bucketName).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      // In production surface or log the error properly
      rethrow;
    }
  }

  // String _getBucketName() {
  //   reutn;
  // }

  void _saveClothingItem(ClothingItem item) async {
    // Saves the ClothingItem metadata to Firestore.
    try {
      await FirebaseFirestore.instance
      .collection('clothes')
      .add(item.toMap());
    } catch (e) {
      // handle/log error as appropriate
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentPageIndex,
        children: _pages,
      ),
      // ADD clothing categories
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          //outfits
          BottomNavigationBarItem(
            icon: IconTheme(
              data: IconThemeData(
                color: null,
              ),
              child: ImageIcon(
                AssetImage('assets/icons/outfit.png'),
                size: 20,
              ),
            ),
            activeIcon: IconTheme(
              data: IconThemeData(
                color: Color.fromARGB(255, 0, 183, 255),
              ),
              child: ImageIcon(
                AssetImage('assets/icons/outfit.png'),
                size: 35,
              ),
            ),
            label: 'Outfits',
          ),
          // Clothing carousel
          BottomNavigationBarItem(
            icon: IconTheme(
              data: IconThemeData(
                color: null,
              ),
              child: ImageIcon(
                AssetImage('assets/icons/clothing_carousel.png'),
                size: 25,
              ),
            ),
            activeIcon: IconTheme(
              data: IconThemeData(
                color: Color.fromARGB(255, 255, 215, 0),
              ),
              child: ImageIcon(
                AssetImage('assets/icons/clothing_carousel.png'),
                size: 35,
              ),
            ),
            label: 'Dresser',
          ),
           // Create outfit button (only shows when on outfits page)
          if (currentPageIndex == 0) ...[
            BottomNavigationBarItem(
              icon: IconTheme(
                data: IconThemeData(
                  color: null,
                ),
                child: ImageIcon(
                  AssetImage('assets/icons/hanger_sparkle_outlined.png'),
                  size: 15,
                ),
              ),
              activeIcon: IconTheme(
                data: IconThemeData(
                  color: Color.fromARGB(255, 255, 215, 0),
                ),
                child: ImageIcon(
                  AssetImage('assets/icons/hanger_sparkle_filled.png'),
                  size: 25,
                ),
              ),
              label: 'Create Outfit',
            ),
          ],
          // Add Clothing button (only shows when on items page)
          if (currentPageIndex == 1) ...[
            BottomNavigationBarItem(
              icon: Icon(
                Icons.photo_camera_back_outlined,
                size: 25,
              ),
              label: 'Add Clothing',
            )
          ],
        ],

        currentIndex: currentPageIndex,
        onTap: _handleBottomBarTap,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,

        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 0, 0, 0)
        ),
        unselectedLabelStyle: TextStyle(
          color: const Color.fromARGB(255, 0, 0, 0),
        ),

        selectedItemColor: Color.fromARGB(255, 0, 0, 0),
        unselectedItemColor: Colors.grey,
  
        selectedIconTheme: const IconThemeData(
          color: Color.fromARGB(255, 0, 0, 0),
        ),
        unselectedIconTheme: const IconThemeData(
          color: Colors.grey,
        ),
      ),
    );
  }
}