import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leave_request.dart';

class LeaveService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String attachmentsBucket = 'leave-attachments';

  String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Uploads an optional attachment (e.g. a medical certificate) to the
  /// private `leave-attachments` bucket, scoped to the current user's own
  /// folder, and returns the storage path to save on the leave request.
  Future<String> _uploadAttachment({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _client.storage.from(attachmentsBucket).uploadBinary(path, bytes);
    return path;
  }

  /// Submits a new leave request with status 'pending'. An Admin approves
  /// or rejects it later (currently done manually via SQL — see the
  /// leave_and_checkout_migration.sql demo section; there's no Admin UI
  /// for this yet).
  Future<LeaveRequest> submitLeaveRequest({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    Uint8List? attachmentBytes,
    String? attachmentFileName,
  }) async {
    final userId = _client.auth.currentUser!.id;

    String? attachmentPath;
    if (attachmentBytes != null && attachmentFileName != null) {
      attachmentPath = await _uploadAttachment(
        bytes: attachmentBytes,
        fileName: attachmentFileName,
      );
    }

    final data = await _client
        .from('leave_requests')
        .insert({
          'salesperson_id': userId,
          'leave_type': leaveType,
          'start_date': _dateStr(startDate),
          'end_date': _dateStr(endDate),
          'reason': (reason == null || reason.trim().isEmpty) ? null : reason.trim(),
          'attachment_path': attachmentPath,
          'status': 'pending',
        })
        .select()
        .single();
    return LeaveRequest.fromJson(data);
  }

  /// Returns all of the current salesperson's leave requests, most
  /// recent first.
  Future<List<LeaveRequest>> getMyLeaveRequests() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('leave_requests')
        .select()
        .eq('salesperson_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => LeaveRequest.fromJson(e)).toList();
  }

  /// A short-lived signed URL to view/download an attachment (the bucket
  /// is private, so a plain public URL won't work).
  Future<String> getAttachmentSignedUrl(String path) {
    return _client.storage.from(attachmentsBucket).createSignedUrl(path, 60 * 10);
  }
}
