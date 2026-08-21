import 'package:flutter/material.dart';

/// Look of a profile page: the banner behind the header, the backdrop behind
/// everything else, and how the floating glass reads against both.
///
/// The colour work lives in [presets] and only the preset id plus the two image
/// URLs are serialised. That way a preset can be retuned in a later release and
/// every profile picks up the new palette, instead of everyone staying frozen
/// on whatever hex codes were current the day they chose it.
@immutable
class ProfileTheme {
  const ProfileTheme({
    required this.id,
    required this.label,
    required this.backdrop,
    required this.banner,
    this.backdropImageUrl,
    this.bannerImageUrl,
    this.glow = const [Color(0x40FFFFFF), Color(0x2EFFFFFF)],
    this.glassTint = const Color(0x2EFFFFFF),
    this.glassBorder = const Color(0x40FFFFFF),
    this.blur = 18,
    this.foreground = const Color(0xFFFFFFFF),
    this.muted = const Color(0xB3FFFFFF),
    this.brightness = Brightness.dark,
    this.backdropDepth = 34,
    this.bannerDepth = 16,
  });

  final String id;
  final String label;

  /// Backdrop gradient stops, top to bottom.
  final List<Color> backdrop;

  /// Banner gradient stops, used when [bannerImageUrl] is null.
  final List<Color> banner;

  final String? backdropImageUrl;
  final String? bannerImageUrl;

  /// Soft blobs painted over the backdrop. A flat gradient has nothing to
  /// betray movement — parallax on one is literally invisible, so the texture
  /// is load-bearing rather than decorative.
  final List<Color> glow;

  final Color glassTint;
  final Color glassBorder;
  final double blur;

  /// Text and icon colour on top of the backdrop.
  final Color foreground;
  final Color muted;

  /// Drives the status bar icons; [Brightness.dark] means a dark backdrop.
  final Brightness brightness;

  /// Travel in logical pixels at full tilt. The backdrop moves furthest, the
  /// banner sits between it and the pinned foreground.
  final double backdropDepth;
  final double bannerDepth;

  bool get isDark => brightness == Brightness.dark;

  static const presets = <ProfileTheme>[
    ProfileTheme(
      id: 'midnight',
      label: 'Midnight',
      backdrop: [Color(0xFF11131C), Color(0xFF1D2136), Color(0xFF0B0C12)],
      banner: [Color(0xFF3B3A8C), Color(0xFF7A4FA3), Color(0xFF23234A)],
      glow: [Color(0x593B6FF0), Color(0x4DAE4FE0)],
    ),
    ProfileTheme(
      id: 'ember',
      label: 'Ember',
      backdrop: [Color(0xFF1B0F0C), Color(0xFF33170F), Color(0xFF120907)],
      banner: [Color(0xFFB4441F), Color(0xFFE0803A), Color(0xFF5E2413)],
      glow: [Color(0x66E0642A), Color(0x4DF0A742)],
    ),
    ProfileTheme(
      id: 'mint',
      label: 'Mint',
      backdrop: [Color(0xFF071613), Color(0xFF0E2C26), Color(0xFF04100E)],
      banner: [Color(0xFF12806B), Color(0xFF4FC7A1), Color(0xFF0A3A31)],
      glow: [Color(0x5934D3A8), Color(0x4D2E9BD6)],
    ),
    ProfileTheme(
      id: 'paper',
      label: 'Paper',
      backdrop: [Color(0xFFF6F4EF), Color(0xFFEDE8DE), Color(0xFFF9F8F5)],
      banner: [Color(0xFFD9CFC0), Color(0xFFC2B5A3), Color(0xFFEDE8DE)],
      glow: [Color(0x40C0A98A), Color(0x33A8B7C0)],
      glassTint: Color(0x59FFFFFF),
      glassBorder: Color(0x33000000),
      foreground: Color(0xFF1A1A1A),
      muted: Color(0x991A1A1A),
      brightness: Brightness.light,
    ),
  ];

  static ProfileTheme byId(String? id) => presets.firstWhere(
        (theme) => theme.id == id,
        orElse: () => presets.first,
      );

  ProfileTheme copyWith({
    String? backdropImageUrl,
    String? bannerImageUrl,
    bool clearBackdropImage = false,
    bool clearBannerImage = false,
  }) =>
      ProfileTheme(
        id: id,
        label: label,
        backdrop: backdrop,
        banner: banner,
        backdropImageUrl:
            clearBackdropImage ? null : backdropImageUrl ?? this.backdropImageUrl,
        bannerImageUrl:
            clearBannerImage ? null : bannerImageUrl ?? this.bannerImageUrl,
        glow: glow,
        glassTint: glassTint,
        glassBorder: glassBorder,
        blur: blur,
        foreground: foreground,
        muted: muted,
        brightness: brightness,
        backdropDepth: backdropDepth,
        bannerDepth: bannerDepth,
      );

  Map<String, dynamic> toMap() => {
        'preset': id,
        'backdrop_image_url': backdropImageUrl,
        'banner_image_url': bannerImageUrl,
      };

  factory ProfileTheme.fromMap(Map<String, dynamic>? map) {
    if (map == null) return presets.first;
    return byId(map['preset'] as String?).copyWith(
      backdropImageUrl: map['backdrop_image_url'] as String?,
      bannerImageUrl: map['banner_image_url'] as String?,
    );
  }
}
