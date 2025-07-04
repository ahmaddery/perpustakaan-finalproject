import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Pick image from gallery or camera
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Upload image to Firebase Storage
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return null;

      final String fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('profile_images').child(fileName);
      
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? profileImageUrl,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
        };
      }

      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update display name in Firebase Auth if provided
      if (fullName != null && fullName.isNotEmpty) {
        await user.updateDisplayName(fullName);
        updateData['fullName'] = fullName;
      }

      // Update profile photo URL in Firebase Auth if provided
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        await user.updatePhotoURL(profileImageUrl);
        updateData['profileImageUrl'] = profileImageUrl;
      }

      // Update data in Firestore
      await _firestore.collection('users').doc(user.uid).update(updateData);

      return {
        'success': true,
        'message': 'Profile updated successfully',
        'data': updateData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating profile: ${e.toString()}',
      };
    }
  }

  // Get current user profile data
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return null;

      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        // Merge Firebase Auth data with Firestore data
        return {
          'uid': user.uid,
          'email': user.email,
          'fullName': userData['fullName'] ?? user.displayName ?? '',
          'profileImageUrl': userData['profileImageUrl'] ?? user.photoURL ?? '',
          'role': userData['role'] ?? 'user',
          'createdAt': userData['createdAt'],
          'updatedAt': userData['updatedAt'],
        };
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Delete old profile image from storage
  Future<bool> deleteProfileImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) return true;
      
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }
}