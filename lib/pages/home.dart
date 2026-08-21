import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/components/crop_clipper.dart';
import 'package:virtual_wardrobe/models/clothing_item.dart';
import 'package:virtual_wardrobe/pages/canvas.dart';
import 'package:virtual_wardrobe/pages/item.dart';
import 'package:virtual_wardrobe/pages/outfits_details_page.dart';
import 'package:virtual_wardrobe/pages/tryon_page.dart';
import 'package:virtual_wardrobe/services/itemprovider.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';
import 'package:virtual_wardrobe/services/userprofileprovider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home palette / type — local tokens so the page reads as one system without
// changing the global theme (which every other page depends on).
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _P {
  static const ink      = Color(0xFF111111);
  static const inkMuted = Color(0xFF6B6B6B);
  static const inkFaint = Color(0xFFA8A8A8);
  static const line     = Color(0xFFEBEBEB);
  static const surface  = Color(0xFFF7F7F7);
  static const canvas   = Color(0xFFFCFCFC);

  // Accents echo the bottom navigation bar so the app feels of a piece.
  static const mint  = Color(0xFF6FD8AE); // build / canvas
  static const lilac = Color(0xFFB9A0FF); // wardrobe
  static const amber = Color(0xFFFFB259); // try-on
}

abstract final class _Type {
  /// Small letter-spaced caps used above every section.
  static TextStyle eyebrow([Color color = _P.inkFaint]) => GoogleFonts.robotoMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: color,
      );

  static TextStyle wordmark() => GoogleFonts.robotoMono(
        fontSize: 20,
        fontWeight: FontWeight.w300,
        letterSpacing: 6,
        color: _P.ink,
      );

  static TextStyle display({FontWeight weight = FontWeight.w300}) =>
      GoogleFonts.robotoMono(
        fontSize: 26,
        height: 1.25,
        fontWeight: weight,
        color: _P.ink,
      );

  static TextStyle cardTitle() => GoogleFonts.robotoMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _P.ink,
      );

  static TextStyle meta([Color color = _P.inkFaint]) => GoogleFonts.robotoMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle stat() => GoogleFonts.robotoMono(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: _P.ink,
      );
}

