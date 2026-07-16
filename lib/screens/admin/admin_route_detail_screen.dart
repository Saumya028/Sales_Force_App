import 'package:flutter/material.dart';
import '../../models/outlet.dart';
import '../../models/sales_route.dart';
import '../../services/admin_route_service.dart';

/// Manage one route's shop list: shops already on it (with a way to take
/// them off), and unrouted shops available to add. Creating brand-new
/// shops still happens via a salesperson's "Add New Shop" screen in the
/// field, or the Supabase table editor for bulk setup — this screen is
/// for organizing shops that already exist into routes.
class AdminRouteDetailScreen extends StatefulWidget {
  final SalesRoute route;
  const AdminRouteDetailScreen({super.key, required this.route});

  @override
  State<AdminRouteDetailScreen> createState() => _AdminRouteDetailScreenState();
}

class _AdminRouteDetailScreenState extends State<AdminRouteDetailScreen> {
  final _routeService = AdminRouteService();
  late Future<List<Outlet>> _onRouteFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _onRouteFuture = _routeService.getOutletsForRoute(widget.route.id);
    });
  }

  Future<void> _removeFromRoute(Outlet outlet) async {
    setState(() => _isBusy = true);
    try {
      await _routeService.setOutletRoute(outlet.id, null);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _addShops() async {
    List<Outlet> unrouted;
    try {
      unrouted = await _routeService.getUnroutedOutlets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load shops: $e')));
      }
      return;
    }

    if (!mounted) return;
    if (unrouted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unassigned shops left — every shop is already on a route.')),
      );
      return;
    }

    final selected = <String>{};
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Shops to Route'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Only unassigned shops are shown — a shop can only be on one route.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 320),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: unrouted.map((outlet) {
                          final checked = selected.contains(outlet.id);
                          return CheckboxListTile(
                            dense: true,
                            value: checked,
                            title: Text(outlet.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: outlet.address != null && outlet.address!.isNotEmpty
                                ? Text(outlet.address!, maxLines: 1, overflow: TextOverflow.ellipsis)
                                : null,
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  selected.add(outlet.id);
                                } else {
                                  selected.remove(outlet.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: selected.isEmpty ? null : () => Navigator.pop(context, true),
                  child: Text('Add ${selected.length} Shop${selected.length == 1 ? '' : 's'}'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || selected.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      for (final outletId in selected) {
        await _routeService.setOutletRoute(outletId, widget.route.id);
      }
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shops added to route.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteRoute() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this route?'),
        content: const Text(
          'Its shops will become unassigned (not deleted) and any salesman '
          'currently on this route will need to be reassigned.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _routeService.deleteRoute(widget.route.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Route',
            onPressed: _isBusy ? null : _deleteRoute,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : _addShops,
        icon: const Icon(Icons.add),
        label: const Text('Add Shops'),
      ),
      body: AbsorbPointer(
        absorbing: _isBusy,
        child: FutureBuilder<List<Outlet>>(
          future: _onRouteFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final outlets = snapshot.data ?? [];
            if (outlets.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No shops on this route yet. Tap "Add Shops" to pick from unassigned shops.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: outlets.length,
              itemBuilder: (context, index) {
                final outlet = outlets[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.store_outlined)),
                    title: Text(outlet.name),
                    subtitle: outlet.address != null && outlet.address!.isNotEmpty
                        ? Text(outlet.address!, maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      tooltip: 'Remove from route',
                      onPressed: () => _removeFromRoute(outlet),
                    ),
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
