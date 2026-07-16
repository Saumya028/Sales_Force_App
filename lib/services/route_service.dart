import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sales_route.dart';

/// Salesperson-side: which route am I currently on?
class RouteService {
  final SupabaseClient _client = Supabase.instance.client;

  /// The route the current salesperson is assigned to right now, or
  /// `null` if an Admin hasn't assigned one yet. This is what the
  /// Territory screen uses to decide whether there's a route to show
  /// at all — the actual shop list comes from OutletService.getMyOutlets()
  /// (RLS already filters those to this same route).
  Future<SalesRoute?> getMyCurrentRoute() async {
    final userId = _client.auth.currentUser!.id;
    final profile = await _client
        .from('profiles')
        .select('current_route_id')
        .eq('id', userId)
        .maybeSingle();
    final routeId = profile?['current_route_id'] as String?;
    if (routeId == null) return null;

    final route = await _client.from('routes').select().eq('id', routeId).maybeSingle();
    if (route == null) return null;
    return SalesRoute.fromJson(route);
  }
}
