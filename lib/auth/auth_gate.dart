import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:virtual_wardrobe/pages/login_page.dart';
import 'package:virtual_wardrobe/main.dart'; // imports Start

/// Sits at the root of the widget tree and listens to Firebase's auth stream.
/// - Signed in  → shows [Start] (the main app with bottom nav)
/// - Signed out → shows [LoginPage]
///
/// Firebase Auth automatically persists the session to device storage, so a
/// user who signed in previously will be emitted immediately on the next app
/// launch without hitting the network — they will never see [LoginPage] again
/// unless they explicitly log out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for the persisted session to load.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // A user is signed in — show the main app.
        if (snapshot.hasData && snapshot.data != null) {
          return Start();
        } else {
          return const LoginPage();
          }

        // No user — show the login / register screen.
        
      },
    );
  }
}