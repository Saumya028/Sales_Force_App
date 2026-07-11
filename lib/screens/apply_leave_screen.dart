import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/leave_request.dart';
import '../services/leave_service.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  static const _leaveTypes = ['casual', 'sick', 'emergency', 'earned'];

  final _leaveService = LeaveService();
  final _reasonController = TextEditingController();

  String _selectedType = 'casual';
  late DateTime _startDate;
  late DateTime _endDate;

  Uint8List? _attachmentBytes;
  String? _attachmentFileName;

  bool _submitting = false;
  late Future<List<LeaveRequest>> _pastRequestsFuture;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = _startDate.add(const Duration(days: 1));
    _pastRequestsFuture = _leaveService.getMyLeaveRequests();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _refreshPastRequests() {
    setState(() => _pastRequestsFuture = _leaveService.getMyLeaveRequests());
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn\'t read that file. Please try another.')),
          );
        }
        return;
      }
      setState(() {
        _attachmentBytes = file.bytes;
        _attachmentFileName = file.name;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t open the file picker.')),
        );
      }
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachmentBytes = null;
      _attachmentFileName = null;
    });
  }

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please briefly explain the reason for your leave.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _leaveService.submitLeaveRequest(
        leaveType: _selectedType,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonController.text,
        attachmentBytes: _attachmentBytes,
        attachmentFileName: _attachmentFileName,
      );
      _reasonController.clear();
      setState(() {
        _attachmentBytes = null;
        _attachmentFileName = null;
      });
      _refreshPastRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t submit your request. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _sectionLabel('LEAVE TYPE'),
                const SizedBox(height: 10),
                ..._leaveTypes.map(_buildLeaveTypeOption),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDateField('START DATE', _startDate, _pickStartDate)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDateField('END DATE', _endDate, _pickEndDate)),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionLabel('REASON'),
                const SizedBox(height: 10),
                _buildReasonField(),
                const SizedBox(height: 20),
                _buildAttachmentRow(),
                const SizedBox(height: 28),
                _sectionLabel('PAST REQUESTS'),
                const SizedBox(height: 10),
                _buildPastRequests(),
                const SizedBox(height: 28),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLeaveTypeOption(String type) {
    final selected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE7EDFF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? const Color(0xFF3D6BFF) : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  LeaveRequest.typeLabels[type] ?? type,
                  style: TextStyle(
                    color: selected ? const Color(0xFF3D6BFF) : Colors.black87,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14.5,
                  ),
                ),
              ),
              if (selected) const Icon(Icons.check, color: Color(0xFF3D6BFF), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('d MMM yyyy').format(date),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 17, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _reasonController,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Briefly explain the reason...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          contentPadding: const EdgeInsets.all(14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildAttachmentRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attachment (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (_attachmentFileName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _attachmentFileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (_attachmentFileName != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: _removeAttachment,
              tooltip: 'Remove attachment',
            ),
          TextButton(
            onPressed: _pickAttachment,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE7EDFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              _attachmentFileName == null ? 'Upload' : 'Replace',
              style: const TextStyle(color: Color(0xFF3D6BFF), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastRequests() {
    return FutureBuilder<List<LeaveRequest>>(
      future: _pastRequestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No leave requests yet.', style: TextStyle(color: Colors.grey.shade600)),
          );
        }
        return Column(
          children: requests.map(_buildPastRequestCard).toList(),
        );
      },
    );
  }

  Widget _buildPastRequestCard(LeaveRequest request) {
    final Color pillColor;
    final Color pillTextColor;
    switch (request.status) {
      case 'approved':
        pillColor = Colors.green.shade50;
        pillTextColor = Colors.green.shade700;
        break;
      case 'rejected':
        pillColor = Colors.red.shade50;
        pillTextColor = Colors.red.shade700;
        break;
      default:
        pillColor = Colors.orange.shade50;
        pillTextColor = Colors.orange.shade700;
    }

    final sameDay = request.startDate.year == request.endDate.year &&
        request.startDate.month == request.endDate.month &&
        request.startDate.day == request.endDate.day;
    final dateLabel = sameDay
        ? DateFormat('d MMM yyyy').format(request.startDate)
        : '${DateFormat('d').format(request.startDate)}–${DateFormat('d MMM yyyy').format(request.endDate)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.typeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(dateLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: pillColor, borderRadius: BorderRadius.circular(20)),
            child: Text(
              request.status.toUpperCase(),
              style: TextStyle(color: pillTextColor, fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3D6BFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Submit Leave Request', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
