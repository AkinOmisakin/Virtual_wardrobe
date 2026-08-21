import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// import 'package:virtual_wardrobe/pages/item.dart';
// import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/pages/outfit_edit_page.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';




class OutfitDetailsPage extends StatelessWidget {
  final ResolvedOutfit resolved;

  const OutfitDetailsPage({super.key, required this.resolved});
  

  @override
  Widget build(BuildContext context) {
    final outfit = resolved.outfit;
    final items = resolved.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(outfit.name),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8, // Adjust based on your UI preference
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell( 
                  onTap: () => null, // Navigate to item details page if needed
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(10.0),
                        alignment: Alignment.center,
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                        ),
                      )
                    )
                  )
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: () {
                // Navigate to the edit outfit page
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => OutfitEditPage(resolved: resolved),
                  ),
                );
              },
              child: const Text('Edit Outfit'),
            ),
          ),
        ],
      ),
    );
  }
}