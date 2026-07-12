import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// components
import 'package:virtual_wardrobe/components/Expandable_FAB.dart';

// pages
import 'package:virtual_wardrobe/pages/fits.dart';
import 'package:virtual_wardrobe/pages/storage.dart';
import 'package:virtual_wardrobe/pages/canvas.dart';
import 'package:virtual_wardrobe/pages/tryon_page.dart';

// models
import 'package:virtual_wardrobe/models/clothing_item.dart';

// services
import 'package:virtual_wardrobe/services/ai_service.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key, required this.userId});
  final String userId;


  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      OutfitsPage(userId: widget.userId),
      ItemsPage(userId: widget.userId),
      CanvasScreen(userId: widget.userId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _pages.length,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(icon: ImageIcon(AssetImage('assets/icons/outfit.png'))),
              Tab(icon: ImageIcon(AssetImage('assets/icons/clothing_carousel.png'))),
              Tab(icon: ImageIcon(AssetImage('assets/icons/hanger_sparkle_filled.png'))),
            ],
          ),
          title: Center(
            child: Text('Wardrobe',
                style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        floatingActionButton: ExpandableFab(
          initialOpen: false,
          distance: 110,
          children: [
            ActionButton(
              onPressed: _onAddClothing,
              icon: const Icon(Icons.photo_camera_back_outlined),
            ),
            ActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const TryOnPage(),
                  ),
                );
              },
              icon: const ImageIcon(
                color: Color.fromARGB(255, 250, 167, 43),
                AssetImage('assets/icons/get-dressed.png')
              ),
            ),
            
          ],
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: _pages,
        ),
      ),
    );
  }

  // ── source picker sheet ────────────────────────────────────────────────────

  void _onAddClothing() {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1920,
                  maxHeight: 1920,
                );
                if (img != null && mounted) await _processAndShowForm(File(img.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photos'),
              onTap: () async {
                Navigator.pop(ctx);
                final imgs = await picker.pickMultiImage(
                  maxWidth: 1920,
                  maxHeight: 1920,
                );
                for (final img in imgs) {
                  if (!mounted) return;
                  await _processAndShowForm(File(img.path));
                }
              },
            ),
            InkWell(
              onTap: () => Navigator.pop(ctx),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text('Close',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI processing → form ───────────────────────────────────────────────────

  /// Shows a processing overlay, runs background removal + tagging,
  /// then opens the pre-filled clothing form.
  Future<void> _processAndShowForm(File imageFile) async {
    // Show the processing screen (not dismissible).
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProcessingDialog(),
    );

    AiImageResult result;
    try {
      result = await AiService.instance.processClothingImage(imageFile);
    } catch (e) {
      // If AI fails entirely, fall back to unprocessed image with no tags.
      result = AiImageResult(processedFile: imageFile);
    }
    
    if (!mounted) return;

    // showDialog uses rootNavigator:true by default; pop from the same root
    // navigator, not the branch navigator that StatefulShellRoute creates.
    Navigator.of(context, rootNavigator: true).pop();

    if (!mounted) return;

    // Open the pre-filled form.
    final ClothingItem? saved = await showModalBottomSheet<ClothingItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ClothingForm(aiResult: result),
    );

    if (saved != null && mounted) _saveClothingItem(saved);
  }

  Future<void> _saveClothingItem(ClothingItem item) async {
    try {
      debugPrint('[Wardrobe] Inserting into clothing_items: type=${item.type.name}, url=${item.imageUrl}');
      await Supabase.instance.client
          .from('clothing_items')
          .insert(item.toMap(widget.userId));
      debugPrint('[Wardrobe] DB insert OK');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Processing dialog — shown while AI runs
// ─────────────────────────────────────────────────────────────────────────────

class _ProcessingDialog extends StatefulWidget {
  const _ProcessingDialog();

  @override
  State<_ProcessingDialog> createState() => _ProcessingDialogState();
}

class _ProcessingDialogState extends State<_ProcessingDialog> {
  int _step = 0;

  // Cycle through status messages so the user knows what's happening.
  static const _steps = [
    'Removing background…',
    'Analysing your item…',
    'Generating tags…',
  ];

  @override
  void initState() {
    super.initState();
    _cycle();
  }

  void _cycle() async {
    for (var i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      setState(() => _step = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Colors.black),
            ),
            const SizedBox(height: 20),
            Text(
              _steps[_step.clamp(0, _steps.length - 1)],
              style: Theme.of(context).textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'This only takes a moment',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontStyle: FontStyle.normal, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Clothing form — pre-filled with AI results, fully editable
// ─────────────────────────────────────────────────────────────────────────────

class _ClothingForm extends StatefulWidget {
  const _ClothingForm({required this.aiResult});
  final AiImageResult aiResult;

  @override
  State<_ClothingForm> createState() => _ClothingFormState();
}

class _ClothingFormState extends State<_ClothingForm> {
  late ClothingType _selectedType;
  late TextEditingController _descController;
  late List<String> _tags;
  late List<String> _colours;
  late String? _style;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.aiResult;
    _selectedType = r.detectedType ?? ClothingType.top;
    _descController = TextEditingController(text: r.description ?? '');
    _tags    = List.from(r.tags);
    _colours = List.from(r.colours);
    _style   = r.style;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (_, scrollController) => Column(
        children: [
          // drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.only(
                left: 16, right: 16, bottom:
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              children: [

                // ── image preview ─────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.white,
                      child: Image.file(
                        widget.aiResult.processedFile,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // ── AI badge ──────────────────────────────────────────
                if (widget.aiResult.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '✦ AI filled',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Review and edit before saving',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                fontStyle: FontStyle.normal,
                                color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // ── category dropdown ─────────────────────────────────
                DropdownButtonFormField<ClothingType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ClothingType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t.displayName)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedType = v);
                  },
                ),

                const SizedBox(height: 12),

                // ── description ───────────────────────────────────────
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Description'),
                ),

                const SizedBox(height: 16),

                // ── colours ───────────────────────────────────────────
                if (_colours.isNotEmpty) ...[
                  Text('Colours',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  _EditableChipRow(
                    chips: _colours,
                    onChanged: (v) => setState(() => _colours = v),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── tags ──────────────────────────────────────────────
                if (_tags.isNotEmpty) ...[
                  Text('Tags',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  _EditableChipRow(
                    chips: _tags,
                    onChanged: (v) => setState(() => _tags = v),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── style ─────────────────────────────────────────────
                if (_style != null && _style!.isNotEmpty) ...[
                  Text('Style',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    children: [
                      Chip(
                        label: Text(_style!),
                        backgroundColor: Colors.grey[100],
                        side: BorderSide(color: Colors.grey[300]!),
                        onDeleted: () => setState(() => _style = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 8),

                // ── save button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save to wardrobe',
                            style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // One transparent PNG stored for both display (shown on white in UI)
      // and canvas (shown without background for natural layering).
      final imageUrl = await _uploadToSupabase(
          widget.aiResult.processedFile, _selectedType, 'item');
      final String? cutoutUrl =
          widget.aiResult.cutoutFile != null ? imageUrl : null;

      final item = ClothingItem(
        type:        _selectedType,
        imageUrl:    imageUrl,
        cutoutUrl:   cutoutUrl,
        description: _descController.text.trim(),
        tags:        _tags,
        colours:     _colours,
        style:       _style,
      );

      if (mounted) Navigator.of(context).pop(item);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _uploadToSupabase(File file, ClothingType type, String suffix) async {
    final folder   = type.name.toLowerCase();
    final fileExt  = file.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$suffix.$fileExt';
    final filePath = '$folder/$fileName';
    const bucket   = 'Clothing images';

    debugPrint('[Wardrobe] Uploading $suffix: $bucket/$filePath (${file.lengthSync()} bytes)');

    await Supabase.instance.client.storage
        .from(bucket)
        .upload(filePath, file);

    final url = Supabase.instance.client.storage
        .from(bucket)
        .getPublicUrl(filePath);

    debugPrint('[Wardrobe] Upload OK ($suffix): $url');
    return url;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editable chip row  (tap × to remove a tag)
// ─────────────────────────────────────────────────────────────────────────────

class _EditableChipRow extends StatelessWidget {
  const _EditableChipRow({
    required this.chips,
    required this.onChanged,
  });

  final List<String> chips;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips.map((chip) {
        return Chip(
          label: Text(chip,
              style: const TextStyle(fontSize: 12)),
          backgroundColor: Colors.grey[100],
          side: BorderSide(color: Colors.grey[300]!),
          deleteIcon: const Icon(Icons.close, size: 14),
          onDeleted: () {
            final updated = List<String>.from(chips)..remove(chip);
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}
