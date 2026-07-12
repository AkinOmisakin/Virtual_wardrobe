import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:virtual_wardrobe/models/user_post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/services/userprofileprovider.dart';
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

class _ProfileBodyState extends State<_ProfileBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // One tab for now; add more (Saved, Tagged…) here later.
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProfileProvider>(context);

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = provider.profile;

    return Scaffold(
      key: _scaffoldKey,

      // ── app bar ───────────────────────────────────────────────────────────
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          profile?.username ?? 'profile',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, size: 22),
            tooltip: 'Options',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),

      // ── options drawer ────────────────────────────────────────────────────
      endDrawer: _OptionsDrawer(profile: profile),

      // ── body ──────────────────────────────────────────────────────────────
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeader(profile: profile),
                const Divider(height: 1),
              ],
            ),
          ),
          // Sticky tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on_outlined, size: 22)),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _PostsGrid(posts: provider.posts),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile header  (avatar · name · username · bio · stats)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    final postCount = provider.posts.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── avatar row ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              GestureDetector(
                onTap: () => _showEditProfile(context, profile),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: profile?.avatarUrl != null
                          ? CachedNetworkImageProvider(profile!.avatarUrl!)
                          : null,
                      child: profile?.avatarUrl == null
                          ? Icon(Icons.person,
                              size: 44, color: Colors.grey[400])
                          : null,
                    ),
                    // Edit badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // ── stats row ────────────────────────────────────────────
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(value: postCount.toString(), label: 'posts'),
                    _StatColumn(value: '—', label: 'followers'),
                    _StatColumn(value: '—', label: 'following'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── name ─────────────────────────────────────────────────────
          Text(
            profile?.name ?? 'Your Name',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontSize: 14),
          ),

          // ── bio ───────────────────────────────────────────────────────
          if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              profile!.bio!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 12, fontStyle: FontStyle.normal),
            ),
          ],

          const SizedBox(height: 14),

          // ── action buttons ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  label: 'Edit profile',
                  onTap: () => _showEditProfile(context, profile),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OutlineButton(
                  label: 'Share profile',
                  onTap: () => _shareProfile(context, profile),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

class _PostsGrid extends StatelessWidget {
  const _PostsGrid({required this.posts});

  final List<UserPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No posts yet',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () => _showPostDetail(context, post),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              CachedNetworkImage(
                imageUrl: post.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: Colors.grey[100]),
                errorWidget: (_, __, ___) =>
                    Container(color: Colors.grey[200],
                        child: const Icon(Icons.broken_image)),
              ),
              // Post type badge
              Positioned(
                top: 6,
                right: 6,
                child: _PostTypeBadge(type: post.type),
              ),
            ],
          ),
        );
      },
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
                      placeholder: (_, __) =>
                          Container(color: Colors.grey[100]),
                      errorWidget: (_, __, ___) =>
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
                    Icon(Icons.favorite_border,
                        size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${post.likes}',
                        style: Theme.of(context).textTheme.bodyMedium),
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
  const _OptionsDrawer({required this.profile});

  final UserProfile? profile;

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
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: push SettingsPage
              },
            ),
            _DrawerItem(
              icon: Icons.lock_outline,
              label: 'Privacy',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: push PrivacyPage
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Log out failed: $e')),
                );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
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
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontStyle: FontStyle.normal, fontSize: 11),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontSize: 12),
          ),
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
// Sticky tab bar delegate
// ─────────────────────────────────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => tabBar != old.tabBar;
}
