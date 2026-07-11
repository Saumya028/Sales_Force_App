/// A single day's attendance record for a salesperson.
class AttendanceRecord {
  final String id;
  final DateTime attendanceDate;
  final String status; // present | late | half_day | absent | on_leave
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  AttendanceRecord({
    required this.id,
    required this.attendanceDate,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'],
      attendanceDate: DateTime.parse(json['attendance_date']),
      status: json['status'] ?? 'present',
      checkInTime: json['check_in_time'] == null
          ? null
          : DateTime.parse(json['check_in_time']),
      checkOutTime: json['check_out_time'] == null
          ? null
          : DateTime.parse(json['check_out_time']),
    );
  }

  /// Hours worked so far (or in total, if checked out). Null if the
  /// salesperson hasn't checked in yet.
  Duration? get elapsed {
    if (checkInTime == null) return null;
    final end = checkOutTime ?? DateTime.now();
    return end.difference(checkInTime!);
  }

  /// Elapsed time as decimal hours (e.g. 7.5), or null pre-check-in.
  double? get elapsedHours {
    final d = elapsed;
    if (d == null) return null;
    return d.inMinutes / 60.0;
  }
}
