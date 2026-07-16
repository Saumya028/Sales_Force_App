import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sales_route.dart';
import '../models/outlet.dart';

/// Admin-side: create/manage routes, put shops on them, and assign a
/// route to a salesperson.
class AdminRouteService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<SalesRoute>> getAllRoutes() async {
    final data = await _client.from('routes').select().order('name');
    return (data as List).map((e) => SalesRoute.fromJson(e)).toList();
  }

  Future<SalesRoute> createRoute(String name) async {
    final data = await _client.from('routes').insert({'name': name.trim()}).select().single();
    return SalesRoute.fromJson(data);
  }

  Future<void> deleteRoute(String routeId) async {
    // Shops on this route just become unassigned (route_id -> null),
    // not deleted — the FK has no cascade, so clear it first.
    await _client.from('outlets').update({'route_id': null}).eq('route_id', routeId);
    await _client.from('routes').delete().eq('id', routeId);
  }

  /// Every shop currently on [routeId].
  Future<List<Outlet>> getOutletsForRoute(String routeId) async {
    final data = await _client.from('outlets').select().eq('route_id', routeId).order('name');
    return (data as List).map((e) => Outlet.fromJson(e)).toList();
  }

  /// Shops not yet on any route, so the Admin can add them to one.
  Future<List<Outlet>> getUnroutedOutlets() async {
    final data = await _client.from('outlets').select().isFilter('route_id', null).order('name');
    return (data as List).map((e) => Outlet.fromJson(e)).toList();
  }

  /// Moves a shop onto [routeId] (or off any route, if null).
  Future<void> setOutletRoute(String outletId, String? routeId) async {
    await _client.from('outlets').update({'route_id': routeId}).eq('id', outletId);
  }

  /// Every salesperson's current route assignment, keyed by salesperson
  /// id — lets a "Salesmen" list show which route each person is on.
  Future<Map<String, String>> getCurrentRouteIdsBySalesperson() async {
    final data = await _client.from('profiles').select('id, current_route_id').eq('role', 'salesperson');
    final map = <String, String>{};
    for (final row in data as List) {
      final routeId = row['current_route_id'] as String?;
      if (routeId != null) map[row['id'] as String] = routeId;
    }
    return map;
  }

  /// Assigns (or clears, if routeId is null) which route a salesperson
  /// is currently covering. This is now the entire "Assign Route" action
  /// — no shop picking, since the route already has its shops.
  Future<void> assignRouteToSalesperson({
    required String salespersonId,
    required String? routeId,
  }) async {
    await _client.from('profiles').update({'current_route_id': routeId}).eq('id', salespersonId);
  }
}
