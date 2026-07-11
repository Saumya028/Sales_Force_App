import 'leave_request.dart';

/// A leave request as seen by an Admin — same fields as [LeaveRequest],
/// plus the salesperson's name (joined from `profiles`) since an admin is
/// looking at everyone's requests, not just their own.
class AdminLeaveRequest {
  final String id;
  final String salespersonId;
  final String salespersonName;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;
  final String? attachmentPath;
  final String status; // pending | approved | rejected
  final String? adminRemarks;
  final DateTime createdAt;

  AdminLeaveRequest({
    required this.id,
    required this.salespersonId,
    required this.salespersonName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.reason,
    this.attachmentPath,
    required this.status,
    this.adminRemarks,
    required this.createdAt,
  });

  factory AdminLeaveRequest.fromJson(Map<String, dynamic> json) {
    return AdminLeaveRequest(
      id: json['id'],
      salespersonId: json['salesperson_id'],
      salespersonName:
          json['profiles'] != null ? (json['profiles']['full_name'] ?? 'Unknown') : 'Unknown',
      leaveType: json['leave_type'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      reason: json['reason'],
      attachmentPath: json['attachment_path'],
      status: json['status'] ?? 'pending',
      adminRemarks: json['admin_remarks'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  int get dayCount => endDate.difference(startDate).inDays + 1;

  String get typeLabel => LeaveRequest.typeLabels[leaveType] ?? leaveType;
}
