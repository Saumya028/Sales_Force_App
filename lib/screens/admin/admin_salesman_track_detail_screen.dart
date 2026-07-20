import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/location_ping.dart';
import '../../models/salesman_tracking_status.dart';
import '../../models/visit_timeline_entry.dart';
import '../../services/admin_tracking_service.dart';

const _kBlue = Color(0xFF3D6BFF);

class AdminSalesmanTrackDetailScreen extends StatefulWidget {
  final SalesmanTrackingStatus status;

  const AdminSalesmanTrackDetailScreen({super.key, required this.status});

  @override
  State<AdminSalesmanTrackDetailScreen> createState() => _AdminSalesmanTrackDetailScreenState();
}

class _AdminSalesmanTrackDetailScreenState extends State<AdminSalesmanTrackDetailScreen> {
  final _service = AdminTrackingService();
  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final results = await Future.wait([
      _service.getTodayTrail(widget.status.salespersonId),
      _service.getTodayVisitTimeline(widget.status.salespersonId),
    ]);
    return _DetailData(
      trail: results[0] as List<LocationPing>,
      timeline: results[1] as List<VisitTimelineEntry>,
    );
  }

  String _timeAgo(DateTime from) {
    final diff = DateTime.now().difference(from);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: FutureBuilder<_DetailData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(context, status),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMap(status, data?.trail ?? []),
                      const SizedBox(height: 14),
                      _buildStatusCard(status),
                      const SizedBox(height: 14),
                      _buildQuickStats(status),
                      const SizedBox(height: 14),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        _buildTimeline(status, data?.timeline ?? []),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SalesmanTrackingStatus status) {
    final meta = _statusMeta(status.status);
    final initials = status.fullName.trim().isEmpty
        ? '?'
        : status.fullName.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.black87)),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE7EDFF),
            child: Text(initials, style: const TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(status.routeName ?? 'No route assigned', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: meta.color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(meta.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: meta.color)),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(SalesmanTrackingStatus status, List<LocationPing> trail) {
    final lastPing = status.lastPing;
    final center = lastPing != null
        ? LatLng(lastPing.latitude, lastPing.longitude)
        : (trail.isNotEmpty ? LatLng(trail.last.latitude, trail.last.longitude) : const LatLng(20.5937, 78.9629));

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: trail.isEmpty ? 4 : 15),
              markers: {
                if (lastPing != null)
                  Marker(
                    markerId: const MarkerId('current'),
                    position: LatLng(lastPing.latitude, lastPing.longitude),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                if (trail.isNotEmpty)
                  Marker(
                    markerId: const MarkerId('start'),
                    position: LatLng(trail.first.latitude, trail.first.longitude),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  ),
              },
              polylines: {
                if (trail.length > 1)
                  Polyline(
                    polylineId: const PolylineId('trail'),
                    points: trail.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                    color: _kBlue,
                    width: 4,
                  ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: true,
            ),
            if (lastPing != null)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'Updated ${_timeAgo(lastPing.recordedAt)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(SalesmanTrackingStatus status) {
    final lastPing = status.lastPing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: status.isOnShift ? const Color(0xFF16A34A) : Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  status.isOnShift
                      ? (lastPing != null ? (lastPing.isStationary ? 'Stationary' : 'On the move') : 'On shift')
                      : (status.attendance == null ? 'Not checked in yet' : 'Shift ended'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoCell(
                  'LOCATION',
                  lastPing != null ? '${lastPing.latitude.toStringAsFixed(4)}, ${lastPing.longitude.toStringAsFixed(4)}' : '—',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoCell(
                  'CHECK IN',
                  status.attendance?.checkInTime != null
                      ? DateFormat('hh:mm a').format(status.attendance!.checkInTime!.toLocal())
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _infoCell(
                  'SPEED',
                  lastPing?.speedKmh != null
                      ? (lastPing!.isStationary ? 'Stationary' : '${lastPing.speedKmh!.toStringAsFixed(0)} km/h')
                      : '—',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoCell('BATTERY', lastPing?.batteryLevel != null ? '${lastPing!.batteryLevel}%' : '—'),
              ),
            ],
          ),
          if (lastPing?.batteryLevel != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: lastPing!.batteryLevel! / 100,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  lastPing.batteryLevel! < 20 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, letterSpacing: 0.3)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickStats(SalesmanTrackingStatus status) {
    return Row(
      children: [
        Expanded(child: _statBox('${status.visitsToday}/${status.totalDealersOnRoute}', 'Visits', _kBlue)),
        const SizedBox(width: 10),
        Expanded(child: _statBox('${status.ordersToday}', 'Orders', const Color(0xFF16A34A))),
        const SizedBox(width: 10),
        Expanded(child: _statBox('₹${status.revenueToday.toStringAsFixed(0)}', 'Revenue', const Color(0xFF7C3AED))),
      ],
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildTimeline(SalesmanTrackingStatus status, List<VisitTimelineEntry> timeline) {
    final checkIn = status.attendance?.checkInTime;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's Trail", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          if (checkIn != null)
            _timelineRow(
              color: _kBlue,
              title: 'Shift Start',
              time: DateFormat('hh:mm a').format(checkIn.toLocal()),
              isFirst: true,
              isLast: timeline.isEmpty,
            ),
          for (var i = 0; i < timeline.length; i++)
            _timelineRow(
              color: timeline[i].outcome == 'order_placed' ? const Color(0xFF16A34A) : Colors.grey.shade400,
              title: timeline[i].outletName,
              time: DateFormat('hh:mm a').format(timeline[i].time),
              subtitle: timeline[i].orderAmount != null ? 'Order: ₹${timeline[i].orderAmount!.toStringAsFixed(0)}' : null,
              isFirst: checkIn == null && i == 0,
              isLast: i == timeline.length - 1,
            ),
          if (checkIn == null && timeline.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No activity recorded yet today.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _timelineRow({
    required Color color,
    required String title,
    required String time,
    String? subtitle,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey.shade200)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle != null ? '$time · $subtitle' : time,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitle != null ? const Color(0xFF16A34A) : Colors.grey.shade500,
                      fontWeight: subtitle != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusMeta _statusMeta(String status) {
    switch (status) {
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
}

class _DetailData {
  final List<LocationPing> trail;
  final List<VisitTimelineEntry> timeline;
  _DetailData({required this.trail, required this.timeline});
}

class _StatusMeta {
  final String label;
  final Color color;
  _StatusMeta(this.label, this.color);
}
