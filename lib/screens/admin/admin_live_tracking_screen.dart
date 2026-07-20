import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/salesman_tracking_status.dart';
import '../../services/admin_tracking_service.dart';
import 'admin_salesman_track_detail_screen.dart';
import 'admin_all_tracking_map_screen.dart';

const _kBlue = Color(0xFF3D6BFF);

/// Admin "Live Tracking" — every salesman's current status, today's
/// visit progress, and last known position, refreshed on demand (see
/// AdminTrackingService.getLiveStatuses). Tap a card for the full
/// map + GPS trail (AdminSalesmanTrackDetailScreen).
class AdminLiveTrackingScreen extends StatefulWidget {
  const AdminLiveTrackingScreen({super.key});

  @override
  State<AdminLiveTrackingScreen> createState() => _AdminLiveTrackingScreenState();
}

class _AdminLiveTrackingScreenState extends State<AdminLiveTrackingScreen> {
  final _service = AdminTrackingService();
  late Future<List<SalesmanTrackingStatus>> _future;
  Timer? _autoRefresh;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _service.getLiveStatuses();
    // Keeps the list reasonably fresh without the admin having to pull
    // to refresh constantly — matches "Live" in the header.
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _future = _service.getLiveStatuses());
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  void _refresh() => setState(() => _future = _service.getLiveStatuses());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: FutureBuilder<List<SalesmanTrackingStatus>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Column(
                children: [
                  _buildHeader(context, null),
                  const Expanded(child: Center(child: CircularProgressIndicator())),
                ],
              );
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  _buildHeader(context, null),
                  Expanded(child: Center(child: Text('Error: ${snapshot.error}'))),
                ],
              );
            }
            final all = snapshot.data ?? [];
            final filtered = _query.isEmpty
                ? all
                : all.where((s) => s.fullName.toLowerCase().contains(_query.toLowerCase())).toList();

            return Column(
              children: [
                _buildHeader(context, all),
                _buildStatsRow(all),
                _buildSearchBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('No salesmen match that search.')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => _TrackingCard(
                              status: filtered[index],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminSalesmanTrackDetailScreen(status: filtered[index]),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<SalesmanTrackingStatus>? all) {
    final activeCount = all?.where((s) => s.isOnShift).length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Tracking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (all != null)
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                      ),
                      Text(
                        'Live · ${all.length} salesmen',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.black54),
            style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder()),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: all == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AdminAllTrackingMapScreen(statuses: all)),
                    ),
            icon: const Icon(Icons.map_outlined, color: Colors.black54),
            style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<SalesmanTrackingStatus> all) {
    final active = all.where((s) => s.status == 'active').length;
    final late = all.where((s) => s.status == 'late').length;
    final absent = all.where((s) => s.status == 'absent').length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          _statCell('$active', 'Active', const Color(0xFF16A34A)),
          _divider(),
          _statCell('$late', 'Late', const Color(0xFFF59E0B)),
          _divider(),
          _statCell('$absent', 'Absent', const Color(0xFFDC2626)),
          _divider(),
          _statCell('${all.length}', 'Total', _kBlue),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: Colors.grey.shade200);

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search salesmen...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final SalesmanTrackingStatus status;
  final VoidCallback onTap;

  const _TrackingCard({required this.status, required this.onTap});

  _StatusMeta get _meta {
    switch (status.status) {
      case 'active':
        return _StatusMeta('ACTIVE', const Color(0xFF16A34A));
      case 'late':
        return _StatusMeta('LATE', const Color(0xFFF59E0B));
      case 'off_duty':
        return _StatusMeta('OFF DUTY', Colors.grey.shade600);
      default:
        return _StatusMeta('ABSENT', const Color(0xFFDC2626));
    }
  }

  String _timeAgo(DateTime from) {
    final diff = DateTime.now().difference(from);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  String get _activityLine {
    if (!status.isOnShift) {
      return status.attendance == null ? 'Not checked in yet' : 'Shift ended';
    }
    final ping = status.lastPing;
    if (ping == null) return 'Location unavailable';
    final freshEnough = DateTime.now().difference(ping.recordedAt) <= const Duration(minutes: 3);
    if (!freshEnough) return 'Last seen ${_timeAgo(ping.recordedAt)} (app in background)';
    if (ping.isStationary) return 'Stationary · updated ${_timeAgo(ping.recordedAt)}';
    return 'On the move · ${ping.speedKmh!.toStringAsFixed(0)} km/h';
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final initials = status.fullName.trim().isEmpty
        ? '?'
        : status.fullName.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE7EDFF),
                    child: Text(initials, style: const TextStyle(color: _kBlue, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(status.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          status.routeName ?? 'No route assigned',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: meta.color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(meta.label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: meta.color)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: status.isOnShift ? const Color(0xFF16A34A) : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_activityLine, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                    ),
                  ],
                ),
              ),
              if (status.attendance?.checkInTime != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Check In: ${DateFormat('hh:mm a').format(status.attendance!.checkInTime!.toLocal())}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
              if (status.isOnShift) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Visit Progress', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    const Spacer(),
                    Text(
                      '${status.visitsToday}/${status.totalDealersOnRoute} dealers · ${(status.visitProgress * 100).round()}%',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: status.visitProgress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(_kBlue),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 15, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('${status.ordersToday} orders', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(
                      '₹${status.revenueToday.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMeta {
  final String label;
  final Color color;
  _StatusMeta(this.label, this.color);
}
