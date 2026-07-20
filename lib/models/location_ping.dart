/// A single GPS reading sent by a salesperson's app while on shift.
class LocationPing {
  final String id;
  final String salespersonId;
  final double latitude;
  final double longitude;
  final double? speedKmh;
  final int? batteryLevel;
  final DateTime recordedAt;

  LocationPing({
    required this.id,
    required this.salespersonId,
    required this.latitude,
    required this.longitude,
    this.speedKmh,
    this.batteryLevel,
    required this.recordedAt,
  });

  factory LocationPing.fromJson(Map<String, dynamic> json) {
    return LocationPing(
      id: json['id'],
      salespersonId: json['salesperson_id'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speedKmh: (json['speed_kmh'] as num?)?.toDouble(),
      batteryLevel: json['battery_level'] as int?,
      recordedAt: DateTime.parse(json['recorded_at']),
    );
  }

  bool get isStationary => (speedKmh ?? 0) < 1.5;
}
