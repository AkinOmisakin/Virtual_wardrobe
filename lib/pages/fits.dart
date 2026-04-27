import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:virtual_wardrobe/pages/outfits_details_page.dart';
import 'package:virtual_wardrobe/models/outfit.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';

class OutfitsPage extends StatelessWidget {
  const OutfitsPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OutfitProvider>(context);

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (provider.error != null) {
      return Scaffold(body: Center(child: Text('Error: ${provider.error}')));
    }

    if (provider.outfits.isEmpty) {
      debugPrint('No outfits found for user $userId');
      return const _EmptyState();
    }

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: provider.outfits.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          return _OutfitCard(resolved: provider.outfits[index]);
        },
      ),
    );
  }
}

// ── empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border_outlined, size: 56, color: Colors.grey[400]),
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

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OutfitDetailsPage(resolved: resolved),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header: name + action buttons ──────────────────────────
            // Buttons are wrapped in GestureDetector with opaque hit-testing
            // so their taps are consumed before bubbling to the card InkWell.
            Row(
              children: [
                Expanded(
                  child: Text(
                    outfit.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showRenameDialog(context, provider, outfit),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.edit_outlined, size: 18),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _confirmDelete(context, provider, outfit),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // if (items.isEmpty)
            //   const _MissingItemsNote()
            // else
            _OutfitCanvasPreview(resolved: resolved),

            const SizedBox(height: 6),

            Text(
              '${items.length} item${items.length == 1 ? '' : 's'}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[500]),
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
    final controller = TextEditingController(text: outfit.name);
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
            child: const Text('Cancel'),
          ),
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
        content: Text('Delete "${outfit.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && outfit.id != null) {
      await provider.deleteOutfit(outfit.id!);
    }
  }
}

// ── missing items note ────────────────────────────────────────────────────────

class _MissingItemsNote extends StatelessWidget {
  const _MissingItemsNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
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

// ── canvas preview ────────────────────────────────────────────────────────────

class _OutfitCanvasPreview extends StatelessWidget {
  const _OutfitCanvasPreview({required this.resolved});

  final ResolvedOutfit resolved;

  @override
  Widget build(BuildContext context) {
    final canvasItems = resolved.outfit.canvasItems;

    // No saved canvas state — fall back to a simple horizontal image strip.
    if (canvasItems == null || canvasItems.isEmpty) {
      return _ItemStrip(items: resolved.items);
    }

    // 1. Calculate the bounding box of all items
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final canvasData in canvasItems) {
      // Skip entries whose item has since been deleted.
      if (!resolved.items.any((i) => i.id == canvasData.itemId)) continue;

      // Factor in scale to compute the true visual bounds
      final scaledSize = canvasData.size * canvasData.scale;
      final offset = (scaledSize - canvasData.size) / 2;

      final itemLeft = canvasData.x - offset;
      final itemTop = canvasData.y - offset;
      final itemRight = canvasData.x + canvasData.size + offset;
      final itemBottom = canvasData.y + canvasData.size + offset;

      if (itemLeft < minX) minX = itemLeft;
      if (itemTop < minY) minY = itemTop;
      if (itemRight > maxX) maxX = itemRight;
      if (itemBottom > maxY) maxY = itemBottom;
    }

    // Fallback if no valid items were found
    if (minX == double.infinity) {
      return _ItemStrip(items: resolved.items);
    }

    // Add a little padding so items don't touch the very edge of the preview
    const double padding = 16.0;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          // 2. Use a FittedBox to cleanly scale the bounded content
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: contentWidth,
              height: contentHeight,
              child: Stack(
                children: [
                  for (final canvasData in canvasItems)
                    Builder(builder: (_) {
                      final hasItem =
                          resolved.items.any((i) => i.id == canvasData.itemId);
                      if (!hasItem) return const SizedBox.shrink();

                      final item = resolved.items
                          .firstWhere((i) => i.id == canvasData.itemId);

                      return Positioned(
                        // 3. Shift positions relative to our new bounding box
                        left: canvasData.x - minX,
                        top: canvasData.y - minY,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..scale(canvasData.scale)
                            ..rotateZ(canvasData.rotation),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            width: canvasData.size,
                            height: canvasData.size,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const SizedBox.shrink(),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── fallback strip (outfits saved without canvas state) ──────────────────────

class _ItemStrip extends StatelessWidget {
  const _ItemStrip({required this.items});

  final List items;

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
              color: Colors.grey[100],
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 24),
              ),
            ),
          );
        },
      ),
    );
  }
}
