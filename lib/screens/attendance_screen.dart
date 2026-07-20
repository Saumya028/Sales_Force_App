import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/leave_request.dart';
import '../services/attendance_service.dart';
import '../services/leave_service.dart';
import '../services/location_tracking_service.dart';
import 'apply_leave_screen.dart';

/// Attendance tab: today's check-in/out card, a monthly calendar with
/// Present/Absent/Late/Half-Day color coding, a "This Month" summary, and
/// an "Apply Leave" shortcut. Every number here is computed from real
/// `attendance` and `leave_requests` rows — see the README for the exact
/// rules used for "Absent" (computed, not stored) and "Half Day".
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _attendanceService = AttendanceService();
  final _leaveService = LeaveService();

  late DateTime _displayedMonth; // always the 1st of some month
  late Future<_AttendanceData> _future;

  bool _actionLoading = false;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
    _future = _load();
    // Ticks once a minute so an in-progress shift's duration stays fresh.
    _liveTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<_AttendanceData> _load() async {
    final results = await Future.wait([
      _attendanceService.getTodayAttendance(),
      _attendanceService.getAttendanceForMonth(_displayedMonth),
      _leaveService.getMyLeaveRequests(),
    ]);
    return _AttendanceData(
      today: results[0] as AttendanceRecord?,
      monthRecords: results[1] as List<AttendanceRecord>,
      leaveRequests: results[2] as List<LeaveRequest>,
    );
  }

  void _refresh() => setState(() {
        _future = _load();
      });

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + delta, 1);
      _future = _load();
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _displayedMonth.year == now.year && _displayedMonth.month == now.month;
  }

  Future<void> _startShift() async {
    setState(() => _actionLoading = true);
    try {
      await _attendanceService.checkIn();
      LocationTrackingService.instance.start();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift started — you\'re marked present for today.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t start shift. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _endShift() async {
    setState(() => _actionLoading = true);
    try {
      final record = await _attendanceService.checkOut();
      LocationTrackingService.instance.stop();
      _refresh();
      if (mounted) {
        final hours = record.elapsedHours ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shift ended — ${hours.toStringAsFixed(1)}h logged today.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t end shift. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _openApplyLeave() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLeaveScreen())).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _openApplyLeave,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE7EDFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Apply Leave', style: TextStyle(color: Color(0xFF3D6BFF), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: FutureBuilder<_AttendanceData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 160),
                    Center(child: Text('Error: ${snapshot.error}')),
                  ],
                );
              }
              final data = snapshot.data!;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _buildTodayCard(data.today),
                      const SizedBox(height: 16),
                      _buildCalendarCard(data.monthRecords),
                      const SizedBox(height: 16),
                      _buildMonthSummaryCard(data),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Today card
  // ---------------------------------------------------------------------

  Widget _buildTodayCard(AttendanceRecord? today) {
    final statusMeta = _statusMeta(today?.status);
    final checkedOut = today?.checkOutTime != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TODAY — ${DateFormat('d MMM yyyy').format(DateTime.now())}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _todayColumn(
                  'Status',
                  today == null ? 'Not Started' : statusMeta.label,
                  valueColor: today == null ? Colors.grey.shade500 : statusMeta.color,
                ),
              ),
              Expanded(
                child: _todayColumn(
                  'Check In',
                  today?.checkInTime != null ? DateFormat('hh:mm a').format(today!.checkInTime!.toLocal()) : '—',
                ),
              ),
              Expanded(
                child: _todayColumn(
                  'Check Out',
                  today?.checkOutTime != null ? DateFormat('hh:mm a').format(today!.checkOutTime!.toLocal()) : '—',
                ),
              ),
            ],
          ),
          if (today != null && today.checkInTime != null) ...[
            const SizedBox(height: 10),
            Text(
              checkedOut
                  ? 'Shift completed — ${(today.elapsedHours ?? 0).toStringAsFixed(1)}h worked'
                  : 'On shift — ${(today.elapsedHours ?? 0).toStringAsFixed(1)}h so far',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 16),
          if (today == null)
            _actionButton('Start Shift', Icons.play_arrow, const Color(0xFF3D6BFF), _startShift)
          else if (!checkedOut)
            _actionButton('End Shift', Icons.stop, const Color(0xFFDC2626), _endShift),
        ],
      ),
    );
  }

  Widget _todayColumn(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87),
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _actionLoading ? null : onPressed,
        icon: _actionLoading
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Calendar card
  // ---------------------------------------------------------------------

  Widget _buildCalendarCard(List<AttendanceRecord> monthRecords) {
    final recordsByDay = <int, AttendanceRecord>{
      for (final r in monthRecords) r.attendanceDate.day: r,
    };
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday; // 1=Mon..7=Sun
    final leadingBlanks = firstWeekday - 1;
    final today = DateTime.now();
    final todayIsInThisMonth = today.year == _displayedMonth.year && today.month == _displayedMonth.month;

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      final isToday = todayIsInThisMonth && today.day == day;
      final record = recordsByDay[day];
      cells.add(_buildDayCell(date: date, record: record, isToday: isToday));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              _roundIconButton(Icons.chevron_left, () => _changeMonth(-1)),
              const SizedBox(width: 8),
              _roundIconButton(Icons.chevron_right, _isCurrentMonth ? null : () => _changeMonth(1)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
            children: cells,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legendDot(const Color(0xFF16A34A), 'Present'),
              _legendDot(const Color(0xFFDC2626), 'Absent'),
              _legendDot(const Color(0xFFF5B400), 'Late'),
              _legendDot(const Color(0xFF9C6ADE), 'Half Day'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? Colors.grey.shade100 : Colors.grey.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: enabled ? Colors.black54 : Colors.grey.shade300),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildDayCell({required DateTime date, required AttendanceRecord? record, required bool isToday}) {
    final today = DateTime.now();
    final isSunday = date.weekday == DateTime.sunday;
    final isFuture = DateTime(date.year, date.month, date.day).isAfter(DateTime(today.year, today.month, today.day));

    Color bg;
    String label;
    Color textColor = Colors.white;

    if (record != null) {
      final meta = _statusMeta(record.status);
      bg = meta.color;
      label = meta.letter;
    } else if (isSunday || isFuture) {
      bg = Colors.grey.shade200;
      label = '–';
      textColor = Colors.grey.shade500;
    } else {
      // Past working day with no record on file — computed as Absent.
      bg = const Color(0xFFDC2626);
      label = 'A';
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: const Color(0xFF3D6BFF), width: 2.5) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12.5),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // This Month summary card
  // ---------------------------------------------------------------------

  Widget _buildMonthSummaryCard(_AttendanceData data) {
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final today = DateTime.now();
    final isCurrentMonth = _isCurrentMonth;
    final lastRelevantDay = isCurrentMonth ? today.day : daysInMonth;

    final recordsByDay = <int, AttendanceRecord>{
      for (final r in data.monthRecords) r.attendanceDate.day: r,
    };

    var daysPresent = 0;
    var daysAbsent = 0;
    double workingHours = 0;

    for (var day = 1; day <= lastRelevantDay; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      if (date.weekday == DateTime.sunday) continue; // non-working day

      final record = recordsByDay[day];
      if (record == null) {
        daysAbsent++;
        continue;
      }
      if (record.status == 'present' || record.status == 'late' || record.status == 'half_day') {
        daysPresent++;
      }
      if (record.checkOutTime != null) {
        workingHours += (record.checkOutTime!.difference(record.checkInTime!).inMinutes) / 60.0;
      } else if (record.attendanceDate.year == today.year &&
          record.attendanceDate.month == today.month &&
          record.attendanceDate.day == today.day) {
        workingHours += (record.elapsedHours ?? 0);
      }
    }

    final leavesTaken = data.leaveRequests.fold<int>(0, (sum, r) => sum + r.daysWithinMonth(_displayedMonth));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('This Month', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _summaryTile('Days Present', '$daysPresent')),
              const SizedBox(width: 12),
              Expanded(child: _summaryTile('Days Absent', '$daysAbsent')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryTile('Leaves Taken', '$leavesTaken')),
              const SizedBox(width: 12),
              Expanded(child: _summaryTile('Working Hours', '${workingHours.round()}h')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  _StatusMeta _statusMeta(String? status) {
    switch (status) {
      case 'late':
        return _StatusMeta('Late', 'L', const Color(0xFFF5B400));
      case 'half_day':
        return _StatusMeta('Half Day', 'H', const Color(0xFF9C6ADE));
      case 'absent':
        return _StatusMeta('Absent', 'A', const Color(0xFFDC2626));
      case 'present':
      default:
        return _StatusMeta('Present', 'P', const Color(0xFF16A34A));
    }
  }
}

class _AttendanceData {
  final AttendanceRecord? today;
  final List<AttendanceRecord> monthRecords;
  final List<LeaveRequest> leaveRequests;

  _AttendanceData({required this.today, required this.monthRecords, required this.leaveRequests});
}

class _StatusMeta {
  final String label;
  final String letter;
  final Color color;
  _StatusMeta(this.label, this.letter, this.color);
}
