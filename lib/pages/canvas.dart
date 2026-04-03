import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//pages
import 'package:virtual_wardrobe/pages/storage.dart';

//models
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/models/clothing_categories.dart';
import 'package:virtual_wardrobe/models/canvas_item.dart';
import 'package:virtual_wardrobe/models/outfit.dart';

//services
import 'package:provider/provider.dart';
import 'package:virtual_wardrobe/services/itemprovider.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // inventory trackers
  String _selectedFilter = 'All';
  final List<ClothingItem> _selectedItems = [];
  // canvas trackers
  final List<CanvasItem> _itemsInCanvas = [];
  CanvasItem? _selectedCanvasItem;
  late final double addOffsetToNewItem = _itemsInCanvas.length * 20;
  // for smooth scaling/rotation
  late double _initialScale;
  late double _initialRotation;
  // save state
  bool _saving = false;

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final provider = Provider.of<ItemProvider>(context);
    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (provider.error != null) {
      return Scaffold(body: Center(child: Text('Error: ${provider.error}')));
    }

    final filteredItems = ClothesViewModel.categorizeItems(provider.items);
    final filterOptions = <String>['All'] +
        filteredItems.map((i) => i.title).toList();

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildCanvas(),
                if (_selectedCanvasItem != null) _showToolBar(),
                // Save button — only visible when there are items on the canvas
                if (_itemsInCanvas.isNotEmpty) _buildSaveButton(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GestureDetector(
        onTap: () =>
            _showInventory(provider.items, filteredItems, filterOptions),
        onVerticalDragStart: (_) =>
            _showInventory(provider.items, filteredItems, filterOptions),
        child: Container(
          height: 50,
          color: const Color.fromRGBO(0, 0, 0, 0.9),
          child: const Center(
            child: ImageIcon(
              AssetImage('assets/icons/up-chevron.png'),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ── save button overlay ────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _itemsInCanvas.isEmpty ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : _onSaveOutfit,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_add_outlined,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Save outfit',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── save outfit flow ───────────────────────────────────────────────────────

  /// Shows a name dialog then writes the outfit to Firestore.
  Future<void> _onSaveOutfit() async {
    // Guard: every canvas item must have a Firestore id. Items added from the
    // wardrobe always have one (ItemProvider passes docId through). If somehow
    // an item slipped in without one, bail early rather than saving corrupt data.
    final missingId =
        _itemsInCanvas.any((c) => c.item.id == null || c.item.id!.isEmpty);
    if (missingId) {
      _showSnack('Some items are missing an ID — please re-add them.');
      return;
    }

    final name = await _showNameDialog();
    if (name == null) return; // user cancelled

    setState(() => _saving = true);
    try {
      await _saveOutfit(name);
      if (mounted) _showSnack('Outfit "$name" saved!');
    } catch (e) {
      if (mounted) _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Shows a dialog asking for the outfit name.
  /// Returns the trimmed name, or null if cancelled.
  Future<String?> _showNameDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save outfit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Summer casual',
            labelText: 'Outfit name',
          ),
          onSubmitted: (v) {
            final name = v.trim();
            if (name.isNotEmpty) Navigator.of(ctx).pop(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Builds an [Outfit] from the current canvas state and writes it to
  /// the 'outfits' Firestore collection.
  Future<void> _saveOutfit(String name) async {
    final outfit = Outfit(
      name: name,
      // Deduplicated ordered list of item IDs (preserves z-order from canvas)
      itemIds: _itemsInCanvas.map((c) => c.item.id!).toList(),
      // Full canvas state so the layout can be restored later
      canvasItems: _itemsInCanvas
          .map(
            (c) => OutfitCanvasItem.fromValues(
              itemId: c.item.id!,
              position: c.position,
              scale: c.scale,
              rotation: c.rotation,
              size: c.size,
            ),
          )
          .toList(),
    );

    await FirebaseFirestore.instance
        .collection('outfits')
        .add(outfit.toMap());
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── canvas ─────────────────────────────────────────────────────────────────

  Widget _buildCanvas() {
    return GestureDetector(
      onTap: _deselect,
      child: Container(
        color: Colors.grey[200],
        child: Stack(
          children: _itemsInCanvas.map(_buildCanvasItem).toList(),
        ),
      ),
    );
  }

  Widget _buildCanvasItem(CanvasItem canvasItem) {
    final itemSelected = _selectedCanvasItem == canvasItem;

    return Positioned(
      left: canvasItem.position.dx,
      top: canvasItem.position.dy,
      child: GestureDetector(
        onTap: itemSelected ? _deselect : () => _select(canvasItem),
        onScaleStart: (details) {
          _select(canvasItem);
          _initialScale = canvasItem.scale;
          _initialRotation = canvasItem.rotation;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 1) {
              _selectedCanvasItem!.position += details.focalPointDelta;
            }
            if (details.pointerCount >= 2) {
              _selectedCanvasItem!.scale = _initialScale * details.scale;
              _selectedCanvasItem!.rotation =
                  _initialRotation + details.rotation;
            }
          });
        },
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..multiply(
                Matrix4.diagonal3Values(canvasItem.scale, canvasItem.scale, 1.0))
            ..rotateZ(canvasItem.rotation),
          child: DottedBorder(
            options: RectDottedBorderOptions(
              color: itemSelected
                  ? const Color.fromARGB(255, 183, 0, 255)
                  : const Color.fromARGB(0, 0, 0, 0),
              dashPattern: const [10, 5],
              strokeWidth: 2,
              padding: const EdgeInsets.all(16),
            ),
            child: SizedBox(
              width: canvasItem.size,
              height: canvasItem.size,
              child: CachedNetworkImage(
                imageUrl: canvasItem.item.imageUrl,
                fit: BoxFit.contain,
                placeholder: (c, u) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (c, u, e) =>
                    const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── inventory sheet ────────────────────────────────────────────────────────

  List<ClothingItem> getVisibleItems(
      List<ClothingItem> items, List<ClothingCategory> filteredItems) {
    if (_selectedFilter == 'All') return items;
    return filteredItems
        .firstWhere((cat) => cat.title == _selectedFilter)
        .items;
  }

  void _showInventory(List<ClothingItem> items,
      List<ClothingCategory> filteredItems, List<String> filterOptions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: DefaultTabController(
                length: 2,
                child: Scaffold(
                  appBar: AppBar(
                    elevation: 0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    automaticallyImplyLeading: false,
                    automaticallyImplyActions: false,
                    titleSpacing: 0,
                    centerTitle: true,
                    title: SizedBox(
                      height: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const ImageIcon(
                            AssetImage('assets/icons/down-chevron.png'),
                            color: Color.fromRGBO(0, 0, 0, 0.9),
                            size: 20,
                          ),
                          Text('Select',
                              style: Theme.of(context).textTheme.titleSmall),
                        ],
                      ),
                    ),
                    bottom: TabBar(
                      labelPadding: const EdgeInsets.only(bottom: 6),
                      unselectedLabelColor: Colors.grey[400],
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      tabs: [
                        Tab(
                          icon: const ImageIcon(
                            AssetImage('assets/icons/clothing_carousel.png'),
                            size: 30,
                          ),
                          text: 'Store room',
                        ),
                        Tab(
                          icon: const ImageIcon(
                            AssetImage('assets/icons/outfit.png'),
                            size: 30,
                          ),
                          text: 'Outfits',
                        ),
                      ],
                    ),
                  ),
                  body: TabBarView(
                    children: [
                      _buildInventory(
                          items, filteredItems, filterOptions, setModalState),
                      const Center(child: Text('Items tab content goes here')),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInventory(
      List<ClothingItem> items,
      List<ClothingCategory> filteredItems,
      List<String> filterOptions,
      Function setModalState) {
    final visibleItems = getVisibleItems(items, filteredItems);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        automaticallyImplyActions: false,
        flexibleSpace: Container(
          alignment: Alignment.center,
          child: InkWell(
            onTap: _onAddClothing,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_camera_back_outlined, size: 20),
                const SizedBox(width: 8),
                Text(' Add new clothing',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (filterOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12.0, vertical: 8.0),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filterOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final opt = filterOptions[i];
                    final selected = opt == _selectedFilter;
                    return ChoiceChip(
                      label: Text(opt,
                          style: TextStyle(
                              color:
                                  selected ? Colors.white : Colors.black87)),
                      selected: selected,
                      onSelected: (_) {
                        setModalState(() {
                          _selectedFilter = opt;
                          _selectedItems.clear();
                        });
                      },
                      selectedColor: Colors.black,
                      backgroundColor: Colors.grey[200],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    );
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: GridView.builder(
                padding:
                    const EdgeInsets.only(top: 8, bottom: 12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: visibleItems.length,
                itemBuilder: (context, index) {
                  final ClothingItem it = visibleItems[index];
                  final isSelected = _selectedItems.contains(it);
                  return InkWell(
                    onTap: () {
                      setModalState(() {
                        if (_selectedItems.contains(it)) {
                          _selectedItems.remove(it);
                        } else {
                          _selectedItems.add(it);
                        }
                      });
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: isSelected
                              ? Border.all(
                                  color: Colors.purpleAccent, width: 3)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: it.imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          placeholder: (c, u) => const Center(
                              child: CircularProgressIndicator()),
                          errorWidget: (c, u, e) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 12.0),
              child: SizedBox(
                width: double.infinity,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _selectedItems.isEmpty ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: _selectedItems.isEmpty,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _selectedItems.isEmpty
                          ? null
                          : () {
                              _addToCanvas(_selectedItems);
                              _selectedItems.clear();
                              Navigator.of(context).pop();
                            },
                      child: Text(
                        'Add selected item (${_selectedItems.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── canvas helpers ─────────────────────────────────────────────────────────

  void _addToCanvas(List<ClothingItem> items) {
    setState(() {
      _itemsInCanvas.addAll(items.map((item) => CanvasItem(
            item: item,
            position: Offset(
                100 + addOffsetToNewItem, 100 + addOffsetToNewItem),
          )));
    });
  }

  void _delete(CanvasItem item) {
    setState(() {
      _itemsInCanvas.remove(item);
      _selectedCanvasItem = null;
    });
  }

  void _duplicate(CanvasItem item) {
    setState(() {
      _itemsInCanvas.add(CanvasItem(
        item: item.item,
        position: item.position + const Offset(20, 20),
        scale: item.scale,
        rotation: item.rotation,
      ));
    });
  }

  void _select(CanvasItem item) {
    setState(() {
      _selectedCanvasItem = item;
      final idx = _itemsInCanvas.indexWhere((e) => e == item);
      if (idx != -1) {
        final entry = _itemsInCanvas.removeAt(idx);
        _itemsInCanvas.add(entry);
      }
    });
  }

  void _deselect() {
    setState(() => _selectedCanvasItem = null);
  }

  void _onAddClothing() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.only(
              bottom: 24.0, left: 16.0, right: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const ListTile(
                leading: Icon(Icons.camera_alt_outlined),
                title: Text('Camera'),
              ),
              const ListTile(
                leading: Icon(Icons.photo_library_outlined),
                title: Text('Photos'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Close',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _showToolBar() {
    return Positioned(
      top: 50,
      right: 16,
      width: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4)),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                IconButton(
                  onPressed: () => _delete(_selectedCanvasItem!),
                  icon: const Icon(Icons.delete),
                ),
                IconButton(
                  onPressed: () => _duplicate(_selectedCanvasItem!),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}