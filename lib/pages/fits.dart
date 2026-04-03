import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import 'package:virtual_wardrobe/pages/outfits_details_page.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/models/outfit.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';


class OutfitsPage extends StatelessWidget {
  const OutfitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OutfitProvider>(context);

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (provider.error != null) {
      return Scaffold(
          body: Center(child: Text('Error: ${provider.error}')));
    }

    if (provider.outfits.isEmpty) {
      return _EmptyState();
    }

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: provider.outfits.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final resolved = provider.outfits[index];
          return _OutfitCard(resolved: resolved);
        },
      ),
    );
  }
}

// ── empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_outlined,
                size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No outfits saved yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Build one on the canvas and tap "Save outfit"',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── outfit card ───────────────────────────────────────────────────────────────

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.resolved});

  final ResolvedOutfit resolved;

  @override
  Widget build(BuildContext context) {
    final outfit = resolved.outfit;
    final items = resolved.items;
    final provider = Provider.of<OutfitProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell( // Add this to make the whole card clickable
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OutfitDetailsPage(resolved: resolved),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header remains the same
          Row(
            children: [
              Expanded(
                child: Text(outfit.name, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _showRenameDialog(context, provider, outfit),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                onPressed: () => _confirmDelete(context, provider, outfit),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // NEW: The Canvas Preview
          if (items.isEmpty)
            _MissingItemsNote()
          else
            _OutfitCanvasPreview(resolved: resolved),

          const SizedBox(height: 8),

          Text(
            '${items.length} item${items.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    ),
      
     
    );
  }



  // ── dialogs ───────────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(
    BuildContext context,
    OutfitProvider provider,
    Outfit outfit,
  ) async {
    final controller =
        TextEditingController(text: outfit.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename outfit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.of(ctx).pop(v.trim());
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.of(ctx).pop(v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && outfit.id != null) {
      await provider.renameOutfit(outfit.id!, newName);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OutfitProvider provider,
    Outfit outfit,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete outfit'),
        content:
            Text('Delete "${outfit.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && outfit.id != null) {
      await provider.deleteOutfit(outfit.id!);
    }
  }
}

// ── item image strip ──────────────────────────────────────────────────────────

class _ItemStrip extends StatelessWidget {
  const _ItemStrip({required this.items});

  final List<ClothingItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 80,
              height: 90,
              color: Colors.grey[100],
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 24)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── missing items note ────────────────────────────────────────────────────────

class _MissingItemsNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          'Items have been removed from your wardrobe',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── the "canvas" style preview ────────────────────────────────────────────────

class _OutfitCanvasPreview extends StatelessWidget {
  const _OutfitCanvasPreview({required this.resolved});

  final ResolvedOutfit resolved;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1, // Creates a square canvas area
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: resolved.items.map((item) {
              // 1. Find the saved canvas metadata for this specific item
              final canvasData = resolved.outfit.canvasItems?.firstWhere(
                (c) => c.itemId == item.id,
                orElse: () => OutfitCanvasItem(itemId: item.id ?? '', x: 0, y: 0),
              );

              // 2. If no data exists, don't try to render at 0,0
              if (canvasData == null) return const SizedBox.shrink();

              return Positioned(
                left: canvasData.x,
                top: canvasData.y,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(canvasData.scale)    // Apply saved scale
                    ..rotateZ(canvasData.rotation), // Apply saved rotation
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    width: canvasData.size,      // Use saved size
                    height: canvasData.size,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}