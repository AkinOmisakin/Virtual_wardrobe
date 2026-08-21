import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:virtual_wardrobe/components/parallax.dart';
import 'package:virtual_wardrobe/models/profile_theme.dart';

/// Full-page background: a fixed gradient with a drifting texture layer on top.
///
/// The gradient itself never moves. Translating a smooth gradient produces no
/// visible change, so only the parts with edges — the glow blobs, or the user's
/// own image — are worth the transform.
class ThemedBackdrop extends StatelessWidget {
  const ThemedBackdrop({super.key, required this.theme});

  final ProfileTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.backdrop,
        ),
      ),
      child: ParallaxLayer(
        depth: theme.backdropDepth,
        child: theme.backdropImageUrl != null
            ? CachedNetworkImage(
                imageUrl: theme.backdropImageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => _Glows(theme: theme),
                errorWidget: (context, url, error) => _Glows(theme: theme),
              )
            : _Glows(theme: theme),
      ),
    );
  }
}

/// Soft radial blobs. Radial gradients fading to transparent give the same look
/// as a blurred circle without a save layer, which matters here because this
/// repaints on every frame of a tilt.
class _Glows extends StatelessWidget {
  const _Glows({required this.theme});

  final ProfileTheme theme;

  @override
  Widget build(BuildContext context) {
    final primary = theme.glow.first;
    final secondary = theme.glow.length > 1 ? theme.glow[1] : theme.glow.first;

    return Stack(
      children: [
        Positioned(top: -80, left: -60, child: _blob(340, primary)),
        Positioned(top: 260, right: -110, child: _blob(300, secondary)),
        Positioned(bottom: -120, left: 20, child: _blob(380, primary)),
        Positioned(bottom: 180, right: 40, child: _blob(180, secondary)),
      ],
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      );
}

/// The header banner — an X-style cover image, or the theme's gradient when the
/// user has not set one.
///
/// Fades out at the bottom so it dissolves into [ThemedBackdrop] rather than
/// ending on a hard line, which would make the two layers' different parallax
/// depths obvious as a shearing edge.
class ThemedBanner extends StatelessWidget {
  const ThemedBanner({super.key, required this.theme});

  final ProfileTheme theme;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.55, 1],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ParallaxLayer(
        depth: theme.bannerDepth,
        child: theme.bannerImageUrl != null
            ? CachedNetworkImage(
                imageUrl: theme.bannerImageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => _gradient(),
                errorWidget: (context, url, error) => _gradient(),
              )
            : _gradient(),
      ),
    );
  }

  Widget _gradient() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.banner,
          ),
        ),
      );
}
