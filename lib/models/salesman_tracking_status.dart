import 'attendance.dart';
import 'location_ping.dart';

/// One entry in the Admin "Live Tracking" list — a salesperson's
/// attendance + latest known location + today's progress, all in one
/// place. Built by [AdminTrackingService.getLiveStatuses].
class SalesmanTrackingStatus {
  final String salespersonId;
  final String fullName;
  final String? routeName;
  final AttendanceRecord? attendance; // null = hasn't checked in today
  final LocationPing? lastPing;
  final int visitsToday; // distinct dealers visited today
  final int totalDealersOnRoute;
  final int ordersToday;
  final double revenueToday;

  SalesmanTrackingStatus({
    required this.salespersonId,
    required this.fullName,
    this.routeName,
    this.attendance,
    this.lastPing,
    required this.visitsToday,
    required this.totalDealersOnRoute,
    required this.ordersToday,
    required this.revenueToday,
  });

  /// active | late | off_duty | absent
  String get status {
    if (attendance == null) return 'absent';
    if (attendance!.checkOutTime != null) return 'off_duty';
    if (attendance!.status == 'late') return 'late';
    return 'active';
  }

  bool get isOnShift => attendance != null && attendance!.checkOutTime == null;

  double get visitProgress => totalDealersOnRoute == 0 ? 0 : (visitsToday / totalDealersOnRoute).clamp(0, 1);
}
