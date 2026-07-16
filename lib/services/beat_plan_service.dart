import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/beat_plan.dart';

class BeatPlanService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Returns today's beat plan for the current salesperson, or `null` if
  /// their manager hasn't set one — purely the cosmetic "Assigned Area"
  /// banner on the Home dashboard. The Territory screen's actual shop
  /// list now comes from RouteService/OutletService instead (see
  /// routes_redesign_migration.sql).
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
}
