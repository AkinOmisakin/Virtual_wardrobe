import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:virtual_wardrobe/components/clothing_item.dart';
import 'package:virtual_wardrobe/pages/outfits_.dart';
import 'package:virtual_wardrobe/pages/wardrobe_.dart';
import 'package:virtual_wardrobe/services/dbhelper_.dart';
// import 'package:camera/camera.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {

  final List<(Widget, String)> _pages = [
    (OutfitsPage(), 'Outfits'),
    (WardrobeBody(), 'Wardrobe'),
    // Placeholder(), // Placeholder for Add Clothing page
  ];

  // File? _selectedImage;

  int currentPageIndex = 0; // Tracks the currently selected page index
  // NavigationDestinationLabelBehavior labelBehavior = NavigationDestinationLabelBehavior.alwaysShow;

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
      // print('Add Outfit button pressed');
      null;
    }
    if (currentPageIndex == 1 && index == 2) {
      // On Wardrobe Page and 'Insert' button pressed
      _onAddClothing();
    }
  }

  Future<void> _onAddClothing() async {
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
                onTap: () => _selectPhotoFromSource(ImageSource.camera),
              ),
              // Add Photo from gallery option
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photos'),
                onTap: () => _selectPhotoFromSource(ImageSource.gallery),
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

  // Future<File?> _selectPhotoFromSource(ImageSource source) async {
  //   final ImagePicker imagePicker = ImagePicker();
  //   final XFile? selectedImage = 
  //           await imagePicker.pickImage(source: source);
  //   if (selectedImage == null) return null;

  //   try {
  //     final docs = await getApplicationDocumentsDirectory(); // Get the app's document directory
  //     final ext = p.extension(selectedImage.path); // Get the file extension
  //     final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext'; // Unique file name
  //     final savedPath = p.join(docs.path, fileName); // Full path to save the image

  //     // copy to app folder
  //     final savedFile = await File(selectedImage.path).copy(savedPath);

  //     // insert into local DB
  //     final item = ImageItem(path: savedFile.path, createdAt: DateTime.now().toIso8601String());
  //     await DBHelper.instance.insertImage(item);

  //     return savedFile;
  //   } catch (e) {
  //     // ignore: avoid_print
  //     print('Error saving image: $e');
  //     return null;
  //   }
  // }

  Future<void> _selectPhotoFromSource(ImageSource source) async {
    // pick an image (you can switch to ImageSource.camera where appropriate)
    final ImagePicker imagePicker = ImagePicker();
    final XFile? selectedImage = await imagePicker.pickImage(source: source, imageQuality: 85);
    if (selectedImage == null) return;

    // show preview + metadata form
    ClothingType selectedType = ClothingType.top;
    final TextEditingController descController = TextEditingController();

    final savedImage = await showModalBottomSheet<File?>(
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
                          File(selectedImage.path),
                          fit: BoxFit.contain,
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
                      decoration: const InputDecoration(labelText: 'Type'),
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
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // copy file to app documents folder
                              final docs = await getApplicationDocumentsDirectory();
                              final ext = p.extension(selectedImage.path);
                              final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
                              final savedPath = p. join(docs.path, fileName);
                              final savedFile = await File(selectedImage.path).copy(savedPath);

                              // optionally attach metadata (selectedType/name) here
                              // e.g. insert into DB or call a callback
                              // Example return value: saved file
                              Navigator.of(ctx).pop(savedFile);
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

    if (savedImage != null) {
      // saved is the File in app storage; here you should:
      // - insert path + metadata into your DB
      // - update UI state (setState) to show the new item in Wardrobe
      final savedPath = savedImage.path;

      final item = ClothingItem(
        id: null, // make id nullable in your model (int?) so DB can autoincrement
        path: savedPath,
        type: selectedType,
        createdAt: DateTime.now(),
        description: descController.text,
      );

      await WardrobeDatabase.instance.insertImage(item);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved — add it to DB / refresh wardrobe.')),
      );

    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar
      appBar: AppBar(
        title: Text(_pages[currentPageIndex].$2),
      ),

      // Body
      body: _pages[currentPageIndex].$1,

      // ADD clothing categories
      bottomNavigationBar: BottomNavigationBar(

        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.man_4_sharp,
              // color: Colors.grey
            ),
            label: 'Outfits',
          ),
    
          BottomNavigationBarItem(
            icon: Icon(
              Icons.checkroom,
              // color: Colors.grey
            ),
            label: 'Wardrobe',
          ),

          if (currentPageIndex == 0) ...[ // Outfits Page
            BottomNavigationBarItem(
              icon: Icon(
                Icons.mode_edit_outlined,
                // color: Colors.grey
              ),
              label: 'Create Outfit',
            ),
          ],
          if (currentPageIndex == 1) ...[
            BottomNavigationBarItem(
              icon: Icon(
                Icons.photo_camera_back_outlined,
                // color: Colors.grey
              ),
              label: 'Insert',
            )
          ],
        ],

        currentIndex: currentPageIndex,
        onTap: _handleBottomBarTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: false,
        selectedIconTheme: const IconThemeData(
          color: Colors.blue,
        ),
        unselectedIconTheme: const IconThemeData(
          color: Colors.grey,
        ),
      ),
    );
  }
}