const double _gutter = 20;
const double _sectionGap = 30;

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Fetched once per page mount: the greeting name and avatar. Kept out of
  /// [UserProfileProvider] (which only lives under the profile tab) so home
  /// stays cheap — a single row, and the page degrades gracefully without it.
  late final Future<_Greeter> _greeter = _loadGreeter();

  Future<_Greeter> _loadGreeter() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const _Greeter();
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      return _Greeter(
        name: row?['name'] as String?,
        avatarUrl: row?['avatar_url'] as String?,
      );
    } catch (_) {
      return _Greeter(name: user.userMetadata?['name'] as String?);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<_Greeter>(
        future: _greeter,
        builder: (context, snapshot) {
          final greeter = snapshot.data ?? const _Greeter();
          return CustomScrollView(
            slivers: [
              _TopBar(greeter: greeter),
              SliverToBoxAdapter(child: _Greeting(greeter: greeter)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _LatestFit(userId: userId)),
              const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
              SliverToBoxAdapter(child: _QuickActions(userId: userId)),
              const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
              const SliverToBoxAdapter(child: _RecentOutfitsSection()),
              SliverToBoxAdapter(child: _NewInWardrobeSection(userId: userId)),
              const SliverToBoxAdapter(child: _WardrobeStats()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

/// The bits of the profile the home page needs.
class _Greeter {
  const _Greeter({this.name, this.avatarUrl});
  final String? name;
  final String? avatarUrl;

  /// First name only — "Good evening, Akin" reads better than the full name.
  String? get firstName {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initial {
    final f = firstName;
    return (f == null || f.isEmpty) ? '·' : f[0].toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar — wordmark + avatar shortcut to the profile tab
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.greeter});
  final _Greeter greeter;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: _gutter,
      title: Text('CHER', style: _Type.wordmark()),
      actions: [
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _P.surface,
              border: Border.all(color: _P.line),
              image: greeter.avatarUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(greeter.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: greeter.avatarUrl != null
                ? null
                : Text(greeter.initial, style: _Type.cardTitle()),
          ),
        ),
        const SizedBox(width: _gutter),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _P.line),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Greeting — date line + time-aware salutation
// ─────────────────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.greeter});
  final _Greeter greeter;

  static const _weekdays = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY',
    'FRIDAY', 'SATURDAY', 'SUNDAY',
  ];
  static const _months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final salutation = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final name = greeter.firstName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
            style: _Type.eyebrow(),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: _Type.display(),
              children: [
                TextSpan(text: name == null ? '$salutation.' : '$salutation,\n'),
                if (name != null)
                  TextSpan(
                    text: '$name.',
                    style: _Type.display(weight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Latest fit — the hero card
// ─────────────────────────────────────────────────────────────────────────────

class _LatestFit extends StatelessWidget {
  const _LatestFit({required this.userId});
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OutfitProvider>(context);

    if (provider.isLoading) return const _HeroSkeleton();
    if (provider.error != null) return _ErrorNote(message: provider.error!);
    if (provider.outfits.isEmpty) return _StartFirstFitCard(userId: userId);

    final latest = provider.outfits.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OutfitDetailsPage(resolved: latest),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _P.line),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Row(
                  children: [
                    Text('LATEST FIT', style: _Type.eyebrow(_P.ink)),
                    const Spacer(),
                    Text(_timeAgo(latest.outfit.createdAt), style: _Type.meta()),
                  ],
                ),
              ),
              SizedBox(
                height: 260,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: _OutfitPreview(resolved: latest),
                ),
              ),
              Container(height: 1, color: _P.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            latest.outfit.name,
                            style: _Type.cardTitle(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(_itemCount(latest.items.length),
                              style: _Type.meta(_P.inkMuted)),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _P.ink,
                      ),
                      child: const Icon(Icons.arrow_forward,
                          size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state hero: nothing to show yet, so sell the next action.
class _StartFirstFitCard extends StatelessWidget {
  const _StartFirstFitCard({required this.userId});
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
        decoration: BoxDecoration(
          color: _P.canvas,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _P.line),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _P.mint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.auto_awesome_outlined,
                  size: 22, color: _P.ink),
            ),
            const SizedBox(height: 18),
            Text('No fits yet', style: _Type.display().copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Lay your pieces out on the canvas and\nsave your first outfit.',
              textAlign: TextAlign.center,
              style: _Type.meta(_P.inkMuted).copyWith(height: 1.6, fontSize: 11),
            ),
            const SizedBox(height: 22),
            if (userId != null)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CanvasScreen(userId: userId!),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 13),
                  decoration: BoxDecoration(
                    color: _P.ink,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'Build a fit',
                    style: _Type.cardTitle().copyWith(color: Colors.white),
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
// Quick actions
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.userId});
  final String? userId;

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              icon: Icons.add_a_photo_outlined,
              label: 'Add item',
              tint: _P.lilac,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ItemPage(userId: userId!)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.dashboard_customize_outlined,
              label: 'Build a fit',
              tint: _P.mint,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CanvasScreen(userId: userId!)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.checkroom_outlined,
              label: 'Try on',
              tint: _P.amber,
              // TryOnPage reads UserProfileProvider, which only exists under the
              // profile tab — so supply one scoped to this route.
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => UserProfileProvider(userId: userId!),
                    child: const TryOnPage(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.line),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 18, color: _P.ink),
            ),
            const SizedBox(height: 10),
            Text(label, style: _Type.meta(_P.ink), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing, this.onTrailingTap});

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: _Type.eyebrow(_P.ink)),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(trailing!, style: _Type.meta(_P.inkMuted)),
                  const SizedBox(width: 3),
                  const Icon(Icons.chevron_right, size: 14, color: _P.inkMuted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent outfits — everything except the hero
// ─────────────────────────────────────────────────────────────────────────────

class _RecentOutfitsSection extends StatelessWidget {
  const _RecentOutfitsSection();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OutfitProvider>(context);

    // The hero already shows the newest fit; this row picks up from the second.
    final rest = provider.outfits.skip(1).take(8).toList();
    if (provider.isLoading || provider.error != null || rest.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'More fits',
          trailing: 'All ${provider.outfits.length}',
          onTrailingTap: () => context.go('/wardrobe'),
        ),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            itemCount: rest.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _OutfitCard(resolved: rest[index]),
          ),
        ),
        const SizedBox(height: _sectionGap),
      ],
    );
  }
}

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
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _P.canvas,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _P.line),
                ),
                child: _OutfitPreview(resolved: resolved),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              resolved.outfit.name,
              style: _Type.cardTitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              '${_itemCount(resolved.items.length)} · ${_timeAgo(resolved.outfit.createdAt)}',
              style: _Type.meta(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New in wardrobe — most recently added pieces
// ─────────────────────────────────────────────────────────────────────────────

class _NewInWardrobeSection extends StatelessWidget {
  const _NewInWardrobeSection({required this.userId});
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ItemProvider>(context);
    final items = provider.items.take(12).toList();

    if (provider.isLoading || provider.error != null || items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'New in your wardrobe',
          trailing: 'All ${provider.items.length}',
          onTrailingTap: () => context.go('/wardrobe'),
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _ItemTile(
              item: items[index],
              userId: userId,
            ),
          ),
        ),
        const SizedBox(height: _sectionGap),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.userId});
  final ClothingItem item;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: userId == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ItemPage(
                    item: item,
                    userId: userId!,
                    isEditing: true,
                  ),
                ),
              ),
      child: Container(
        width: 84,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _P.canvas,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.line),
        ),
        child: CachedNetworkImage(
          imageUrl: item.imageUrl,
          fit: BoxFit.contain,
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, _) =>
              const Icon(Icons.broken_image_outlined, size: 16, color: _P.inkFaint),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wardrobe stats strip
