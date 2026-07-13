import 'package:flutter/material.dart';
import '../models/outlet.dart';
import '../services/order_service.dart';
import 'order_screen.dart';

class OutletDetailScreen extends StatefulWidget {
  final Outlet outlet;
  const OutletDetailScreen({super.key, required this.outlet});

  @override
  State<OutletDetailScreen> createState() => _OutletDetailScreenState();
}

class _OutletDetailScreenState extends State<OutletDetailScreen> {
  final _orderService = OrderService();
  bool _isSaving = false;

  Future<void> _recordNoOrder() async {
    final remarks = await _promptText('Reason for no order');
    if (remarks == null) return;
    setState(() => _isSaving = true);
    await _orderService.recordVisitOutcome(
      outletId: widget.outlet.id,
      outcome: 'no_order',
      remarks: remarks,
    );
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _recordFollowUp() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null) return;
    final remarks = await _promptText('Follow-up remarks (optional)');
    setState(() => _isSaving = true);
    await _orderService.recordVisitOutcome(
      outletId: widget.outlet.id,
      outcome: 'follow_up',
      remarks: remarks,
      followUpDate: date,
    );
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  Future<String?> _promptText(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outlet = widget.outlet;
    return Scaffold(
      appBar: AppBar(title: Text(outlet.name)),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(outlet.address ?? '', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  if (outlet.ownerName != null) Text('Owner: ${outlet.ownerName}'),
                  if (outlet.mobileNumber != null) Text('Phone: ${outlet.mobileNumber}'),
                  if (outlet.gstNumber != null) Text('GST: ${outlet.gstNumber}'),
                  if (outlet.businessType != null)
                    Text('Type: ${outlet.businessType![0].toUpperCase()}${outlet.businessType!.substring(1)}'),
                  const SizedBox(height: 32),
                  const Text('Visit Outcome', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Place Order'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => OrderScreen(outlet: outlet)),
                        );
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: const Text('Follow-up'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      onPressed: _recordFollowUp,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('No Order'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        foregroundColor: Colors.red,
                      ),
                      onPressed: _recordNoOrder,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
