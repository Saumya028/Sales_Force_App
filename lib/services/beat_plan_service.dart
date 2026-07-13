import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/beat_plan.dart';
import '../models/outlet.dart';

class BeatPlanService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Returns today's beat plan for the current salesperson, or `null` if
  /// their manager hasn't assigned one yet.
  Future<BeatPlan?> getTodayPlan() async {
    final userId = _client.auth.currentUser!.id;
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final data = await _client
        .from('beat_plans')
        .select()
        .eq('salesperson_id', userId)
        .eq('plan_date', todayStr)
        .maybeSingle();

    if (data == null) return null;
    return BeatPlan.fromJson(data);
  }

  /// The specific dealers an Admin attached to [beatPlanId] via the
  /// "Assign Route" screen. This is what the Territory map plots — not
  /// every outlet the salesperson has ever been assigned.
  Future<List<Outlet>> getRouteOutlets(String beatPlanId) async {
    final data = await _client
        .from('route_outlets')
        .select('outlets(*)')
        .eq('beat_plan_id', beatPlanId);
    return (data as List)
        .where((row) => row['outlets'] != null)
        .map((row) => Outlet.fromJson(row['outlets']))
        .toList();
  }
}
