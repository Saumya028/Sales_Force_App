import 'package:flutter/material.dart';
import '../../models/admin_order.dart';
import '../../services/admin_order_service.dart';
import '../../services/auth_service.dart';
import 'admin_order_detail_screen.dart';

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

  Widget _buildOrderList(Future<List<AdminOrder>> future) {
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
        children: [_buildOrderList(_pendingFuture), _buildOrderList(_allFuture)],
      ),
    );
  }
}
