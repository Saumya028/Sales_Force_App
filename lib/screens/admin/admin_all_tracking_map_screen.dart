import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/salesman_tracking_status.dart';
import 'admin_salesman_track_detail_screen.dart';

const _kBlue = Color(0xFF3D6BFF);

/// Every on-shift salesman's last known position, all on one map —
/// opened from the map icon on the Live Tracking list header.
class AdminAllTrackingMapScreen extends StatelessWidget {
  final List<SalesmanTrackingStatus> statuses;

  const AdminAllTrackingMapScreen({super.key, required this.statuses});

  @override
  Widget build(BuildContext context) {
    final withLocation = statuses.where((s) => s.lastPing != null).toList();
    final center = withLocation.isNotEmpty
        ? LatLng(withLocation.first.lastPing!.latitude, withLocation.first.lastPing!.longitude)
        : const LatLng(20.5937, 78.9629); // India-wide fallback when nobody has a live position yet

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Salesmen'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: withLocation.isEmpty
          ? const Center(child: Text('No live positions yet — check back once salesmen are on shift.'))
          : GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: withLocation.length == 1 ? 15 : 11),
              markers: withLocation.map((s) {
                final ping = s.lastPing!;
                return Marker(
                  markerId: MarkerId(s.salespersonId),
                  position: LatLng(ping.latitude, ping.longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    s.status == 'active'
                        ? BitmapDescriptor.hueGreen
                        : s.status == 'late'
                            ? BitmapDescriptor.hueOrange
                            : BitmapDescriptor.hueAzure,
                  ),
                  infoWindow: InfoWindow(
                    title: s.fullName,
                    snippet: ping.isStationary ? 'Stationary' : '${ping.speedKmh?.toStringAsFixed(0) ?? '—'} km/h',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AdminSalesmanTrackDetailScreen(status: s)),
                    ),
                  ),
                );
              }).toSet(),
              zoomControlsEnabled: false,
            ),
    );
  }
}
