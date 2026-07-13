import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/outlet_service.dart';
import '../models/outlet.dart';

const _kBlue = Color(0xFF3366FF);
const _kBg = Color(0xFFF3F4F8);
const _kLabel = Color(0xFF5B6472);

enum _BusinessType { retailer, wholesaler, distributor }

extension on _BusinessType {
  String get label => switch (this) {
        _BusinessType.retailer => 'Retailer',
        _BusinessType.wholesaler => 'Wholesaler',
        _BusinessType.distributor => 'Distributor',
      };
  String get value => switch (this) {
        _BusinessType.retailer => 'retailer',
        _BusinessType.wholesaler => 'wholesaler',
        _BusinessType.distributor => 'distributor',
      };
}

enum _LocationStatus { capturing, success, failed }

/// Lets a salesperson add a shop they've visited that isn't in the
/// system yet. On success, pops back with the newly created Outlet so
/// the caller can navigate straight into it (e.g. to place an order).
class AddOutletScreen extends StatefulWidget {
  const AddOutletScreen({super.key});

  @override
  State<AddOutletScreen> createState() => _AddOutletScreenState();
}

class _AddOutletScreenState extends State<AddOutletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _outletService = OutletService();
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _mobileController = TextEditingController();
  final _gstController = TextEditingController();
  final _addressController = TextEditingController();

  _BusinessType _businessType = _BusinessType.retailer;

  XFile? _shopFrontImage;
  XFile? _businessCardImage;

  _LocationStatus _locationStatus = _LocationStatus.capturing;
  Position? _position;

  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _mobileController.dispose();
    _gstController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _locationStatus = _LocationStatus.capturing);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services disabled');
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationStatus = _LocationStatus.success;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.failed);
    }
  }

  Future<void> _pickPhoto(bool isShopFront) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _kBlue),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _kBlue),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      if (isShopFront) {
        _shopFrontImage = file;
      } else {
        _businessCardImage = file;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      String? shopFrontUrl;
      String? businessCardUrl;
      if (_shopFrontImage != null) {
        final bytes = await _shopFrontImage!.readAsBytes();
        shopFrontUrl = await _outletService.uploadDealerPhoto(
          bytes: bytes,
          fileName: 'shop_front_${_shopFrontImage!.name}',
        );
      }
      if (_businessCardImage != null) {
        final bytes = await _businessCardImage!.readAsBytes();
        businessCardUrl = await _outletService.uploadDealerPhoto(
          bytes: bytes,
          fileName: 'business_card_${_businessCardImage!.name}',
        );
      }

      final outlet = await _outletService.createOutlet(
        name: _nameController.text,
        ownerName: _ownerController.text,
        mobileNumber: _mobileController.text.isEmpty
            ? null
            : '+91${_mobileController.text.trim()}',
        gstNumber: _gstController.text,
        address: _addressController.text,
        businessType: _businessType.value,
        shopFrontPhotoUrl: shopFrontUrl,
        businessCardPhotoUrl: businessCardUrl,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
      );
      if (mounted) Navigator.pop(context, outlet);
    } catch (e) {
      setState(() {
        _errorText = 'Could not save dealer: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isSaving,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _FieldLabel('DEALER NAME'),
                      _PillField(
                        controller: _nameController,
                        hint: 'Enter shop name',
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Shop name is required'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel('OWNER NAME'),
                      _PillField(
                        controller: _ownerController,
                        hint: 'Full name',
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel('MOBILE NUMBER'),
                      _PillField(
                        controller: _mobileController,
                        hint: '00000 00000',
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        prefixText: '+91 ',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final digits = v.trim();
                          if (digits.length != 10) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel('GST NUMBER'),
                      _PillField(
                        controller: _gstController,
                        hint: '22AAAAA0000A1Z5',
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 15,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (v.trim().length != 15) {
                            return 'GST number must be 15 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel('ADDRESS'),
                      _PillField(
                        controller: _addressController,
                        hint: 'Street, Area, City',
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel('BUSINESS TYPE'),
                      _buildBusinessTypeSelector(),
                      const SizedBox(height: 18),
                      _FieldLabel('PHOTOS'),
                      _buildPhotoPickers(),
                      const SizedBox(height: 16),
                      _buildGpsCard(),
                      if (_errorText != null) ...[
                        const SizedBox(height: 16),
                        Text(_errorText!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 28),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
          const SizedBox(width: 4),
          const Text(
            'Add New Dealer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTypeSelector() {
    return Row(
      children: _BusinessType.values.map((type) {
        final selected = type == _businessType;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type == _BusinessType.values.last ? 0 : 8,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _businessType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _kBlue : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  type.label,
                  style: TextStyle(
                    color: selected ? Colors.white : _kBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotoPickers() {
    return Row(
      children: [
        Expanded(
          child: _PhotoPicker(
            label: 'Shop Front',
            image: _shopFrontImage,
            onTap: () => _pickPhoto(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PhotoPicker(
            label: 'Business Card',
            image: _businessCardImage,
            onTap: () => _pickPhoto(false),
          ),
        ),
      ],
    );
  }

  Widget _buildGpsCard() {
    final Color dotColor = switch (_locationStatus) {
      _LocationStatus.success => const Color(0xFF2ECC71),
      _LocationStatus.failed => const Color(0xFFE74C3C),
      _LocationStatus.capturing => Colors.orange,
    };

    String subtitle;
    if (_locationStatus == _LocationStatus.capturing) {
      subtitle = 'Capturing location...';
    } else if (_locationStatus == _LocationStatus.success && _position != null) {
      final lat = _position!.latitude;
      final lng = _position!.longitude;
      final ns = lat >= 0 ? 'N' : 'S';
      final ew = lng >= 0 ? 'E' : 'W';
      subtitle =
          '${lat.abs().toStringAsFixed(4)}° $ns, ${lng.abs().toStringAsFixed(4)}° $ew · Auto-captured';
    } else {
      subtitle = 'Location unavailable · Tap to retry';
    }

    return GestureDetector(
      onTap: _locationStatus == _LocationStatus.failed ? _captureLocation : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE9EEFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: _kBlue, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GPS Coordinates',
                    style: TextStyle(
                      color: _kBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _kLabel, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (_locationStatus == _LocationStatus.capturing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kBlue.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Save Dealer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: _kLabel,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _PillField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? maxLength;
  final String? prefixText;
  final String? Function(String?)? validator;

  const _PillField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.maxLength,
    this.prefixText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefixText,
          prefixStyle: const TextStyle(fontSize: 15, color: Colors.black87),
          hintStyle: const TextStyle(color: Color(0xFFB4B9C4)),
          filled: true,
          fillColor: Colors.white,
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final String label;
  final XFile? image;
  final VoidCallback onTap;

  const _PhotoPicker({
    required this.label,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: image != null ? _kBlue : const Color(0xFFC7CCD6),
              radius: 16,
            ),
            child: Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: image == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined,
                            color: _kLabel, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: const TextStyle(color: _kLabel, fontSize: 12.5),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        FutureBuilder<Uint8List>(
                          future: image!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            }
                            return Image.memory(snapshot.data!, fit: BoxFit.cover);
                          },
                        ),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight dashed rounded-rect border, avoiding a third-party
/// dependency just for the "empty photo slot" look in the mockup.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
