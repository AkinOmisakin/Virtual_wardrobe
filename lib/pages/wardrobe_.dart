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
  ];

  final List<String> trousers = [
    'assets/jeans.jpg',
    'assets/cargo.jpg',
  ];

  final List<String> jackets = [
    'assets/cashmere.jpg',
    'assets/red_hoodie.jpg',
  ];

  void _removeClothingItem(int index) {
    setState(() {
      tops.removeAt(index);
      trousers.removeAt(index);
      jackets.removeAt(index);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // BODY** with clothing categories
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Tops', context),
            _clothingCarousel(tops),

            _sectionTitle('Trousers', context),
            _clothingCarousel(trousers),

            _sectionTitle('Jackets', context),
            _clothingCarousel(jackets),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
  
  Widget _clothingCarousel(List<String> images) {
    if (images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
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
              // Clothing item description
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      images[index].split('/').last.split('.').first.replaceAll('_', ' ').toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    //remove item button
                    ElevatedButton(
                      onPressed: () => _removeClothingItem(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: const Text('Remove Item'),
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}


// Padding(
//   padding: const EdgeInsets.all(12.0),
//   child: ClipRRect(
//     borderRadius: BorderRadius.circular(20),
//     child: Container(
//       color: Theme.of(context).colorScheme.surface,
      
//       child: Image(
//         image: AssetImage(images[index]),
//         fit: BoxFit.contain,
//     ),
//     ),
//   ),
// );