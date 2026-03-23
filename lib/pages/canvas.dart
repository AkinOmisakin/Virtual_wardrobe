// 
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';


//pages

import 'package:virtual_wardrobe/pages/storage.dart';

//models
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/models/canvas_entry.dart';
import 'package:virtual_wardrobe/models/clothing_categories.dart'; 

//components
import 'package:virtual_wardrobe/components/Expandable_FAB.dart';

//services
import 'package:provider/provider.dart';
import 'package:virtual_wardrobe/services/itemprovider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

   @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen>{

  // ── Canvas state ──
  final List<CanvasEntry> _entries = [];
  String? _selectedUid;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ItemProvider>(context);
    if (provider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null) {
      return Scaffold(body: Center(child: Text('Error: ${provider.error}')));
    }

    final items = provider.items;
    final categories = ClothesViewModel.categorizeItems(items);

    return Scaffold(
      body: _buildCanvas(),
      bottomNavigationBar: GestureDetector(
        onTap: () => _showInventory(categories),
        onVerticalDragStart: (_) => _showInventory(categories),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 50,
              color: const Color.fromRGBO(0, 0, 0, 0.9),
              child: const Center(child: ImageIcon(
                  AssetImage('assets/icons/up-chevron.png'),
                  color: Colors.white,
                )),
            ),
        
          ]
        )
      ),
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onTap: _deselectAll,
      child: Container(
        color: Colors.grey[200],
        child: Stack(
          children: [
            
          ]
        )
      )
    );
  }

  void _deselectAll() {
    setState(() {
      _selectedUid = null;
      for (final e in _entries) {
        e.isSelected = false;
      }
    });
  }

  void _showInventory(List<ClothingCategory> categories) {
    showModalBottomSheet(
      // clipBehavior: AppBar().clipBehavior,
      // useSafeArea: true,
      showDragHandle: false,
      enableDrag: true,
      // isScrollControlled: true,
      elevation: 10,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height,
      ),
      shape: ContinuousRectangleBorder(
        // borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // backgroundColor: const Color.fromRGBO(255, 255, 255, 0.39), // might be good for a frosted glass effect
      backgroundColor: Colors.white,
      context: context,
      builder: (BuildContext context) {
        return ChangeNotifierProvider(
          create: (context) => ItemProvider(),
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                automaticallyImplyLeading: false,
                centerTitle: true,
                title: Text('Add', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
                flexibleSpace: ImageIcon(
                  AssetImage('assets/icons/down-chevron.png'),
                  color: const Color.fromARGB(255, 0, 0, 0),
                  size: 24,
                ),
                bottom: const TabBar(
                  tabs: [

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
                          AssetImage('assets/icons/outfit.png')
                        )
                      )
                    ),

                  ],
                )
              ),
              body: TabBarView(
                // controller: TabController(length: 2, vsync: ScaffoldState()),
                children: [
                  _buildInventory(categories),
                  Center(child: Text('Items tab content goes here')),
                ]
              )
            )
          )
        );
      }
    );
  }

  Widget _buildInventory(List<ClothingCategory> categories) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Row(
            children: [
              IconButton(
                onPressed: _onAddClothing,
                icon: Icon(Icons.add_a_photo_rounded, size: 20)
              ),
              Text('Add new Clothing', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              const Icon(Icons.category_outlined, size: 20),
            ],
          )
        ],
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Column(
            children: [
              Text(category.title, style: Theme.of(context).textTheme.titleMedium),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: category.items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = category.items[itemIndex];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
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

      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8 // Limit height to 80% of screen height
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

    // for (var img in selectedImages) {
    //   //for each image selected create a clothing item object
    //   clothingItems.add(await _buildClothingItemForm(img));
    // }

    // for (var item in clothingItems) {
    //   if (item != null) {
    //     // if item is 
    //     _saveClothingItem(item);
    //   }
    // }
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
    // final ClothingItem? savedItem = await _buildClothingItemForm(selectedImage);
    // if (savedItem != null) {
    //     _saveClothingItem(savedItem);
    // }
  }
  
  Future<XFile?> getImageFromCamera(ImagePicker picker) async {
    //get image from camera
    final XFile? capturedImage = await picker.pickImage(source: ImageSource.camera);
    if (capturedImage == null) return null;
    return capturedImage;
  }

//   Route<void> _routeToEditItemPage(ClothingItem item) {
//     return PageRouteBuilder(
//       pageBuilder: (context, animation, secondaryAnimation) => ItemPage(item: item, isEditing: true),
//       transitionsBuilder: (context, animation, secondaryAnimation, child) {
//         // animate page from the bottom
//         const begin = Offset(0.0, 1.0);
//         const end = Offset.zero;
//         const curve = Curves.decelerate;
//         final tween = Tween(begin: begin, end: end)
//                       .chain(CurveTween(curve: curve));
//         return SlideTransition(
//           position: animation.drive(tween), 
//           child: child
//         );
//       }
//     );
//   } 
}