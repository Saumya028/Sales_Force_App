import 'package:flutter/material.dart';
import '../../models/admin_order.dart';
import '../../services/admin_order_service.dart';
import '../../services/auth_service.dart';
import 'admin_order_detail_screen.dart';

const _kBlue = Color(0xFF3366FF);
const _kGreen = Color(0xFF34A853);
const _kRed = Color(0xFFE74C3C);
const _kBg = Color(0xFFF3F4F8);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _adminOrderService = AdminOrderService();
  final _authService = AuthService();
  late TabController _tabController;
  late Future<List<AdminOrder>> _pendingFuture;
  late Future<List<AdminOrder>> _allFuture;

  // Tracks order ids currently being approved/rejected so we can disable
  // their buttons and show a small inline spinner without blocking the
  // rest of the list.
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  void _refresh() {
    setState(() {
      _pendingFuture = _adminOrderService.getPendingOrders();
      _allFuture = _adminOrderService.getAllOrders();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_approval':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'closed':
        return Colors.grey;
      case 'follow_up_scheduled':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _approve(AdminOrder order) async {
    setState(() => _processingIds.add(order.id));
    try {
      await _adminOrderService.approveOrder(order.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(order.id));
    }
  }

  Future<void> _reject(AdminOrder order) async {
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

    setState(() => _processingIds.add(order.id));
    try {
      await _adminOrderService.rejectOrder(order.id, reason.trim());
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(order.id));
    }
  }

  Widget _buildPendingList(Future<List<AdminOrder>> future) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<AdminOrder>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final orders = (snapshot.data ?? []).where((o) => o.outcome == 'order_placed').toList();
          if (orders.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('No orders here.')),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PendingBanner(count: orders.length),
              const SizedBox(height: 14),
              for (final order in orders) ...[
                _PendingOrderCard(
                  order: order,
                  isProcessing: _processingIds.contains(order.id),
                  onApprove: () => _approve(order),
                  onReject: () => _reject(order),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)),
                    );
                    _refresh();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllOrdersList(Future<List<AdminOrder>> future) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<AdminOrder>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('No orders here.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final isActionable = order.outcome == 'order_placed';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(order.outletName),
                  subtitle: Text(
                    '${order.salespersonName}'
                    '${isActionable ? ' • ₹${order.totalAmount.toStringAsFixed(2)}' : ' • ${order.outcome.replaceAll('_', ' ')}'}',
                  ),
                  trailing: Text(
                    order.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  onTap: isActionable
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)),
                          );
                          _refresh();
                        }
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Pending Approval'), Tab(text: 'All Orders')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPendingList(_pendingFuture), _buildAllOrdersList(_allFuture)],
      ),
    );
  }
}

/// The amber "N orders pending your approval" strip at the top of the
/// Pending Approval tab.
class _PendingBanner extends StatelessWidget {
  final int count;
  const _PendingBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB8860B), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count order${count == 1 ? '' : 's'} pending your approval',
              style: const TextStyle(
                color: Color(0xFF8A5A00),
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single pending order rendered as a card: outlet + amount up top,
/// salesperson + product count as a subtitle, and full-width Reject /
/// Approve buttons along the bottom — matching the target mockup.
class _PendingOrderCard extends StatelessWidget {
  final AdminOrder order;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onTap;

  const _PendingOrderCard({
    required this.order,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      order.outletName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _kBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'by ${order.salespersonName} · ${order.productCount} product${order.productCount == 1 ? '' : 's'}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 14),
              if (isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 18, color: _kRed),
                        label: const Text('Reject', style: TextStyle(color: _kRed, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF3C2C2)),
                          backgroundColor: const Color(0xFFFFF5F5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 18, color: Colors.white),
                        label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
