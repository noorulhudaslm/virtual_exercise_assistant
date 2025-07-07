import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/change_password.dart';

class AuthServices {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Secure storage instance
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Storage keys
  static const String _emailKey = 'saved_email';
  static const String _passwordKey = 'saved_password';
  static const String _rememberMeKey = 'remember_me';

  /// Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Get the current user
  User? get currentUser => _firebaseAuth.currentUser;

  String? get displayName => _firebaseAuth.currentUser?.displayName;

  /// Check if user is logged in
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  /// Check if current user's email is verified
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;

  /// Helper method to extract username from email
  String _getUsernameFromEmail(String email) {
    return email.split('@')[0];
  }

  /// Save login credentials securely
  Future<void> saveLoginCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: _emailKey, value: email);
      await _secureStorage.write(key: _passwordKey, value: password);
      await _secureStorage.write(key: _rememberMeKey, value: 'true');
      print('Login credentials saved securely');
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  /// Get saved login credentials
  Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: _emailKey);
      final password = await _secureStorage.read(key: _passwordKey);
      final rememberMe = await _secureStorage.read(key: _rememberMeKey);

      return {'email': email, 'password': password, 'rememberMe': rememberMe};
    } catch (e) {
      print('Error retrieving saved credentials: $e');
      return {'email': null, 'password': null, 'rememberMe': null};
    }
  }

  /// Check if credentials are saved
  Future<bool> hasRememberMe() async {
    try {
      final rememberMe = await _secureStorage.read(key: _rememberMeKey);
      return rememberMe == 'true';
    } catch (e) {
      print('Error checking remember me status: $e');
      return false;
    }
  }

  /// Clear saved credentials
  Future<void> clearSavedCredentials() async {
    try {
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _passwordKey);
      await _secureStorage.delete(key: _rememberMeKey);
      print('Saved credentials cleared');
    } catch (e) {
      print('Error clearing credentials: $e');
    }
  }

  /// Sign up with email and password and send verification email
  Future<User?> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // Set display name - use provided name or extract from email
        final nameToSet = displayName ?? _getUsernameFromEmail(email);
        await userCredential.user!.updateDisplayName(nameToSet);
        await userCredential.user!.reload();

        // Send email verification
        await userCredential.user!.sendEmailVerification();

        print('Verification email sent to: $email');
        return userCredential.user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('Sign up error: ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      print('Unexpected error during sign up: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Resend verification email
  Future<void> resendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('Verification email resent to: ${user.email}');
      } else {
        throw 'No user found or email already verified.';
      }
    } on FirebaseAuthException catch (e) {
      print('Resend verification error: ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      print('Unexpected error during resend verification: $e');
      throw 'Failed to resend verification email. Please try again.';
    }
  }

  /// Check if user's email is verified and reload user data
  Future<bool> checkEmailVerification() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      return _firebaseAuth.currentUser?.emailVerified ?? false;
    } catch (e) {
      print('Error checking email verification: $e');
      return false;
    }
  }

  /// Sign in with email and password (enhanced with password saving)
  Future<User?> signInWithEmail(
    String email,
    String password, {
    bool requireVerification = true,
    bool rememberMe = false,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // Reload user to get latest verification status
        await userCredential.user!.reload();
        final user = _firebaseAuth.currentUser;

        // Check if email verification is required and if email is verified
        if (requireVerification && !(user?.emailVerified ?? false)) {
          // Sign out the user since email is not verified
          await _firebaseAuth.signOut();
          throw 'Please verify your email address before signing in. Check your inbox for the verification link.';
        }

        // If user doesn't have a display name, set it from email
        if (user?.displayName == null || user!.displayName!.isEmpty) {
          final username = _getUsernameFromEmail(email);
          await user?.updateDisplayName(username);
          await user?.reload();
        }

        // Save credentials if rememberMe is true
        if (rememberMe) {
          await saveLoginCredentials(email, password);
        } else {
          // Clear saved credentials if rememberMe is false
          await clearSavedCredentials();
        }

        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (e is String) {
        throw e; // Re-throw our custom email verification message
      }
      print('Unexpected error during sign in: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Auto sign-in using saved credentials
  Future<User?> autoSignIn() async {
    try {
      final credentials = await getSavedCredentials();
      final email = credentials['email'];
      final password = credentials['password'];
      final rememberMe = credentials['rememberMe'];

      if (email != null && password != null && rememberMe == 'true') {
        print('Attempting auto sign-in for: $email');
        return await signInWithEmail(email, password, rememberMe: true);
      }
      return null;
    } catch (e) {
      print('Auto sign-in failed: $e');
      // Clear invalid credentials
      await clearSavedCredentials();
      return null;
    }
  }

  /// Update the user's display name
  Future<void> updateDisplayName(String name) async {
    await _firebaseAuth.currentUser?.updateDisplayName(name);
    await _firebaseAuth.currentUser?.reload();
  }

  /// Change user password
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        print('No user is currently signed in');
        return false;
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      // Update saved password if remember me is enabled
      final hasRemember = await hasRememberMe();
      if (hasRemember) {
        await saveLoginCredentials(user.email!, newPassword);
      }

      print('Password changed successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          print('Current password is incorrect');
          break;
        case 'weak-password':
          print('New password is too weak');
          break;
        case 'requires-recent-login':
          print('Please sign in again before changing password');
          break;
        default:
          print('Password change error: ${e.message}');
      }
      return false;
    } catch (e) {
      print('Unexpected error during password change: $e');
      return false;
    }
  }

  /// Enhanced Sign out method
  Future<bool> signOut({bool clearRememberedCredentials = false}) async {
    try {
      await _firebaseAuth.signOut();

      // Optionally clear remembered credentials
      if (clearRememberedCredentials) {
        await clearSavedCredentials();
      }

      print('User signed out successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      print('Sign out error: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error during sign out: $e');
      return false;
    }
  }

  /// Send a password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.message}');
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      print('Unexpected error during password reset: $e');
      throw 'Failed to send password reset email. Please try again.';
    }
  }

  /// Get the display name with fallback to username from email
  String getDisplayNameWithFallback() {
    final user = _firebaseAuth.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    } else if (user?.email != null) {
      return _getUsernameFromEmail(user!.email!);
    }
    return 'User';
  }

  /// Delete user account (requires recent authentication)
  Future<bool> deleteAccount(String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        print('No user is currently signed in');
        throw 'No user is currently signed in.';
      }

      // Re-authenticate user with password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Clear saved credentials before deleting account
      await clearSavedCredentials();

      // Delete the user account
      await user.delete();

      print('User account deleted successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          throw 'Incorrect password. Please try again.';
        case 'requires-recent-login':
          throw 'Please sign in again before deleting your account.';
        case 'user-not-found':
          throw 'Account not found.';
        default:
          print('Delete account error: ${e.message}');
          throw _handleFirebaseAuthException(e);
      }
    } catch (e) {
      if (e is String) {
        throw e; // Re-throw our custom messages
      }
      print('Unexpected error during account deletion: $e');
      throw 'Failed to delete account. Please try again.';
    }
  }

  /// Re-authenticate user with password (used before sensitive operations)
  Future<bool> reauthenticateWithPassword(String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in.';
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (e is String) {
        throw e;
      }
      throw 'Authentication failed. Please try again.';
    }
  }

  /// Handle Firebase Auth exceptions and return user-friendly messages
  String _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