// ─────────────────────────────────────────────────────────────────────────────

class _WardrobeStats extends StatelessWidget {
  const _WardrobeStats();

  @override
  Widget build(BuildContext context) {
    final items = Provider.of<ItemProvider>(context);
    final outfits = Provider.of<OutfitProvider>(context);

    if (items.isLoading || outfits.isLoading) return const SizedBox.shrink();
    if (items.items.isEmpty && outfits.outfits.isEmpty) {
      return const SizedBox.shrink();
    }

    final categories = items.items.map((i) => i.type).toSet().length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _Stat(value: items.items.length, label: 'PIECES'),
            const _StatDivider(),
            _Stat(value: outfits.outfits.length, label: 'FITS'),
            const _StatDivider(),
            _Stat(value: categories, label: 'CATEGORIES'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: _Type.stat()),
          const SizedBox(height: 5),
          Text(label, style: _Type.eyebrow(_P.inkMuted)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: _P.line);
}

// ─────────────────────────────────────────────────────────────────────────────
// Outfit preview — canvas-accurate layout, falling back to an image grid
// ─────────────────────────────────────────────────────────────────────────────

class _OutfitPreview extends StatelessWidget {
  const _OutfitPreview({required this.resolved});
  final ResolvedOutfit resolved;

  @override
  Widget build(BuildContext context) {
    return resolved.outfit.canvasItems?.isNotEmpty == true
        ? _CanvasPreview(resolved: resolved)
        : _ImageGrid(items: resolved.items);
  }
}

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
      // Accounts for scale and crop, so cropped items don't leave dead space.
      final bounds = c.visualBounds;
      minX = [minX, bounds.left  ].reduce((a, b) => a < b ? a : b);
      minY = [minY, bounds.top   ].reduce((a, b) => a < b ? a : b);
      maxX = [maxX, bounds.right ].reduce((a, b) => a > b ? a : b);
      maxY = [maxY, bounds.bottom].reduce((a, b) => a > b ? a : b);
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
                      ..scaleByDouble(c.scale, c.scale, c.scale, 1)
                      ..rotateZ(c.rotation),
                    child: ClipRect(
                      clipper: CropClipper(c.crop),
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
                ),
          ],
        ),
      ),
    );
  }
}

/// Fallback: tiled images when an outfit has no saved canvas state.
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.items});

  final List<ClothingItem> items;

  @override
  Widget build(BuildContext context) {
    final preview = items.take(4).toList();
    if (preview.isEmpty) {
      return const Center(
        child: Icon(Icons.checkroom_outlined, size: 32, color: _P.line),
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
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      physics: const NeverScrollableScrollPhysics(),
      children: preview.map((item) {
        return CachedNetworkImage(
          imageUrl: item.imageUrl,
          fit: BoxFit.contain,
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, _) =>
              const Icon(Icons.broken_image, size: 16),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / error states
// ─────────────────────────────────────────────────────────────────────────────

/// Breathing placeholder for the hero card while outfits load.
class _HeroSkeleton extends StatefulWidget {
  const _HeroSkeleton();

  @override
  State<_HeroSkeleton> createState() => _HeroSkeletonState();
}

class _HeroSkeletonState extends State<_HeroSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Container(
          height: 372,
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _P.line),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFDBD6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 16, color: Colors.red[400]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: _Type.meta(_P.inkMuted).copyWith(height: 1.5, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────────────────────

String _itemCount(int n) => '$n item${n == 1 ? '' : 's'}';

String _timeAgo(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
