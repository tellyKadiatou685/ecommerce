// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'pages/profile/profile_page.dart'; // 🔥 AJOUT DE L'IMPORT PROFIL

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BIBOCOM App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/profile': (context) => const ProfilePage(), // 🔥 AJOUT DE LA ROUTE PROFIL
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// 🔥 ALTERNATIVE: Si vous voulez utiliser Navigator.pushNamed au lieu de MaterialPageRoute
// Dans votre custom_bottom_navigation.dart, vous pouvez remplacer:

/*
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const ProfilePage(),
  ),
);

// Par:
Navigator.pushNamed(context, '/profile');
*/