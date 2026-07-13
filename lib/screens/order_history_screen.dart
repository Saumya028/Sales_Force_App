import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sales_order.dart';
import '../services/order_service.dart';
import 'order_detail_screen.dart';

const _kBlue = Color(0xFF3366FF);
const _kGreen = Color(0xFF2ECC71);
const _kOrange = Color(0xFFF5A623);
const _kRed = Color(0xFFE74C3C);
const _kBg = Color(0xFFF3F4F8);

enum _OrderTab { pending, approved, rejected, completed }

extension on _OrderTab {
  String get label => switch (this) {
        _OrderTab.pending => 'Pending Approval',
        _OrderTab.approved => 'Approved',
        _OrderTab.rejected => 'Rejected',
        _OrderTab.completed => 'Completed',
      };

  /// Backing `orders.status` value(s) for this tab.
  bool matches(String status) => switch (this) {
        _OrderTab.pending => status == 'pending_approval',
        _OrderTab.approved => status == 'approved',
        _OrderTab.rejected => status == 'rejected',
        _OrderTab.completed => status == 'closed',
      };
}

/// Status pill + card colors, shared by the list and the detail screen.
Color statusColor(String status) {
  switch (status) {
    case 'pending_approval':
      return _kOrange;
    case 'approved':
      return _kGreen;
    case 'rejected':
      return _kRed;
    case 'closed':
      return _kBlue;
    default:
      return Colors.grey;
  }
}

String statusLabel(String status) {
  if (status == 'closed') return 'COMPLETED';
  if (status == 'pending_approval') return 'PENDING';
  return status.replaceAll('_', ' ').toUpperCase();
}

/// "Orders" tab — every sales order the current salesperson has placed,
/// grouped into Pending Approval / Approved / Rejected / Completed like
/// the mockup. Tapping a row opens OrderDetailScreen.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _orderService = OrderService();
  final _tabScrollController = ScrollController();
  late Future<List<SalesOrder>> _ordersFuture;
  _OrderTab _tab = _OrderTab.pending;
  String _query = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _orderService.getMyOrders();
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _ordersFuture = _orderService.getMyOrders());
    await _ordersFuture;
  }

  List<SalesOrder> _filter(List<SalesOrder> all) {
    // Orders tab only shows genuine sales orders (line items + amount),
    // not "no order" / follow-up visit outcomes logged from the same table.
    var orders = all.where((o) => o.outcome == 'order_placed').toList();
    orders = orders.where((o) => _tab.matches(o.status)).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      orders = orders.where((o) {
        return o.displayOrderNumber.toLowerCase().contains(q) ||
            (o.outletName ?? '').toLowerCase().contains(q);
      }).toList();
    }
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search order number or outlet',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
          if (!_searching)
            IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildTabRow(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<SalesOrder>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text('Error: ${snapshot.error}')),
                      ],
                    );
                  }
                  final orders = _filter(snapshot.data ?? []);
                  if (orders.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No orders in this category.')),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OrderCard(
                        order: orders[index],
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => OrderDetailScreen(order: orders[index])),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 40,
        child: ListView(
          controller: _tabScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: _OrderTab.values.map((tab) {
            final selected = tab == _tab;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(tab.label),
                selected: selected,
                onSelected: (_) => setState(() => _tab = tab),
                selectedColor: _kBlue,
                backgroundColor: _kBg,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide.none,
                ),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final SalesOrder order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(order.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: _kBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.displayOrderNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.outletName ?? 'Outlet'} · ${DateFormat('d MMM').format(order.createdAt.toLocal())}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel(order.status),
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10.5),
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
