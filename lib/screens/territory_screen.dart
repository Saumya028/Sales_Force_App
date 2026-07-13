import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/beat_plan.dart';
import '../models/outlet.dart';
import '../models/sales_order.dart';
import '../services/beat_plan_service.dart';
import '../services/order_service.dart';
import 'outlet_detail_screen.dart';

const _kBlue = Color(0xFF3366FF);
const _kGreen = Color(0xFF2ECC71);
const _kOrange = Color(0xFFF5A623);
const _kBg = Color(0xFFF3F4F8);

enum _Filter { all, nearby, pending, visited, notVisited }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All',
        _Filter.nearby => 'Nearby',
        _Filter.pending => 'Pending',
        _Filter.visited => 'Visited',
        _Filter.notVisited => 'Not Visited',
      };
}

class _StopData {
  final Outlet outlet;
  final SalesOrder? order;
  final double? distanceKm;
  bool get visited => order != null;
  _StopData({required this.outlet, required this.order, required this.distanceKm});
}

class _RouteData {
  final BeatPlan? plan;
  final List<_StopData> stops;
  final Position? myPosition;
  _RouteData({required this.plan, required this.stops, required this.myPosition});
}

/// "Territory" — a live Google Map of the shops on the salesperson's
/// route for today (as attached by an Admin via "Assign Route"), plotted
/// relative to the salesperson's current GPS location, with status
/// filters and a distance-sorted list underneath. Opened from the
/// "View Route" quick action on the Home dashboard.
class TerritoryScreen extends StatefulWidget {
  const TerritoryScreen({super.key});

  @override
  State<TerritoryScreen> createState() => _TerritoryScreenState();
}

class _TerritoryScreenState extends State<TerritoryScreen> {
  final _beatPlanService = BeatPlanService();
  final _orderService = OrderService();
  final _filterScrollController = ScrollController();

