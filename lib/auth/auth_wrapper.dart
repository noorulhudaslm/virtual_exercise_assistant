import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_services.dart';
import '../screens/login_signup_ui.dart';
import '../screens/app_intro_screen.dart'; 

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If user is logged in, go to main app
        if (snapshot.hasData && snapshot.data != null) {
          return const AppIntroScreen(); // or your main app screen
        }
        
        // If user is not logged in, show login screen
        return const LoginSignupScreen();
      },
    );
  }
}