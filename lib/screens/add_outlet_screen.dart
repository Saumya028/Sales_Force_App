import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/outlet_service.dart';
import '../models/outlet.dart';
import 'pick_location_screen.dart';

const _kBlue = Color(0xFF3366FF);
const _kBg = Color(0xFFF3F4F8);
const _kLabel = Color(0xFF5B6472);

const List<String> _kDealerCategories = [
  'General Store',
  'Stationery',
  'Medical Store',
  'Grocery / Kirana',
  'Electronics',
  'Hardware',
  'Bakery',
  'Cosmetics',
  'Other',
];

const List<String> _kWeekDays = [
  'None',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

enum _LocationStatus { capturing, success, failed }

/// Which of the fixed photo slots a picker call is for; `extra` appends
/// to the open-ended list instead of filling a single named slot.
enum _PhotoSlot { shopFront, businessCard, owner, extra }

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
  final _mobileController = TextEditingController();
  final _gstController = TextEditingController();
  final _addressController = TextEditingController();

  // Owner name(s) — at least one field, salesperson can add more.
  final List<TextEditingController> _ownerControllers = [TextEditingController()];

  // Manager / accountant.
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();

  // Office contact.
  final _officeTelController = TextEditingController();
  final _officeEmailController = TextEditingController();
  final _websiteController = TextEditingController();

  // Dealer category.
  String _dealerCategory = _kDealerCategories.first;
  final _customCategoryController = TextEditingController();

  // Working hours / weekly off.
  TimeOfDay? _workingHoursFrom;
  TimeOfDay? _workingHoursTo;
  String _weeklyOff = _kWeekDays.first;

  // Fixed photo slots.
  XFile? _shopFrontImage;
  XFile? _businessCardImage;
  XFile? _ownerImage;
  // Open-ended extra photos (interior, signage, stock, etc.).
  final List<XFile> _extraImages = [];

  _LocationStatus _locationStatus = _LocationStatus.capturing;
  Position? _position;
  // Set when the salesperson manually adjusts the pin on the map;
  // overrides the auto-captured GPS position on save.
  LatLng? _manualLatLng;

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
    _mobileController.dispose();
    _gstController.dispose();
    _addressController.dispose();
    for (final c in _ownerControllers) {
      c.dispose();
    }
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _officeTelController.dispose();
    _officeEmailController.dispose();
    _websiteController.dispose();
    _customCategoryController.dispose();
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
        _manualLatLng = null;
        _locationStatus = _LocationStatus.success;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.failed);
    }
  }

  double? get _latitude => _manualLatLng?.latitude ?? _position?.latitude;
  double? get _longitude => _manualLatLng?.longitude ?? _position?.longitude;

  Future<void> _adjustOnMap() async {
    final startLat = _latitude ?? 20.5937; // Falls back to India's centroid
    final startLng = _longitude ?? 78.9629;
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          initialLatitude: startLat,
          initialLongitude: startLng,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _manualLatLng = result;
      _locationStatus = _LocationStatus.success;
    });
  }

  Future<void> _pickPhoto(_PhotoSlot slot) async {
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
      switch (slot) {
        case _PhotoSlot.shopFront:
          _shopFrontImage = file;
          break;
        case _PhotoSlot.businessCard:
          _businessCardImage = file;
          break;
        case _PhotoSlot.owner:
          _ownerImage = file;
          break;
        case _PhotoSlot.extra:
          _extraImages.add(file);
          break;
      }
    });
  }

  void _addOwnerField() {
    setState(() => _ownerControllers.add(TextEditingController()));
  }

  void _removeOwnerField(int index) {
    setState(() {
      _ownerControllers[index].dispose();
      _ownerControllers.removeAt(index);
    });
  }

  Future<void> _pickWorkingHour(bool isFrom) async {
    final initial = (isFrom ? _workingHoursFrom : _workingHoursTo) ??
        const TimeOfDay(hour: 10, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _workingHoursFrom = picked;
      } else {
        _workingHoursTo = picked;
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
      Future<String?> upload(XFile? file, String prefix) async {
        if (file == null) return null;
        final bytes = await file.readAsBytes();
        return _outletService.uploadDealerPhoto(
          bytes: bytes,
          fileName: '${prefix}_${file.name}',
        );
      }

      final shopFrontUrl = await upload(_shopFrontImage, 'shop_front');
      final businessCardUrl = await upload(_businessCardImage, 'business_card');
      final ownerPhotoUrl = await upload(_ownerImage, 'owner');

      final extraUrls = <String>[];
      for (final img in _extraImages) {
        final url = await upload(img, 'extra');
        if (url != null) extraUrls.add(url);
      }

      final ownerNames = _ownerControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final category = _dealerCategory == 'Other'
          ? _customCategoryController.text.trim()
          : _dealerCategory;

      final outlet = await _outletService.createOutlet(
        name: _nameController.text,
        ownerNames: ownerNames,
        mobileNumber: _mobileController.text.isEmpty
            ? null
            : '+91${_mobileController.text.trim()}',
        gstNumber: _gstController.text,
        address: _addressController.text,
        dealerCategory: category.isEmpty ? null : category,
        managerName: _managerNameController.text,
        managerPhone: _managerPhoneController.text.isEmpty
            ? null
            : '+91${_managerPhoneController.text.trim()}',
        officeTelephone: _officeTelController.text,
        officeEmail: _officeEmailController.text,
        website: _websiteController.text,
        workingHoursFrom:
            _workingHoursFrom == null ? null : _workingHoursFrom!.format(context),
        workingHoursTo:
            _workingHoursTo == null ? null : _workingHoursTo!.format(context),
        weeklyOff: _weeklyOff == 'None' ? null : _weeklyOff,
        shopFrontPhotoUrl: shopFrontUrl,
        businessCardPhotoUrl: businessCardUrl,
        ownerPhotoUrl: ownerPhotoUrl,
        extraPhotoUrls: extraUrls,
        latitude: _latitude,
        longitude: _longitude,
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
                      _FieldLabel('OWNER NAME(S)'),
                      _buildOwnerFields(),
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
                      _FieldLabel('MANAGER / ACCOUNTANT'),
                      _PillField(
                        controller: _managerNameController,
                        hint: 'Name (optional)',
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 10),
                      _PillField(
                        controller: _managerPhoneController,
                        hint: '00000 00000',
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        prefixText: '+91 ',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (v.trim().length != 10) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel('OFFICE TELEPHONE'),
                      _PillField(
                        controller: _officeTelController,
                        hint: 'Landline / office number',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel('OFFICE EMAIL'),
                      _PillField(
                        controller: _officeEmailController,
                        hint: 'office@example.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel('WEBSITE / INSTAGRAM'),
                      _PillField(
                        controller: _websiteController,
                        hint: 'www.example.com or @handle',
                        keyboardType: TextInputType.url,
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
                      _FieldLabel('DEALER CATEGORY'),
                      _buildDealerCategorySelector(),
                      const SizedBox(height: 18),
                      _FieldLabel('WORKING HOURS'),
                      _buildWorkingHoursRow(),
                      const SizedBox(height: 18),
                      _FieldLabel('WEEKLY OFF'),
                      _buildWeeklyOffSelector(),
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

  Widget _buildOwnerFields() {
    return Column(
      children: [
        for (int i = 0; i < _ownerControllers.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == _ownerControllers.length - 1 ? 0 : 10),
            child: Row(
              children: [
                Expanded(
                  child: _PillField(
                    controller: _ownerControllers[i],
                    hint: i == 0 ? 'Full name' : 'Additional owner name',
                    textCapitalization: TextCapitalization.words,
                    validator: i == 0
                        ? null
                        : null,
                  ),
                ),
                if (_ownerControllers.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeOwnerField(i),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addOwnerField,
            icon: const Icon(Icons.add, size: 18, color: _kBlue),
            label: const Text('Add another owner', style: TextStyle(color: _kBlue)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ),
      ],
    );
  }

  Widget _buildDealerCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _dealerCategory,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: _kLabel),
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              items: _kDealerCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _dealerCategory = v);
              },
            ),
          ),
        ),
        if (_dealerCategory == 'Other') ...[
          const SizedBox(height: 10),
          _PillField(
            controller: _customCategoryController,
            hint: 'Enter category',
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (_dealerCategory != 'Other') return null;
              return (v == null || v.trim().isEmpty) ? 'Enter a category' : null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildWorkingHoursRow() {
    return Row(
      children: [
        Expanded(child: _buildTimePickerPill('From', _workingHoursFrom, () => _pickWorkingHour(true))),
        const SizedBox(width: 12),
        Expanded(child: _buildTimePickerPill('To', _workingHoursTo, () => _pickWorkingHour(false))),
      ],
    );
  }

  Widget _buildTimePickerPill(String label, TimeOfDay? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18, color: _kLabel),
            const SizedBox(width: 8),
            Text(
              value == null ? label : value.format(context),
              style: TextStyle(
                fontSize: 15,
                color: value == null ? const Color(0xFFB4B9C4) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyOffSelector() {
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
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _weeklyOff,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: _kLabel),
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          items: _kWeekDays
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _weeklyOff = v);
          },
        ),
      ),
    );
  }

  Widget _buildPhotoPickers() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PhotoPicker(
                label: 'Shop Front',
                image: _shopFrontImage,
                onTap: () => _pickPhoto(_PhotoSlot.shopFront),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PhotoPicker(
                label: 'Business Card',
                image: _businessCardImage,
                onTap: () => _pickPhoto(_PhotoSlot.businessCard),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PhotoPicker(
                label: 'Owner Photo',
                image: _ownerImage,
                onTap: () => _pickPhoto(_PhotoSlot.owner),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_extraImages.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < _extraImages.length; i++)
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FutureBuilder<Uint8List>(
                          future: _extraImages[i].readAsBytes(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            return Image.memory(snapshot.data!, fit: BoxFit.cover);
                          },
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _extraImages.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _pickPhoto(_PhotoSlot.extra),
            icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: _kBlue),
            label: const Text('Add more photos', style: TextStyle(color: _kBlue)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
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
    } else if (_locationStatus == _LocationStatus.success && _latitude != null) {
      final lat = _latitude!;
      final lng = _longitude!;
      final ns = lat >= 0 ? 'N' : 'S';
      final ew = lng >= 0 ? 'E' : 'W';
      final source = _manualLatLng != null ? 'Set on map' : 'Auto-captured';
      subtitle =
          '${lat.abs().toStringAsFixed(4)}° $ns, ${lng.abs().toStringAsFixed(4)}° $ew · $source';
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
            else if (_locationStatus == _LocationStatus.success)
              TextButton(
                onPressed: _adjustOnMap,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text('Adjust on map', style: TextStyle(color: _kBlue)),
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
        aspectRatio: 1.0,
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
                            color: _kLabel, size: 22),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _kLabel, fontSize: 11),
                          ),
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
