// import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
//models
import 'package:virtual_wardrobe/models/clothing_categories.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
//cloud
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/pages/item.dart';
import 'package:provider/provider.dart';
import 'package:virtual_wardrobe/services/itemprovider.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage>  {
  static bool _show = false;

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

    final items = provider.items ?? [];
    final categories = ClothesViewModel.categorizeItems(items);

    return Scaffold(
      body: _buildCategoryList(categories),
    );
  }
  
  /// Builds a scrollable list of clothing categories, each with a section title and carousel of items.
  /// 
  /// [categories] is a list of ClothingCategory objects to display.
  Widget _buildCategoryList(List<ClothingCategory> categories) {

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: categories.map((category) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, category.title, category.items),
              _clothingCarousel(category.items),
              const SizedBox(height: 24),
            ]
          );
        }).toList()
    );
  }
  void _handleTitle() {
    setState(() {
      _show = !_show;
    });
  }

  Widget _sectionTitle(BuildContext context, String title, List<ClothingItem> items) {
    // final showItemCount = _showCountFor.contains(title);
    return InkWell(
      onTap: _handleTitle,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _show ? '$title (${items.length})' : title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
    // return Row(children: [
      // Title
      // Padding(
      //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      //   child: Text(
      //     '${title} (${items.length})',
      //     style: Theme.of(context).textTheme.titleMedium,
      //   ),
      // ),
      // Item count
      // if (items.isNotEmpty)
      //   Padding(
      //     padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      //     child: Text(
      //       '(${items.length}) Items',
      //       style: Theme.of(context).textTheme.titleSmall,
      //       textAlign: ,
      //     ),
        // ),
    // ]);
  }


  Widget _clothingCarousel(List<ClothingItem> items) {
    return SizedBox(
      height: 200,
      child:  PageView.builder(
        controller: PageController(viewportFraction: 0.5),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: () => Navigator.of(context).push(_routeToEditItemPage(item)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: EdgeInsets.all(10.0),
                  alignment: Alignment.center,
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl, // Use the URL from Firestore
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Icon(Icons.broken_image),
                  )
                )
              )
            )
          );
        }
      )
    );
  }

  Route<void> _routeToEditItemPage(ClothingItem item) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => ItemPage(item: item),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // animate page from the bottom
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.decelerate;
        final tween = Tween(begin: begin, end: end)
                      .chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child
        );
      }
    );
  } 


  // method to show modal bottom sheet for removing items
  // void _remove(List<ClothingItem> items, ClothingItem item) {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return SafeArea(
  //         child: Wrap(
  //           children: <Widget>[
  //             ListTile(
  //               leading: const Icon(Icons.delete, color: Colors.red),
  //               title: const Text('Delete Item', style: TextStyle(color: Colors.red)),
  //               onTap: () => _removeClothingItem(items, item),
  //             ),
  //             ListTile(
  //               leading: const Icon(Icons.cancel),
  //               title: const Text('Cancel'),
  //               onTap: () => Navigator.of(context).pop(),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // method to remove clothing items from the lists
  // void _removeClothingItem(List<ClothingItem> items, ClothingItem item) {
  //   Navigator.of(context).pop();
  //   setState(() {
  //     items.remove(item);
  //   });
  //   _deleteItemFromBackend(item);
  // }
  // void _deleteItemFromBackend(ClothingItem item) {
  //   final imageUrl = item.imageUrl;
  //   try {
  //     _deleteFromFirestoreById(item);
  //   } catch (e) {
  //     // print('Firestore deletion error: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to remove item from Firestore: $e')),
  //     );
  //   }

  //   try {
  //     _deleteFromSupabaseStorageByUrl(imageUrl);
  //   } catch (e) {
  //     // print('Supabase deletion error: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to remove image from Supabase: $e')),
  //     );
  //   }
  // }

  // Future<void> _deleteFromFirestoreById(ClothingItem item) async {
  //   final coll = FirebaseFirestore.instance.collection('clothes');
  //   final query = await coll.where('id', isEqualTo: item.id).limit(1).get();
  //   if (query.docs.isNotEmpty) {
  //     await query.docs.first.reference.delete();
  //     // print('Deleted Firestore document for imageUrl: $item.id');
  //   } else {
  //     debugPrint('No Firestore document found for imageUrl: $item.id');
  //   }
  // }

  // Future<void> _deleteFromSupabaseStorageByUrl(String imageUrl) async {
  //   final client = Supabase.instance.client;
  //   // Try to parse the common Supabase public storage URL:
  //   // Example: https://xyz.supabase.co/storage/v1/object/public/<bucket>/<path/to/file.jpg>
  //   // Example (Bear_t.png): https://zmnhdlrwnxsqcrcrzvje.supabase.co/storage/v1/object/public/Clothing%20images/bear_t.png
  //   try {

  //     // Fallback: try to parse using URI segments looking for 'public' then bucket
  //     final uri = Uri.parse(imageUrl);
  //     final seg = uri.pathSegments;
  //     final pubIdx = seg.indexOf('public');
  //     if (pubIdx != -1 && seg.length > pubIdx + 1) {
  //       final bucket = seg[pubIdx + 1];
  //       final path = seg.sublist(pubIdx + 2).join('/');
  //       if (path.isNotEmpty) {
  //         await client.storage.from(bucket).remove([path]);
  //         // print('Deleted supabase storage file (fallback): $bucket/$path');
  //         return;
  //       }
  //     }

  //     // If we reach here, parsing failed
  //     throw 'Could not determine Supabase bucket/path from URL';
  //   } catch (e) {
  //     // Re-throw to be handled by caller
  //     rethrow;
  //   }
  // }
  
}

class ClothesViewModel {
  static List<ClothingCategory> categorizeItems(List<ClothingItem> items) {
    // group items in the list by their type
    final grouped = groupBy(items, (ClothingItem item) => item.type);
  
    // Preferred ordering: Tops, Bottoms (trousers), Shoes
    final preferredOrder = [
      ClothingType.headwear,
      ClothingType.top,
      ClothingType.trouser,
      ClothingType.shoe,
      ClothingType.outwear,
      ClothingType.dress,
    ];

    final Map<ClothingType, String> groupNames = {
      ClothingType.headwear: 'Headwear',
      ClothingType.top: 'Tops',
      ClothingType.trouser: 'Trousers',
      ClothingType.shoe: 'Shoes',
      ClothingType.outwear: 'Outwear',
      ClothingType.dress: 'Dresses',
    };

    // The list of items group by type in a preferred order
    final List<ClothingCategory> result = [];

    // Add preferred types first (if present)
    for (final type in preferredOrder) {
      final bucket = grouped[type];
      if (bucket != null && bucket.isNotEmpty) {
        result.add(ClothingCategory(groupNames[type] as String, bucket));
      }
    }

    return result;
  }
}