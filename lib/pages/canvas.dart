import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';

//pages
import 'package:virtual_wardrobe/pages/storage.dart';

//models
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/models/clothing_categories.dart';
import 'package:virtual_wardrobe/models/canvas_item.dart';
import 'package:virtual_wardrobe/models/outfit.dart';

//components
import 'package:virtual_wardrobe/components/crop_clipper.dart';

//services
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/services/itemprovider.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';
import 'package:virtual_wardrobe/utils/error_messages.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key, required this.userId, this.editing});
  final String userId;

  /// When set, the canvas opens pre-loaded with this outfit and saving
  /// overwrites it instead of creating a new one. It also switches the screen
  /// into full-screen editor mode, where the X is the only way out.
  ///
  /// Reached through [OutfitEditPage] rather than constructed directly.
  final ResolvedOutfit? editing;

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

/// Smallest crop, as a fraction of the item box, so it can never be dragged
/// inside-out or become impossible to grab again.
const double _minCropFraction = 0.12;

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
  // for smooth scaling/rotation
  late double _initialScale;
  late double _initialRotation;
  // save state
  bool _saving = false;
  /// Whether the canvas has changed since it was opened or last saved. Only
  /// consulted in editor mode, to warn before the X throws the edits away.
  bool _dirty = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) _hydrateFrom(editing);
  }

  /// Rebuilds the canvas from a saved outfit.
  ///
  /// Items the user has since deleted from their wardrobe cannot be resolved,
  /// so they are dropped — the same thing the outfit previews do. Outfits saved
  /// before canvas state existed carry no transforms at all, so their items are
  /// cascaded like freshly added ones instead of piling up on one spot.
  void _hydrateFrom(ResolvedOutfit resolved) {
    final canvasItems = resolved.outfit.canvasItems;

    if (canvasItems == null || canvasItems.isEmpty) {
      for (final item in resolved.items) {
        _itemsInCanvas.add(CanvasItem(item: item, position: _nextDropSpot()));
      }
      return;
    }

    final itemById = {
      for (final i in resolved.items)
        if (i.id != null) i.id!: i,
    };

    for (final c in canvasItems) {
      final item = itemById[c.itemId];
      if (item == null) continue;
      _itemsInCanvas.add(CanvasItem(
        item: item,
        position: Offset(c.x, c.y),
        scale: c.scale,
        rotation: c.rotation,
        size: c.size,
        crop: c.crop,
      ));
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final provider = Provider.of<ItemProvider>(context);
    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

    final filteredItems = ClothesViewModel.categorizeItems(provider.items);
    final filterOptions = <String>['All'] +
        filteredItems.map((i) => i.title).toList();

    final scaffold = Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildCanvas(),
                if (_selectedCanvasItem != null) _showToolBar(),
                // Save button — only visible when there are items on the canvas
                if (_itemsInCanvas.isNotEmpty) _buildSaveButton(),
                _clearCanvasButton(),
                if (_isEditing) _buildCloseButton(),
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

    if (!_isEditing) return scaffold;

    // The X is the only way out, so the Android back gesture must not pop the
    // route behind our back — it is routed through the same close handler
    // instead, which is where the unsaved-changes warning lives.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: scaffold,
    );
  }

  // ── close button (editor mode only) ────────────────────────────────────────

  Widget _buildCloseButton() {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              onPressed: _close,
              icon: const Icon(Icons.close, color: Colors.black),
              tooltip: 'Close',
            ),
          ),
        ),
      ),
    );
  }

  /// Leaves the editor, checking first that nothing unsaved is being thrown
  /// away. Saving deliberately does not close the page, so this is the only
  /// exit and it is the one place that has to ask.
  Future<void> _close() async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
              "Your edits to this outfit haven't been saved yet."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ----------- clear canvas button ------------

  Widget _clearCanvasButton() {
    return Positioned(
      bottom: 15,
      left: 280,
      // right: 
      child: AnimatedOpacity(
        opacity: _itemsInCanvas.isEmpty ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            onPressed: _clearCanvas, 
            icon: const Icon(
              Icons.cleaning_services_sharp,
              color: Colors.black,
              shadows: [Shadow(color: Colors.grey, blurRadius: 45)],
              ),
            )
        )
    )
    );
    
    
  }

  // ── save button overlay ────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Positioned(
      bottom: 20,
      right: 135,
      left: 135,
      child: AnimatedOpacity(
        opacity: _itemsInCanvas.isEmpty ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : _onSaveOutfit,
            
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 209, 82, 231),
                borderRadius: BorderRadius.circular(24),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      spacing: 6.0,
                      textDirection: TextDirection.ltr,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            _isEditing
                                ? Icons.check
                                : Icons.bookmark_add_outlined,
                            color: Colors.black,
                            size: 16),
                        // const SizedBox(width: 6),
                        Text(_isEditing ? 'Save changes' : 'Save outfit',
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ),
        )
        
      ),
    );
  }


  // ── save outfit flow ───────────────────────────────────────────────────────

  /// Writes the canvas to Supabase: a new outfit, or an overwrite of the one
  /// being edited. Editing never pops the page — the X is the only exit — so a
  /// user can keep tweaking and save again.
  Future<void> _onSaveOutfit() async {
    // Guard: every canvas item must have a database id. Items added from the
    // wardrobe always have one (ItemProvider passes docId through). If somehow
    // an item slipped in without one, bail early rather than saving corrupt data.
    final missingId =
        _itemsInCanvas.any((c) => c.item.id == null || c.item.id!.isEmpty);
    if (missingId) {
      _showSnack('Some items are missing an ID — please re-add them.');
      return;
    }

    // An outfit being edited keeps its name; renaming lives on the fits list.
    // A brand new one has to be named before there is anything to write.
    final editingId = widget.editing?.outfit.id;
    final String name;
    if (editingId != null) {
      name = widget.editing!.outfit.name;
    } else {
      final entered = await _showNameDialog();
      if (entered == null) return; // user cancelled
      name = entered;
    }

    setState(() => _saving = true);
    try {
      if (editingId != null) {
        await _updateOutfit(editingId, name);
        if (mounted) {
          setState(() => _dirty = false);
          _showSnack('Outfit "$name" updated!');
        }
      } else {
        await _saveOutfit(name);
        if (mounted) {
          setState(() => _dirty = false);
          _showSnack('Outfit "$name" saved!');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack(friendlyError(e,
            fallback: "Couldn't save your outfit. Please try again."));
      }
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

  /// Saves the canvas state as a new outfit: inserts the outfit row then all
  /// outfit_items rows in a single batch.
  Future<void> _saveOutfit(String name) async {
    final db = Supabase.instance.client;

    // 1. Insert outfit row and retrieve generated ID.
    final outfitRow = await db
        .from('outfits')
        .insert({'user_id': widget.userId, 'name': name})
        .select('id')
        .single();
    final outfitId = outfitRow['id'] as String;

    // 2. Insert one outfit_items row per canvas item.
    await db.from('outfit_items').insert(_itemRowsFor(outfitId));
  }

  /// Overwrites an existing outfit with the current canvas.
  ///
  /// The item rows are replaced wholesale rather than diffed: `position` is the
  /// z-order, so nearly any edit renumbers the whole set anyway. The delete and
  /// the insert are two statements, so a failure between them would leave the
  /// outfit empty — recoverable by saving again, since the canvas still holds
  /// the state.
  Future<void> _updateOutfit(String outfitId, String name) async {
    final db = Supabase.instance.client;

    await db.from('outfits').update({
      'name': name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', outfitId);

    await db.from('outfit_items').delete().eq('outfit_id', outfitId);
    await db.from('outfit_items').insert(_itemRowsFor(outfitId));
  }

  /// One `outfit_items` row per canvas item, `position` carrying the z-order.
  /// The canvas columns come from OutfitCanvasItem so the write side and the
  /// read side of the row can't drift apart.
  List<Map<String, dynamic>> _itemRowsFor(String outfitId) {
    return _itemsInCanvas.asMap().entries.map((e) {
      final i = e.key;
      final c = e.value;
      return {
        'outfit_id': outfitId,
        'position':  i,
        ...OutfitCanvasItem.fromValues(
          itemId:   c.item.id!,
          position: c.position,
          scale:    c.scale,
          rotation: c.rotation,
          size:     c.size,
          crop:     c.crop,
        ).toMap(),
      };
    }).toList();
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
    // Crop rect in the item's own pixels. The layout box always stays
    // `size × size` so cropping never shifts the item — only the visible
    // pixels (and the handles) move.
    final cropPx = _cropToPixels(canvasItem);

    return Positioned(
      left: canvasItem.position.dx,
      top: canvasItem.position.dy,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..multiply(
              Matrix4.diagonal3Values(canvasItem.scale, canvasItem.scale, 1.0))
          ..rotateZ(canvasItem.rotation),
        child: SizedBox(
          width: canvasItem.size,
          height: canvasItem.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The image itself. ClipRect also clips hit-testing, so the
              // cropped-away area no longer reacts to taps or drags.
              Positioned.fill(
                child: GestureDetector(
                  onTap: itemSelected ? _deselect : () => _select(canvasItem),
                  onScaleStart: (details) {
                    _select(canvasItem);
                    _initialScale = canvasItem.scale;
                    _initialRotation = canvasItem.rotation;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      final selected = _selectedCanvasItem!;
                      if (details.pointerCount == 1) {
                        // focalPointDelta arrives in the item's local space
                        // (this detector sits *inside* the Transform), so map
                        // it back through the rotation and scale.
                        selected.position += _rotate(
                                details.focalPointDelta, selected.rotation) *
                            selected.scale;
                      }
                      if (details.pointerCount >= 2) {
                        selected.scale = _initialScale * details.scale;
                        selected.rotation =
                            _initialRotation + details.rotation;
                      }
                      _dirty = true;
                    });
                  },
                  child: ClipRect(
                    clipper: CropClipper(canvasItem.crop),
                    child: CachedNetworkImage(
                      imageUrl:
                          canvasItem.item.cutoutUrl ?? canvasItem.item.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (c, u) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (c, u, e) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ),
              // Selection outline, drawn on the crop rect.
              if (itemSelected)
                Positioned.fromRect(
                  rect: cropPx,
                  child: IgnorePointer(
                    child: DottedBorder(
                      options: RectDottedBorderOptions(
                        color: const Color.fromARGB(255, 183, 0, 255),
                        dashPattern: const [10, 5],
                        strokeWidth: 2,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              // Crop handles sit above the image detector in the Stack, so a
              // pointer that lands on one never reaches the move/pinch gesture.
              if (itemSelected)
                for (final handle in _CropHandle.values)
                  _buildCropHandle(canvasItem, handle, cropPx),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropHandle(
      CanvasItem canvasItem, _CropHandle handle, Rect cropPx) {
    final centre = handle.centreOf(cropPx);
    // Handles are drawn in item space, so they shrink/grow with the item.
    // Divide by the scale to keep them a constant size on screen instead.
    const hitSize = 34.0;
    const dotSize = 12.0;

    return Positioned(
      left: centre.dx - hitSize / 2,
      top: centre.dy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => _resizeCrop(canvasItem, handle, details.delta),
        child: Center(
          child: Container(
            width: handle.isCorner ? dotSize : dotSize * 0.8,
            height: handle.isCorner ? dotSize : dotSize * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: handle.isCorner ? BoxShape.rectangle : BoxShape.circle,
              border: Border.all(
                  color: const Color.fromARGB(255, 183, 0, 255), width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Rect _cropToPixels(CanvasItem canvasItem) => Rect.fromLTRB(
        canvasItem.crop.left * canvasItem.size,
        canvasItem.crop.top * canvasItem.size,
        canvasItem.crop.right * canvasItem.size,
        canvasItem.crop.bottom * canvasItem.size,
      );

  /// Moves the edges owned by [handle] by [delta].
  ///
  /// [delta] comes from a gesture *inside* the item's Transform, so it is
  /// already expressed in un-rotated, un-scaled item pixels — no correction
  /// needed. Dragging inwards shrinks the crop, dragging back outwards grows
  /// it again until it is clamped at the original bounds.
  void _resizeCrop(CanvasItem canvasItem, _CropHandle handle, Offset delta) {
    final dx = delta.dx / canvasItem.size;
    final dy = delta.dy / canvasItem.size;

    var left = canvasItem.crop.left;
    var top = canvasItem.crop.top;
    var right = canvasItem.crop.right;
    var bottom = canvasItem.crop.bottom;

    if (handle.movesLeft) left = (left + dx).clamp(0.0, right - _minCropFraction);
    if (handle.movesRight) {
      right = (right + dx).clamp(left + _minCropFraction, 1.0);
    }
    if (handle.movesTop) top = (top + dy).clamp(0.0, bottom - _minCropFraction);
    if (handle.movesBottom) {
      bottom = (bottom + dy).clamp(top + _minCropFraction, 1.0);
    }

    setState(() {
      canvasItem.crop = Rect.fromLTRB(left, top, right, bottom);
      _dirty = true;
    });
  }

  void _resetCrop(CanvasItem canvasItem) {
    setState(() {
      canvasItem.crop = kNoCrop;
      _dirty = true;
    });
  }

  /// Rotates [v] by [radians] (item space → canvas space).
  Offset _rotate(Offset v, double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Offset(v.dx * cos - v.dy * sin, v.dx * sin + v.dy * cos);
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
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
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

  /// Where the next item should land. Each one is stepped 20px down-right of
  /// the last so a multi-item add doesn't bury everything under one image, and
  /// the cascade wraps before it can walk off the canvas.
  Offset _nextDropSpot() {
    final step = (_itemsInCanvas.length * 20.0) % 120;
    return Offset(100 + step, 100 + step);
  }

  void _addToCanvas(List<ClothingItem> items) {
    setState(() {
      for (final item in items) {
        _itemsInCanvas.add(CanvasItem(item: item, position: _nextDropSpot()));
      }
      _dirty = true;
    });
  }

  void _delete(CanvasItem item) {
    setState(() {
      _itemsInCanvas.remove(item);
      _selectedCanvasItem = null;
      _dirty = true;
    });
  }

  void _clearCanvas() {
    setState(() {
      _itemsInCanvas.clear();
      _dirty = true;
    });
  }

  void _duplicate(CanvasItem item) {
    setState(() {
      _itemsInCanvas.add(CanvasItem(
        item: item.item,
        position: item.position + const Offset(20, 20),
        scale: item.scale,
        rotation: item.rotation,
        crop: item.crop,
      ));
      _dirty = true;
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
      // Editor mode puts the X in this corner, so the toolbar starts below it.
      top: _isEditing ? 110 : 50,
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
                IconButton(
                  onPressed: _selectedCanvasItem!.isCropped
                      ? () => _resetCrop(_selectedCanvasItem!)
                      : null,
                  icon: const Icon(Icons.crop_free),
                  tooltip: 'Reset crop',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── crop plumbing ────────────────────────────────────────────────────────────

/// Which edges of the crop rect a handle drags.
enum _CropHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left;

  bool get movesLeft =>
      this == topLeft || this == left || this == bottomLeft;
  bool get movesRight =>
      this == topRight || this == right || this == bottomRight;
  bool get movesTop => this == topLeft || this == top || this == topRight;
  bool get movesBottom =>
      this == bottomLeft || this == bottom || this == bottomRight;

  bool get isCorner =>
      (movesLeft || movesRight) && (movesTop || movesBottom);

  Offset centreOf(Rect r) => switch (this) {
        _CropHandle.topLeft => r.topLeft,
        _CropHandle.top => r.topCenter,
        _CropHandle.topRight => r.topRight,
        _CropHandle.right => r.centerRight,
        _CropHandle.bottomRight => r.bottomRight,
        _CropHandle.bottom => r.bottomCenter,
        _CropHandle.bottomLeft => r.bottomLeft,
        _CropHandle.left => r.centerLeft,
      };
}
