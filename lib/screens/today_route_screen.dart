import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/outlet.dart';
import '../models/sales_order.dart';
import '../services/outlet_service.dart';
import '../services/order_service.dart';
import 'outlet_detail_screen.dart';

/// Full "Today's Route" list — every dealer assigned to this salesperson,
/// with a VISITED/PENDING badge based on whether they logged a visit
/// outcome today. The Home dashboard shows a short preview of this same
/// data; "View All" opens this screen.
class TodayRouteScreen extends StatefulWidget {
  const TodayRouteScreen({super.key});

  @override
  State<TodayRouteScreen> createState() => _TodayRouteScreenState();
}

class _TodayRouteScreenState extends State<TodayRouteScreen> {
  final _outletService = OutletService();
  final _orderService = OrderService();
  late Future<_RouteData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RouteData> _load() async {
    final results = await Future.wait([
      _outletService.getMyOutlets(),
      _orderService.getTodayOrders(),
    ]);
    final outlets = results[0] as List<Outlet>;
    final todayOrders = results[1] as List<SalesOrder>;

    final latestOrderByOutlet = <String, SalesOrder>{};
    for (final order in todayOrders) {
      latestOrderByOutlet.putIfAbsent(order.outletId, () => order);
    }
    return _RouteData(outlets: outlets, latestOrderByOutlet: latestOrderByOutlet);
  }

  void _refresh() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Route")),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<_RouteData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final data = snapshot.data!;
            if (data.outlets.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No dealers assigned yet.')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: data.outlets.length,
              itemBuilder: (context, index) {
                final outlet = data.outlets[index];
                final order = data.latestOrderByOutlet[outlet.id];
                return _RouteTile(
                  outlet: outlet,
                  order: order,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OutletDetailScreen(outlet: outlet)),
                    );
                    _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RouteData {
  final List<Outlet> outlets;
  final Map<String, SalesOrder> latestOrderByOutlet;
  _RouteData({required this.outlets, required this.latestOrderByOutlet});
}

class _RouteTile extends StatelessWidget {
  final Outlet outlet;
  final SalesOrder? order;
  final VoidCallback onTap;

  const _RouteTile({required this.outlet, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final visited = order != null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          Icons.circle,
          size: 12,
          color: visited ? Colors.green : Colors.orange,
        ),
        title: Text(outlet.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          visited
              ? DateFormat('h:mm a').format(order!.createdAt.toLocal())
              : 'Not visited yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: visited ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                visited ? 'VISITED' : 'PENDING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: visited ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              visited && order!.totalAmount > 0
                  ? '₹${order!.totalAmount.toStringAsFixed(0)}'
                  : '–',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
