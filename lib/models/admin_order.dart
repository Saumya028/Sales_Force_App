class AdminOrder {
  final String id;
  final String outletId;
  final String outletName;
  final String salespersonName;
  final String status;
  final String outcome;
  final double totalAmount;
  final DateTime createdAt;
  final String? remarks;
  final String? adminRemarks;

  AdminOrder({
    required this.id,
    required this.outletId,
    required this.outletName,
    required this.salespersonName,
    required this.status,
    required this.outcome,
    required this.totalAmount,
    required this.createdAt,
    this.remarks,
    this.adminRemarks,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    return AdminOrder(
      id: json['id'],
      outletId: json['outlet_id'],
      outletName: json['outlets'] != null ? (json['outlets']['name'] ?? 'Unknown outlet') : 'Unknown outlet',
      salespersonName:
          json['profiles'] != null ? (json['profiles']['full_name'] ?? 'Unknown rep') : 'Unknown rep',
      status: json['status'],
      outcome: json['outcome'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      remarks: json['remarks'],
      adminRemarks: json['admin_remarks'],
    );
  }

  /// Human-friendly order number for display (e.g. "ORD-2025-4821"), same
  /// derivation as SalesOrder.displayOrderNumber so the two sides show a
  /// matching number for the same underlying order.
  String get displayOrderNumber {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    final tag = (digits.isNotEmpty ? digits : id.hashCode.abs().toString())
        .padLeft(4, '0');
    return 'ORD-${createdAt.year}-${tag.substring(tag.length - 4)}';
  }
}
