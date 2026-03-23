import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// components
import 'package:virtual_wardrobe/components/Expandable_FAB.dart';

//pages
import 'package:virtual_wardrobe/pages/fits.dart';
import 'package:virtual_wardrobe/pages/storage.dart';
import 'package:virtual_wardrobe/pages/canvas_example.dart';
import 'package:virtual_wardrobe/pages/canvas.dart';

//models
import 'package:virtual_wardrobe/models/clothing_item.dart';


//services
import 'package:virtual_wardrobe/services/itemprovider.dart';
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
      OutfitsPage(),
      ItemsPage(),
      // OutfitCanvasPage(),
      CanvasScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ItemProvider(),
      child: DefaultTabController(
        length: _pages.length,
        child: Scaffold(
          appBar: AppBar( //https://api.flutter.dev/flutter/material/AppBar-class.html
            bottom: const TabBar(
              tabs: [

                Tab(
                  icon: IconTheme(
                    data: IconThemeData(
                      color: null,
                    ), 
                    child: ImageIcon(
                      AssetImage('assets/icons/outfit.png')
                    )
                  )
                ),

                Tab(
                  icon: IconTheme(
                    data: IconThemeData(
                      color: null,
                    ), 
                    child: ImageIcon(
                      AssetImage('assets/icons/clothing_carousel.png')
                    )
                  )
                ),

                Tab(
                  icon: IconTheme(
                    data: IconThemeData(
                      color: null,
                    ), 
                    child: ImageIcon(
                      AssetImage('assets/icons/hanger_sparkle_filled.png')
                    )
                  )
                )
              ],
            ),
            title: Center(child: Text('Wardrobe', style: Theme.of(context).textTheme.titleLarge)),
            // elevation: 4,
          ),

          //Optional menu component: Expandable floating action buttion
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
            physics: const NeverScrollableScrollPhysics(), // disable swipe between tabs
            children: _pages
          ),

        )
      )
    );
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

    for (var item in clothingItems) {
      if (item != null) {
        // if item is 
        _saveClothingItem(item);
      }
    }
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
                        DropdownMenuItem(value: ClothingType.trouser, child: Text('Trouser')),
                        DropdownMenuItem(value: ClothingType.shoe, child: Text('Shoe')),
                        DropdownMenuItem(value: ClothingType.outwear, child: Text('Outwear')),
                        DropdownMenuItem(value: ClothingType.dress, child: Text('Dress')),
                        DropdownMenuItem(value: ClothingType.accessory, child: Text('Accessory')),
                      ],
                      onChanged: (v) => setModalState(() => selectedType = v ?? ClothingType.top),
                      decoration: const InputDecoration(labelText: 'type'),
                    ),

                    const SizedBox(height: 8),


                    //TODO: replace with tags

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
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
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
}