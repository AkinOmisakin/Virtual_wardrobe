import 'dart:math';

import 'package:flutter/material.dart';
import 'package:virtual_wardrobe/pages/home_page_.dart';
// import 'package:virtual_wardrobe/pages/outfits_.dart';
import 'package:virtual_wardrobe/pages/wardrobe_page.dart';
import 'package:virtual_wardrobe/pages/profile_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.load(fileName: ".env");
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY in .env');
  }
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const VirtualWardrobeApp());
}


class VirtualWardrobeApp extends StatelessWidget {
  const VirtualWardrobeApp({super.key});

  // TODOLIST: 
  // 1. Change the gender icon in the bottom navigation bar to a more custom user icon (woman or neutral)

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentPageIndex = 0; // Tracks the currently selected page index

  late final List<Widget> _pages; // List of pages for navigation

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(),
      WardrobePage(),
      ProfilePage(),
    ];
  }

  NavigationDestinationLabelBehavior labelBehavior = NavigationDestinationLabelBehavior.onlyShowSelected; // sets visibility of labels in the bottom navigation bar

  // Updates the current page index based on user selection
  void _navigationBottomBar(int index) {
    setState(() {
      currentPageIndex = index;
    });
  }

  // Builds the main scaffold with bottom navigation bar
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentPageIndex,
        children: _pages
      ),

      bottomNavigationBar: NavigationBar(
        destinations: const <NavigationDestination> [
          NavigationDestination(
            icon: Icon(
              Icons.home_filled,
              color: Colors.black,
              size: 25,
            ),
            selectedIcon: Icon(
              Icons.home_filled,
              color: Colors.green,
              size: 35,
            ),
            label: 'Home'
          ),
          NavigationDestination(
            icon: ImageIcon(
              AssetImage('assets/icons/wardrobe_person.png'),
              color: Colors.black,
              size: 25,
            ),
            selectedIcon: ImageIcon(
              AssetImage('assets/icons/wardrobe_opened.png'),
              color: Colors.deepPurple,
              size: 30,
              ),
            label: 'Wardrobe'
          ),
          NavigationDestination(
            icon: IconTheme(
              data: IconThemeData(
                color: null,
              ),
              child: Icon(
                Icons.person,
                size: 25,
              )
            ),
            selectedIcon: IconTheme(
              data: IconThemeData(
                color: Colors.orangeAccent,
              ),
              child: Icon(
                Icons.person,
                size: 35,
              ),
            ),
            label: 'Profile'
          ),
        ],

        selectedIndex: currentPageIndex,
        labelBehavior: labelBehavior,
        animationDuration: const Duration(milliseconds: 300),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 14,
          // fontWeight: FontWeight.bold,
          )),
        elevation: sqrt(10) * 10,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
            color: Colors.grey.shade300,
            width: 1.0,
          ),
        ),
        onDestinationSelected: _navigationBottomBar,
        backgroundColor: const Color.fromARGB(255, 253, 237, 95),
        indicatorColor: const Color.fromARGB(255, 255, 255, 255),

      ),
    );
  }
}


