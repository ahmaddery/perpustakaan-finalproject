import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SessionManager {
  static const String _keyUserId = 'user_uid'; // Changed to UID for Firebase
  static const String _keyUserData = 'user_data';
  static const String _keyIsLoggedIn = 'is_logged_in';

  // Save user session (Firebase Auth compatible)
  static Future<void> saveSession({
    required String userId, // Firebase UID
    required String fullName,
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final userData = {
      'uid': userId,
      'fullName': fullName,
      'email': email,
      'role': role,
    };
    
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserData, jsonEncode(userData));
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  // Save user session (legacy method for backward compatibility)
  static Future<void> saveUserSession(Map<String, dynamic> userData) async {
    await saveSession(
      userId: userData['uid'] ?? userData['user_id']?.toString() ?? '',
      fullName: userData['fullName'] ?? userData['full_name'] ?? '',
      email: userData['email'] ?? '',
      role: userData['role'] ?? 'user',
    );
  }

  // Get current user data
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    bool isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!isLoggedIn) return null;
    
    String? userDataString = prefs.getString(_keyUserData);
    if (userDataString == null) return null;
    
    try {
      return jsonDecode(userDataString);
    } catch (e) {
      return null;
    }
  }

  // Get current user ID (Firebase UID)
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    
    bool isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!isLoggedIn) return null;
    
    return prefs.getString(_keyUserId);
  }

  // Get current user ID as int (legacy method for backward compatibility)
  static Future<int?> getCurrentUserIdAsInt() async {
    String? uid = await getCurrentUserId();
    if (uid == null) return null;
    
    // For backward compatibility, try to parse UID as int
    // This will return null for Firebase UIDs which are strings
    try {
      return int.parse(uid);
    } catch (e) {
      return null;
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Clear user session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserData);
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  // Update user data in session
  static Future<void> updateUserSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_keyUserData, jsonEncode(userData));
  }

  // Update specific session data
  static Future<void> updateSession({
    String? fullName,
    String? email,
    String? role,
  }) async {
    Map<String, dynamic>? currentUser = await getCurrentUser();
    if (currentUser == null) return;

    if (fullName != null) currentUser['fullName'] = fullName;
    if (email != null) currentUser['email'] = email;
    if (role != null) currentUser['role'] = role;

    await updateUserSession(currentUser);
  }

  // Get user role
  static Future<String?> getUserRole() async {
    Map<String, dynamic>? userData = await getCurrentUser();
    return userData?['role'];
  }

  // Check if user is admin
  static Future<bool> isAdmin() async {
    String? role = await getUserRole();
    return role == 'admin';
  }

  // Check if user is staff
  static Future<bool> isStaff() async {
    String? role = await getUserRole();
    return role == 'staff';
  }
}