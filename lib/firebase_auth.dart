import 'package:flutter/material.dart';
import 'package:player_collector/pages/home.dart';
import 'package:player_collector/signin/signin.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const SignInPage();
          }
          return const HomePage();
        }
        
        // While waiting for the authentication state, show a loading indicator
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}