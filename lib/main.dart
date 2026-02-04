import 'package:flutter/material.dart';
import 'package:virtual_wardrobe/pages/home_page_.dart';
// import 'package:virtual_wardrobe/pages/outfits_.dart';
import 'package:virtual_wardrobe/pages/wardrobe_outfits_menu.dart';
import 'package:virtual_wardrobe/pages/profile_.dart';



void main () => runApp(const VirtualWardrobeApp());

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

  // List of pages for navigation
  final List<Widget> _pages = [
    HomePage(),
    WardrobePage(),
    ProfilePage(),
  ];

  int currentPageIndex = 0; // Tracks the currently selected page index
  NavigationDestinationLabelBehavior labelBehavior = NavigationDestinationLabelBehavior.alwaysHide; // sets visibility of labels in the bottom navigation bar

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
      body: _pages[currentPageIndex], // Display the selected page

      bottomNavigationBar: NavigationBar(
        destinations: const <NavigationDestination> [
          NavigationDestination(
            icon: Icon(
              Icons.home_filled,
              color: Colors.black,
            ),
            selectedIcon: Icon(
              Icons.home_filled,
              color: Colors.green,
            ),
            label: 'Home'
          ),
          NavigationDestination(
            icon: Icon(
              Icons.checkroom,
              color: Colors.black,
            ),
            selectedIcon: Icon(
              Icons.checkroom,
              color: Colors.deepPurple,
            ),
            label: 'Wardrobe'
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person,
              color: Colors.black,
            ),
            selectedIcon: Icon(
              Icons.person,
              color: Colors.orangeAccent, 
            ),
            label: 'Profile'
          ),
        ],

        selectedIndex: currentPageIndex,
        labelBehavior: labelBehavior,
        onDestinationSelected: _navigationBottomBar,
        backgroundColor: const Color.fromARGB(255, 253, 237, 95),
        indicatorColor: const Color.fromARGB(255, 255, 255, 255),
        
      ),
    );
  }
}


