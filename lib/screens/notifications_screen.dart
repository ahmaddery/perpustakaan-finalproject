import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';
import 'loan_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationData> _notifications = [];
  bool _isLoading = true;
  String _currentLanguage = 'id';
  String _selectedFilter = 'all'; // all, due_reminder, overdue

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadNotifications();
    _notificationService.addListener(_onNotificationReceived);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationReceived);
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final language = await SettingsService.getLanguage();
    setState(() {
      _currentLanguage = language;
    });
  }

  void _onNotificationReceived(NotificationData notification) {
    if (mounted) {
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

  List<NotificationData> get _filteredNotifications {
    switch (_selectedFilter) {
      case 'due_reminder':
        return _notifications.where((n) => n.type == NotificationType.dueReminder).toList();
      case 'overdue':
        return _notifications.where((n) => n.type == NotificationType.overdue).toList();
      default:
        return _notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
            tooltip: 'Refresh Notifikasi',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Buttons
          Container(
            color: Colors.blue[600],
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterButton('all', 'Semua'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton('due_reminder', 'Jatuh Tempo'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton('overdue', 'Terlambat'),
                ),
              ],
            ),
          ),
          
          // Notification Count
          if (_filteredNotifications.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Text(
                '${_filteredNotifications.length} notifikasi',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          
          // Notifications List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredNotifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredNotifications.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final notification = _filteredNotifications[index];
                            return NotificationCard(notification: notification);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    switch (_selectedFilter) {
      case 'due_reminder':
        message = 'Tidak ada pengingat jatuh tempo';
        icon = Icons.schedule;
        break;
      case 'overdue':
        message = 'Tidak ada keterlambatan';
        icon = Icons.check_circle;
        break;
      default:
        message = 'Tidak ada notifikasi';
        icon = Icons.notifications_none;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tarik ke bawah untuk memperbarui',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.white : Colors.blue[700],
        foregroundColor: isSelected ? Colors.blue[600] : Colors.white,
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationData notification;

  const NotificationCard({
    Key? key,
    required this.notification,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getPriorityColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showNotificationDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getPriorityColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getNotificationIcon(),
                      color: _getPriorityColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getTimeText(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notification.priority == NotificationPriority.high)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notification.message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Jatuh tempo: ${_formatDate(notification.dueDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  String _getTimeText() {
    if (notification.type == NotificationType.dueReminder) {
      final daysUntilDue = notification.dueDate.difference(DateTime.now()).inDays;
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showNotificationDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getNotificationIcon(),
              color: _getPriorityColor(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notification.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Tanggal Jatuh Tempo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(notification.dueDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (notification.overdueDays != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.warning, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Hari Keterlambatan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${notification.overdueDays} hari',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ],
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

  void _navigateToLoanDetails(BuildContext context) {
    // Navigate to loan details screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoanDetailScreen(loanId: notification.loanId),
      ),
    );
  }
}