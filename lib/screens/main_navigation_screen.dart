import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../services/settings_service.dart';
import '../services/localization_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_badge.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_screen.dart';
import 'books_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'members_screen.dart';
import 'loans_screen.dart';
import 'books_management_screen.dart';
import 'notifications_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _currentLanguage = 'id';
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadUserData();
    _initializeNotificationService();
  }

  Future<void> _initializeNotificationService() async {
    await _notificationService.startNotificationService();
  }

  Future<void> _loadLanguage() async {
    final language = await SettingsService.getLanguage();
    setState(() {
      _currentLanguage = language;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await SessionManager.getCurrentUser();
      setState(() {
        _currentUser = userData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(LocalizationService.getText('logout', _currentLanguage)),
          content: Text(_currentLanguage == 'id' 
              ? 'Apakah Anda yakin ingin keluar?'
              : 'Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(LocalizationService.getText('cancel', _currentLanguage)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await SessionManager.clearSession();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(LocalizationService.getText('logout', _currentLanguage)),
            ),
          ],
        );
      },
    );
  }

  List<Widget> get _pages => [
    const DashboardScreen(),
    const BooksScreen(),
    const MembersScreen(),
    const LoansScreen(),
    const NotificationsScreen(),
    SettingsScreenWithLogout(
      onLogout: _logout,
      currentLanguage: _currentLanguage,
      onLanguageChanged: _loadLanguage,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      return const LoginScreen();
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        currentLanguage: _currentLanguage,
      ),
    );
  }
}

// Dashboard Screen (modified from HomeScreen)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  String _currentLanguage = 'id';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final language = await SettingsService.getLanguage();
    setState(() {
      _currentLanguage = language;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await SessionManager.getCurrentUser();
      setState(() {
        _currentUser = userData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          LocalizationService.getText('dashboard', _currentLanguage),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          _currentUser!['role'] == 'admin' ? Icons.admin_panel_settings : Icons.person,
                          size: 30,
                          color: Colors.blue[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocalizationService.getText('welcome', _currentLanguage),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _currentUser!['full_name'] ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                LocalizationService.getText(_currentUser!['role'] ?? 'user', _currentLanguage).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Quick Actions
            Text(
              LocalizationService.getText('quick_actions', _currentLanguage),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Action Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildActionCard(
                  icon: Icons.people,
                  title: LocalizationService.getText('manage_members', _currentLanguage),
                  subtitle: LocalizationService.getText('member_management', _currentLanguage),
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MembersScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.assignment,
                  title: LocalizationService.getText('borrowing', _currentLanguage),
                  subtitle: LocalizationService.getText('book_borrowing', _currentLanguage),
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoansScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.book,
                  title: LocalizationService.getText('manage_books', _currentLanguage),
                  subtitle: LocalizationService.getText('add_edit_books', _currentLanguage),
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BooksManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.analytics,
                  title: LocalizationService.getText('reports', _currentLanguage),
                  subtitle: LocalizationService.getText('library_reports', _currentLanguage),
                  color: Colors.indigo,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(LocalizationService.getText('feature_under_development', _currentLanguage))),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Settings Screen with Logout
class SettingsScreenWithLogout extends StatelessWidget {
  final VoidCallback onLogout;
  final String currentLanguage;
  final VoidCallback onLanguageChanged;

  const SettingsScreenWithLogout({
    super.key,
    required this.onLogout,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          LocalizationService.getText('settings', currentLanguage),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: onLogout,
            tooltip: LocalizationService.getText('logout', currentLanguage),
          ),
        ],
      ),
      body: const SettingsScreen(),
    );
  }
}