import 'package:flutter/material.dart';

/// An uncropped rect: the whole item is visible.
const Rect kNoCrop = Rect.fromLTRB(0, 0, 1, 1);

/// Clips a child down to [crop], expressed as fractions of the child's own
/// size (`Rect.fromLTRB(0, 0, 1, 1)` = no crop).
///
/// The child keeps its full size, so cropping hides pixels without moving or
/// rescaling what is left — which is what makes drag-to-crop feel stable in the
/// editor, and what lets saved-outfit previews reuse the same layout maths as
/// uncropped items.
///
/// Shared by the canvas editor and every saved-outfit preview so a cropped item
/// looks identical everywhere.
class CropClipper extends CustomClipper<Rect> {
  const CropClipper(this.crop);

  final Rect crop;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        crop.left * size.width,
        crop.top * size.height,
        crop.right * size.width,
        crop.bottom * size.height,
      );

  @override
  bool shouldReclip(CropClipper oldClipper) => oldClipper.crop != crop;
}
