import 'package:flutter/material.dart';
import '../models/outlet.dart';
import '../services/outlet_service.dart';
import 'outlet_detail_screen.dart';

/// A simple "pick a dealer" list used by the Home dashboard's "Place Order"
/// quick action. Tapping a dealer opens the same OutletDetailScreen used
/// everywhere else in the app, where Place Order/Follow-up/No Order live.
class OutletPickerScreen extends StatefulWidget {
  const OutletPickerScreen({super.key});

  @override
  State<OutletPickerScreen> createState() => _OutletPickerScreenState();
}

class _OutletPickerScreenState extends State<OutletPickerScreen> {
  final _outletService = OutletService();
  late Future<List<Outlet>> _outletsFuture;

  @override
  void initState() {
    super.initState();
    _outletsFuture = _outletService.getMyOutlets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Dealer to Place Order')),
      body: FutureBuilder<List<Outlet>>(
        future: _outletsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final outlets = snapshot.data ?? [];
          if (outlets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No dealers assigned yet. Add one first from the Visits tab.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: outlets.length,
            itemBuilder: (context, index) {
              final outlet = outlets[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(outlet.name),
                  subtitle: outlet.address != null ? Text(outlet.address!) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OutletDetailScreen(outlet: outlet)),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