  GoogleMapController? _mapController;
  late Future<_RouteData> _future;
  _Filter _filter = _Filter.all;
  bool _boundsFitted = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _filterScrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<Position?> _getMyPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }

  Future<_RouteData> _load() async {
    final plan = await _beatPlanService.getTodayPlan();
    final myPosition = await _getMyPosition();

    if (plan == null) {
      return _RouteData(plan: null, stops: [], myPosition: myPosition);
    }

    final results = await Future.wait([
      _beatPlanService.getRouteOutlets(plan.id),
      _orderService.getTodayOrders(),
    ]);
    final outlets = results[0] as List<Outlet>;
    final todayOrders = results[1] as List<SalesOrder>;

    final latestOrderByOutlet = <String, SalesOrder>{};
    for (final order in todayOrders) {
      latestOrderByOutlet.putIfAbsent(order.outletId, () => order);
    }

    final stops = outlets.map((outlet) {
      double? distanceKm;
      if (myPosition != null && outlet.latitude != null && outlet.longitude != null) {
        final meters = Geolocator.distanceBetween(
          myPosition.latitude,
          myPosition.longitude,
          outlet.latitude!,
          outlet.longitude!,
        );
        distanceKm = meters / 1000;
      }
      return _StopData(
        outlet: outlet,
        order: latestOrderByOutlet[outlet.id],
        distanceKm: distanceKm,
      );
    }).toList();

    stops.sort((a, b) {
      if (a.distanceKm == null && b.distanceKm == null) return 0;
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });

    return _RouteData(plan: plan, stops: stops, myPosition: myPosition);
  }

  void _refresh() {
    setState(() {
      _boundsFitted = false;
      _future = _load();
    });
  }

  List<_StopData> _applyFilter(List<_StopData> stops) {
    switch (_filter) {
      case _Filter.all:
        return stops;
      case _Filter.nearby:
        return stops.where((s) => s.distanceKm != null && s.distanceKm! <= 2).toList();
      case _Filter.pending:
      case _Filter.notVisited:
        return stops.where((s) => !s.visited).toList();
      case _Filter.visited:
        return stops.where((s) => s.visited).toList();
    }
  }

  void _fitBounds(_RouteData data) {
    final controller = _mapController;
    if (controller == null) return;

    final points = <LatLng>[];
    if (data.myPosition != null) {
      points.add(LatLng(data.myPosition!.latitude, data.myPosition!.longitude));
    }
    for (final s in data.stops) {
      if (s.outlet.latitude != null && s.outlet.longitude != null) {
        points.add(LatLng(s.outlet.latitude!, s.outlet.longitude!));
      }
    }
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 14));
      return;
    }

    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  void _showLegend() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Map Legend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _legendRow(_kBlue, Icons.my_location, 'Your current location'),
              const SizedBox(height: 12),
              _legendRow(_kGreen, Icons.storefront, 'Visited today'),
              const SizedBox(height: 12),
              _legendRow(_kOrange, Icons.storefront, 'Pending / not visited'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendRow(Color color, IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  void _openOutletCard(_StopData stop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(stop.outlet.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  _StatusPill(visited: stop.visited),
                ],
              ),
              const SizedBox(height: 6),
              if (stop.outlet.address != null && stop.outlet.address!.isNotEmpty)
                Text(stop.outlet.address!, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(
                stop.distanceKm != null
                    ? '${stop.distanceKm!.toStringAsFixed(1)} km away'
                    : 'Distance unavailable',
                style: const TextStyle(color: _kBlue, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OutletDetailScreen(outlet: stop.outlet)),
                    ).then((_) => _refresh());
                  },
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BitmapDescriptor _markerIcon(bool visited) => BitmapDescriptor.defaultMarkerWithHue(
        visited ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: FutureBuilder<_RouteData>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final data = snapshot.data;
            final visibleStops = data != null ? _applyFilter(data.stops) : <_StopData>[];

            if (!loading && data != null && !_boundsFitted && data.stops.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _fitBounds(data);
                  setState(() => _boundsFitted = true);
                }
              });
            }

            return Column(
              children: [
                _buildHeader(),
                if (!loading && data?.plan != null) ...[
                  _buildFilterRow(),
                  const SizedBox(height: 10),
                ],
                if (loading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (snapshot.hasError)
                  Expanded(child: Center(child: Text('Error: ${snapshot.error}')))
                else if (data?.plan == null)
                  Expanded(child: _buildNoRouteState())
                else ...[
                  _buildMap(data!),
                  const SizedBox(height: 12),
                  Expanded(
                    child: visibleStops.isEmpty
                        ? const Center(child: Text('No dealers in this filter.'))
                        : RefreshIndicator(
                            onRefresh: () async => _refresh(),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: visibleStops.length,
                              itemBuilder: (context, index) {
                                final stop = visibleStops[index];
                                return _StopTile(
                                  stop: stop,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => OutletDetailScreen(outlet: stop.outlet),
                                      ),
                                    );
                                    _refresh();
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoRouteState() {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.map_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No route assigned for today',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask your manager to assign today\'s route and shops from the Admin dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
          const Text(
            'Territory',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const Spacer(),
          _RoundIconButton(
            icon: Icons.center_focus_strong,
            filled: true,
            onTap: () async {
              final data = await _future;
              _fitBounds(data);
            },
          ),
          const SizedBox(width: 10),
          _RoundIconButton(icon: Icons.menu, filled: false, onTap: _showLegend),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left, color: Colors.grey),
            onPressed: () => _filterScrollController.animateTo(
              (_filterScrollController.offset - 120)
                  .clamp(0, _filterScrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            ),
          ),
          Expanded(
            child: ListView(
              controller: _filterScrollController,
              scrollDirection: Axis.horizontal,
              children: _Filter.values.map((f) {
                final selected = f == _filter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(f.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: _kBlue,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: selected ? _kBlue : Colors.grey.shade300),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right, color: Colors.grey),
            onPressed: () => _filterScrollController.animateTo(
              (_filterScrollController.offset + 120)
                  .clamp(0, _filterScrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMap(_RouteData data) {
    final markers = <Marker>{};
    for (final stop in data.stops) {
      final o = stop.outlet;
      if (o.latitude == null || o.longitude == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId(o.id),
          position: LatLng(o.latitude!, o.longitude!),
          icon: _markerIcon(stop.visited),
          infoWindow: InfoWindow(
            title: o.name,
            snippet: stop.distanceKm != null
                ? '${stop.distanceKm!.toStringAsFixed(1)} km · ${stop.visited ? 'Visited' : 'Pending'}'
                : stop.visited
                    ? 'Visited'
                    : 'Pending',
            onTap: () => _openOutletCard(stop),
          ),
          onTap: () => _openOutletCard(stop),
        ),
      );
    }

    final initialTarget = data.myPosition != null
        ? LatLng(data.myPosition!.latitude, data.myPosition!.longitude)
        : (markers.isNotEmpty ? markers.first.position : const LatLng(20.5937, 78.9629));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 260,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: data.myPosition != null ? 13 : 4,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_boundsFitted) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds(data));
              }
            },
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: filled ? _kBlue : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: filled ? Colors.white : Colors.black87, size: 20),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool visited;
  const _StatusPill({required this.visited});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: visited ? _kGreen.withOpacity(0.12) : _kOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        visited ? 'VISITED' : 'PENDING',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: visited ? const Color(0xFF1E9E56) : const Color(0xFFB9770E),
        ),
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final _StopData stop;
  final VoidCallback onTap;
  const _StopTile({required this.stop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: stop.visited ? _kGreen : _kOrange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.outlet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stop.distanceKm != null
                            ? '${stop.distanceKm!.toStringAsFixed(1)} km'
                            : 'Distance unknown',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                _StatusPill(visited: stop.visited),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
