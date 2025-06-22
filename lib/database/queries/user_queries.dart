import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class UserQueries {
  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Authenticate user with email and password
  static Future<Map<String, dynamic>?> authenticateUser(
    Database db,
    String email,
    String password,
  ) async {
    String hashedPassword = _hashPassword(password);
    
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'email = ? AND password_hash = ? AND is_active = 1',
      whereArgs: [email, hashedPassword],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  /// Register a new user
  static Future<bool> registerUser(
    Database db, {
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    // Check if email already exists
    List<Map<String, dynamic>> existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (existing.isNotEmpty) {
      return false; // Email already exists
    }

    String hashedPassword = _hashPassword(password);
    
    try {
      await db.insert('users', {
        'full_name': fullName,
        'email': email,
        'password_hash': hashedPassword,
        'role': role,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get user by ID
  static Future<Map<String, dynamic>?> getUserById(
    Database db,
    int userId,
  ) async {
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  /// Get all active users
  static Future<List<Map<String, dynamic>>> getAllUsers(Database db) async {
    return await db.query('users', where: 'is_active = 1');
  }

  /// Insert default admin user
  static Future<void> insertDefaultAdmin(Database db) async {
    String adminPassword = _hashPassword('admin123');
    await db.insert('users', {
      'full_name': 'Administrator',
      'email': 'admin@perpustakaan.com',
      'password_hash': adminPassword,
      'role': 'admin',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}