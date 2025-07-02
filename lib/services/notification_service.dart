import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/database_helper.dart';
import '../screens/loans/loan_detail_screen.dart';
import '../main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  Timer? _notificationTimer;
  List<Function(NotificationData)> _listeners = [];
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Store dismissed notification IDs to temporarily hide them
  final Set<int> _dismissedNotifications = <int>{};

  // Initialize push notifications
  Future<void> _initializeNotifications() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    // Handle notification tap - navigate to loan detail screen
    final payload = notificationResponse.payload;
    if (payload != null && payload.isNotEmpty) {
      final parts = payload.split(':');
      if (parts.length == 2) {
        final loanId = int.tryParse(parts[1]);

        if (loanId != null) {
          // Get the current context from the navigator
          final context = navigatorKey.currentContext;
          if (context != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LoanDetailScreen(loanId: loanId),
              ),
            );
          }
        }
      }
    }
    print('Notification tapped: $payload');
  }

  // Start notification service
  Future<void> startNotificationService() async {
    await _initializeNotifications();

    // Check for notifications every hour
    _notificationTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkNotifications();
    });

    // Also check immediately when service starts
    _checkNotifications();
  }

  // Stop notification service
  void stopNotificationService() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  // Add notification listener
  void addListener(Function(NotificationData) listener) {
    _listeners.add(listener);
  }

  // Remove notification listener
  void removeListener(Function(NotificationData) listener) {
    _listeners.remove(listener);
  }

  // Force refresh all listeners (used after payment completion)
  Future<void> refreshAllListeners() async {
    for (final listener in _listeners) {
      try {
        // Create a dummy notification just to trigger refresh
        // Listeners should ignore this and call getAllNotifications() instead
        final dummyNotification = NotificationData(
          type: NotificationType.dueReminder,
          title: 'REFRESH_TRIGGER',
          message: 'This triggers a refresh',
          loanId: -1, // Special ID to indicate refresh
          memberId: -1,
          bookId: -1,
          dueDate: DateTime.now(),
          priority: NotificationPriority.low,
        );
        listener(dummyNotification);
      } catch (e) {
        print('Error notifying listener: $e');
      }
    }
  }

  // Clear notifications for a specific loan after payment is completed
  Future<void> clearNotificationsForLoan(int loanId) async {
    try {
      // Clear push notifications for this loan
      await _flutterLocalNotificationsPlugin.cancel(loanId);

      // Force refresh all listeners to update their notification counts
      await refreshAllListeners();

      print('Notifications cleared for loan ID: $loanId');
    } catch (e) {
      print('Error clearing notifications for loan $loanId: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();

      // Notify listeners to refresh
      await checkNotificationsNow();

      print('All notifications cleared');
    } catch (e) {
      print('Error clearing all notifications: $e');
    }
  }

  // Mark notification as read/handled
  Future<void> markNotificationAsHandled(int loanId) async {
    try {
      // Cancel the specific notification
      await _flutterLocalNotificationsPlugin.cancel(loanId);

      // You could also store handled notifications in a database table
      // For now, we'll just refresh notifications
      await checkNotificationsNow();

      print('Notification marked as handled for loan ID: $loanId');
    } catch (e) {
      print('Error marking notification as handled: $e');
    }
  }

  // Check for due date reminders and overdue notifications
  Future<void> _checkNotifications() async {
    try {
      await _checkDueDateReminders();
      await _checkOverdueNotifications();
    } catch (e) {
      print('Error checking notifications: $e');
    }
  }

  // Check for loans due in 1-3 days
  Future<void> _checkDueDateReminders() async {
    final now = DateTime.now();

    final loans = await _dbHelper.getActiveLoans();

    for (final loan in loans) {
      final dueDate = DateTime.parse(loan['due_date']);
      final daysUntilDue = dueDate.difference(now).inDays;

      // Notify if due in 1-3 days
      if (daysUntilDue >= 1 && daysUntilDue <= 3) {
        final member = await _dbHelper.getMemberById(loan['member_id']);
        final book = await _dbHelper.getBookById(loan['book_id']);

        if (member != null && book != null) {
          final notification = NotificationData(
            type: NotificationType.dueReminder,
            title: 'Pengingat Jatuh Tempo',
            message:
                'Buku "${book['title']}" yang dipinjam oleh ${member['full_name']} akan jatuh tempo dalam $daysUntilDue hari.',
            loanId: loan['loan_id'],
            memberId: loan['member_id'],
            bookId: loan['book_id'],
            dueDate: dueDate,
            priority:
                daysUntilDue == 1
                    ? NotificationPriority.high
                    : NotificationPriority.medium,
          );

          await _notifyListeners(notification);
        }
      }
    }
  }

  // Check for overdue loans
  Future<void> _checkOverdueNotifications() async {
    final overdueLoans = await _dbHelper.getOverdueLoans();

    for (final loan in overdueLoans) {
      final member = await _dbHelper.getMemberById(loan['member_id']);
      final book = await _dbHelper.getBookById(loan['book_id']);

      if (member != null && book != null) {
        final dueDate = DateTime.parse(loan['due_date']);
        final overdueDays = DateTime.now().difference(dueDate).inDays;

        final notification = NotificationData(
          type: NotificationType.overdue,
          title: 'Keterlambatan Pengembalian',
          message:
              'Buku "${book['title']}" yang dipinjam oleh ${member['full_name']} sudah terlambat $overdueDays hari.',
          loanId: loan['loan_id'],
          memberId: loan['member_id'],
          bookId: loan['book_id'],
          dueDate: dueDate,
          overdueDays: overdueDays,
          priority:
              overdueDays > 7
                  ? NotificationPriority.high
                  : NotificationPriority.medium,
        );

        await _notifyListeners(notification);
      }
    }
  }

  // Get all current notifications
  Future<List<NotificationData>> getAllNotifications() async {
    List<NotificationData> notifications = [];

    // Get due date reminders
    final now = DateTime.now();
    final loans = await _dbHelper.getActiveLoans();

    for (final loan in loans) {
      final loanId = loan['loan_id'];

      // Skip if notification was dismissed
      if (_dismissedNotifications.contains(loanId)) {
        continue;
      }

      final dueDate = DateTime.parse(loan['due_date']);
      final daysUntilDue = dueDate.difference(now).inDays;

      if (daysUntilDue >= 1 && daysUntilDue <= 3) {
        final member = await _dbHelper.getMemberById(loan['member_id']);
        final book = await _dbHelper.getBookById(loan['book_id']);

        if (member != null && book != null) {
          notifications.add(
            NotificationData(
              type: NotificationType.dueReminder,
              title: 'Pengingat Jatuh Tempo',
              message:
                  'Buku "${book['title']}" yang dipinjam oleh ${member['full_name']} akan jatuh tempo dalam $daysUntilDue hari.',
              loanId: loanId,
              memberId: loan['member_id'],
              bookId: loan['book_id'],
              dueDate: dueDate,
              priority:
                  daysUntilDue == 1
                      ? NotificationPriority.high
                      : NotificationPriority.medium,
            ),
          );
        }
      }
    }

    // Get overdue notifications
    final overdueLoans = await _dbHelper.getOverdueLoans();

    for (final loan in overdueLoans) {
      final loanId = loan['loan_id'];

      // Skip if notification was dismissed
      if (_dismissedNotifications.contains(loanId)) {
        continue;
      }

      final member = await _dbHelper.getMemberById(loan['member_id']);
      final book = await _dbHelper.getBookById(loan['book_id']);

      if (member != null && book != null) {
        final dueDate = DateTime.parse(loan['due_date']);
        final overdueDays = DateTime.now().difference(dueDate).inDays;

        notifications.add(
          NotificationData(
            type: NotificationType.overdue,
            title: 'Keterlambatan Pengembalian',
            message:
                'Buku "${book['title']}" yang dipinjam oleh ${member['full_name']} sudah terlambat $overdueDays hari.',
            loanId: loanId,
            memberId: loan['member_id'],
            bookId: loan['book_id'],
            dueDate: dueDate,
            overdueDays: overdueDays,
            priority:
                overdueDays > 7
                    ? NotificationPriority.high
                    : NotificationPriority.medium,
          ),
        );
      }
    }

    // Sort by priority and date
    notifications.sort((a, b) {
      if (a.priority != b.priority) {
        return b.priority.index.compareTo(a.priority.index);
      }
      return a.dueDate.compareTo(b.dueDate);
    });

    return notifications;
  }

  // Send push notification
  Future<void> _sendPushNotification(NotificationData notification) async {
    if (!_isInitialized) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'perpustakaan_channel',
          'Perpustakaan Notifications',
          channelDescription: 'Notifikasi untuk sistem perpustakaan',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      notification.loanId, // Use loan ID as notification ID
      notification.title,
      notification.message,
      platformChannelSpecifics,
      payload: '${notification.type.name}:${notification.loanId}',
    );
  }

  // Notify all listeners and send push notification
  Future<void> _notifyListeners(NotificationData notification) async {
    // Send push notification to device
    await _sendPushNotification(notification);

    // Notify in-app listeners
    for (final listener in _listeners) {
      try {
        listener(notification);
      } catch (e) {
        print('Error notifying listener: $e');
      }
    }
  }

  // Manual check for notifications (for testing or immediate check)
  Future<void> checkNotificationsNow() async {
    await _checkNotifications();
  }

  // Dismiss a specific notification temporarily
  Future<void> dismissNotification(int loanId) async {
    try {
      // Add to dismissed list
      _dismissedNotifications.add(loanId);

      // Clear push notification for this loan
      await _flutterLocalNotificationsPlugin.cancel(loanId);

      // Force refresh all listeners to update their notification counts
      await refreshAllListeners();

      print('Notification dismissed for loan ID: $loanId');
    } catch (e) {
      print('Error dismissing notification for loan $loanId: $e');
    }
  }

  // Restore a specific dismissed notification
  Future<void> restoreNotification(int loanId) async {
    _dismissedNotifications.remove(loanId);
    await refreshAllListeners();
  }

  // Clear all dismissed notifications (reset dismissed state)
  Future<void> clearDismissedNotifications() async {
    _dismissedNotifications.clear();
    await refreshAllListeners();
  }
}

// Notification data model
class NotificationData {
  final NotificationType type;
  final String title;
  final String message;
  final int loanId;
  final int memberId;
  final int bookId;
  final DateTime dueDate;
  final int? overdueDays;
  final NotificationPriority priority;
  final DateTime createdAt;

  NotificationData({
    required this.type,
    required this.title,
    required this.message,
    required this.loanId,
    required this.memberId,
    required this.bookId,
    required this.dueDate,
    this.overdueDays,
    required this.priority,
  }) : createdAt = DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'title': title,
      'message': message,
      'loanId': loanId,
      'memberId': memberId,
      'bookId': bookId,
      'dueDate': dueDate.toIso8601String(),
      'overdueDays': overdueDays,
      'priority': priority.toString(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// Notification types
enum NotificationType { dueReminder, overdue }

// Notification priority
enum NotificationPriority { low, medium, high }
