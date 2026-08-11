import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:virtual_wardrobe/services/outfitprovider.dart';
import 'package:virtual_wardrobe/services/userprofileprovider.dart';
import 'package:virtual_wardrobe/services/tryon_service.dart';
import 'package:virtual_wardrobe/utils/error_messages.dart';

class TryOnPage extends StatefulWidget {
  const TryOnPage({super.key});

  @override
  State<TryOnPage> createState() => _TryOnPageState();
}

class _TryOnPageState extends State<TryOnPage> {
  // Stages: select → processing → result
  String _stage = 'select';
  String? _resultUrl;
  String? _error;

  int _step = 0;
  int _totalSteps = 1;
  String _stepLabel = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Try on'),
        centerTitle: true,
      ),
      body: switch (_stage) {
        'processing' => _ProcessingView(
            step: _step,
            total: _totalSteps,
            label: _stepLabel,
          ),
        'result' => _ResultView(
            resultUrl: _resultUrl!,
            onRetry: () => setState(() => _stage = 'select'),
          ),
        _ => _SelectView(
            error: _error,
            onTryOn: _startTryOn,
          ),
      },
    );
  }

  Future<void> _startTryOn(List<String> selectedOutfitItemIds) async {
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final outfitProvider =
        Provider.of<OutfitProvider>(context, listen: false);

    // 1. Ensure a model photo exists.
    final personUrl = await profileProvider.freshModelPhotoUrl();
    if (personUrl == null) {
      setState(() => _error =
          'Add a photo of yourself in your profile first.');
      return;
    }

    // 2. Resolve the chosen outfit's items.
    final resolved = outfitProvider.outfits
        .firstWhere((o) => o.outfit.id == selectedOutfitItemIds.first);
    final items = resolved.items;

    if (items.isEmpty) {
      setState(() => _error = 'That outfit has no items to try on.');
      return;
    }

    // 3. Run the chained try-on.
    setState(() {
      _stage = 'processing';
      _error = null;
      _step = 0;
      _totalSteps = items.length;
      _stepLabel = 'Preparing…';
    });

    try {
      final result = await TryOnService.instance.tryOnOutfit(
        personImageUrl: personUrl,
        items: items,
        onProgress: (current, total, label) {
          if (mounted) {
            setState(() {
              _step = current;
              _totalSteps = total;
              _stepLabel = label;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _resultUrl = result;
          _stage = 'result';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e,
              fallback: 'Try-on failed. Please try again.');
          _stage = 'select';
        });
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Select view — choose an outfit
// ─────────────────────────────────────────────────────────────────────────────

class _SelectView extends StatefulWidget {
  const _SelectView({required this.onTryOn, this.error});

  final void Function(List<String> outfitId) onTryOn;
  final String? error;

  @override
  State<_SelectView> createState() => _SelectViewState();
}

class _SelectViewState extends State<_SelectView> {
  String? _selectedOutfitId;

  @override
  Widget build(BuildContext context) {
    final outfitProvider = Provider.of<OutfitProvider>(context);
    final profileProvider = Provider.of<UserProfileProvider>(context);

    final hasModelPhoto = profileProvider.profile?.modelPhotoUrl != null;

    if (outfitProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // ── model photo status banner ───────────────────────────────────
        if (!hasModelPhoto)
          Container(
            width: double.infinity,
            color: Colors.amber[50],
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.amber[800]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add a photo of yourself in your profile to use try-on.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            fontStyle: FontStyle.normal,
                            color: Colors.amber[900]),
                  ),
                ),
              ],
            ),
          ),

        if (widget.error != null)
          Container(
            width: double.infinity,
            color: Colors.red[50],
            padding: const EdgeInsets.all(14),
            child: Text(
              widget.error!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                      fontStyle: FontStyle.normal, color: Colors.red[700]),
            ),
          ),

        // ── outfit list or empty prompt ──────────────────────────────────
        Expanded(
          child: outfitProvider.outfits.isEmpty
              ? _EmptyOutfitsPrompt()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: outfitProvider.outfits.length,
                  itemBuilder: (context, index) {
                    final resolved = outfitProvider.outfits[index];
                    final selected =
                        resolved.outfit.id == _selectedOutfitId;
                    return GestureDetector(
                      onTap: () => setState(
                          () => _selectedOutfitId = resolved.outfit.id),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? Colors.black
                                : Colors.grey[200]!,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12)),
                                child: Container(
                                  color: Colors.grey[50],
                                  width: double.infinity,
                                  child: _outfitThumb(resolved),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                resolved.outfit.name,
                                style: Theme.of(context).textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // ── try-on button ────────────────────────────────────────────────
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: (!hasModelPhoto || _selectedOutfitId == null)
                    ? null
                    : () => widget.onTryOn([_selectedOutfitId!]),
                child: Text(
                  'Try it on',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _outfitThumb(resolved) {
    final items = resolved.items;
    if (items.isEmpty) {
      return Icon(Icons.checkroom_outlined,
          size: 32, color: Colors.grey[300]);
    }
    return CachedNetworkImage(
      imageUrl: items.first.imageUrl,
      fit: BoxFit.contain,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
    );
  }
}

class _EmptyOutfitsPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checkroom_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No outfits yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create an outfit on the canvas first, then come back to try it on.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                      fontStyle: FontStyle.normal, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Processing view
// ─────────────────────────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({
    required this.step,
    required this.total,
    required this.label,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Colors.black),
            ),
            const SizedBox(height: 24),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (total > 1)
              Text(
                'Item $step of $total',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                        fontStyle: FontStyle.normal, color: Colors.grey[500]),
              ),
            const SizedBox(height: 4),
            Text(
              'Each layer takes around 20 seconds',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                      fontStyle: FontStyle.normal, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result view
// ─────────────────────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  const _ResultView({required this.resultUrl, required this.onRetry});

  final String resultUrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: resultUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onRetry,
                    child: const Text('Try another'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    // TODO: hook up "save as post" or "save to gallery"
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Saving coming soon')),
                      );
                    },
                    child: const Text('Save',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
