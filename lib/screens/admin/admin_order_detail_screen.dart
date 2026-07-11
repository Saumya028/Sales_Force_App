import 'package:flutter/material.dart';
import '../../models/admin_order.dart';
import '../../models/order_item_detail.dart';
import '../../services/admin_order_service.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final AdminOrder order;
  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  final _adminOrderService = AdminOrderService();
  late Future<List<OrderItemDetail>> _itemsFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _adminOrderService.getOrderItems(widget.order.id);
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      await _adminOrderService.approveOrder(widget.order.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for rejection'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Client over credit limit'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await _adminOrderService.rejectOrder(widget.order.id, reason.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isPending = order.status == 'pending_approval';

    return Scaffold(
      appBar: AppBar(title: Text(order.outletName)),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Salesperson: ${order.salespersonName}'),
                      const SizedBox(height: 4),
                      Text('Status: ${order.status.replaceAll('_', ' ').toUpperCase()}'),
                      if (order.adminRemarks != null && order.adminRemarks!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Reason: ${order.adminRemarks}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<OrderItemDetail>>(
                    future: _itemsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return const Center(child: Text('No line items.'));
                      }
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            title: Text(item.productName),
                            subtitle: Text('Qty: ${item.quantity} × ₹${item.price.toStringAsFixed(2)}'),
                            trailing: Text('₹${item.amount.toStringAsFixed(2)}'),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Total: ₹${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isPending)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.all(16),
                            ),
                            onPressed: _reject,
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.all(16),
                            ),
                            onPressed: _approve,
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
