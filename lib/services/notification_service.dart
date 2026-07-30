import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';
import '../models/leave_request.dart';
import 'attendance_service.dart';

/// Builds the Notifications feed for both Admin and Salesman.
///
/// There is no dedicated `notifications` table. Every entry is derived
/// from tables that already exist and already have the right RLS
/// policies in place (`orders`, `leave_requests`, `outlets`,
/// `attendance`, `beat_plans`) — the same approach
/// [AdminDashboardService] uses for its stats. That means: no schema
/// migration to ship this feature, and no risk of the feed drifting out
/// of sync with the data it's describing.
class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

  String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatShortDate(DateTime date) => DateFormat('d MMM').format(date);

  /// Formats a leave date range the way the mock does: "10–11 Jul" when
  /// both ends fall in the same month, otherwise "28 Jun – 2 Jul".
  String _formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${start.day}–${end.day} ${DateFormat('MMM').format(end)}';
    }
    return '${_formatShortDate(start)} – ${_formatShortDate(end)}';
  }

  /// Admin-side feed: recent activity across every salesperson.
  Future<List<AppNotification>> loadAdminNotifications() async {
    final todayStr = _dateStr(DateTime.now());

    final results = await Future.wait([
      _client
          .from('orders')
          .select('id, created_at, total_amount, outlets(name), profiles(full_name)')
          .eq('outcome', 'order_placed')
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('leave_requests')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('orders')
          .select('id, created_at, follow_up_date, outlets(name), profiles(full_name)')
          .eq('outcome', 'follow_up')
          .eq('status', 'follow_up_scheduled')
          .lt('follow_up_date', todayStr)
          .order('follow_up_date', ascending: false)
          .limit(20),
      _client
          .from('outlets')
          .select('id, name, created_at, route_id, profiles!created_by(full_name), routes(name)')
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('attendance')
          .select('id, created_at, check_in_time, salesperson_id, profiles(full_name)')
          .eq('status', 'late')
          .order('created_at', ascending: false)
          .limit(20),
    ]);

    final orders = results[0] as List;
    final leaves = results[1] as List;
    final followUps = results[2] as List;
    final newOutlets = results[3] as List;
    final lateAttendance = results[4] as List;

    final notifications = <AppNotification>[];

    for (final o in orders) {
      final name = o['profiles']?['full_name'] ?? 'A salesperson';
      final outlet = o['outlets']?['name'] ?? 'an outlet';
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      notifications.add(AppNotification(
        id: 'order-${o['id']}',
        kind: NotificationKind.newOrder,
        title: 'New Order Submitted',
        body: '$name placed an order of ₹${amount.toStringAsFixed(0)} for $outlet',
        timestamp: DateTime.parse(o['created_at']).toLocal(),
      ));
    }

    for (final l in leaves) {
      final name = l['profiles']?['full_name'] ?? 'A salesperson';
      final start = DateTime.parse(l['start_date']);
      final end = DateTime.parse(l['end_date']);
      final days = end.difference(start).inDays + 1;
      final typeLabel = LeaveRequest.typeLabels[l['leave_type']] ?? l['leave_type'];
      notifications.add(AppNotification(
        id: 'leave-${l['id']}',
        kind: NotificationKind.leaveRequest,
        title: 'Leave Request',
        body: '$name requested $days day${days == 1 ? '' : 's'} $typeLabel '
            '(${_formatDateRange(start, end)})',
        timestamp: DateTime.parse(l['created_at']).toLocal(),
      ));
    }

    for (final f in followUps) {
      final outlet = f['outlets']?['name'] ?? 'an outlet';
      final dueDate = DateTime.parse(f['follow_up_date']);
      notifications.add(AppNotification(
        id: 'followup-${f['id']}',
        kind: NotificationKind.followUpReminder,
        title: 'Follow-up Reminder',
        body: 'Visit to $outlet is overdue since ${_formatShortDate(dueDate)}',
        timestamp: DateTime.parse(f['created_at']).toLocal(),
      ));
    }

    for (final d in newOutlets) {
      final name = d['profiles']?['full_name'] ?? 'A salesperson';
      final createdAt = DateTime.parse(d['created_at']).toLocal();
      final routeName = d['routes']?['name'];
      final routeSuffix = routeName != null ? ' on $routeName route' : '';
      notifications.add(AppNotification(
        id: 'dealer-${d['id']}',
        kind: NotificationKind.newDealer,
        title: 'New Dealer Added',
        body: "$name added '${d['name']}'$routeSuffix",
        timestamp: createdAt,
      ));
    }

    for (final a in lateAttendance) {
      final name = a['profiles']?['full_name'] ?? 'A salesperson';
      final checkIn = a['check_in_time'] != null ? DateTime.parse(a['check_in_time']).toLocal() : null;
      var body = '$name checked in late today';
      if (checkIn != null) {
        // Reuses the same "late" cutoff AttendanceService already applies
        // when marking a check-in 'late' vs 'present'.
        final expected = DateTime(checkIn.year, checkIn.month, checkIn.day, AttendanceService.lateAfterHour);
        final lateMinutes = checkIn.difference(expected).inMinutes;
        if (lateMinutes > 0) {
          body = '$name checked in $lateMinutes minutes late today';
        }
      }
      notifications.add(AppNotification(
        id: 'attendance-${a['id']}',
        kind: NotificationKind.attendanceAlert,
        title: 'Attendance Alert',
        body: body,
        timestamp: checkIn ?? DateTime.parse(a['created_at']).toLocal(),
      ));
    }

    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }

  /// Salesman-side feed: updates on the current user's own orders,
  /// leave requests, follow-ups, and beat-plan assignments.
  Future<List<AppNotification>> loadSalesmanNotifications() async {
    final userId = _client.auth.currentUser!.id;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    final results = await Future.wait([
      _client
          .from('orders')
          .select('id, created_at, updated_at, status, outcome, follow_up_date, outlets(name)')
          .eq('salesperson_id', userId)
          .order('created_at', ascending: false)
          .limit(30),
      _client
          .from('leave_requests')
          .select('*')
          .eq('salesperson_id', userId)
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('beat_plans')
          .select('*')
          .eq('salesperson_id', userId)
          .order('plan_date', ascending: false)
          .limit(10),
    ]);

    final orders = results[0] as List;
    final leaves = results[1] as List;
    final beatPlans = results[2] as List;

    final notifications = <AppNotification>[];

    for (final o in orders) {
      final status = o['status'];
      final outlet = o['outlets']?['name'] ?? 'an outlet';
      final updatedAt = o['updated_at'] != null
          ? DateTime.parse(o['updated_at']).toLocal()
          : DateTime.parse(o['created_at']).toLocal();

      if (status == 'approved' || status == 'rejected') {
        notifications.add(AppNotification(
          id: 'order-status-${o['id']}',
          kind: status == 'approved' ? NotificationKind.orderApproved : NotificationKind.orderRejected,
          title: status == 'approved' ? 'Order Approved' : 'Order Rejected',
          body: status == 'approved' ? 'Your order for $outlet was approved' : 'Your order for $outlet was rejected',
          timestamp: updatedAt,
        ));
      }

      if (o['outcome'] == 'follow_up' && status == 'follow_up_scheduled' && o['follow_up_date'] != null) {
        final dueDate = DateTime.parse(o['follow_up_date']);
        if (dueDate.isBefore(todayDateOnly)) {
          notifications.add(AppNotification(
            id: 'followup-${o['id']}',
            kind: NotificationKind.followUpReminder,
            title: 'Follow-up Reminder',
            body: 'Your follow-up visit to $outlet is overdue since ${_formatShortDate(dueDate)}',
            timestamp: DateTime.parse(o['created_at']).toLocal(),
          ));
        }
      }
    }

    for (final l in leaves) {
      final status = l['status'];
      if (status == 'approved' || status == 'rejected') {
        final start = DateTime.parse(l['start_date']);
        final end = DateTime.parse(l['end_date']);
        final updatedAt =
            l['updated_at'] != null ? DateTime.parse(l['updated_at']).toLocal() : DateTime.parse(l['created_at']).toLocal();
        notifications.add(AppNotification(
          id: 'leave-status-${l['id']}',
          kind: status == 'approved' ? NotificationKind.leaveApproved : NotificationKind.leaveRejected,
          title: status == 'approved' ? 'Leave Approved' : 'Leave Rejected',
          body: 'Your leave request (${_formatDateRange(start, end)}) was $status',
          timestamp: updatedAt,
        ));
      }
    }

    for (final b in beatPlans) {
      final planDate = DateTime.parse(b['plan_date']);
      notifications.add(AppNotification(
        id: 'beatplan-${b['id']}',
        kind: NotificationKind.beatPlanAssigned,
        title: 'Beat Plan Assigned',
        body: "You've been assigned to ${b['zone_name']} zone for ${_formatShortDate(planDate)}",
        timestamp: DateTime.parse(b['created_at']).toLocal(),
      ));
    }

    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }
}
