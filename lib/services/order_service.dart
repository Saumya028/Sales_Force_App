import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sales_order.dart';
import '../models/product.dart';

class OrderService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Places a full order with line items for the given outlet.
  Future<void> placeOrder({
    required String outletId,
    required Map<Product, int> cart,
  }) async {
    final userId = _client.auth.currentUser!.id;

    double total = 0;
    for (final entry in cart.entries) {
      total += entry.key.price * entry.value;
    }

    final orderResponse = await _client
        .from('orders')
        .insert({
          'salesperson_id': userId,
          'outlet_id': outletId,
          'outcome': 'order_placed',
          'status': 'pending_approval',
          'total_amount': total,
        })
        .select()
        .single();

    final orderId = orderResponse['id'];

    final items = cart.entries.map((entry) {
      return {
        'order_id': orderId,
        'product_id': entry.key.id,
        'quantity': entry.value,
        'price': entry.key.price,
        'amount': entry.key.price * entry.value,
      };
    }).toList();

    await _client.from('order_items').insert(items);
  }

  /// Records a "No Order" or "Follow-up" visit outcome (no products involved).
  Future<void> recordVisitOutcome({
    required String outletId,
    required String outcome, // 'no_order' or 'follow_up'
    String? remarks,
    DateTime? followUpDate,
  }) async {
    final userId = _client.auth.currentUser!.id;

    await _client.from('orders').insert({
      'salesperson_id': userId,
      'outlet_id': outletId,
      'outcome': outcome,
      'status': outcome == 'no_order' ? 'closed' : 'follow_up_scheduled',
      'remarks': remarks,
      'follow_up_date': followUpDate?.toIso8601String(),
      'total_amount': 0,
    });
  }

  /// Returns all orders/visits placed by the current salesperson, most recent first.
  Future<List<SalesOrder>> getMyOrders() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('orders')
        .select('*, outlets(name)')
        .eq('salesperson_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => SalesOrder.fromJson(e)).toList();
  }

  /// Returns every visit/order logged *today* by the current salesperson.
  /// Powers the Home dashboard's "Today's Visits" and "Orders Placed" stats
  /// and the "Today's Route" list (which outlets have already been visited).
  Future<List<SalesOrder>> getTodayOrders() async {
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));

    final data = await _client
        .from('orders')
        .select('*, outlets(name)')
        .eq('salesperson_id', userId)
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', startOfNextDay.toIso8601String())
        .order('created_at', ascending: false);
    return (data as List).map((e) => SalesOrder.fromJson(e)).toList();
  }

  /// Count of this salesperson's follow-ups that are scheduled but not
  /// yet resolved (i.e. still awaiting a future visit).
  Future<int> getPendingFollowUpsCount() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('orders')
        .select('id')
        .eq('salesperson_id', userId)
        .eq('status', 'follow_up_scheduled');
    return (data as List).length;
  }
}
