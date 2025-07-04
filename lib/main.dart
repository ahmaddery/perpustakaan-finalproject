import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/theme_provider.dart';
import 'services/firebase_auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/core/main_navigation_screen.dart';

// Global navigator key for accessing context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Sistem Perpustakaan',
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Delay untuk splash screen effect
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      // Check Firebase Auth state
      final authService = FirebaseAuthService();
      final currentUser = authService.currentUser;
      
      if (mounted) {
        if (currentUser != null) {
          // User sudah login dengan Firebase Auth
          // Update session manager dengan data Firebase
          final userData = await authService.getCurrentUserData();
          if (userData != null) {
            await SessionManager.saveSession(
              userId: userData['uid'] ?? '',
              fullName: userData['fullName'] ?? '',
              email: userData['email'] ?? '',
              role: userData['role'] ?? 'user',
            );
          }
          
          // Initialize notification service when user is logged in
          await NotificationService().startNotificationService();
          
          // Arahkan ke main navigation dengan bottom navbar
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          );
        } else {
          // User belum login, clear session dan arahkan ke login
          await SessionManager.clearSession();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      // Jika terjadi error, clear session dan arahkan ke login
      if (mounted) {
        await SessionManager.clearSession();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = isDarkMode ? Colors.grey[900]! : primaryColor;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.library_books,
                size: 60,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            
            // App Title
            Text(
              'Sistem Perpustakaan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Kelola perpustakaan dengan mudah',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 48),
            
            // Loading Indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onPrimary,
              ),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Memuat...',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
