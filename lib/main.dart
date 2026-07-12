import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Cher',
      routerConfig: router,
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
    );
  }
}
