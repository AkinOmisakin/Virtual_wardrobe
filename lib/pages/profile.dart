import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:virtual_wardrobe/components/glass.dart';
import 'package:virtual_wardrobe/components/themed_backdrop.dart';
import 'package:virtual_wardrobe/models/profile_theme.dart';
import 'package:virtual_wardrobe/models/user_post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/pages/delete_account_dialog.dart';
import 'package:virtual_wardrobe/pages/report_dialog.dart';
import 'package:virtual_wardrobe/services/report_service.dart';
import 'package:virtual_wardrobe/services/tilt.dart';
import 'package:virtual_wardrobe/services/userprofileprovider.dart';
import 'package:virtual_wardrobe/utils/error_messages.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile page
// ─────────────────────────────────────────────────────────────────────────────

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.userId});
  final String userId;
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserProfileProvider(userId: userId),
      child: const _ProfileBody(),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody();

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  /// Height of the cover layer. Taller than the gap above the card so the
  /// banner's fade-out lands behind the glass rather than above it.
  static const _bannerHeight = 300.0;

  /// Where the floating card starts, measured from the top of the page.
  static const _cardTop = 186.0;

  ProfileTheme _theme = ProfileTheme.presets.first;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProfileProvider>(context);

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: _theme.backdrop.last,
        body: Center(
          child: CircularProgressIndicator(color: _theme.foreground),
        ),
      );
    }

    final profile = provider.profile;

    // Everything that drifts lives under this scope; everything pinned is just
    // an ordinary widget painted on top of it.
    return TiltScope(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _theme.backdrop.last,
        extendBodyBehindAppBar: true,

        // ── app bar ─────────────────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: _theme.foreground,
          systemOverlayStyle: _theme.isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          title: Text(
            profile?.username ?? 'profile',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: _theme.foreground),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu, size: 22),
              tooltip: 'Options',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
        ),

        // ── options drawer ──────────────────────────────────────────────────
        endDrawer: _OptionsDrawer(
          profile: profile,
          theme: _theme,
          onThemeChanged: (theme) => setState(() => _theme = theme),
        ),

        // ── body ────────────────────────────────────────────────────────────
        body: Stack(
          children: [
            // Layer 1 — the deepest, and the only one that fills the page.
            Positioned.fill(child: ThemedBackdrop(theme: _theme)),

            // Layer 2 — the cover, drifting less than the backdrop behind it.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _bannerHeight,
              child: ThemedBanner(theme: _theme),
            ),

            // Layer 3 — pinned. No parallax anywhere below this line: the
            // effect reads as depth precisely because this half holds still.
            CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: _cardTop)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _FloatingProfileCard(
                      profile: profile,
                      theme: _theme,
                      onSettings: () =>
                          _scaffoldKey.currentState?.openEndDrawer(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: _PostsGrid(posts: provider.posts, theme: _theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating profile card  (avatar · name · username · bio · stats · settings)
// ─────────────────────────────────────────────────────────────────────────────

/// The pinned half of the effect. Nothing in here is wrapped in a
/// [ParallaxLayer] — it holds still while the cover and backdrop slide under
/// it, which is the entire illusion.
class _FloatingProfileCard extends StatefulWidget {
  const _FloatingProfileCard({
    required this.profile,
    required this.theme,
    required this.onSettings,
  });

  final UserProfile? profile;
  final ProfileTheme theme;
  final VoidCallback onSettings;

  @override
  State<_FloatingProfileCard> createState() => _FloatingProfileCardState();
}

class _FloatingProfileCardState extends State<_FloatingProfileCard> {
  static const _avatarRadius = 42.0;

  bool _uploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    final postCount = provider.posts.length;
    final profile = widget.profile;
    final theme = widget.theme;
    final bio = profile?.bio;

    return Padding(
      // Reserves the space the avatar overhangs into, so the card's own box
      // still describes how much room the sliver needs.
      padding: const EdgeInsets.only(top: _avatarRadius),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          GlassPanel(
            blur: theme.blur,
            tint: theme.glassTint,
            borderColor: theme.glassBorder,
            padding: EdgeInsets.fromLTRB(20, _avatarRadius + 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── name ───────────────────────────────────────────────
                Text(
                  profile?.name ?? 'Your Name',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 17,
                        color: theme.foreground,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${profile?.username ?? 'username'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        fontStyle: FontStyle.normal,
                        color: theme.muted,
                      ),
                ),

                // ── bio ────────────────────────────────────────────────
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          fontStyle: FontStyle.normal,
                          color: theme.muted,
                        ),
                  ),
                ],

                const SizedBox(height: 18),

                // ── stats ──────────────────────────────────────────────
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                //   children: [
                //     _StatColumn(
                //         value: postCount.toString(),
                //         label: 'posts',
                //         theme: theme),
                //     _StatDivider(theme: theme),
                //     _StatColumn(
                //         value: '—', label: 'followers', theme: theme),
                //     _StatDivider(theme: theme),
                //     _StatColumn(
                //         value: '—', label: 'following', theme: theme),
                //   ],
                // ),

                const SizedBox(height: 18),

                // ── actions ────────────────────────────────────────────
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: _OutlineButton(
                        label: 'Edit profile',
                        theme: theme,
                        onTap: () => _showEditProfile(context, profile),
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // Expanded(
                    //   child: _OutlineButton(
                    //     label: 'Share',
                    //     theme: theme,
                    //     onTap: () => _shareProfile(context, profile),
                    //   ),
                    // ),
                    // const SizedBox(width: 8),
                    // _OutlineButton(
                    //   icon: Icons.settings_outlined,
                    //   theme: theme,
                    //   onTap: widget.onSettings,
                    // ),
                  ],
                ),
              ],
            ),
          ),

          // ── avatar, overhanging the top edge ─────────────────────────
          Positioned(
            top: -_avatarRadius,
            child: GestureDetector(
              onTap: _uploadingAvatar ? null : _showAvatarSheet,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.glassBorder, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: _avatarRadius,
                      backgroundColor: theme.isDark
                          ? const Color(0xFF2A2E3D)
                          : Colors.grey[200],
                      backgroundImage: profile?.avatarUrl != null
                          ? CachedNetworkImageProvider(profile!.avatarUrl!)
                          : null,
                      child: profile?.avatarUrl == null
                          ? Icon(Icons.person,
                              size: 42, color: theme.muted)
                          : null,
                    ),

                    // Upload progress, over whatever the avatar currently is.
                    if (_uploadingAvatar)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x99000000),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Camera badge — says "this opens a photo picker" rather
                    // than the generic "+" it used to show.
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: theme.isDark ? Colors.white : Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.isDark ? Colors.black26 : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.photo_camera_outlined,
                          color: theme.isDark ? Colors.black : Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── avatar upload ─────────────────────────────────────────────────────────

  /// Source picker for the profile photo, shaped like the add-clothing sheet in
  /// [WardrobePage] so the two upload flows feel like the same app.
  void _showAvatarSheet() {
    final hasAvatar = widget.profile?.avatarUrl != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Profile photo',
                  style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photos'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              if (hasAvatar)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red[400]),
                  title: Text('Remove current photo',
                      style: TextStyle(color: Colors.red[400])),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeAvatar();
                  },
                ),
              InkWell(
                onTap: () => Navigator.pop(ctx),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    // Square crop up front: the picker's own cropper is the only one the user
    // gets, and every place this image appears is a circle.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;

    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    setState(() => _uploadingAvatar = true);
    try {
      await provider.uploadAvatar(File(picked.path));
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e,
            fallback: "Couldn't update your photo. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    setState(() => _uploadingAvatar = true);
    try {
      await provider.removeAvatar();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e,
            fallback: "Couldn't remove your photo. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showEditProfile(BuildContext context, UserProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditProfileSheet(profile: profile),
    );
  }

  void _shareProfile(BuildContext context, UserProfile? profile) {
    final handle = '@${profile?.username ?? 'username'}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share profile',
                style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 24),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(handle,
                        style: Theme.of(ctx).textTheme.labelMedium),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: handle));
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    child: const Icon(Icons.copy_outlined, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Posts grid
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a sliver, not a box — it lives directly in the page's
/// [CustomScrollView] so the whole foreground scrolls as one surface over the
/// fixed background.
class _PostsGrid extends StatelessWidget {
  const _PostsGrid({required this.posts, required this.theme});

  final List<UserPost> posts;
  final ProfileTheme theme;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: GlassPanel(
          blur: theme.blur,
          tint: theme.glassTint,
          borderColor: theme.glassBorder,
          shadow: false,
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, size: 44, color: theme.muted),
              const SizedBox(height: 12),
              Text(
                'No posts yet',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: theme.muted),
              ),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = posts[index];
          return GlassTile(
            imageUrl: post.imageUrl,
            tint: theme.glassTint,
            borderColor: theme.glassBorder,
            onTap: () => _showPostDetail(context, post),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _PostTypeBadge(type: post.type),
              ),
            ),
          );
        },
        childCount: posts.length,
      ),
    );
  }

  void _showPostDetail(BuildContext context, UserPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PostDetailSheet(post: post),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post detail sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PostDetailSheet extends StatelessWidget {
  const _PostDetailSheet({required this.post});

  final UserPost post;

  @override
  Widget build(BuildContext context) {
    final provider =
        Provider.of<UserProfileProvider>(context, listen: false);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                // image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: Colors.grey[100]),
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // type label + likes
                Row(
                  children: [
                    _PostTypeBadge(type: post.type),
                    const Spacer(),
                    // Saved try-on images are AI output, so they need the same
                    // disclosure and flagging route as the live result screen.
                    if (post.type == PostType.aiTryOn) ...[
                      Icon(Icons.auto_awesome,
                          size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('AI',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: Colors.grey[600])),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.favorite_border,
                        size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${post.likes}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    IconButton(
                      icon: Icon(Icons.flag_outlined,
                          size: 16, color: Colors.grey[500]),
                      tooltip: 'Report',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => showReportSheet(
                        context,
                        type: ReportedContentType.post,
                        contentRef: post.id,
                        contentUrl: post.imageUrl,
                      ),
                    ),
                  ],
                ),

                if (post.caption != null && post.caption!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(post.caption!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontStyle: FontStyle.normal)),
                ],

                const SizedBox(height: 24),

                // delete button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete post'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await provider.deletePost(post.id);
                  },
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
// Options end drawer  (settings · edit profile · share)
// ─────────────────────────────────────────────────────────────────────────────

class _OptionsDrawer extends StatelessWidget {
  const _OptionsDrawer({
    required this.profile,
    required this.theme,
    required this.onThemeChanged,
  });

  final UserProfile? profile;
  final ProfileTheme theme;
  final ValueChanged<ProfileTheme> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 260,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                profile?.username ?? 'menu',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.edit_outlined,
              label: 'Edit profile',
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _EditProfileSheet(profile: profile),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.share_outlined,
              label: 'Share profile',
              onTap: () {
                final handle = '@${profile?.username ?? 'username'}';
                Navigator.of(context).pop();
                Clipboard.setData(ClipboardData(text: handle));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile link copied')),
                );
              },
            ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.palette_outlined,
              label: 'Appearance',
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _AppearanceSheet(
                    selected: theme,
                    onSelected: onThemeChanged,
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: push SettingsPage
              },
            ),
            // Hidden until PRIVACY_POLICY_URL is set, so the menu never offers
            // a link that goes nowhere.
            if ((dotenv.env['PRIVACY_POLICY_URL'] ?? '').isNotEmpty)
              _DrawerItem(
                icon: Icons.lock_outline,
                label: 'Privacy',
                onTap: () {
                  Navigator.of(context).pop();
                  launchUrl(
                    Uri.parse(dotenv.env['PRIVACY_POLICY_URL']!),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            _DrawerItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: push NotificationsPage
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.logout,
              label: 'Log out',
              color: Colors.red[400],
              onTap: () {
                Navigator.of(context).pop();
                // TODO: sign-out logic
                // Show confirmation dialog
                _showLogoutDialog(context);
              },
            ),
            // Both stores require in-app account deletion, and it has to be
            // reachable without contacting support.
            _DrawerItem(
              icon: Icons.delete_forever_outlined,
              label: 'Delete account',
              color: Colors.red[400],
              onTap: () {
                Navigator.of(context).pop();
                showDeleteAccountDialog(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  

  }
  static void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              try {
                await Supabase.instance.client.auth.signOut();
                await GoogleSignIn.instance.signOut();
              } catch (e) {
                showErrorSnackBar(context, e,
                    fallback: "Couldn't log out. Please try again.");
              }
            },
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.black87;
    return ListTile(
      leading: Icon(icon, size: 20, color: effectiveColor),
      title: Text(
        label,
        style:
            Theme.of(context).textTheme.labelMedium?.copyWith(color: effectiveColor),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 20,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit profile sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile? profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.profile?.name ?? '');
    _usernameController =
        TextEditingController(text: widget.profile?.username ?? '');
    _bioController =
        TextEditingController(text: widget.profile?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('Edit profile',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 20),

          _Field(controller: _nameController, label: 'Name'),
          const SizedBox(height: 12),
          _Field(
            controller: _usernameController,
            label: 'Username',
            prefix: '@',
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _bioController,
            label: 'Bio',
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Save',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final provider =
          Provider.of<UserProfileProvider>(context, listen: false);
      await provider.updateProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e,
            fallback: "Couldn't save your profile. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.theme,
  });

  final String value;
  final String label;
  final ProfileTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 16,
                color: theme.foreground,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.normal,
                fontSize: 11,
                color: theme.muted,
              ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.theme});

  final ProfileTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 26, color: theme.glassBorder);
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    this.label,
    this.icon,
    required this.theme,
    required this.onTap,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final ProfileTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 9,
          horizontal: label == null ? 10 : 0,
        ),
        decoration: BoxDecoration(
          color: theme.glassTint,
          border: Border.all(color: theme.glassBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 12,
                        color: theme.foreground,
                      ),
                )
              : Icon(icon, size: 17, color: theme.foreground),
        ),
      ),
    );
  }
}

