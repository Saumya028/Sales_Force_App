import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_order.dart';
import '../models/order_item_detail.dart';

class AdminOrderService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<AdminOrder>> getPendingOrders() async {
    final data = await _client
        .from('orders')
        .select('*, outlets(name), profiles(full_name)')
        .eq('status', 'pending_approval')
        .order('created_at', ascending: false);
    return (data as List).map((e) => AdminOrder.fromJson(e)).toList();
  }

  Future<List<AdminOrder>> getAllOrders() async {
    final data = await _client
        .from('orders')
        .select('*, outlets(name), profiles(full_name)')
        .order('created_at', ascending: false);
    return (data as List).map((e) => AdminOrder.fromJson(e)).toList();
  }

  Future<List<OrderItemDetail>> getOrderItems(String orderId) async {
    final data = await _client
        .from('order_items')
        .select('*, products(name)')
        .eq('order_id', orderId);
    return (data as List).map((e) => OrderItemDetail.fromJson(e)).toList();
  }

  Future<void> approveOrder(String orderId) async {
    await _client.from('orders').update({'status': 'approved'}).eq('id', orderId);
  }

  Future<void> rejectOrder(String orderId, String reason) async {
    await _client.from('orders').update({
      'status': 'rejected',
      'admin_remarks': reason,
    }).eq('id', orderId);
  }
}
