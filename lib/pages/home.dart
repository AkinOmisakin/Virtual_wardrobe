import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// import 'package:virtual_wardrobe/models/outfit.dart';
import 'package:virtual_wardrobe/pages/outfits_details_page.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Cher', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _RecentOutfitsSection(),
            // Add more home sections here later (e.g. trending, for you…)
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent outfits section
// ─────────────────────────────────────────────────────────────────────────────

class _RecentOutfitsSection extends StatelessWidget {
  const _RecentOutfitsSection();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OutfitProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── section header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent outfits',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!provider.isLoading &&
                  provider.error == null &&
                  provider.outfits.isNotEmpty)
                TextButton(
                  focusNode: FocusNode(skipTraversal: true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black),
                  clipBehavior: Clip.none,
                  onPressed: () {},
                  child: Text(
                    'View all',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith( 
                          color: const Color.fromARGB(129, 0, 0, 0),
                            // decoration: TextDecoration.underline,
                          ),
                  )
                )
            ],
          ),
        ),

        // ── content ─────────────────────────────────────────────────────
        if (provider.isLoading)
          const _LoadingRow()
        else if (provider.error != null)
          _ErrorNote(message: provider.error!)
        else if (provider.outfits.isEmpty)
          const _EmptyNote()
        else
          _OutfitScrollRow(
            outfits: provider.outfits.take(5).toList(),
          ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal scroll row of outfit cards
// ─────────────────────────────────────────────────────────────────────────────

class _OutfitScrollRow extends StatelessWidget {
  const _OutfitScrollRow({required this.outfits});

  final List<ResolvedOutfit> outfits;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: outfits.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _OutfitCard(resolved: outfits[index]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual outfit card
// ─────────────────────────────────────────────────────────────────────────────

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.resolved});

  final ResolvedOutfit resolved;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OutfitDetailsPage(resolved: resolved),
        ),
      ),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── preview thumbnail ────────────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.grey[50],
                  child: resolved.outfit.canvasItems?.isNotEmpty == true
                      ? _CanvasPreview(resolved: resolved)
                      : _ImageGrid(items: resolved.items),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── outfit name ──────────────────────────────────────────────
            Text(
              resolved.outfit.name,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── item count ───────────────────────────────────────────────
            Text(
              '${resolved.items.length} item${resolved.items.length == 1 ? '' : 's'}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontStyle: FontStyle.normal, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Canvas-accurate preview  (bounding-box approach from home.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _CanvasPreview extends StatelessWidget {
  const _CanvasPreview({required this.resolved});

  final ResolvedOutfit resolved;

  @override
  Widget build(BuildContext context) {
    final canvasItems = resolved.outfit.canvasItems!;

    // Build lookup map once.
    final itemById = {for (final i in resolved.items) i.id: i};

    // Calculate bounding box of all valid items.
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final c in canvasItems) {
      if (!itemById.containsKey(c.itemId)) continue;
      final scaledSize = c.size * c.scale;
      final overflow   = (scaledSize - c.size) / 2;
      minX = [minX, c.x - overflow].reduce((a, b) => a < b ? a : b);
      minY = [minY, c.y - overflow].reduce((a, b) => a < b ? a : b);
      maxX = [maxX, c.x + c.size + overflow].reduce((a, b) => a > b ? a : b);
      maxY = [maxY, c.y + c.size + overflow].reduce((a, b) => a > b ? a : b);
    }

    // Fallback if nothing valid.
    if (minX == double.infinity) return _ImageGrid(items: resolved.items);

    const pad = 12.0;
    minX -= pad; minY -= pad; maxX += pad; maxY += pad;
    final w = maxX - minX;
    final h = maxY - minY;

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            for (final c in canvasItems)
              if (itemById.containsKey(c.itemId))
                Positioned(
                  left: c.x - minX,
                  top:  c.y - minY,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..scale(c.scale)
                      ..rotateZ(c.rotation),
                    child: CachedNetworkImage(
                      imageUrl: itemById[c.itemId]!.imageUrl,
                      width:  c.size,
                      height: c.size,
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.broken_image, size: 20),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback: 2×2 image grid when no canvas state is saved
// ─────────────────────────────────────────────────────────────────────────────

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.items});

  final List items;

  @override
  Widget build(BuildContext context) {
    final preview = items.take(4).toList();
    if (preview.isEmpty) {
      return Center(
        child: Icon(Icons.checkroom_outlined,
            size: 32, color: Colors.grey[300]),
      );
    }
    if (preview.length == 1) {
      return CachedNetworkImage(
        imageUrl: preview[0].imageUrl,
        fit: BoxFit.contain,
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const Icon(Icons.broken_image),
      );
    }
    // 2-column grid for 2–4 items.
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: preview.map((item) {
        return Container(
          color: Colors.grey[100],
          child: CachedNetworkImage(
            imageUrl: item.imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) =>
                const Icon(Icons.broken_image, size: 16),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// State widgets
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    // Shimmer-style placeholder cards while loading.
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                  width: 100, height: 10,
                  color: Colors.grey[100]),
              const SizedBox(height: 4),
              Container(
                  width: 60, height: 8,
                  color: Colors.grey[100]),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.bookmark_border_outlined,
                size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No outfits yet — build one on the canvas',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontStyle: FontStyle.normal, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Could not load outfits: $message',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.red[400], fontStyle: FontStyle.normal),
      ),
    );
  }
}
