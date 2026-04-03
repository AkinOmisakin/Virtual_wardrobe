import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:virtual_wardrobe/models/outfit.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Items in this look',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
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
                return _IndividualItemCard(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IndividualItemCard extends StatelessWidget {
  final ClothingItem item;

  const _IndividualItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              item.type.displayName, // Shows 'Shoes', 'Tops', etc.
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}