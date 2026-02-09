// import 'dart:io';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:virtual_wardrobe/components/clothing_categories.dart';
import 'package:virtual_wardrobe/components/clothing_item.dart';

class WardrobeBody extends StatefulWidget {
  const WardrobeBody({super.key});

  @override
  State<WardrobeBody> createState() => _WardrobeBodyState();
}

class _WardrobeBodyState extends State<WardrobeBody> {
  
  // lists of clothing displayed in the wardrobe carousels
  static List<ClothingItem> tops = [
    ClothingItem(
      type: ClothingType.top,
      image: Image.asset('assets/clothing/bear_t.jpg'),
      description: 'A cute bear t-shirt',
    ),
    ClothingItem(
      type: ClothingType.top,
      image: Image.asset('assets/clothing/peace_t.jpg'),
      description: 'A stylish peace sign t-shirt',
    ),
    ClothingItem(
      type: ClothingType.top,
      image: Image.asset('assets/clothing/cashmere.jpg'),
      description: 'A warm cashmere sweater',
    ),
    ClothingItem(
      type: ClothingType.top,
      image: Image.asset('assets/clothing/red_hoodie.jpg'),
      description: 'A cozy red hoodie',
    ),
  ];

  // list_trousers = SELECT * FROM clothing_items WHERE type = 'trousers';
  // trousers.mergeFromDatabase(list_trousers);

  static List<ClothingItem> trousers = [
    ClothingItem(
      type: ClothingType.trousers,
      image: Image.asset('assets/clothing/jeans.jpg'),
      description: 'A pair of stylish jeans',
    ),
    ClothingItem(
      type: ClothingType.trousers,
      image: Image.asset('assets/clothing/cargo.jpg'),
      description: 'A pair of comfortable cargo pants',
    ),
  ];

  static List<ClothingItem> shoes = [
    ClothingItem(
      type: ClothingType.shoes,
      image: Image.asset('assets/clothing/blue_laces_shoe.jpg'),
      description: 'A pair of blue shoes with white laces',
    ),
    ClothingItem(
      type: ClothingType.shoes,
      image: Image.asset('assets/clothing/brown_smart_shoe.jpg'),
      description: 'A pair of brown smart shoes',
    ),
  ];

  late List<ClothingCategory> categories;

  @override
  void initState() {
    super.initState();
    categories = [
      ClothingCategory('Tops', tops),
      ClothingCategory('Trousers', trousers),
      ClothingCategory('Shoes', shoes),
    ];
  }

  

  // method to remove clothing items from the lists
  void _removeClothingItem(List<ClothingItem> category, int index) {
    Navigator.of(context).pop();
    setState(() {
      category.removeAt(index);
    });
  }

  // method to show modal bottom sheet for removing items
  void _remove(List<ClothingItem> category, int index) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Item', style: TextStyle(color: Colors.red)),
                onTap: () => _removeClothingItem(category, index),
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
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
                          child: Image(
                            image: items[index].image.image,
                            fit: BoxFit.cover,
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
                            onTap: () => _remove(items, index), // remove item at index
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
}