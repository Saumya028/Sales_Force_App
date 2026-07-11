/// An admin-assigned daily working area for a salesperson
/// (e.g. "South Delhi Zone-3", 8.2 km of coverage for the day).
class BeatPlan {
  final String id;
  final DateTime planDate;
  final String zoneName;
  final double? coverageKm;

  BeatPlan({
    required this.id,
    required this.planDate,
    required this.zoneName,
    this.coverageKm,
  });

  factory BeatPlan.fromJson(Map<String, dynamic> json) {
    return BeatPlan(
      id: json['id'],
      planDate: DateTime.parse(json['plan_date']),
      zoneName: json['zone_name'],
      coverageKm: json['coverage_km'] == null
          ? null
          : (json['coverage_km'] as num).toDouble(),
    );
  }
}
