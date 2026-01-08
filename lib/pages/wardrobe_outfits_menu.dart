import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:virtual_wardrobe/pages/outfits_.dart';
import 'package:virtual_wardrobe/pages/wardrobe_.dart';
import 'package:virtual_wardrobe/services/dbhelper_.dart';
import 'package:virtual_wardrobe/components/imageclass_.dart';
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
  int buttonIndex = 0;

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

  // void _onAddClothing() {
  //   showModalBottomSheet(
  //     context: context,

  //     builder: (ctx) => Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: <Widget> [
  //         // Add Photo from gallery option
  //         ElevatedButton(
  //           onPressed: () async {
  //             final image_file = await _selectPhotoFromSource(ImageSource.gallery);
  //             if (image_file != null) {
  //               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image added from gallery')));
  //               // TODO: refresh wardrobe UI / reload images from DB
  //             }
  //           },
  //           child: const Text('Add Clothing'),
  //         ),

  //         // Take Photo option
  //         ElevatedButton(
  //           onPressed: () async{
  //             final image_file = await _selectPhotoFromSource(ImageSource.camera);
  //             if (image_file != null) {
  //               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image added from gallery')));
  //               // TODO: refresh wardrobe UI / reload images from DB
  //             }
  //           },
  //           child: Column(
  //             children: const <Widget>[
  //               Icon(Icons.camera_alt_outlined),
  //               Text('Take Photo'),
  //             ],
  //           ),
  //         )

  //       ],
  //     ),
  //   );
  // }

  Future<File?> _selectPhotoFromSource(ImageSource source) async {
    final ImagePicker imagePicker = ImagePicker();
    final XFile? selectedImage = 
            await imagePicker.pickImage(source: source, imageQuality: 90);
    if (selectedImage == null) return null;

    try {
      final docs = await getApplicationDocumentsDirectory(); // Get the app's document directory
      final ext = p.extension(selectedImage.path); // Get the file extension
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext'; // Unique file name
      final savedPath = p.join(docs.path, fileName); // Full path to save the image

      // copy to app folder
      final savedFile = await File(selectedImage.path).copy(savedPath);

      // insert into local DB
      final item = ImageItem(path: savedFile.path, createdAt: DateTime.now().toIso8601String());
      await DBHelper.instance.insertImage(item);

      return savedFile;
    } catch (e) {
      // ignore: avoid_print
      print('Error saving image: $e');
      return null;
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
                Icons.add_circle_outline,
                // color: Colors.grey
              ),
              label: 'Create Outfit',
            ),
          ],
          if (currentPageIndex == 1) ...[
            BottomNavigationBarItem(
              icon: Icon(
                Icons.camera_alt_outlined,
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