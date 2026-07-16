import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/admin_order.dart';
import '../../models/order_item_detail.dart';
import '../../services/admin_order_service.dart';
import '../order_history_screen.dart' show statusColor, statusLabel;

const _kBlue = Color(0xFF3366FF);
const _kRed = Color(0xFFE74C3C);
const _kGrey = Color(0xFFBDBDBD);
const _kBg = Color(0xFFF3F4F8);

enum _StepState { done, current, future, rejected }

class _TimelineStep {
  final String title;
  final String subtitle;
  final _StepState state;
  _TimelineStep(this.title, this.subtitle, this.state);
}

/// Admin-facing order detail — same header/timeline/products layout as the
/// salesperson's OrderDetailScreen, plus who placed it and Approve/Reject
/// actions while the order is still pending.
class AdminOrderDetailScreen extends StatefulWidget {
  final AdminOrder order;
  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  final _adminOrderService = AdminOrderService();
  late Future<List<OrderItemDetail>> _itemsFuture;
  late AdminOrder _order;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _itemsFuture = _adminOrderService.getOrderItems(_order.id);
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      await _adminOrderService.approveOrder(_order.id);
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
      await _adminOrderService.rejectOrder(_order.id, reason.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  List<_TimelineStep> _buildSteps() {
    final submittedTime = DateFormat('d MMM, hh:mm a').format(_order.createdAt.toLocal());
    switch (_order.status) {
      case 'pending_approval':
        return [
          _TimelineStep('Order Submitted', submittedTime, _StepState.done),
          _TimelineStep('Manager Review', 'In Progress', _StepState.current),
          _TimelineStep('Approved', '—', _StepState.future),
          _TimelineStep('Processing', '—', _StepState.future),
          _TimelineStep('Delivered', '—', _StepState.future),
        ];
      case 'approved':
        return [
          _TimelineStep('Order Submitted', submittedTime, _StepState.done),
          _TimelineStep('Manager Review', 'Completed', _StepState.done),
          _TimelineStep('Approved', 'In Progress', _StepState.current),
          _TimelineStep('Processing', '—', _StepState.future),
          _TimelineStep('Delivered', '—', _StepState.future),
        ];
      case 'closed':
        return [
          _TimelineStep('Order Submitted', submittedTime, _StepState.done),
          _TimelineStep('Manager Review', 'Completed', _StepState.done),
          _TimelineStep('Approved', 'Completed', _StepState.done),
          _TimelineStep('Processing', 'Completed', _StepState.done),
          _TimelineStep('Delivered', 'Completed', _StepState.done),
        ];
      case 'rejected':
        return [
          _TimelineStep('Order Submitted', submittedTime, _StepState.done),
          _TimelineStep('Manager Review', 'Completed', _StepState.done),
          _TimelineStep(
            'Rejected',
            _order.adminRemarks?.isNotEmpty == true ? _order.adminRemarks! : 'No reason given',
            _StepState.rejected,
          ),
        ];
      default:
        return [_TimelineStep('Order Submitted', submittedTime, _StepState.done)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final isPending = order.status == 'pending_approval';
    final steps = _buildSteps();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Order Number', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                                const SizedBox(height: 2),
                                Text(order.displayOrderNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor(order.status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel(order.status),
                              style: TextStyle(
                                  color: statusColor(order.status), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dealer', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                                const SizedBox(height: 2),
                                Text(order.outletName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                                const SizedBox(height: 2),
                                Text(DateFormat('d MMM yyyy').format(order.createdAt.toLocal()),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Salesperson', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Text(order.salespersonName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 14),
                      for (var i = 0; i < steps.length; i++)
                        _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      FutureBuilder<List<OrderItemDetail>>(
                        future: _itemsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }
                          final items = snapshot.data ?? [];
                          if (items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No line items.'),
                            );
                          }
                          return Column(
                            children: [
                              for (final item in items) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.productName,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                            const SizedBox(height: 2),
                                            Text('Qty: ${item.quantity} × ₹${item.price.toStringAsFixed(0)}',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                                          ],
                                        ),
                                      ),
                                      Text('₹${item.amount.toStringAsFixed(0)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                    ],
                                  ),
                                ),
                                if (item != items.last) Divider(height: 1, color: Colors.grey.shade200),
                              ],
                              Divider(height: 24, color: Colors.grey.shade300),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(
                                    '₹${order.totalAmount.toStringAsFixed(0)}',
                                    style:
                                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kBlue),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kRed,
                            side: const BorderSide(color: _kRed),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: _reject,
                          child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: _approve,
                          child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;
  const _TimelineRow({required this.step, required this.isLast});

  Color get _circleColor => switch (step.state) {
        _StepState.done => _kBlue,
        _StepState.current => _kBlue,
        _StepState.future => Colors.white,
        _StepState.rejected => _kRed,
      };

  Color get _titleColor => switch (step.state) {
        _StepState.future => Colors.grey.shade400,
        _StepState.rejected => _kRed,
        _ => Colors.black87,
      };

  Widget get _icon => switch (step.state) {
        _StepState.done => const Icon(Icons.check, color: Colors.white, size: 14),
        _StepState.current => Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        _StepState.future => const SizedBox.shrink(),
        _StepState.rejected => const Icon(Icons.close, color: Colors.white, size: 14),
      };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _circleColor,
                  shape: BoxShape.circle,
                  border: step.state == _StepState.future ? Border.all(color: _kGrey, width: 2) : null,
                ),
                child: Center(child: _icon),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: step.state == _StepState.done ? _kBlue : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: _titleColor)),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      color: step.state == _StepState.rejected ? _kRed : Colors.grey.shade500,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
