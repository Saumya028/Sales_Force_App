import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/profile.dart';
import '../../models/beat_plan.dart';
import '../../models/outlet.dart';
import '../../models/admin_leave_request.dart';
import '../../services/admin_user_service.dart';
import '../../services/admin_beat_plan_service.dart';
import '../../services/admin_leave_service.dart';
import 'add_salesman_screen.dart';

/// Admin's "Manage Salesmen" hub: two tabs —
///  1. Salesmen — add, deactivate/reactivate, assign a daily route
///  2. Leave Requests — approve/reject, newest first
class AdminSalesmenScreen extends StatefulWidget {
  const AdminSalesmenScreen({super.key});

  @override
  State<AdminSalesmenScreen> createState() => _AdminSalesmenScreenState();
}

class _AdminSalesmenScreenState extends State<AdminSalesmenScreen>
    with SingleTickerProviderStateMixin {
  final _userService = AdminUserService();
  final _beatPlanService = AdminBeatPlanService();
  final _leaveService = AdminLeaveService();

  late final TabController _tabController;

  late Future<List<Profile>> _salesmenFuture;
  late Future<Map<String, BeatPlan>> _todayPlansFuture;
  late Future<List<AdminLeaveRequest>> _leaveFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshSalesmen();
    _refreshLeave();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshSalesmen() {
    setState(() {
      _salesmenFuture = _userService.getAllSalesmen();
      _todayPlansFuture = _beatPlanService.getTodayPlansBySalesman();
    });
  }

  void _refreshLeave() {
    setState(() {
      _leaveFuture = _leaveService.getAllLeaveRequests();
    });
  }

  Future<void> _addSalesman() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddSalesmanScreen()),
    );
    if (created == true) {
      _refreshSalesmen();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salesman account created.')),
        );
      }
    }
  }

  Future<void> _toggleStatus(Profile profile) async {
    final deactivating = profile.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(deactivating ? 'Remove Salesman?' : 'Reactivate Salesman?'),
        content: Text(
          deactivating
              ? '${profile.fullName ?? 'This salesman'} will be signed out and won\'t be able to '
                  'log back in. Their past orders and history are kept.'
              : '${profile.fullName ?? 'This salesman'} will be able to log in again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: deactivating ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
            child: Text(deactivating ? 'Remove' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _userService.setSalesmanStatus(profile.id, deactivating ? 'inactive' : 'active');
      _refreshSalesmen();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deactivating ? 'Salesman removed.' : 'Salesman reactivated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _assignRoute(Profile profile, BeatPlan? existingPlan) async {
    final zoneController = TextEditingController(text: existingPlan?.zoneName ?? '');
    final coverageController = TextEditingController(
      text: existingPlan?.coverageKm != null ? existingPlan!.coverageKm!.toStringAsFixed(1) : '',
    );
    DateTime selectedDate = DateTime.now();

    // Fetch this salesman's dealers up front, plus which ones are
    // already on today's route (if we're editing an existing plan), so
    // the dialog can show a pre-checked shop list.
    List<Outlet> outlets;
    Set<String> selectedOutletIds;
    try {
      final results = await Future.wait([
        _beatPlanService.getSalesmanOutlets(profile.id),
        existingPlan != null
            ? _beatPlanService.getRouteOutletIds(existingPlan.id)
            : Future.value(<String>[]),
      ]);
      outlets = results[0] as List<Outlet>;
      selectedOutletIds = (results[1] as List<String>).toSet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load dealers: $e')));
      }
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Assign Route — ${profile.fullName ?? 'Salesman'}'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: zoneController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Zone / Area Name *',
                          hintText: 'e.g. South Delhi Zone-3',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: coverageController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Coverage (km)',
                          hintText: 'Optional',
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                          );
                          if (picked != null) setDialogState(() => selectedDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date'),
                          child: Text(DateFormat('d MMM yyyy').format(selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Shops on this route (${selectedOutletIds.length} selected)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Only checked shops will appear on this salesman\'s route map.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      if (outlets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'This salesman has no dealers assigned yet.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 260),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: outlets.map((outlet) {
                              final checked = selectedOutletIds.contains(outlet.id);
                              return CheckboxListTile(
                                dense: true,
                                value: checked,
                                title: Text(outlet.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: outlet.address != null && outlet.address!.isNotEmpty
                                    ? Text(outlet.address!, maxLines: 1, overflow: TextOverflow.ellipsis)
                                    : (outlet.latitude == null
                                        ? const Text('No GPS location saved', style: TextStyle(color: Colors.orange))
                                        : null),
                                onChanged: (v) {
                                  setDialogState(() {
                                    if (v == true) {
                                      selectedOutletIds.add(outlet.id);
                                    } else {
                                      selectedOutletIds.remove(outlet.id);
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
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    if (zoneController.text.trim().isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final coverage = double.tryParse(coverageController.text.trim());
    try {
      final beatPlanId = await _beatPlanService.assignRoute(
        salespersonId: profile.id,
        zoneName: zoneController.text,
        coverageKm: coverage,
        date: selectedDate,
      );
      await _beatPlanService.setRouteOutlets(
        beatPlanId: beatPlanId,
        outletIds: selectedOutletIds.toList(),
      );
      _refreshSalesmen();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route assigned.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _approveLeave(AdminLeaveRequest request) async {
    try {
      await _leaveService.approveLeave(request.id);
      _refreshLeave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave approved.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _rejectLeave(AdminLeaveRequest request) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _leaveService.rejectLeave(request.id, reason: reasonController.text);
      _refreshLeave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave rejected.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Salesmen'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Salesmen'), Tab(text: 'Leave Requests')],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _addSalesman,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Salesman'),
          );
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSalesmenTab(), _buildLeaveTab()],
      ),
    );
  }

  Widget _buildSalesmenTab() {
    return RefreshIndicator(
      onRefresh: () async => _refreshSalesmen(),
      child: FutureBuilder<List<Profile>>(
        future: _salesmenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final salesmen = snapshot.data ?? [];
          if (salesmen.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No salesmen yet. Tap "Add Salesman" to create one.')),
              ],
            );
          }
          return FutureBuilder<Map<String, BeatPlan>>(
            future: _todayPlansFuture,
            builder: (context, planSnapshot) {
              final plans = planSnapshot.data ?? {};
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: salesmen.length,
                itemBuilder: (context, index) {
                  final profile = salesmen[index];
                  final plan = plans[profile.id];
                  return _SalesmanCard(
                    profile: profile,
                    todayPlan: plan,
                    onAssignRoute: () => _assignRoute(profile, plan),
                    onToggleStatus: () => _toggleStatus(profile),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeaveTab() {
    return RefreshIndicator(
      onRefresh: () async => _refreshLeave(),
      child: FutureBuilder<List<AdminLeaveRequest>>(
        future: _leaveFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No leave requests yet.')),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _LeaveRequestCard(
                request: request,
                onApprove: request.status == 'pending' ? () => _approveLeave(request) : null,
                onReject: request.status == 'pending' ? () => _rejectLeave(request) : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _SalesmanCard extends StatelessWidget {
  final Profile profile;
  final BeatPlan? todayPlan;
  final VoidCallback onAssignRoute;
  final VoidCallback onToggleStatus;

  const _SalesmanCard({
    required this.profile,
    required this.todayPlan,
    required this.onAssignRoute,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final active = profile.isActive;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: active ? const Color(0xFFE7EDFF) : Colors.grey.shade200,
                  child: Icon(Icons.person, color: active ? const Color(0xFF3D6BFF) : Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName ?? 'Unnamed Salesman',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        todayPlan != null
                            ? 'Today: ${todayPlan!.zoneName}'
                            : 'No route assigned today',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: active ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    active ? 'ACTIVE' : 'REMOVED',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: active ? onAssignRoute : null,
                  icon: const Icon(Icons.route_outlined, size: 18),
                  label: const Text('Assign Route'),
                ),
                TextButton.icon(
                  onPressed: onToggleStatus,
                  icon: Icon(active ? Icons.person_remove_outlined : Icons.person_add_alt_1_outlined, size: 18),
                  label: Text(active ? 'Remove' : 'Reactivate'),
                  style: TextButton.styleFrom(foregroundColor: active ? Colors.red : Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveRequestCard extends StatelessWidget {
  final AdminLeaveRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _LeaveRequestCard({required this.request, this.onApprove, this.onReject});

  Color _statusColor() {
    switch (request.status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sameDay = request.startDate.year == request.endDate.year &&
        request.startDate.month == request.endDate.month &&
        request.startDate.day == request.endDate.day;
    final dateLabel = sameDay
        ? DateFormat('d MMM yyyy').format(request.startDate)
        : '${DateFormat('d MMM').format(request.startDate)} – ${DateFormat('d MMM yyyy').format(request.endDate)}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(request.salespersonName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _statusColor()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${request.typeLabel} · $dateLabel (${request.dayCount} day${request.dayCount > 1 ? 's' : ''})',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            if (request.reason != null && request.reason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(request.reason!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
            ],
            if (request.adminRemarks != null && request.adminRemarks!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Admin note: ${request.adminRemarks}',
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: onApprove, child: const Text('Approve')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
