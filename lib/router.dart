import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/pages/home.dart';
import 'package:virtual_wardrobe/pages/login_page.dart';
import 'package:virtual_wardrobe/pages/profile.dart';
import 'package:virtual_wardrobe/pages/wardrobe.dart';
import 'package:virtual_wardrobe/services/credits_provider.dart';
import 'package:virtual_wardrobe/services/itemprovider.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';

// ── Router ────────────────────────────────────────────────────────────────────

final _authNotifier = _AuthNotifier();

final router = GoRouter(
  initialLocation: '/home',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final isLoggedIn =
        Supabase.instance.client.auth.currentSession != null;
    final isOnLogin = state.matchedLocation == '/login';
    if (!isLoggedIn && !isOnLogin) return '/login';
    if (isLoggedIn && isOnLogin) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => const LoginPage(),
    ),
    StatefulShellRoute.indexedStack(
      // Providers wrap the shell so every tab shares the same instances and
      // they are disposed automatically on sign-out when the shell is unmounted.
      builder: (context, state, navigationShell) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ItemProvider()),
          // Loaded once on sign-in; the try-on and top-up flows refresh it.
          ChangeNotifierProvider(create: (_) => CreditsProvider()..refresh()),
        ],
        child: _OutfitProviderBridge(
          child: AppShell(navigationShell: navigationShell),
        ),
      ),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/wardrobe',
            builder: (_, _) {
              // Don't force-unwrap: during an auth-state race the user can be
              // null for a frame before the redirect sends us to /login.
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) return const _AuthLoadingScreen();
              return WardrobePage(userId: userId);
            },
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) return const _AuthLoadingScreen();
              return ProfilePage(userId: userId);
            },
          ),
        ]),
      ],
    ),
  ],
);

// ── Navigation shell ──────────────────────────────────────────────────────────

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        animationDuration: const Duration(milliseconds: 200),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_filled, color: Colors.black, size: 25),
            selectedIcon: Icon(Icons.home_filled,
                color: Colors.lightGreenAccent, size: 35),
            label: 'Home',
          ),
          NavigationDestination(
            icon: ImageIcon(AssetImage('assets/icons/wardrobe_person.png'),
                color: Colors.black, size: 25),
            selectedIcon: ImageIcon(
                AssetImage('assets/icons/wardrobe_opened.png'),
                color: Colors.purpleAccent,
                size: 30),
            label: 'Wardrobe',
          ),
          NavigationDestination(
            icon: Icon(Icons.person, color: Colors.black, size: 25),
            selectedIcon:
                Icon(Icons.person, size: 35, color: Colors.orangeAccent),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ── Auth-transition placeholder ─────────────────────────────────────────────────

/// Brief spinner shown when a protected route builds while the user is null.
/// The redirect resolves to /login on the next frame, so this is transient.
class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
      ),
    );
  }
}

// ── Provider bridge ───────────────────────────────────────────────────────────

class _OutfitProviderBridge extends StatefulWidget {
  const _OutfitProviderBridge({required this.child});
  final Widget child;

  @override
  State<_OutfitProviderBridge> createState() => _OutfitProviderBridgeState();
}

class _OutfitProviderBridgeState extends State<_OutfitProviderBridge> {
  OutfitProvider? _outfitProvider;

  @override
  Widget build(BuildContext context) {
    final itemProvider = Provider.of<ItemProvider>(context);

    if (_outfitProvider == null) {
      _outfitProvider = OutfitProvider(allItems: itemProvider.items);
    } else {
      _outfitProvider!.updateItems(itemProvider.items);
    }

    return ChangeNotifierProvider<OutfitProvider>.value(
      value: _outfitProvider!,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _outfitProvider?.dispose();
    super.dispose();
  }
}

// ── Auth notifier ─────────────────────────────────────────────────────────────

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) {
          // Defer so GoRouter's redirect never fires mid-build, which would
          // violate the navigator's _debugLocked assertion.
          WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
        });
  }
  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
