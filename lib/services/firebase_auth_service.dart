import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  // Singleton pattern
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;
  
  // Get user data from Firestore
  Future<UserData?> getUserData() async {
    try {
      if (_auth.currentUser == null) return null;
      
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      if (!doc.exists) return null;
      
      return UserData.fromFirestore(doc.data()!);
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
  
  // Sign up with email and password
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    try {
      // Validation
      if (email.isEmpty || password.isEmpty || fullName.isEmpty || username.isEmpty) {
        return AuthResult(success: false, message: 'All fields are required');
      }
      
      if (password.length < 6) {
        return AuthResult(success: false, message: 'Password must be at least 6 characters');
      }
      
      if (!email.contains('@')) {
        return AuthResult(success: false, message: 'Please enter a valid email');
      }
      
      // Check if username is already taken
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .get();
      
      if (usernameQuery.docs.isNotEmpty) {
        return AuthResult(success: false, message: 'Username already taken');
      }
      
      // Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await credential.user?.updateDisplayName(fullName);
      
      // Create user document in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'username': username.toLowerCase(),
        'fullName': fullName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
      
      print('✅ User registered: $email');
      
      return AuthResult(
        success: true,
        message: 'Account created successfully!',
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'operation-not-allowed':
          message = 'Operation not allowed';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        default:
          message = 'Registration failed: ${e.message}';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Registration failed: $e');
    }
  }
  
  // Login with email and password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      // Validation
      if (email.isEmpty || password.isEmpty) {
        return AuthResult(success: false, message: 'Email and password are required');
      }
      
      // Sign in
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last login
      await _firestore.collection('users').doc(credential.user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      
      print('✅ User logged in: $email');
      
      return AuthResult(
        success: true,
        message: 'Login successful!',
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Login failed: $e');
    }
  }
  
  // Login with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      // This requires google_sign_in package
      // Implementation depends on platform setup
      return AuthResult(
        success: false,
        message: 'Google sign-in not implemented yet',
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Google sign-in failed: $e');
    }
  }
  
  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    print('✅ User logged out');
  }
  
  // Send password reset email
  Future<AuthResult> resetPassword(String email) async {
    try {
      if (email.isEmpty) {
        return AuthResult(success: false, message: 'Please enter your email');
      }
      
      await _auth.sendPasswordResetEmail(email: email);
      
      return AuthResult(
        success: true,
        message: 'Password reset email sent! Check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        default:
          message = 'Failed to send reset email: ${e.message}';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Failed to send reset email: $e');
    }
  }
  
  // Update profile
  Future<AuthResult> updateProfile({
    String? fullName,
    String? username,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(success: false, message: 'No user logged in');
      }
      
      Map<String, dynamic> updates = {};
      
      if (fullName != null && fullName.isNotEmpty) {
        await user.updateDisplayName(fullName);
        updates['fullName'] = fullName;
      }
      
      if (username != null && username.isNotEmpty) {
        // Check if username is taken by another user
        final usernameQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: username.toLowerCase())
            .get();
        
        if (usernameQuery.docs.isNotEmpty && 
            usernameQuery.docs.first.id != user.uid) {
          return AuthResult(success: false, message: 'Username already taken');
        }
        
        updates['username'] = username.toLowerCase();
      }
      
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
      }
      
      return AuthResult(success: true, message: 'Profile updated successfully!');
    } catch (e) {
      return AuthResult(success: false, message: 'Update failed: $e');
    }
  }
  
  // Change password
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(success: false, message: 'No user logged in');
      }
      
      if (newPassword.length < 6) {
        return AuthResult(
          success: false,
          message: 'New password must be at least 6 characters',
        );
      }
      
      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
      
      return AuthResult(success: true, message: 'Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect';
          break;
        case 'weak-password':
          message = 'New password is too weak';
          break;
        case 'requires-recent-login':
          message = 'Please logout and login again to change password';
          break;
        default:
          message = 'Password change failed: ${e.message}';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Password change failed: $e');
    }
  }
  
  // Delete account
  Future<AuthResult> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(success: false, message: 'No user logged in');
      }
      
      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Delete user document from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete user from Firebase Auth
      await user.delete();
      
      print('✅ Account deleted');
      
      return AuthResult(success: true, message: 'Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'requires-recent-login':
          message = 'Please logout and login again to delete account';
          break;
        default:
          message = 'Account deletion failed: ${e.message}';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Account deletion failed: $e');
    }
  }
  
  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

// User data model
class UserData {
  final String uid;
  final String email;
  final String username;
  final String fullName;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  
  UserData({
    required this.uid,
    required this.email,
    required this.username,
    required this.fullName,
    this.createdAt,
    this.lastLogin,
  });
  
  factory UserData.fromFirestore(Map<String, dynamic> data) {
    return UserData(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      fullName: data['fullName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'fullName': fullName,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
    };
  }
}

// Auth result model
class AuthResult {
  final bool success;
  final String message;
  final User? user;
  
  AuthResult({
    required this.success,
    required this.message,
    this.user,
  });
}
