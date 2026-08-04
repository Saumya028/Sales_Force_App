import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sales_target.dart';

class AdminTargetService {
  final SupabaseClient _client = Supabase.instance.client;

  /// All targets assigned for [period] ('YYYY-MM'), with achievedValue
  /// still at its default (0) — use [getTargetsWithProgress] if you need
  /// real progress numbers too.
  Future<List<SalesTarget>> getTargetsForPeriod(String period) async {
    final data = await _client
        .from('sales_targets')
        // sales_targets has two FKs into profiles (salesperson_id AND
        // created_by), so the join must name which one explicitly —
        // otherwise PostgREST can't tell which relationship to embed.
        .select('*, profiles!sales_targets_salesperson_id_fkey(full_name), products(name)')
        .eq('period', period)
        .order('created_at');
    return (data as List).map((e) => SalesTarget.fromJson(e)).toList();
  }

  Future<void> assignTarget({
    required String salespersonId,
    required String targetType,
    String? productId,
    required double goalValue,
    required String period,
    required String priority,
    String? managerNote,
  }) async {
    final adminId = _client.auth.currentUser?.id;
    await _client.from('sales_targets').insert({
      'salesperson_id': salespersonId,
      'target_type': targetType,
      'product_id': targetType == 'product' ? productId : null,
      'goal_value': goalValue,
      'period': period,
      'priority': priority,
      'manager_note': (managerNote == null || managerNote.trim().isEmpty) ? null : managerNote.trim(),
      'created_by': adminId,
    });
  }

  Future<void> deleteTarget(String id) async {
    await _client.from('sales_targets').delete().eq('id', id);
  }

  /// Fetches every target for [period] and fills in each one's
  /// `achievedValue` by aggregating that month's *approved* orders,
  /// their order_items, and new outlets — real numbers pulled straight
  /// from the same tables the rest of the admin dashboard already uses,
  /// not a mocked/cached figure.
  Future<List<SalesTarget>> getTargetsWithProgress(String period) async {
    final targets = await getTargetsForPeriod(period);
    if (targets.isEmpty) return targets;

    final range = _monthRange(period);

    final results = await Future.wait([
      _client
          .from('orders')
          .select('salesperson_id, total_amount, status, created_at, order_items(product_id, quantity)')
          .eq('status', 'approved')
          .gte('created_at', range.start.toUtc().toIso8601String())
          .lt('created_at', range.end.toUtc().toIso8601String()),
      _client
          .from('outlets')
          .select('id, created_by, created_at')
          .gte('created_at', range.start.toUtc().toIso8601String())
          .lt('created_at', range.end.toUtc().toIso8601String()),
    ]);

    final orders = results[0] as List;
    final newOutlets = results[1] as List;

    for (final target in targets) {
      target.achievedValue = _computeAchieved(target, orders, newOutlets);
    }

    return targets;
  }

  /// Same as [getTargetsWithProgress] but filtered to a single
  /// salesperson — used by "Assign Target" to show their current
  /// targets for the period being assigned.
  Future<List<SalesTarget>> getTargetsForSalespersonWithProgress({
    required String salespersonId,
    required String period,
  }) async {
    final all = await getTargetsWithProgress(period);
    return all.where((t) => t.salespersonId == salespersonId).toList();
  }

  double _computeAchieved(SalesTarget target, List orders, List newOutlets) {
    switch (target.targetType) {
      case 'value':
        double sum = 0;
        for (final o in orders) {
          if (o['salesperson_id'] == target.salespersonId) {
            sum += (o['total_amount'] as num?)?.toDouble() ?? 0;
          }
        }
        return sum;
      case 'quantity':
        double sum = 0;
        for (final o in orders) {
          if (o['salesperson_id'] == target.salespersonId) {
            final items = (o['order_items'] as List?) ?? [];
            for (final item in items) {
              sum += (item['quantity'] as num?)?.toDouble() ?? 0;
            }
          }
        }
        return sum;
      case 'product':
        double sum = 0;
        for (final o in orders) {
          if (o['salesperson_id'] == target.salespersonId) {
            final items = (o['order_items'] as List?) ?? [];
            for (final item in items) {
              if (item['product_id'] == target.productId) {
                sum += (item['quantity'] as num?)?.toDouble() ?? 0;
              }
            }
          }
        }
        return sum;
      case 'new_dealer':
        return newOutlets.where((o) => o['created_by'] == target.salespersonId).length.toDouble();
      default:
        return 0;
    }
  }

  ({DateTime start, DateTime end}) _monthRange(String period) {
    final parts = period.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return (start: start, end: end);
  }
}
