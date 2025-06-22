import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SessionManager {
  static const String _keyUserId = 'user_id';
  static const String _keyUserData = 'user_data';
  static const String _keyIsLoggedIn = 'is_logged_in';

  // Save user session
  static Future<void> saveUserSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(_keyUserId, userData['user_id']);
    await prefs.setString(_keyUserData, jsonEncode(userData));
    await prefs.setBool(_keyIsLoggedIn, true);
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

  // Get current user ID
  static Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    
    bool isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!isLoggedIn) return null;
    
    return prefs.getInt(_keyUserId);
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