class _PostTypeBadge extends StatelessWidget {
  const _PostTypeBadge({required this.type});

  final PostType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      PostType.selfie   => ('photo', Colors.black54),
      PostType.aiTryOn  => ('AI', Colors.deepPurple),
      PostType.canvas   => ('canvas', Colors.teal),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.prefix,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? prefix;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appearance sheet  (theme presets)
// ─────────────────────────────────────────────────────────────────────────────

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet({required this.selected, required this.onSelected});

  final ProfileTheme selected;
  final ValueChanged<ProfileTheme> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Sets the cover and the background your profile floats over.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontStyle: FontStyle.normal,
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final preset in ProfileTheme.presets) ...[
                Expanded(
                  child: _ThemeSwatch(
                    theme: preset,
                    isSelected: preset.id == selected.id,
                    onTap: () {
                      // Preserve any cover the user set, so switching palette
                      // does not silently throw away their banner image.
                      onSelected(preset.copyWith(
                        bannerImageUrl: selected.bannerImageUrl,
                        backdropImageUrl: selected.backdropImageUrl,
                      ));
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                if (preset != ProfileTheme.presets.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final ProfileTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.72,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                // Slightly inside the border so the fill never bleeds over it.
                borderRadius: BorderRadius.circular(11),
                child: Column(
                  children: [
                    // Cover
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: theme.banner,
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Backdrop
                    Expanded(
                      flex: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: theme.backdrop,
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            theme.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  color: isSelected ? Colors.black : Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
