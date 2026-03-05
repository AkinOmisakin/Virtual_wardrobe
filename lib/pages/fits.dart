import 'package:flutter/material.dart';

class OutfitsPage extends StatefulWidget {
  const OutfitsPage({super.key});

   @override
  State<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends State<OutfitsPage> {

  final List<String> outfits = [
    'assets/clothing/bear_t_jeans.png',
    'assets/clothing/peace_t_cargo.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // BODY** with clothing categories
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // _sectionTitle('Display', context),
            _clothingCarousel(outfits),
          ],
        ),
      ),
    );
  }

  // Widget _sectionTitle(String title, BuildContext context) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  //     child: Text(
  //       title,
  //       style: Theme.of(context).textTheme.titleLarge,
  //     ),
  //   );
  // }

  Widget _clothingCarousel(List<String> images) {
    return SizedBox(
      height: 600,
      child: PageView.builder(
        controller: PageController(viewportFraction: 1),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(25.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                
                child: Image(
                  image: AssetImage(images[index]),
                  fit: BoxFit.contain,
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}