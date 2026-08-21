import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:virtual_wardrobe/services/tilt.dart';

/// Slides its child against device tilt, so it reads as sitting *behind* the
/// widgets that stay put.
///
/// Depth is the whole trick: give the furthest layer the largest travel and the
/// nearest one a small fraction of it, and the eye reads the gap as distance.
/// Foreground content gets no layer at all — the effect only exists because
/// something in the frame stays nailed down.
///
/// Needs a [TiltScope] above it; without one the child renders untransformed,
/// which is also the correct behaviour on a device with no accelerometer.
class ParallaxLayer extends StatelessWidget {
  const ParallaxLayer({super.key, required this.depth, required this.child});

  /// Maximum travel on each axis, in logical pixels.
  final double depth;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tilt = TiltScope.maybeOf(context);
    if (tilt == null || depth <= 0) return child;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Scale up by exactly the travel distance, so a fully deflected layer
          // still covers its box instead of dragging an empty edge into frame.
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final scale = width.isFinite && height.isFinite && width > 0 && height > 0
              ? 1 + 2 * depth / math.min(width, height)
              : 1.0;

          return ValueListenableBuilder<Offset>(
            valueListenable: tilt,
            // Built once and handed to the builder, so a frame of tilt costs
            // one Transform and not a rebuild of the layer's contents.
            child: Transform.scale(scale: scale, child: child),
            builder: (context, value, child) => Transform.translate(
              offset: Offset(value.dx * depth, value.dy * depth),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
