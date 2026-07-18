import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance.dart';

class AttendanceService {
  final SupabaseClient _client = Supabase.instance.client;

  String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _todayStr() => _dateStr(DateTime.now());

  /// Returns today's attendance record for the current salesperson, or
  /// `null` if they haven't started their shift yet.
  Future<AttendanceRecord?> getTodayAttendance() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('attendance')
        .select()
        .eq('salesperson_id', userId)
        .eq('attendance_date', _todayStr())
        .maybeSingle();

    if (data == null) return null;
    return AttendanceRecord.fromJson(data);
  }

  /// Returns every attendance record ever logged by the current
  /// salesperson, oldest first. Used to figure out when attendance
  /// tracking actually started for this user (so we don't fabricate
  /// "Absent" days before they ever used the app).
  Future<List<AttendanceRecord>> getAllAttendance() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('attendance')
        .select()
        .eq('salesperson_id', userId)
        .order('attendance_date', ascending: true);
    return (data as List).map((e) => AttendanceRecord.fromJson(e)).toList();
  }

  /// Returns attendance records within [monthStart]'s calendar month.
  /// Powers the monthly calendar grid on the Attendance tab.
  Future<List<AttendanceRecord>> getAttendanceForMonth(DateTime monthStart) async {
    final userId = _client.auth.currentUser!.id;
    final start = DateTime(monthStart.year, monthStart.month, 1);
    final end = DateTime(monthStart.year, monthStart.month + 1, 1);
    final data = await _client
        .from('attendance')
        .select()
        .eq('salesperson_id', userId)
        .gte('attendance_date', _dateStr(start))
        .lt('attendance_date', _dateStr(end))
        .order('attendance_date', ascending: true);
    return (data as List).map((e) => AttendanceRecord.fromJson(e)).toList();
  }

  /// Hour of day after which a check-in counts as "Late" rather than
  /// "Present". Simple, tunable placeholder policy — a real system would
  /// likely make this configurable per company.
  static const int lateAfterHour = 10;

  /// A shift shorter than this counts as a "Half Day" once checked out.
  static const double halfDayThresholdHours = 4;

  /// Marks the current salesperson present for today with the current
  /// time as check-in ("Start Shift"). Status is 'present' or 'late'
  /// depending on the time of day. Safe to call more than once — the
  /// unique (salesperson_id, attendance_date) constraint means a second
  /// call just returns the existing row instead of duplicating it.
  Future<AttendanceRecord> checkIn() async {
    final userId = _client.auth.currentUser!.id;
    final existing = await getTodayAttendance();
    if (existing != null) return existing;

    final now = DateTime.now();
    final status = now.hour >= lateAfterHour ? 'late' : 'present';

    final data = await _client
        .from('attendance')
        .insert({
          'salesperson_id': userId,
          'attendance_date': _todayStr(),
          'status': status,
          // Always send an explicit UTC instant ('...Z'). If we sent a
          // local-time string with no offset, Postgres (UTC session tz)
          // would interpret it as if it *were* UTC, silently shifting it
          // by the device's timezone offset (e.g. +5:30 for IST) — which
          // is exactly what caused check-in times to show hours in the
          // future for Indian users.
          'check_in_time': now.toUtc().toIso8601String(),
        })
        .select()
        .single();
    return AttendanceRecord.fromJson(data);
  }

  /// Records the current time as check-out ("End Shift") on today's
  /// attendance row, and — if the resulting shift was shorter than
  /// [halfDayThresholdHours] — reclassifies the day as 'half_day'.
  /// Throws if the shift was never started. Safe to call more than
  /// once — won't overwrite an existing check-out time.
  Future<AttendanceRecord> checkOut() async {
    final userId = _client.auth.currentUser!.id;
    final existing = await getTodayAttendance();
    if (existing == null) {
      throw StateError('Shift has not been started yet.');
    }
    if (existing.checkOutTime != null) {
      return existing; // already checked out — no-op
    }

    final now = DateTime.now();
    final workedHours = now.difference(existing.checkInTime!).inMinutes / 60.0;
    final newStatus = workedHours < halfDayThresholdHours ? 'half_day' : existing.status;

    final data = await _client
        .from('attendance')
        .update({
          'check_out_time': now.toUtc().toIso8601String(),
          'status': newStatus,
        })
        .eq('salesperson_id', userId)
        .eq('attendance_date', _todayStr())
        .select()
        .single();
    return AttendanceRecord.fromJson(data);
  }
}
