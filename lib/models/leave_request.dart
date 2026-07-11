class LeaveRequest {
  final String id;
  final String leaveType; // casual | sick | emergency | earned
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;
  final String? attachmentPath;
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  LeaveRequest({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.reason,
    this.attachmentPath,
    required this.status,
    required this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'],
      leaveType: json['leave_type'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      reason: json['reason'],
      attachmentPath: json['attachment_path'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// The original filename, derived from the stored path
  /// (`{userId}/{timestamp}_{filename}`), for display purposes.
  String? get attachmentFileName {
    if (attachmentPath == null) return null;
    final parts = attachmentPath!.split('/');
    final last = parts.isNotEmpty ? parts.last : attachmentPath!;
    final underscoreIndex = last.indexOf('_');
    return underscoreIndex == -1 ? last : last.substring(underscoreIndex + 1);
  }

  /// Number of calendar days this request covers, inclusive.
  int get dayCount => endDate.difference(startDate).inDays + 1;

  /// Number of days of this request that fall within [monthStart,
  /// monthStart + 1 month), used to compute "Leaves Taken" per month.
  /// Only counts if [status] is 'approved'.
  int daysWithinMonth(DateTime monthStart) {
    if (status != 'approved') return 0;
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final rangeStart = startDate.isAfter(monthStart) ? startDate : monthStart;
    final rangeEndExclusive =
        endDate.add(const Duration(days: 1)).isBefore(monthEnd) ? endDate.add(const Duration(days: 1)) : monthEnd;
    final days = rangeEndExclusive.difference(rangeStart).inDays;
    return days > 0 ? days : 0;
  }

  static const Map<String, String> typeLabels = {
    'casual': 'Casual Leave',
    'sick': 'Sick Leave',
    'emergency': 'Emergency Leave',
    'earned': 'Earned Leave',
  };

  String get typeLabel => typeLabels[leaveType] ?? leaveType;
}
