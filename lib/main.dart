
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:virtual_wardrobe/pages/home.dart';
import 'package:virtual_wardrobe/pages/wardrobe.dart';
import 'package:virtual_wardrobe/pages/profile.dart';





void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await dotenv.load(fileName: ".env");

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env'
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    runApp(const VirtualWardrobeApp());

  } catch (e) {
    debugPrint('Initialization error: $e');
  }
}


class VirtualWardrobeApp extends StatelessWidget {
  const VirtualWardrobeApp({super.key});

  // TODOLIST: 
  /* 1. Change the gender icon in the bottom navigation bar to a more custom 
  user icon (woman or neutral)*/

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
        splashFactory: NoSplash.splashFactory, // disable splash animation on buttons
        visualDensity: VisualDensity.adaptivePlatformDensity,
        
        // text theme
        textTheme: TextTheme(
          
          // title
          titleLarge: GoogleFonts.robotoMono(
            fontSize: 30,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w300
          ),
          titleMedium: GoogleFonts.robotoMono(
            fontSize: 20,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w300
          ),
          titleSmall: GoogleFonts.robotoMono(
            fontSize: 12,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w400
          ),

          //body
          bodyMedium: GoogleFonts.robotoMono(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w100
          ),

          // bodySmall: GoogleFonts.roboto(
          //   fontSize: 10,
          //   fontStyle: FontStyle.italic,
          //   fontWeight: FontWeight.w700
          // ),

          // label
          labelLarge: TextStyle(
            fontSize: 17,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w100
          ),
          labelMedium: GoogleFonts.robotoMono(
            fontSize: 13,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w500
          ),
          labelSmall: GoogleFonts.robotoMono(
            fontSize: 10,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w500,
            // color: Colors
          ),
        ),

        // appbar theme
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 4,
          surfaceTintColor: Color.fromARGB(50, 158, 158, 158),
        ),

        //tab bar theme
        tabBarTheme: TabBarThemeData(
          //unselected
          unselectedLabelColor: Colors.grey,
          dividerColor: Colors.grey[400],
          // splashFactory: NoSplash.splashFactory,
          // unselectedLabelStyle: Theme.of(context).textTheme.bodySmall,
          //selected
          labelColor: Colors.black,
          indicatorColor: Colors.black,
          // labelStyle: Theme.of(context).textTheme.bodyMedium
          //customize indicator further
          // indicator: BoxDecoration(
          //   color: Colors.transparent,
          // ),
        ),

        //navigationbar theme
        navigationBarTheme: NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected, // sets visibility of labels in the bottom navigation bar
          backgroundColor: Color.fromARGB(255, 255, 255, 255),
          indicatorColor: Color.fromARGB(255, 255, 255, 255),
          elevation: 4,
          labelTextStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.labelSmall
          ),
        ),
  
        scaffoldBackgroundColor: Colors.white
      ),
      home: Start(),
    );
  }
}

class Start extends StatefulWidget {
  const Start({super.key});

  @override
  State<Start> createState() => _StartState();
}

class _StartState extends State<Start> {
  int currentPageIndex = 0; // Tracks the currently selected page index
        
  late final List<Widget> _pages; // List of pages for navigation

  @override
  void initState() {
    super.initState();
    //PageStorageKey to ensure widgets retain state.
    _pages = [
      const HomePage(key: PageStorageKey('home')),
      const ProfilePage(key: PageStorageKey('profile')),
      const WardrobePage(key: PageStorageKey('wardrobe')),
    ];
  }

  // Updates the current page index based on user selection
  void _navigationBar(int index) {
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
        children: List<Widget>.generate(
          _pages.length,
          (i) => TickerMode(
            enabled: currentPageIndex == i,
            child: _pages[i],
          ),
        ),
      ),
      
      bottomNavigationBar: NavigationBar(
        destinations: <NavigationDestination> [

          // Home/Display page 
          NavigationDestination(
            icon: const Icon(
              Icons.home_filled,
              color: Colors.black,
              size: 25,
            ),
            selectedIcon: const Icon(
              Icons.home_filled,
              color: Colors.lightGreenAccent,
              size: 35,
            ),
            
            label: 'Home'
          ),

          // Profile
          NavigationDestination(
            icon: const Icon(
              Icons.person,
              color: Colors.black,
              size: 25
            ),
            selectedIcon: const Icon(
              Icons.person,
              size: 35,
              color: Colors.orangeAccent,
            ),

            label: 'Profile'
          ),

          // Wardrobe
          NavigationDestination(
            icon: const ImageIcon(
              AssetImage('assets/icons/wardrobe_person.png'),
              color: Colors.black,
              size: 25,
            ),
            selectedIcon: const ImageIcon(
              AssetImage('assets/icons/wardrobe_opened.png'),
              color: Colors.purpleAccent,
              size: 30,
            ),

            label: 'Wardrobe'
          ),

        ],

        // handle navigation bar item selection
        selectedIndex: currentPageIndex,
        onDestinationSelected: _navigationBar,
        // animation
        animationDuration: Duration(milliseconds: 200),

      ),
    );
  }
}


