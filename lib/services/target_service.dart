import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sales_target.dart';

/// Salesman-side: read-only access to the targets an Admin assigned to
/// the logged-in user, with real progress computed from their own
/// approved orders/order_items/outlets for the given month — same
/// aggregation approach as AdminTargetService, just scoped to "me".
class TargetService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<SalesTarget>> getMyTargetsWithProgress(String period) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final range = _monthRange(period);

    final results = await Future.wait([
      _client
          .from('sales_targets')
          .select('*, products(name)')
          .eq('salesperson_id', uid)
          .eq('period', period)
          .order('created_at'),
      _client
          .from('orders')
          .select('total_amount, status, created_at, order_items(product_id, quantity)')
          .eq('salesperson_id', uid)
          .eq('status', 'approved')
          .gte('created_at', range.start.toUtc().toIso8601String())
          .lt('created_at', range.end.toUtc().toIso8601String()),
      _client
          .from('outlets')
          .select('id, created_by, created_at')
          .eq('created_by', uid)
          .gte('created_at', range.start.toUtc().toIso8601String())
          .lt('created_at', range.end.toUtc().toIso8601String()),
    ]);

    final targets = (results[0] as List).map((e) => SalesTarget.fromJson(e)).toList();
    final orders = results[1] as List;
    final newDealerCount = (results[2] as List).length.toDouble();

    for (final target in targets) {
      target.achievedValue = _computeAchieved(target, orders, newDealerCount);
    }
    return targets;
  }

  double _computeAchieved(SalesTarget target, List orders, double newDealerCount) {
    switch (target.targetType) {
      case 'value':
        double sum = 0;
        for (final o in orders) {
          sum += (o['total_amount'] as num?)?.toDouble() ?? 0;
        }
        return sum;
      case 'quantity':
        double sum = 0;
        for (final o in orders) {
          final items = (o['order_items'] as List?) ?? [];
          for (final item in items) {
            sum += (item['quantity'] as num?)?.toDouble() ?? 0;
          }
        }
        return sum;
      case 'product':
        double sum = 0;
        for (final o in orders) {
          final items = (o['order_items'] as List?) ?? [];
          for (final item in items) {
            if (item['product_id'] == target.productId) {
              sum += (item['quantity'] as num?)?.toDouble() ?? 0;
            }
          }
        }
        return sum;
      case 'new_dealer':
        return newDealerCount;
      default:
        return 0;
    }
  }

  ({DateTime start, DateTime end}) _monthRange(String period) {
    final parts = period.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return (start: DateTime(year, month, 1), end: DateTime(year, month + 1, 1));
  }
}
