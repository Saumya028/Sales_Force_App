import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/beat_plan.dart';

class AdminBeatPlanService {
  final SupabaseClient _client = Supabase.instance.client;

  String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Sets/refreshes the cosmetic "Assigned Area" banner text for
  /// [salespersonId]'s Home dashboard today. Purely cosmetic — actual
  /// shop visibility comes from profiles.current_route_id (see
  /// AdminRouteService.assignRouteToSalesperson), not from this table.
  Future<void> assignRoute({
    required String salespersonId,
    required String zoneName,
    double? coverageKm,
    DateTime? date,
  }) async {
    final planDate = date ?? DateTime.now();
    await _client.from('beat_plans').upsert(
      {
        'salesperson_id': salespersonId,
        'plan_date': _dateStr(planDate),
        'zone_name': zoneName.trim(),
        'coverage_km': coverageKm,
      },
      onConflict: 'salesperson_id,plan_date',
    );
  }

  /// Today's beat plan for every salesperson, keyed by salesperson id, so
  /// the Salesmen list can show "Today: <zone>" per row.
  Future<Map<String, BeatPlan>> getTodayPlansBySalesman() async {
    final todayStr = _dateStr(DateTime.now());
    final data = await _client.from('beat_plans').select().eq('plan_date', todayStr);
    final map = <String, BeatPlan>{};
    for (final row in data as List) {
      final plan = BeatPlan.fromJson(row);
      map[row['salesperson_id']] = plan;
    }
    return map;
  }
}
