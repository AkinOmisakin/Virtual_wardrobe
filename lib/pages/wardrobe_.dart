// import 'dart:io';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';

class WardrobeBody extends StatefulWidget {
  const WardrobeBody({super.key});

  @override
  State<WardrobeBody> createState() => _WardrobeBodyState();
}

class _WardrobeBodyState extends State<WardrobeBody> {
  
  final List<String> tops = [
    'assets/bear_t.jpg',
    'assets/peace_t.jpg',
    'assets/cashmere.jpg',
    'assets/red_hoodie.jpg',
  ];

  final List<String> trousers = [
    'assets/jeans.jpg',
    'assets/cargo.jpg',
  ];

  void _removeClothingItem(int index) {
    setState(() {
      tops.removeAt(index);
      trousers.removeAt(index);
    });
  }

  void _remove(int index) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Item', style: TextStyle(color: Colors.red)),
                onTap: () => _removeClothingItem(index),
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

      // BODY** with clothing categories
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Tops', context, tops),
            _clothingCarousel(tops),

            _sectionTitle('Trousers', context, trousers),
            _clothingCarousel(trousers),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, BuildContext context, List<String> images) {
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
      if (images.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '(${images.length}) Items',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
    ]);
  }

  Widget _clothingCarousel(List<String> images) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carousel of clothing items
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.7),
            itemCount: images.length,
            itemBuilder: (context, index) {
              return Row(
                children: <Widget>[
                  // Clothing item Image
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        alignment: Alignment.center,
                        child: Image(
                          image: AssetImage(images[index]),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  // add a space between image and description
                  SizedBox(width: 16),
                  // Clothing item description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: <Widget>[
                        Text(
                          images[index].split('/').last.split('.').first.replaceAll('_', ' ').toUpperCase(), // name
                          // style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Spacer(),
                        //remove item button
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: InkWell(
                            onTap: () => _remove(index), // Close the modal
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