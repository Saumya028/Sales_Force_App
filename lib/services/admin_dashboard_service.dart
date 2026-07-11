import 'package:supabase_flutter/supabase_flutter.dart';

/// One day's worth of activity for the "This Week" chart.
class DayActivity {
  final DateTime date;
  final int ordersCount;
  final int visitsCount; // distinct outlets touched that day

  DayActivity({required this.date, required this.ordersCount, required this.visitsCount});
}

class AdminOverview {
  final int totalSalesmen; // active only
  final int presentToday;
  final int lateToday;
  final int absentToday;
  final int totalOrders;
  final int pendingOrders;
  final int todaysVisits; // distinct outlets visited today, across everyone
  final double revenueMtd; // sum of approved orders this calendar month
  final List<DayActivity> weeklyActivity; // Mon..Sat of the current week

  AdminOverview({
    required this.totalSalesmen,
    required this.presentToday,
    required this.lateToday,
    required this.absentToday,
    required this.totalOrders,
    required this.pendingOrders,
    required this.todaysVisits,
    required this.revenueMtd,
    required this.weeklyActivity,
  });
}

class AdminDashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<AdminOverview> loadOverview() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final weekday = today.weekday; // 1 = Monday .. 7 = Sunday
    final mondayThisWeek = today.subtract(Duration(days: weekday - 1));

    final results = await Future.wait([
      _client.from('profiles').select('id, status').eq('role', 'salesperson'),
      _client.from('attendance').select('salesperson_id, status').eq('attendance_date', _dateStr(today)),
      _client
          .from('orders')
          .select('status, outcome, total_amount, outlet_id, created_at')
          .gte('created_at', mondayThisWeek.toIso8601String()),
      _client.from('orders').select('id, status').eq('status', 'pending_approval'),
      _client
          .from('orders')
          .select('total_amount, status, created_at')
          .gte('created_at', monthStart.toIso8601String())
          .eq('status', 'approved'),
      _client.from('orders').select('id'),
    ]);

    final profiles = results[0] as List;
    final attendanceToday = results[1] as List;
    final weekOrders = results[2] as List;
    final pendingOrders = results[3] as List;
    final monthApprovedOrders = results[4] as List;
    final allOrders = results[5] as List;

    final totalSalesmen = profiles.where((p) => (p['status'] ?? 'active') == 'active').length;

    final presentToday = attendanceToday.where((a) => a['status'] == 'present').length;
    final lateToday = attendanceToday.where((a) => a['status'] == 'late' || a['status'] == 'half_day').length;
    final checkedIn = presentToday + lateToday;
    final absentToday = (totalSalesmen - checkedIn).clamp(0, totalSalesmen).toInt();

    final revenueMtd = monthApprovedOrders.fold<double>(
      0,
      (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0),
    );

    // Distinct outlets touched today, across every salesperson.
    final todayOutletIds = <String>{};
    for (final o in weekOrders) {
      final createdAt = DateTime.parse(o['created_at']).toLocal();
      if (createdAt.year == today.year && createdAt.month == today.month && createdAt.day == today.day) {
        todayOutletIds.add(o['outlet_id'] as String);
      }
    }

    // Build Mon..Sat buckets for the chart.
    final buckets = List.generate(6, (i) => mondayThisWeek.add(Duration(days: i)));
    final activity = buckets.map((day) {
      int orders = 0;
      final outlets = <String>{};
      for (final o in weekOrders) {
        final createdAt = DateTime.parse(o['created_at']).toLocal();
        if (createdAt.year == day.year && createdAt.month == day.month && createdAt.day == day.day) {
          orders++;
          outlets.add(o['outlet_id'] as String);
        }
      }
      return DayActivity(date: day, ordersCount: orders, visitsCount: outlets.length);
    }).toList();

    return AdminOverview(
      totalSalesmen: totalSalesmen,
      presentToday: presentToday,
      lateToday: lateToday,
      absentToday: absentToday,
      totalOrders: allOrders.length,
      pendingOrders: pendingOrders.length,
      todaysVisits: todayOutletIds.length,
      revenueMtd: revenueMtd,
      weeklyActivity: activity,
    );
  }
}
