import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/beat_plan.dart';
import '../models/outlet.dart';

class AdminBeatPlanService {
  final SupabaseClient _client = Supabase.instance.client;

  String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Assigns (or replaces) a salesperson's beat/route for [date] (defaults
  /// to today), and returns the beat plan's id so the caller can attach
  /// specific shops to it via [setRouteOutlets]. Relies on the unique
  /// (salesperson_id, plan_date) constraint plus the Admin insert/update
  /// policies on beat_plans.
  Future<String> assignRoute({
    required String salespersonId,
    required String zoneName,
    double? coverageKm,
    DateTime? date,
  }) async {
    final planDate = date ?? DateTime.now();
    final data = await _client
        .from('beat_plans')
        .upsert(
          {
            'salesperson_id': salespersonId,
            'plan_date': _dateStr(planDate),
            'zone_name': zoneName.trim(),
            'coverage_km': coverageKm,
          },
          onConflict: 'salesperson_id,plan_date',
        )
        .select('id')
        .single();
    return data['id'] as String;
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

  /// Every dealer already assigned to this salesperson, so the Admin can
  /// pick which ones belong on today's route. (Relies on the "Admin can
  /// view all outlets" policy — admins aren't restricted to their own
  /// assigned_salesperson_id like a salesperson is.)
  Future<List<Outlet>> getSalesmanOutlets(String salespersonId) async {
    final data = await _client
        .from('outlets')
        .select()
        .eq('assigned_salesperson_id', salespersonId)
        .order('name');
    return (data as List).map((e) => Outlet.fromJson(e)).toList();
  }

  /// The outlet ids currently attached to [beatPlanId], to pre-check the
  /// selection when re-opening "Assign Route" for an existing plan.
  Future<List<String>> getRouteOutletIds(String beatPlanId) async {
    final data = await _client
        .from('route_outlets')
        .select('outlet_id')
        .eq('beat_plan_id', beatPlanId);
    return (data as List).map((e) => e['outlet_id'] as String).toList();
  }

  /// Replaces the full set of shops attached to [beatPlanId] with
  /// [outletIds] (delete-then-insert, simplest correct semantics for an
  /// Admin re-saving a route's shop list).
  Future<void> setRouteOutlets({
    required String beatPlanId,
    required List<String> outletIds,
  }) async {
    await _client.from('route_outlets').delete().eq('beat_plan_id', beatPlanId);
    if (outletIds.isEmpty) return;
    await _client.from('route_outlets').insert(
          outletIds
              .map((outletId) => {'beat_plan_id': beatPlanId, 'outlet_id': outletId})
              .toList(),
        );
  }
}
