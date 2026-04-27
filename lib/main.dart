import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:virtual_wardrobe/auth/auth_gate.dart';
import 'package:virtual_wardrobe/pages/home.dart';
import 'package:virtual_wardrobe/pages/wardrobe.dart';
import 'package:virtual_wardrobe/pages/profile.dart';
import 'package:virtual_wardrobe/services/itemprovider.dart';
import 'package:virtual_wardrobe/services/outfitprovider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await dotenv.load(fileName: '.env');

    final supabaseUrl     = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
    }
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    runApp(const VirtualWardrobeApp());
  } catch (e) {
    debugPrint('Initialization error: $e');
  }
}

class VirtualWardrobeApp extends StatelessWidget {
  const VirtualWardrobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cher',
      theme: ThemeData(
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
      ),
      home: const AuthGate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App shell — providers live here so every tab shares the same instances
// ─────────────────────────────────────────────────────────────────────────────

class Start extends StatelessWidget {
  const Start({super.key});

  @override
  Widget build(BuildContext context) {
    // ItemProvider is created once here and shared across all tabs.
    // _OutfitProviderBridge reads ItemProvider and creates OutfitProvider,
    // so both HomePage and WardrobePage get the same resolved outfits.
    return ChangeNotifierProvider(
      create: (_) => ItemProvider(),
      child: const _OutfitProviderBridge(
        child: _Shell(),
      ),
    );
  }
}

/// Bridges ItemProvider → OutfitProvider, identical to the one in wardrobe.dart
/// but now lifted to the Start level so HomePage can consume OutfitProvider too.
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

// ─────────────────────────────────────────────────────────────────────────────
// Navigation shell
// ─────────────────────────────────────────────────────────────────────────────

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  final String userId = FirebaseAuth.instance.currentUser!.uid;


  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(key: PageStorageKey('home')),
      // WardrobePage no longer needs its own OutfitProviderBridge — it reads
      // from the one created above in Start.
      WardrobePage(key: PageStorageKey('wardrobe'), userId: userId),
      ProfilePage(key: PageStorageKey('profile'), userId: userId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(
          _pages.length,
          (i) => TickerMode(
            enabled: _currentIndex == i,
            child: _pages[i],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
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