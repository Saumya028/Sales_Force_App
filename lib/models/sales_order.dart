class SalesOrder {
  final String id;
  final String outletId;
  final String? outletName;
  final String status;
  final String outcome;
  final double totalAmount;
  final DateTime createdAt;

  SalesOrder({
    required this.id,
    required this.outletId,
    this.outletName,
    required this.status,
    required this.outcome,
    required this.totalAmount,
    required this.createdAt,
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
    );
  }
}
