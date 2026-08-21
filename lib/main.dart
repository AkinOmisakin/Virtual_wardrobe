import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/services/purchases_service.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Always render UI. The bootstrap widget owns initialization so a failure
  // shows an actionable error screen instead of a frozen black window.
  runApp(const _Bootstrap());
}

/// Runs one-time startup (env + Supabase) and gates the app behind it,
/// surfacing a retryable error screen if anything fails.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

enum _InitStatus { loading, ready, error }

class _BootstrapState extends State<_Bootstrap> {
  _InitStatus _status = _InitStatus.loading;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  bool get _isSupabaseInitialized {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _status = _InitStatus.loading;
      _error = null;
    });
    try {
      await dotenv.load(fileName: '.env');

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      // Prefer the modern publishable key; fall back to the legacy anon key.
      // Both are public client keys, gated by row-level security.
      final supabaseKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
          dotenv.env['SUPABASE_ANON_KEY'];
      if (supabaseUrl == null || supabaseKey == null) {
        throw Exception(
            'Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY in .env');
      }

      // Guard against re-initialising on retry (Supabase throws otherwise).
      if (!_isSupabaseInitialized) {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      }

      // Must come after Supabase.initialize so the RevenueCat identity can be
      // pinned to the current session. Never throws — if purchases cannot be
      // configured the app still runs, just without the top-up sheet.
      await PurchasesService.instance.initialize();

      if (mounted) setState(() => _status = _InitStatus.ready);
    } catch (e, st) {
      debugPrint('Initialization error: $e\n$st');
      if (mounted) {
        setState(() {
          _status = _InitStatus.error;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _InitStatus.ready:
        return const VirtualWardrobeApp();
      case _InitStatus.loading:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Cher',
          theme: buildAppTheme(),
          home: const _StartupLoadingScreen(),
        );
      case _InitStatus.error:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Cher',
          theme: buildAppTheme(),
          home: _StartupErrorScreen(error: _error, onRetry: _initialize),
        );
    }
  }
}

/// Shown while startup is in progress.
class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
      ),
    );
  }
}

/// Shown when startup fails; offers a Retry that re-runs initialization.
class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.black54),
                const SizedBox(height: 20),
                Text(
                  "Couldn't start Cher",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Colors.grey[600],
                  ),
                ),
                // Technical detail is developer-only; never shown in release.
                if (kDebugMode && error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoMono(
                      fontSize: 10,
                      color: Colors.red[400],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.robotoMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VirtualWardrobeApp extends StatelessWidget {
  const VirtualWardrobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Cher',
      routerConfig: router,
      theme: buildAppTheme(),
    );
  }
}

/// Shared app theme, used by both the running app and the startup screens.
ThemeData buildAppTheme() {
  return ThemeData(
        useMaterial3: true,
        primaryColor: Colors.white,
        secondaryHeaderColor: Colors.black,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          titleLarge: GoogleFonts.robotoMono(
              fontSize: 30, fontWeight: FontWeight.w300),
          titleMedium: GoogleFonts.robotoMono(
              fontSize: 20, fontWeight: FontWeight.w300, color: Colors.black),
          titleSmall: GoogleFonts.robotoMono(
              fontSize: 12, fontWeight: FontWeight.bold),
          bodyMedium: GoogleFonts.robotoMono(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w100),
          labelLarge: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w100),
          labelMedium: GoogleFonts.robotoMono(
              fontSize: 13, fontWeight: FontWeight.w500),
          labelSmall: GoogleFonts.robotoMono(
              fontSize: 10, fontWeight: FontWeight.w500),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 4,
          surfaceTintColor: Color.fromARGB(50, 158, 158, 158),
        ),
        tabBarTheme: TabBarThemeData(
          unselectedLabelColor: Colors.grey,
          dividerColor: Colors.grey[400],
          labelColor: Colors.black,
          indicatorColor: Colors.black,
        ),
        navigationBarTheme: NavigationBarThemeData(
          labelBehavior:
              NavigationDestinationLabelBehavior.onlyShowSelected,
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          indicatorColor: const Color.fromARGB(255, 255, 255, 255),
          elevation: 4,
          labelTextStyle: WidgetStatePropertyAll(
            GoogleFonts.robotoMono(
                fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ),
        scaffoldBackgroundColor: Colors.white,
      );
}
