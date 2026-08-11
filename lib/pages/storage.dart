// import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';

//models
import 'package:virtual_wardrobe/models/clothing_categories.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
//cloud
import 'package:virtual_wardrobe/pages/item.dart';
import 'package:provider/provider.dart';
import 'package:virtual_wardrobe/services/itemprovider.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key, required this.userId});
  final String userId;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage>  {
  static bool _show = false; // Whether to show item counts in section titles

  // One PageController per category, kept across rebuilds so they aren't
  // recreated (and leaked) on every build. Category titles are a small fixed
  // set, so this map stays bounded.
  final Map<String, PageController> _carouselControllers = {};

  PageController _controllerFor(String key) => _carouselControllers.putIfAbsent(
        key,
        () => PageController(viewportFraction: 0.5),
      );

  @override
  void dispose() {
    for (final controller in _carouselControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ItemProvider>(context);

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              provider.error ?? 'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final items = provider.items;
    if (items.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'Your wardrobe is empty.\nTap the + button to add some items!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

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
              _clothingCarousel(category.title, category.items),
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
  }

  Widget _clothingCarousel(String key, List<ClothingItem> items) {
    return SizedBox(
      height: 200,
      child:  PageView.builder(
        controller: _controllerFor(key),
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
        }
      )
    );
  }

  Route<void> _routeToEditItemPage(ClothingItem item) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => ItemPage(item: item, isEditing: true, userId: widget.userId),
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