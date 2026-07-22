import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// Notifications feed. Works for both Admin (`isAdmin: true` — activity
/// across every salesperson) and Salesman (`isAdmin: false` — updates on
/// their own orders/leaves/beat plans), since both just point at
/// different [NotificationService] methods.
class NotificationsScreen extends StatefulWidget {
  final bool isAdmin;

  const NotificationsScreen({super.key, required this.isAdmin});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() {
    return widget.isAdmin ? _service.loadAdminNotifications() : _service.loadSalesmanNotifications();
  }

  void _refresh() => setState(() => _future = _load());

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: FutureBuilder<List<AppNotification>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 160),
                    Center(child: Text('Error: ${snapshot.error}')),
                  ],
                );
              }
              final notifications = snapshot.data!;
              if (notifications.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: 120),
                    Icon(Icons.notifications_none, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        "You're all caught up!",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      ),
                    ),
                  ],
                );
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _NotificationCard(
                      notification: notifications[index],
                      relativeTime: _relativeTime(notifications[index].timestamp),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final String relativeTime;

  const _NotificationCard({required this.notification, required this.relativeTime});

  @override
  Widget build(BuildContext context) {
    final isNew = notification.isNew;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: isNew ? const Color(0xFF3D6BFF) : Colors.transparent, width: 3),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: notification.iconBg, shape: BoxShape.circle),
            child: Icon(notification.icon, color: notification.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      relativeTime,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
