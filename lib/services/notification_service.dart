import 'dart:async';
import '../database/database_helper.dart';
import 'localization_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  Timer? _notificationTimer;
  List<Function(NotificationData)> _listeners = [];

  // Start notification service
  void startNotificationService() {
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
    final threeDaysFromNow = now.add(const Duration(days: 3));
    
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
            message: 'Buku "${book['title']}" yang dipinjam oleh ${member['full_name']} akan jatuh tempo dalam $daysUntilDue hari.',
            loanId: loan['loan_id'],
            memberId: loan['member_id'],
            bookId: loan['book_id'],
            dueDate: dueDate,
            priority: daysUntilDue == 1 ? NotificationPriority.high : NotificationPriority.medium,
          );
          
          _notifyListeners(notification);
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
          message: 'Buku "${book['title']}" yang dipinjam oleh ${member['full_name']} sudah terlambat $overdueDays hari.',
          loanId: loan['loan_id'],
          memberId: loan['member_id'],
          bookId: loan['book_id'],
          dueDate: dueDate,
          overdueDays: overdueDays,
          priority: overdueDays > 7 ? NotificationPriority.high : NotificationPriority.medium,
        );
        
        _notifyListeners(notification);
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
      final dueDate = DateTime.parse(loan['due_date']);
      final daysUntilDue = dueDate.difference(now).inDays;
      
      if (daysUntilDue >= 1 && daysUntilDue <= 3) {
        final member = await _dbHelper.getMemberById(loan['member_id']);
        final book = await _dbHelper.getBookById(loan['book_id']);
        
        if (member != null && book != null) {
          notifications.add(NotificationData(
            type: NotificationType.dueReminder,
            title: 'Pengingat Jatuh Tempo',
            message: 'Buku "${book['title']}" yang dipinjam oleh ${member['full_name']} akan jatuh tempo dalam $daysUntilDue hari.',
            loanId: loan['loan_id'],
            memberId: loan['member_id'],
            bookId: loan['book_id'],
            dueDate: dueDate,
            priority: daysUntilDue == 1 ? NotificationPriority.high : NotificationPriority.medium,
          ));
        }
      }
    }
    
    // Get overdue notifications
    final overdueLoans = await _dbHelper.getOverdueLoans();
    
    for (final loan in overdueLoans) {
      final member = await _dbHelper.getMemberById(loan['member_id']);
      final book = await _dbHelper.getBookById(loan['book_id']);
      
      if (member != null && book != null) {
        final dueDate = DateTime.parse(loan['due_date']);
        final overdueDays = DateTime.now().difference(dueDate).inDays;
        
        notifications.add(NotificationData(
          type: NotificationType.overdue,
          title: 'Keterlambatan Pengembalian',
          message: 'Buku "${book['title']}" yang dipinjam oleh ${member['full_name']} sudah terlambat $overdueDays hari.',
          loanId: loan['loan_id'],
          memberId: loan['member_id'],
          bookId: loan['book_id'],
          dueDate: dueDate,
          overdueDays: overdueDays,
          priority: overdueDays > 7 ? NotificationPriority.high : NotificationPriority.medium,
        ));
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

  // Notify all listeners
  void _notifyListeners(NotificationData notification) {
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
enum NotificationType {
  dueReminder,
  overdue,
}

// Notification priority
enum NotificationPriority {
  low,
  medium,
  high,
}