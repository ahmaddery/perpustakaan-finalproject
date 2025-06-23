import 'package:flutter/material.dart';
import '../services/notification_service.dart';

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
      if (mounted) {
        setState(() {
          _notificationCount = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notificationCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      child: Text(
        _notificationCount > 99 ? '99+' : _notificationCount.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}