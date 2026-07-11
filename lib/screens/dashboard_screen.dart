import 'package:flutter/material.dart';
import '../models/outlet.dart';
import '../services/outlet_service.dart';
import 'outlet_detail_screen.dart';
import 'add_outlet_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _outletService = OutletService();
  final _searchController = TextEditingController();

  late Future<List<Outlet>> _outletsFuture;
  List<Outlet> _allOutlets = [];
  List<Outlet> _filteredOutlets = [];

  @override
  void initState() {
    super.initState();
    _outletsFuture = _loadOutlets();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Outlet>> _loadOutlets() async {
    final outlets = await _outletService.getMyOutlets();
    _allOutlets = outlets;
    _applyFilter();
    return outlets;
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredOutlets = query.isEmpty
          ? _allOutlets
          : _allOutlets.where((o) {
              return o.name.toLowerCase().contains(query) ||
                  (o.address ?? '').toLowerCase().contains(query);
            }).toList();
    });
  }

  void _refresh() {
    setState(() {
      _outletsFuture = _loadOutlets();
    });
  }

  Future<void> _addNewShop() async {
    final newOutlet = await Navigator.push<Outlet>(
      context,
      MaterialPageRoute(builder: (_) => const AddOutletScreen()),
    );
    if (newOutlet == null) return;
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newOutlet.name} added to your outlets')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dealers'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewShop,
        icon: const Icon(Icons.add_business),
        label: const Text('Add New Shop'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search shop by name or area...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<List<Outlet>>(
                future: _outletsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final outlets = _filteredOutlets;
                  if (_allOutlets.isEmpty) {
                    return ListView(
                      // ListView (not Center) so pull-to-refresh still works
                      // when the list is empty.
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'No outlets yet.\nTap "Add New Shop" to get started.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }
                  if (outlets.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No shops match your search.')),
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
                          leading: const CircleAvatar(child: Icon(Icons.store)),
                          title: Text(outlet.name),
                          subtitle: Text(outlet.address ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OutletDetailScreen(outlet: outlet),
                              ),
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
          ),
        ],
      ),
    );
  }
}
