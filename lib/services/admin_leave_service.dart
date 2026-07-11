import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_leave_request.dart';

class AdminLeaveService {
  final SupabaseClient _client = Supabase.instance.client;

  /// All leave requests across every salesperson, most recent first.
  /// Relies on the "Admin can view all leave requests" policy.
  Future<List<AdminLeaveRequest>> getAllLeaveRequests() async {
    final data = await _client
        .from('leave_requests')
        .select('*, profiles(full_name)')
        .order('created_at', ascending: false);
    return (data as List).map((e) => AdminLeaveRequest.fromJson(e)).toList();
  }

  Future<void> approveLeave(String leaveRequestId) async {
    await _client
        .from('leave_requests')
        .update({'status': 'approved', 'admin_remarks': null})
        .eq('id', leaveRequestId);
  }

  Future<void> rejectLeave(String leaveRequestId, {String? reason}) async {
    await _client.from('leave_requests').update({
      'status': 'rejected',
      'admin_remarks': (reason == null || reason.trim().isEmpty) ? null : reason.trim(),
    }).eq('id', leaveRequestId);
  }
}
