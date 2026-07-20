import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance.dart';
import '../models/location_ping.dart';
import '../models/salesman_tracking_status.dart';
import '../models/visit_timeline_entry.dart';

class AdminTrackingService {
  final SupabaseClient _client = Supabase.instance.client;

  String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Every active salesperson's live status: attendance, latest
  /// position, and today's visit/order/revenue progress. Powers the
  /// "Live Tracking" list screen.
  Future<List<SalesmanTrackingStatus>> getLiveStatuses() async {
    final todayStr = _dateStr(_todayStart);
    final todayStartUtc = _todayStart.toUtc().toIso8601String();
    // Pings older than this are treated as "no live position" rather
    // than shown as a stale pin — matches the foreground-only tracking
    // design (a ping this old means the app's been backgrounded a while).
    final recentPingCutoff = DateTime.now().subtract(const Duration(hours: 6)).toUtc().toIso8601String();

    final results = await Future.wait([
      _client.from('profiles').select('id, full_name, current_route_id').eq('role', 'salesperson').eq('status', 'active'),
      _client.from('attendance').select().eq('attendance_date', todayStr),
      _client.from('routes').select('id, name'),
      _client.from('outlets').select('id, route_id'),
      _client.from('orders').select('salesperson_id, outlet_id, outcome, status, total_amount, created_at').gte('created_at', todayStartUtc),
      _client.from('location_pings').select().gte('recorded_at', recentPingCutoff).order('recorded_at', ascending: false),
    ]);

    final profiles = results[0] as List;
    final attendanceRows = results[1] as List;
    final routes = results[2] as List;
    final outlets = results[3] as List;
    final todayOrders = results[4] as List;
    final recentPings = results[5] as List;

    final routeNameById = {for (final r in routes) r['id'] as String: r['name'] as String};

    final dealerCountByRoute = <String, int>{};
    for (final o in outlets) {
      final routeId = o['route_id'] as String?;
      if (routeId != null) dealerCountByRoute[routeId] = (dealerCountByRoute[routeId] ?? 0) + 1;
    }

    final attendanceBySalesperson = {
      for (final a in attendanceRows) a['salesperson_id'] as String: AttendanceRecord.fromJson(a),
    };

    // recentPings is already newest-first, so the first hit per
    // salesperson id is their latest position.
    final lastPingBySalesperson = <String, LocationPing>{};
    for (final p in recentPings) {
      final ping = LocationPing.fromJson(p);
      lastPingBySalesperson.putIfAbsent(ping.salespersonId, () => ping);
    }

    final visitedOutletsBySalesperson = <String, Set<String>>{};
    final ordersCountBySalesperson = <String, int>{};
    final revenueBySalesperson = <String, double>{};
    for (final o in todayOrders) {
      final salespersonId = o['salesperson_id'] as String;
      final outletId = o['outlet_id'] as String?;
      if (outletId != null) {
        (visitedOutletsBySalesperson[salespersonId] ??= <String>{}).add(outletId);
      }
      if (o['outcome'] == 'order_placed') {
        ordersCountBySalesperson[salespersonId] = (ordersCountBySalesperson[salespersonId] ?? 0) + 1;
        revenueBySalesperson[salespersonId] =
            (revenueBySalesperson[salespersonId] ?? 0) + ((o['total_amount'] as num?)?.toDouble() ?? 0);
      }
    }

    final statuses = profiles.map((p) {
      final id = p['id'] as String;
      final routeId = p['current_route_id'] as String?;
      return SalesmanTrackingStatus(
        salespersonId: id,
        fullName: p['full_name'] ?? 'Unnamed Salesman',
        routeName: routeId != null ? routeNameById[routeId] : null,
        attendance: attendanceBySalesperson[id],
        lastPing: lastPingBySalesperson[id],
        visitsToday: visitedOutletsBySalesperson[id]?.length ?? 0,
        totalDealersOnRoute: routeId != null ? (dealerCountByRoute[routeId] ?? 0) : 0,
        ordersToday: ordersCountBySalesperson[id] ?? 0,
        revenueToday: revenueBySalesperson[id] ?? 0,
      );
    }).toList();

    // Active/on-shift first, then by name — mirrors the mockup's ordering.
    statuses.sort((a, b) {
      final aActive = a.isOnShift ? 0 : 1;
      final bActive = b.isOnShift ? 0 : 1;
      if (aActive != bActive) return aActive.compareTo(bActive);
      return a.fullName.compareTo(b.fullName);
    });

    return statuses;
  }

  /// Every GPS ping recorded today for [salespersonId], oldest first —
  /// used to draw the trail polyline on the detail map.
  Future<List<LocationPing>> getTodayTrail(String salespersonId) async {
    final data = await _client
        .from('location_pings')
        .select()
        .eq('salesperson_id', salespersonId)
        .gte('recorded_at', _todayStart.toUtc().toIso8601String())
        .order('recorded_at');
    return (data as List).map((e) => LocationPing.fromJson(e)).toList();
  }

  /// Today's visit-by-visit timeline for [salespersonId], built from
  /// their real `orders` rows (every visit outcome gets a row, not
  /// just completed orders) joined to the outlet name.
  Future<List<VisitTimelineEntry>> getTodayVisitTimeline(String salespersonId) async {
    final data = await _client
        .from('orders')
        .select('outcome, total_amount, created_at, outlets(name)')
        .eq('salesperson_id', salespersonId)
        .gte('created_at', _todayStart.toUtc().toIso8601String())
        .order('created_at');

    return (data as List).map((row) {
      final outletName = (row['outlets'] as Map?)?['name'] as String? ?? 'Unknown Outlet';
      return VisitTimelineEntry(
        outletName: outletName,
        time: DateTime.parse(row['created_at']).toLocal(),
        outcome: row['outcome'] ?? 'no_order',
        orderAmount: row['outcome'] == 'order_placed' ? ((row['total_amount'] as num?)?.toDouble() ?? 0) : null,
      );
    }).toList();
  }
}
