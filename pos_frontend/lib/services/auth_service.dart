import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final String _baseUrl = 'http://localhost:3000/api/auth'; // Use 10.0.2.2 for Android emulator

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
      // First, we call our backend to create the user in Firebase Auth and in our Firestore db
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      if (response.statusCode == 201) {
        // If backend is successful, we then sign in the user on the client-side
        // This is necessary to get the user's session state on the device.
        UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return userCredential;
      } else {
        // Handle backend errors (e.g., email already exists)
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to register');
      }
    } on FirebaseAuthException catch (e) {
      // This will catch client-side sign-in errors, though most errors should be caught by the backend.
      print('FirebaseAuthException on signUp: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Generic error on signUp: $e');
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