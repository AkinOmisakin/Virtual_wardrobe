import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A translucent panel that blurs whatever the parallax layers put behind it.
///
/// [BackdropFilter] is the expensive widget in this file — it forces a save
/// layer and re-blurs on every frame the background moves, which is every frame
/// during a tilt. One or two per screen is fine; a gridful is not, which is why
/// [GlassTile] leaves blur off by default.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 18,
    this.tint = const Color(0x2EFFFFFF),
    this.borderColor = const Color(0x40FFFFFF),
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.padding = EdgeInsets.zero,
    this.shadow = true,
  });

  final Widget child;
  final double blur;
  final Color tint;
  final Color borderColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    Widget panel = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (shadow) {
      panel = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: panel,
      );
    }

    return panel;
  }
}

/// A translucent grid cell. Holds an image, an arbitrary [child], or both — the
/// child paints over the image, which is what the label and badge slots use.
///
/// With no image the tint is the point: the parallax background drifts visibly
/// through the cell while the cell itself stays put.
class GlassTile extends StatelessWidget {
  const GlassTile({
    super.key,
    this.imageUrl,
    this.child,
    this.onTap,
    this.tint = const Color(0x24FFFFFF),
    this.borderColor = const Color(0x33FFFFFF),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.frosted = false,
    this.scrim = true,
  });

  final String? imageUrl;
  final Widget? child;
  final VoidCallback? onTap;
  final Color tint;
  final Color borderColor;
  final BorderRadius borderRadius;

  /// Blur the background behind the tile. Off by default — see the note on
  /// [GlassPanel] about what a grid of these costs.
  final bool frosted;

  /// Darken the bottom of the image so overlaid text stays readable.
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (context, url) =>
                const ColoredBox(color: Color(0x14FFFFFF)),
            errorWidget: (context, url, error) => const ColoredBox(
              color: Color(0x14FFFFFF),
              child: Icon(Icons.broken_image_outlined,
                  color: Color(0x66FFFFFF), size: 28),
            ),
          ),
        if (imageUrl != null && scrim)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x73000000)],
              ),
            ),
          ),
        if (child != null) child!,
      ],
    );

    if (frosted) {
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: content,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: content,
        ),
      ),
    );
  }
}
