import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../screens/loans/loan_detail_screen.dart';

class NotificationWidget extends StatefulWidget {
  const NotificationWidget({Key? key}) : super(key: key);

  @override
  _NotificationWidgetState createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<NotificationWidget> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationData> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _notificationService.addListener(_onNotificationReceived);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationReceived);
    super.dispose();
  }

  void _onNotificationReceived(NotificationData notification) {
    if (mounted) {
      // If this is a refresh trigger, just reload all notifications
      if (notification.loanId == -1 &&
          notification.title == 'REFRESH_TRIGGER') {
        _loadNotifications();
        return;
      }

      // Refresh all notifications instead of just adding one
      // This ensures that paid/returned loans are properly excluded
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await _notificationService.getAllNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _isLoading = true;
    });
    await _notificationService.checkNotificationsNow();
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifikasi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (_notifications.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_notifications.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshNotifications,
                      tooltip: 'Refresh Notifikasi',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tidak ada notifikasi',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return NotificationTile(notification: notification);
              },
            ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationData notification;

  const NotificationTile({Key? key, required this.notification})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getPriorityColor(),
        child: Icon(_getNotificationIcon(), color: Colors.white, size: 20),
      ),
      title: Text(
        notification.title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(notification.message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            _getTimeText(),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: _getPriorityBadge(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () {
        _showNotificationDetails(context);
      },
    );
  }

  Color _getPriorityColor() {
    switch (notification.priority) {
      case NotificationPriority.high:
        return Colors.red;
      case NotificationPriority.medium:
        return Colors.orange;
      case NotificationPriority.low:
        return Colors.blue;
    }
  }

  IconData _getNotificationIcon() {
    switch (notification.type) {
      case NotificationType.dueReminder:
        return Icons.schedule;
      case NotificationType.overdue:
        return Icons.warning;
    }
  }

  Widget? _getPriorityBadge() {
    if (notification.priority == NotificationPriority.high) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'URGENT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return null;
  }

  String _getTimeText() {
    if (notification.type == NotificationType.dueReminder) {
      final daysUntilDue =
          notification.dueDate.difference(DateTime.now()).inDays;
      if (daysUntilDue == 1) {
        return 'Jatuh tempo besok';
      } else if (daysUntilDue > 1) {
        return 'Jatuh tempo dalam $daysUntilDue hari';
      } else {
        return 'Sudah jatuh tempo';
      }
    } else if (notification.type == NotificationType.overdue) {
      final overdueDays = notification.overdueDays ?? 0;
      return 'Terlambat $overdueDays hari';
    }
    return '';
  }

  void _showNotificationDetails(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(notification.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message),
                const SizedBox(height: 16),
                Text(
                  'Tanggal Jatuh Tempo: ${_formatDate(notification.dueDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (notification.overdueDays != null)
                  Text(
                    'Hari Keterlambatan: ${notification.overdueDays} hari',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToLoanDetails(context);
                },
                child: const Text('Lihat Detail'),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _navigateToLoanDetails(BuildContext context) {
    // Navigate to loans screen and show loan details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoanDetailScreen(loanId: notification.loanId),
      ),
    );
  }
}

// Compact notification badge for app bar
class NotificationBadge extends StatefulWidget {
  const NotificationBadge({Key? key}) : super(key: key);

  @override
  _NotificationBadgeState createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  final NotificationService _notificationService = NotificationService();
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
    _notificationService.addListener(_onNotificationReceived);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationReceived);
    super.dispose();
  }

  void _onNotificationReceived(NotificationData notification) {
    if (mounted) {
      // If this is a refresh trigger, just reload the count
      if (notification.loanId == -1 &&
          notification.title == 'REFRESH_TRIGGER') {
        _loadNotificationCount();
        return;
      }

      // For normal notifications, reload count
      _loadNotificationCount();
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final notifications = await _notificationService.getAllNotifications();
      if (mounted) {
        setState(() {
          _notificationCount = notifications.length;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            _showNotificationsBottomSheet(context);
          },
        ),
        if (_notificationCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$_notificationCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: const NotificationWidget(),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}
