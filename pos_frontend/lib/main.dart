import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/firebase_options.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Ensure that Flutter bindings are initialized before calling Firebase.initializeApp
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

// AuthWrapper listens to authentication changes and shows the correct screen.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String> _getUserRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('role')) {
          return data['role'] as String;
        }
      }
      // User document doesn't exist - this is normal for users who signed in 
      // but weren't registered through the app. Default to customer role.
      return 'customer';
    } catch (e) {
      // Silently handle errors and default to customer role
      return 'customer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is logged in, check their role
        if (snapshot.hasData) {
          // If user is logged in, check their role
          return FutureBuilder<String>(
            future: _getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (roleSnapshot.data == 'admin') {
                return const AdminDashboardScreen();
              }
              // Default to customer screen
              return const HomeScreen();
            },
          );
        }

        // If user is not logged in, show LoginScreen
        return const LoginScreen();
      },
    );
  }
} 