// import 'dart:io';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:virtual_wardrobe/components/clothing_categories.dart';
import 'package:virtual_wardrobe/components/clothing_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class ClothesViewModel {
  static List<ClothingCategory> categorizeItems(List<ClothingItem> items) {
    final grouped = groupBy(items, (ClothingItem item) => item.type);
    
    return grouped.entries
        .map((entry) => ClothingCategory(
              entry.key.displayName,
              entry.value,
            ))
        .toList();
  }
}

// Optimized version: Prevents the widget from being disposed when navigating away


class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true; // Keep the state alive 

  List<ClothingItem>? _cachedItems;
  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadClothes();
  }

  void _loadClothes() {
    _subscription = FirebaseFirestore.instance
        .collection('clothes')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _cachedItems = snapshot.docs
            .map((doc) => ClothingItem.fromMap(doc.data(), docId: doc.id))
            .toList();
        print('Loaded ${_cachedItems!.length} clothing items from Firestore');
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // IMPORTANT: Must call super.build()
    
    if (_cachedItems == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final categories = ClothesViewModel.categorizeItems(_cachedItems!);

    return Scaffold(
      body: _buildCategoryList(categories),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   super.build(context); // Call super.build to ensure the keep-alive functionality works

  //   return Scaffold(
  //     body: StreamBuilder<QuerySnapshot>(
  //       // Listen to the 'clothes' collection in Firestore
  //       stream: FirebaseFirestore.instance.collection('clothes').snapshots(),
  //       builder: (context, snapshot) {
  //         if (snapshot.connectionState == ConnectionState.waiting) {
  //           return const Center(child: CircularProgressIndicator());
  //         }
  //         if (snapshot.hasError) {
  //           return const Center(child: Text('Error fetching clothes'));
  //         }

  //         // Convert Firestore documents into your ClothingItem objects
  //         List<ClothingItem> allItems = snapshot.data!.docs.map((doc) {
  //           print('Document data: ${doc.data()}'); // Debug print
  //           // print(ClothingType.values.byName('Shoes'));
  //           return ClothingItem.fromMap(doc.data() as Map<String, dynamic>, docId: doc.id);
  //         }).toList();

  //         // Group items by type automatically
  //         final categories = ClothesViewModel.categorizeItems(allItems);

  //         return _buildCategoryList(categories);
  //       },
  //     ),
  //   );
  // }
  
  Widget _buildCategoryList(List<ClothingCategory> categories) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.map((category) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, category.title, category.items),
              _clothingCarousel(category.items),
              const SizedBox(height: 24),
            ],
          );
        }).toList(),
      ),
    );
  }
  
  Widget _sectionTitle(BuildContext context, String title, List<ClothingItem> items) {
    return Row(children: [
      // Title
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      // Item count
      if (items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '(${items.length}) Items',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
    ]);
  }

  Widget _clothingCarousel(List<ClothingItem> items) {
    AppBar(
      title: Text('Clothing Items'),
    );

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text("No items yet"),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carousel of clothing items
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.7),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              // Check if the image is a network URL or local asset
              // Usable if pushing for offline support in the future
              // final bool isNetworkImage = item.imageUrl.startsWith('http://') || 
              //                          item.imageUrl.startsWith('https://');
              // print(item);
              return Row(
                children: <Widget>[
                  // Clothing item Image
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          alignment: Alignment.center,
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl, // Use the URL from Firestore
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // space between image and description
                  SizedBox(width: 16),
                  // Clothing item description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: <Widget>[
                        Text(
                          items[index].description.toString(), // name
                          // style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Spacer(),
                        //remove item button
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: InkWell(
                            onTap: () => _remove(items, item), // remove item at index
                            borderRadius: BorderRadius.circular(30), // Pill shape for ripple effect
                            child: Container(
                              width: 80, // Wide button style
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey[200], // Or use Theme.of(context).cardColor for dark mode
                                borderRadius: BorderRadius.circular(30), // Distinctive pill shape
                              ),
                              child: const Text(
                                'Remove',
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
                  )
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  // method to show modal bottom sheet for removing items
  void _remove(List<ClothingItem> items, ClothingItem item) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Item', style: TextStyle(color: Colors.red)),
                onTap: () => _removeClothingItem(items, item),
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  // method to remove clothing items from the lists
  void _removeClothingItem(List<ClothingItem> items, ClothingItem item) {
    Navigator.of(context).pop();
    setState(() {
      items.remove(item);
    });
    _deleteItemFromBackend(item);
  }
  void _deleteItemFromBackend(ClothingItem item) {
    final imageUrl = item.imageUrl;
    try {
      _deleteFromFirestoreById(item);
    } catch (e) {
      print('Firestore deletion error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove item from Firestore: $e')),
      );
    }

    try {
      _deleteFromSupabaseStorageByUrl(imageUrl);
    } catch (e) {
      print('Supabase deletion error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove image from Supabase: $e')),
      );
    }
  }

  Future<void> _deleteFromFirestoreById(ClothingItem item) async {
    final coll = FirebaseFirestore.instance.collection('clothes');
    final query = await coll.where('id', isEqualTo: item.id).limit(1).get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.delete();
      print('Deleted Firestore document for imageUrl: $item.id');
    } else {
      print('No Firestore document found for imageUrl: $item.id');
    }
  }

  Future<void> _deleteFromSupabaseStorageByUrl(String imageUrl) async {
    final client = Supabase.instance.client;
    // Try to parse the common Supabase public storage URL:
    // Example: https://xyz.supabase.co/storage/v1/object/public/<bucket>/<path/to/file.jpg>
    // Example (Bear_t.png): https://zmnhdlrwnxsqcrcrzvje.supabase.co/storage/v1/object/public/Clothing%20images/bear_t.png
    // const marker = '/storage/v1/object/public/';
    // try {
    //   if (imageUrl.contains(marker)) {
    //     final remainder = imageUrl.split(marker)[1];
    //     final parts = remainder.split('/');
    //     if (parts.length >= 2) {
    //       final bucket = parts.first;
    //       final path = parts.sublist(1).join('/');
    //       if (path.isNotEmpty) {
    //         await client.storage.from(bucket).remove([path]);
    //         print('Deleted supabase storage file: $bucket/$path');
    //         return;
    //       }
    //     }
    //   }
    try {

      // Fallback: try to parse using URI segments looking for 'public' then bucket
      final uri = Uri.parse(imageUrl);
      final seg = uri.pathSegments;
      final pubIdx = seg.indexOf('public');
      if (pubIdx != -1 && seg.length > pubIdx + 1) {
        final bucket = seg[pubIdx + 1];
        final path = seg.sublist(pubIdx + 2).join('/');
        if (path.isNotEmpty) {
          await client.storage.from(bucket).remove([path]);
          print('Deleted supabase storage file (fallback): $bucket/$path');
          return;
        }
      }

      // If we reach here, parsing failed
      throw 'Could not determine Supabase bucket/path from URL';
    } catch (e) {
      // Re-throw to be handled by caller
      rethrow;
    }
  }
  
}