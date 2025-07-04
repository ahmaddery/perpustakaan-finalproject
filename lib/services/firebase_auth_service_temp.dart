import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register user with email and password (without Firestore)
  Future<Map<String, dynamic>> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      // Create user with Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(fullName);

      return {
        'success': true,
        'user': {
          'uid': userCredential.user!.uid,
          'fullName': fullName,
          'email': email,
          'role': role, // Note: role is not persisted without Firestore
        },
        'message': 'User registered successfully',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  // Sign in user with email and password (without Firestore)
  Future<Map<String, dynamic>> signInUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return {
        'success': true,
        'user': {
          'uid': userCredential.user!.uid,
          'fullName': userCredential.user!.displayName ?? 'User',
          'email': userCredential.user!.email ?? email,
          'role': 'user', // Default role since we can't get from Firestore
        },
        'message': 'Sign in successful',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  // Sign out user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user data (simplified without Firestore)
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        return {
          'uid': user.uid,
          'fullName': user.displayName ?? 'User',
          'email': user.email ?? '',
          'role': 'user', // Default role
        };
      }
      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }

  // Update user profile (simplified without Firestore)
  Future<bool> updateUserProfile({
    required String fullName,
    String? role,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Update display name in Firebase Auth
        await user.updateDisplayName(fullName);
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Password reset email sent successfully',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  // Check if user is admin (simplified)
  Future<bool> isAdmin() async {
    try {
      // Without Firestore, we can't determine admin role
      // You could implement this based on email or other criteria
      User? user = _auth.currentUser;
      if (user != null) {
        // Example: admin emails
        List<String> adminEmails = ['admin@perpustakaan.com', 'septinna@admin.com'];
        return adminEmails.contains(user.email);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get all users (not available without Firestore)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    // Cannot implement without Firestore
    print('getAllUsers: Firestore required for this feature');
    return [];
  }

  // Delete user account (simplified)
  Future<bool> deleteUserAccount(String uid) async {
    try {
      // Can only delete current user without admin SDK
      User? user = _auth.currentUser;
      if (user != null && user.uid == uid) {
        await user.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting user account: $e');
      return false;
    }
  }

  // Helper method to get user-friendly error messages
  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return 'An authentication error occurred. Please try again.';
    }
  }
}