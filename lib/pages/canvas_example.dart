import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/models/canvas_entry.dart';


class OutfitCanvasPage extends StatefulWidget {
  const OutfitCanvasPage({super.key});

  @override
  State<OutfitCanvasPage> createState() => _OutfitCanvasPageState();
}

class _OutfitCanvasPageState extends State<OutfitCanvasPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ── Firestore stream (mirrors your ItemsPage pattern) ──
  List<ClothingItem>? _inventory;
  StreamSubscription<QuerySnapshot>? _subscription;

  // ── Canvas state ──
  final List<CanvasEntry> _entries = [];
  String? _selectedUid;

  // Gesture base values (snapshotted on gesture start)
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  // Tray category filter
  ClothingType? _trayFilter;

  @override
  void initState() {
    super.initState();
    _subscribeInventory();
  }

  void _subscribeInventory() {
    _subscription = FirebaseFirestore.instance
        .collection('clothes')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _inventory = snapshot.docs
            .map((doc) => ClothingItem.fromMap(doc.data(), docId: doc.id))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ── Canvas mutations ──────────────────────────

  void _addToCanvas(ClothingItem item) {
    setState(() {
      final offset = Offset(
        100 + (_entries.length * 18).toDouble(),
        130 + (_entries.length * 18).toDouble(),
      );
      _entries.add(CanvasEntry(
        uid: '${item.id}_${DateTime.now().microsecondsSinceEpoch}',
        clothingItem: item,
        position: offset,
      ));
      
    });
  }

  void _select(String uid) {
    setState(() {
      _selectedUid = uid;
      for (final e in _entries) {
        e.isSelected = e.uid == uid;
      }
      // Bring to front by moving to end of list
      final idx = _entries.indexWhere((e) => e.uid == uid);
      if (idx != -1) {
        final entry = _entries.removeAt(idx);
        _entries.add(entry);
      }
      // Snapshot current transform as gesture base
      final selected = _entries.last;
      _baseScale = selected.scale;
      _baseRotation = selected.rotation;
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedUid = null;
      for (final e in _entries) {
        e.isSelected = false;
      }
    });
  }

  void _update(String uid, {Offset? position, double? scale, double? rotation}) {
    setState(() {
      final idx = _entries.indexWhere((e) => e.uid == uid);
      if (idx != -1) {
        _entries[idx] = _entries[idx].copyWith(
          position: position,
          scale: scale,
          rotation: rotation,
        );
      }
    });
  }

  void _deleteSelected() {
    if (_selectedUid == null) return;
    setState(() {
      _entries.removeWhere((e) => e.uid == _selectedUid);
      _selectedUid = null;
    });
  }

  void _duplicateSelected() {
    if (_selectedUid == null) return;
    final idx = _entries.indexWhere((e) => e.uid == _selectedUid);
    if (idx == -1) return;
    final orig = _entries[idx];
    setState(() {
      _entries.add(CanvasEntry(
        uid: '${orig.clothingItem.id}_${DateTime.now().microsecondsSinceEpoch}',
        clothingItem: orig.clothingItem,
        position: orig.position + const Offset(24, 24),
        scale: orig.scale,
        rotation: orig.rotation,
      ));
    });
  }

  void _clearCanvas() {
    setState(() {
      _entries.clear();
      _selectedUid = null;
    });
  }

  // ── Filtered inventory for tray ───────────────

  List<ClothingItem> get _filteredInventory {
    if (_inventory == null) return [];
    if (_trayFilter == null) return _inventory!;
    return _inventory!.where((i) => i.type == _trayFilter).toList();
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              itemCount: _entries.length,
              onClear: _entries.isEmpty ? null : _clearCanvas,
              onSave: _entries.isEmpty ? null : _handleSave,
            ),
            Expanded(
              child: Stack(
                children: [
                  _buildCanvas(),
                  if (_selectedUid != null) _buildSelectionToolbar(),
                ],
              ),
            ),
            _InventoryTray(
              inventory: _filteredInventory,
              isLoading: _inventory == null,
              activeFilter: _trayFilter,
              onFilterChanged: (type) => setState(() => _trayFilter = type),
              onItemTap: _addToCanvas,
            ),
          ],
        ),
      ),
    );
  }

  // ── Canvas ────────────────────────────────────

  Widget _buildCanvas() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _deselectAll,
      child: Stack(
        children: [
          const Positioned.fill(child: _DotGridBackground()),
          ..._entries.map((entry) => _CanvasItemWidget(
                key: ValueKey(entry.uid),
                entry: entry,
                onSelect: () => _select(entry.uid),
                onPanDelta: (delta) =>
                    _update(entry.uid, position: entry.position + delta),
                onScaleUpdate: (scale, rotation) => _update(
                  entry.uid,
                  scale: (_baseScale * scale).clamp(0.25, 4.0),
                  rotation: _baseRotation + rotation,
                ),
              )),
        ],
      ),
    );
  }

  // ── Selection toolbar ─────────────────────────

  Widget _buildSelectionToolbar() {
    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(26, 26, 26, 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icons.content_copy_rounded,
                label: 'Duplicate',
                onTap: _duplicateSelected,
              ),
              _ToolbarButton(
                icon: Icons.flip_rounded,
                label: 'Flip',
                onTap: () {}, // wire up Matrix4 scaleX(-1) if needed
              ),
              _ToolbarButton(
                icon: Icons.layers_rounded,
                label: 'To front',
                onTap: () => _select(_selectedUid!),
              ),
              Container(
                width: 1,
                height: 28,
                color: const Color(0xFFE8E5E0),
                margin: const EdgeInsets.symmetric(horizontal: 2),
              ),
              _ToolbarButton(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                onTap: _deleteSelected,
                color: const Color(0xFFD94F4F),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSave() {
    // TODO: serialize _entries and persist outfit to Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Outfit saved!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int itemCount;
  final VoidCallback? onClear;
  final VoidCallback? onSave;

  const _TopBar({
    required this.itemCount,
    required this.onClear,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF2F1EF),
        border: Border(bottom: BorderSide(color: Color(0xFFE0DDD8))),
      ),
      child: Row(
        children: [
          const Text(
            'New Outfit',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
          if (itemCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$itemCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: onSave,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: onSave != null
                    ? const Color.fromARGB(0, 7, 7, 7)
                    : const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Save outfit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CANVAS ITEM WIDGET
// ─────────────────────────────────────────────

class _CanvasItemWidget extends StatelessWidget {
  final CanvasEntry entry;
  final VoidCallback onSelect;
  final void Function(Offset delta) onPanDelta;
  final void Function(double scale, double rotation) onScaleUpdate;

  static const double _baseSize = 140.0;
  // Drag speed multiplier: >1 = faster movement, <1 = slower
  static const double _dragSpeed = 8;

  const _CanvasItemWidget({
    super.key,
    required this.entry,
    required this.onSelect,
    required this.onPanDelta,
    required this.onScaleUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final size = _baseSize * entry.scale;
    return Positioned(
      left: entry.position.dx - size / 2,
      top: entry.position.dy - size / 2,
      child: GestureDetector(
        onTap: onSelect,
        onScaleStart: (_) => onSelect(),
        onScaleUpdate: (details) {
           if (details.pointerCount == 1) {
            onSelect();
            onPanDelta(details.focalPointDelta);
          }
          // Multi-finger -> scale/rotate
          else if (details.pointerCount >= 2) {
            onScaleUpdate(details.scale, details.rotation);
          }
        },
        child: Transform.rotate(
          angle: entry.rotation,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Image
                Positioned.fill(
                  child: Image.network(
                    entry.clothingItem.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5
                              ),
                            ),
                          ),
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Color(0xFFCCCCCC), size: 28),
                    ),
                  ),
                ),
                // Selection border + shadow
                if (entry.isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF1A1A1A),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(26, 26, 26, 0),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                    ),
                  ),
                // Corner handles
                if (entry.isSelected) ...[
                  _handle(Alignment.topLeft),
                  _handle(Alignment.topRight),
                  _handle(Alignment.bottomLeft),
                  _handle(Alignment.bottomRight),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle(Alignment alignment) => Align(
        alignment: alignment,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(26, 26, 26, 1),
                blurRadius: 4,
              )
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  INVENTORY TRAY
// ─────────────────────────────────────────────

class _InventoryTray extends StatelessWidget {
  final List<ClothingItem> inventory;
  final bool isLoading;
  final ClothingType? activeFilter;
  final void Function(ClothingType?) onFilterChanged;
  final void Function(ClothingItem) onItemTap;

  static const _filterTypes = <ClothingType?>[
    null,
    ClothingType.top,
    ClothingType.trouser,
    ClothingType.shoe,
    ClothingType.outwear,
    ClothingType.dress,
    ClothingType.headwear,
    ClothingType.accessory,
  ];

  static String _label(ClothingType? type) =>
      type == null ? 'All' : type.displayName;

  const _InventoryTray({
    required this.inventory,
    required this.isLoading,
    required this.activeFilter,
    required this.onFilterChanged,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E5E0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category filter chips
          SizedBox(
            height: 40,
            // Filtered category list, EG: All, Tops, Trousers, Shoes, etc.
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              itemCount: _filterTypes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final type = _filterTypes[i];
                final active = activeFilter == type;
                return GestureDetector(
                  onTap: () => onFilterChanged(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFF2F1EF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _label(type),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white
                            : const Color(0xFF555555),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Clothing thumbnails
          SizedBox(
            height: 90,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : inventory.isEmpty
                    ? const Center(
                        child: Text(
                          'No items in this category',
                          style: TextStyle(
                              color: Color(0xFFAAAAAA), fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        itemCount: inventory.length,
                        itemBuilder: (_, i) => _TrayThumbnail(
                          item: inventory[i],
                          onTap: () => onItemTap(inventory[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TrayThumbnail extends StatefulWidget {
  final ClothingItem item;
  final VoidCallback onTap;

  const _TrayThumbnail({required this.item, required this.onTap});

  @override
  State<_TrayThumbnail> createState() => _TrayThumbnailState();
}

class _TrayThumbnailState extends State<_TrayThumbnail> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 68,
          height: 78,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6F4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8E5E0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.network(
              widget.item.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFCCCCCC),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOOLBAR BUTTON
// ─────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color.fromARGB(255, 0, 0, 0),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DOT GRID BACKGROUND
// ─────────────────────────────────────────────

class _DotGridBackground extends StatelessWidget {
  const _DotGridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGridPainter(),
      child: Container(color: const Color(0xFFF7F6F4)),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD0CDC8)
      ..strokeCap = StrokeCap.round;
    const spacing = 24.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class InlinePainter extends CustomPainter {
  const InlinePainter({
    required this.brush,
    required this.builder,
    this.isAntiAlias = true,
  });
  final Paint brush;
  final bool isAntiAlias;
  final void Function(Paint paint, Canvas canvas, Rect rect) builder;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    brush.isAntiAlias = isAntiAlias;
    canvas.save();
    builder(brush, canvas, rect);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}


class GridBackgroundBuilder extends StatelessWidget {
  const GridBackgroundBuilder({
    super.key,
    required this.cellWidth,
    required this.cellHeight,
    required this.viewport,
  });

  final double cellWidth;
  final double cellHeight;
  final Rect viewport;

  @override
  Widget build(BuildContext context) {
    final int firstRow = (viewport.top / cellHeight).floor();
    final int lastRow = (viewport.bottom / cellHeight).ceil();
    final int firstCol = (viewport.left / cellWidth).floor();
    final int lastCol = (viewport.right / cellWidth).ceil();

    final colors = Theme.of(context).primaryColor.withValues(alpha: 0.05);
    return Material(
      color: colors,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int row = firstRow; row < lastRow; row++)
            for (int col = firstCol; col < lastCol; col++)
              Positioned(
                left: col * cellWidth,
                top: row * cellHeight,
                child: Container(
                  height: cellHeight,
                  width: cellWidth,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xFFD0CDC8).withValues(alpha: 0),
                      width: 1,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EXAMPLE USAGE (with placeholder images)
// ─────────────────────────────────────────────
//
// OutfitCanvasPage(
//   inventoryItems: [
//     {'id': '1', 'image': NetworkImage('https://...')},
//     {'id': '2', 'image': AssetImage('assets/shirt.png')},
//     {'id': '3', 'image': NetworkImage('https://...')},
//   ],
// )
