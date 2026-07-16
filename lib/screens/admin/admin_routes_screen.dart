import 'package:flutter/material.dart';
import '../../models/sales_route.dart';
import '../../services/admin_route_service.dart';
import 'admin_route_detail_screen.dart';

/// Admin's "Manage Routes" hub — create a reusable route (e.g. "Fort,
/// Mumbai") once, then tap into it to build its shop list. Assigning a
/// route to a salesperson happens from the Salesmen tab, not here.
class AdminRoutesScreen extends StatefulWidget {
  const AdminRoutesScreen({super.key});

  @override
  State<AdminRoutesScreen> createState() => _AdminRoutesScreenState();
}

class _AdminRoutesScreenState extends State<AdminRoutesScreen> {
  final _routeService = AdminRouteService();
  late Future<List<SalesRoute>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _routesFuture = _routeService.getAllRoutes();
    });
  }

  Future<void> _createRoute() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Route'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Route name',
            hintText: 'e.g. Fort, Mumbai',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;

    try {
      final route = await _routeService.createRoute(name);
      _refresh();
      if (mounted) {
        // Jump straight into it so the admin can start adding shops.
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminRouteDetailScreen(route: route)),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Routes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoute,
        icon: const Icon(Icons.add),
        label: const Text('New Route'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<SalesRoute>>(
          future: _routesFuture,
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
            final routes = snapshot.data ?? [];
            if (routes.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No routes yet. Tap "New Route" to create one and add its shops — '
                        'you can then assign it to any salesman from the Salesmen tab.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.route_outlined)),
                    title: Text(route.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdminRouteDetailScreen(route: route)),
                      );
                      _refresh();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
