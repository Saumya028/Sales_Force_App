class OrderItemDetail {
  final String productName;
  final int quantity;
  final double price;
  final double amount;

  OrderItemDetail({
    required this.productName,
    required this.quantity,
    required this.price,
    required this.amount,
  });

  factory OrderItemDetail.fromJson(Map<String, dynamic> json) {
    return OrderItemDetail(
      productName: json['products'] != null ? (json['products']['name'] ?? 'Unknown product') : 'Unknown product',
      quantity: json['quantity'],
      price: (json['price'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
    );
  }
}
