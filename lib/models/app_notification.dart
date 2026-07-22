import 'package:flutter/material.dart';

/// The distinct kinds of notification the feed can show. Each maps to a
/// fixed icon/colour so the list stays visually consistent — see
/// [AppNotification.icon]/[iconColor]/[iconBg].
enum NotificationKind {
  // Admin-side
  newOrder,
  leaveRequest,
  followUpReminder,
  newDealer,
  attendanceAlert,
  // Salesman-side
  orderApproved,
  orderRejected,
  leaveApproved,
  leaveRejected,
  beatPlanAssigned,
}

/// A single row in the Notifications feed.
///
/// Unlike most data in this app, notifications are NOT read from their
/// own table — there isn't one. [NotificationService] derives this feed
/// on the fly from `orders`, `leave_requests`, `outlets`, `attendance`,
/// and `beat_plans` (the same tables the rest of the app already reads),
/// so there's no separate notifications table to keep in sync and no
/// schema migration needed to add a new event type — just teach
/// [NotificationService] to look at a different column/table.
class AppNotification {
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  /// No read/unread state is persisted (by design, for now) — instead we
  /// treat anything from the last hour as "new" and give it the same
  /// highlighted treatment a freshly-arrived push notification would get.
  bool get isNew => DateTime.now().difference(timestamp) < const Duration(hours: 1);

  IconData get icon {
    switch (kind) {
      case NotificationKind.newOrder:
        return Icons.inventory_2_outlined;
      case NotificationKind.leaveRequest:
        return Icons.calendar_month_outlined;
      case NotificationKind.followUpReminder:
        return Icons.error_outline;
      case NotificationKind.newDealer:
        return Icons.add_business_outlined;
      case NotificationKind.attendanceAlert:
        return Icons.access_time_outlined;
      case NotificationKind.orderApproved:
        return Icons.check_circle_outline;
      case NotificationKind.orderRejected:
        return Icons.cancel_outlined;
      case NotificationKind.leaveApproved:
        return Icons.event_available_outlined;
      case NotificationKind.leaveRejected:
        return Icons.event_busy_outlined;
      case NotificationKind.beatPlanAssigned:
        return Icons.map_outlined;
    }
  }

  Color get iconColor {
    switch (kind) {
      case NotificationKind.newOrder:
        return const Color(0xFF3D6BFF);
      case NotificationKind.leaveRequest:
        return const Color(0xFFEA8C00);
      case NotificationKind.followUpReminder:
        return const Color(0xFFDC2626);
      case NotificationKind.newDealer:
        return const Color(0xFF16A34A);
      case NotificationKind.attendanceAlert:
        return const Color(0xFF7C3AED);
      case NotificationKind.orderApproved:
        return const Color(0xFF16A34A);
      case NotificationKind.orderRejected:
        return const Color(0xFFDC2626);
      case NotificationKind.leaveApproved:
        return const Color(0xFF16A34A);
      case NotificationKind.leaveRejected:
        return const Color(0xFFDC2626);
      case NotificationKind.beatPlanAssigned:
        return const Color(0xFF3D6BFF);
    }
  }

  Color get iconBg {
    switch (kind) {
      case NotificationKind.newOrder:
        return const Color(0xFFE7EDFF);
      case NotificationKind.leaveRequest:
        return const Color(0xFFFFF1DC);
      case NotificationKind.followUpReminder:
        return const Color(0xFFFDE7E7);
      case NotificationKind.newDealer:
        return const Color(0xFFE3F7EA);
      case NotificationKind.attendanceAlert:
        return const Color(0xFFF1E7FF);
      case NotificationKind.orderApproved:
        return const Color(0xFFE3F7EA);
      case NotificationKind.orderRejected:
        return const Color(0xFFFDE7E7);
      case NotificationKind.leaveApproved:
        return const Color(0xFFE3F7EA);
      case NotificationKind.leaveRejected:
        return const Color(0xFFFDE7E7);
      case NotificationKind.beatPlanAssigned:
        return const Color(0xFFE7EDFF);
    }
  }
}
