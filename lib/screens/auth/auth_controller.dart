import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/session_manager.dart';
import '../../services/notification_service.dart';

class AuthController {
  static final FirebaseAuthService _authService = FirebaseAuthService();

  /// Login user with email and password
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _authService.signInUser(
        email: email.trim(),
        password: password,
      );

      if (result['success'] == true) {
        final user = result['user'];
        await SessionManager.saveSession(
          userId: user['uid'],
          fullName: user['fullName'],
          email: user['email'],
          role: user['role'],
        );
        
        // Initialize notification service after successful login
        await NotificationService().startNotificationService();
        
        return AuthResult.success(
          message: 'Login berhasil',
          user: user,
        );
      } else {
        return AuthResult.failure(
          message: result['message'] ?? 'Email atau kata sandi salah',
        );
      }
    } catch (e) {
      return AuthResult.failure(
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Register new user
  static Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final result = await _authService.registerUser(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
        role: role,
      );

      if (result['success'] == true) {
        final user = result['user'];
        await SessionManager.saveSession(
          userId: user['uid'],
          fullName: user['fullName'],
          email: user['email'],
          role: user['role'],
        );
        
        return AuthResult.success(
          message: 'Registrasi berhasil',
          user: user,
        );
      } else {
        return AuthResult.failure(
          message: result['message'] ?? 'Registrasi gagal, silakan coba lagi',
        );
      }
    } catch (e) {
      return AuthResult.failure(
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Reset password using email
  static Future<AuthResult> resetPassword(String email) async {
    try {
      final result = await _authService.resetPassword(email.trim());

      if (result['success'] == true) {
        return AuthResult.success(
          message: result['message'] ?? 'Email reset password telah dikirim',
        );
      } else {
        return AuthResult.failure(
          message: result['message'] ?? 'Gagal mengirim email reset password',
        );
      }
    } catch (e) {
      return AuthResult.failure(
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email tidak boleh kosong';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kata sandi tidak boleh kosong';
    }
    if (value.length < 6) {
      return 'Kata sandi minimal 6 karakter';
    }
    return null;
  }

  /// Validate full name
  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama lengkap tidak boleh kosong';
    }
    if (value.trim().length < 2) {
      return 'Nama lengkap minimal 2 karakter';
    }
    return null;
  }

  /// Validate confirm password
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi kata sandi tidak boleh kosong';
    }
    if (value != password) {
      return 'Kata sandi tidak cocok';
    }
    return null;
  }
}

/// Result class for authentication operations
class AuthResult {
  final bool isSuccess;
  final String message;
  final Map<String, dynamic>? user;

  AuthResult._({required this.isSuccess, required this.message, this.user});

  factory AuthResult.success({required String message, Map<String, dynamic>? user}) {
    return AuthResult._(
      isSuccess: true,
      message: message,
      user: user,
    );
  }

  factory AuthResult.failure({required String message}) {
    return AuthResult._(
      isSuccess: false,
      message: message,
    );
  }
}