import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/services/api_config.dart';
import 'dart:convert';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final String _baseUrl = ApiConfig.authUrl;

  // Stream for auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Sign up with email and password
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      print('🔄 Registering user: $email');
      
      // Call our backend to create the user in Firebase Auth and Firestore
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      print('📡 Backend response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 201) {
        print('✅ Backend registration successful');
        
        // Backend has created the user in Firebase Auth, now sign in
        try {
          UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          print('✅ User signed in successfully');
          return userCredential;
        } catch (signInError) {
          print('❌ Sign in error after registration: $signInError');
          throw Exception('Account created but sign-in failed. Please try signing in manually.');
        }
      } else {
        // Handle backend errors
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Failed to register');
        } catch (parseError) {
          throw Exception('Registration failed: ${response.body}');
        }
      }
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException on signUp: ${e.message}');
      throw Exception(e.message ?? 'Firebase authentication error');
    } catch (e) {
      print('❌ Generic error on signUp: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Handle errors like wrong password, user not found, etc.
      print('FirebaseAuthException on signIn: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Generic error on signIn: $e');
      throw Exception('An unknown error occurred.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
} 