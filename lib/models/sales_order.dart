class SalesOrder {
  final String id;
  final String outletId;
  final String? outletName;
  final String status;
  final String outcome;
  final double totalAmount;
  final DateTime createdAt;
  final String? adminRemarks;

  SalesOrder({
    required this.id,
    required this.outletId,
    this.outletName,
    required this.status,
    required this.outcome,
    required this.totalAmount,
    required this.createdAt,
    this.adminRemarks,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    return SalesOrder(
      id: json['id'],
      outletId: json['outlet_id'],
      outletName: json['outlets'] != null ? json['outlets']['name'] : null,
      status: json['status'],
      outcome: json['outcome'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      adminRemarks: json['admin_remarks'],
    );
  }

  /// Human-friendly order number for display (e.g. "ORD-2025-4821").
  /// The schema only stores a UUID `id`, so this derives a short, stable
  /// numeric tag from it rather than requiring a schema migration.
  String get displayOrderNumber {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    final tag = (digits.isNotEmpty ? digits : id.hashCode.abs().toString())
        .padLeft(4, '0');
    return 'ORD-${createdAt.year}-${tag.substring(tag.length - 4)}';
  }
}
