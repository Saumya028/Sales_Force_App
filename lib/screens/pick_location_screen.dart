import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const _kBlue = Color(0xFF3366FF);

/// Full-screen map with a single draggable pin, used from the Add
/// Dealer screen so a salesperson can fine-tune the auto-captured GPS
/// location to the shop's actual spot on the map (e.g. when GPS
/// accuracy is poor indoors).
class PickLocationScreen extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;

  const PickLocationScreen({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
  });

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  late LatLng _picked;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _picked = LatLng(widget.initialLatitude, widget.initialLongitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Shop Location'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _picked, zoom: 17),
            onMapCreated: (c) => _mapController = c,
            onTap: (latLng) => setState(() => _picked = latLng),
            markers: {
              Marker(
                markerId: const MarkerId('picked'),
                position: _picked,
                draggable: true,
                onDragEnd: (latLng) => setState(() => _picked = latLng),
              ),
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tap or drag the pin to the shop\'s exact spot\n'
                        '${_picked.latitude.toStringAsFixed(5)}, '
                        '${_picked.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, _picked),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
