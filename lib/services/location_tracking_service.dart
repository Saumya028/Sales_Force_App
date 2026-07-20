import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:battery_plus/battery_plus.dart';

/// Sends a GPS ping every [_pingInterval] while the salesperson is on
/// shift AND the app is in the foreground — this is intentionally
/// foreground-only tracking (no background service, no extra Android
/// permission beyond the location permission the app already asks
/// for), which keeps battery use low at the cost of the trail pausing
/// whenever the app is minimized.
///
/// Lifecycle:
///  - [start] is called once, right after a successful check-in.
///  - [stop] is called once, right after check-out.
///  - [resumeIfOnShift] is called when the app launches / comes back
///    to the foreground, in case the salesperson is already mid-shift
///    (e.g. app was killed and reopened) — it looks at today's
///    attendance rather than assuming.
///
/// This is a singleton (not tied to any one screen's lifecycle) so
/// tracking keeps running no matter which tab of the app is open.
class LocationTrackingService with WidgetsBindingObserver {
  LocationTrackingService._internal();
  static final LocationTrackingService instance = LocationTrackingService._internal();

  static const _pingInterval = Duration(seconds: 45);

  final SupabaseClient _client = Supabase.instance.client;
  final Battery _battery = Battery();

  Timer? _timer;
  bool _onShift = false;
  bool _observerRegistered = false;

  Position? _lastPosition;
  DateTime? _lastPositionAt;

  void _ensureObserver() {
    if (_observerRegistered) return;
    WidgetsBinding.instance.addObserver(this);
    _observerRegistered = true;
  }

  /// Call right after a successful check-in.
  void start() {
    _onShift = true;
    _ensureObserver();
    _resumeIfForeground();
  }

  /// Call right after a successful check-out.
  void stop() {
    _onShift = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Call once, e.g. from the app shell's initState, so a shift that
  /// was already in progress before the app was (re)opened resumes
  /// sending pings without the salesperson having to check in again.
  Future<void> resumeIfAlreadyOnShift({required bool isOnShift}) async {
    if (isOnShift) {
      start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_onShift) return;
    if (state == AppLifecycleState.resumed) {
      _resumeIfForeground();
    } else {
      // Foreground-only by design: stop pinging the moment the app
      // isn't in front of the user, resume automatically when it is.
      _timer?.cancel();
      _timer = null;
    }
  }

  void _resumeIfForeground() {
    if (!_onShift || _timer != null) return;
    _sendPing(); // immediate ping so the admin sees a fresh position right away
    _timer = Timer.periodic(_pingInterval, (_) => _sendPing());
  }

  Future<void> _sendPing() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return; // Silent — the Add Dealer GPS card already surfaces permission problems to the user.
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      double? speedKmh = (position.speed.isFinite && position.speed > 0) ? position.speed * 3.6 : null;
      // Some devices report an unreliable/zero instantaneous speed
      // indoors or at low accuracy — fall back to distance/time against
      // the previous ping so "Stationary vs Moving" is still sensible.
      if (speedKmh == null && _lastPosition != null && _lastPositionAt != null) {
        final meters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        final seconds = DateTime.now().difference(_lastPositionAt!).inSeconds;
        if (seconds > 0) speedKmh = (meters / seconds) * 3.6;
      }
      _lastPosition = position;
      _lastPositionAt = DateTime.now();

      int? batteryLevel;
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (_) {
        // Battery reporting isn't available on all devices — omit rather than fail the ping.
      }

      await _client.from('location_pings').insert({
        'salesperson_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        if (speedKmh != null) 'speed_kmh': speedKmh,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // A missed ping shouldn't interrupt the salesperson's flow —
      // the next timer tick (or the next app resume) retries.
    }
  }
}
