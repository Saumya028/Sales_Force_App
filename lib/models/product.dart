class Product {
  final String id;
  final String name;
  final String? sku;
  final double price;
  final int stock;

  Product({
    required this.id,
    required this.name,
    this.sku,
    required this.price,
    required this.stock,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      sku: json['sku'],
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] ?? 0,
    );
  }
}
