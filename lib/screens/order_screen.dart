import 'package:flutter/material.dart';
import '../models/outlet.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';

class OrderScreen extends StatefulWidget {
  final Outlet outlet;
  const OrderScreen({super.key, required this.outlet});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _productService = ProductService();
  final _orderService = OrderService();
  late Future<List<Product>> _productsFuture;
  final Map<Product, int> _cart = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _productsFuture = _productService.getAllProducts();
  }

  double get _total => _cart.entries.fold(0, (sum, e) => sum + e.key.price * e.value);

  void _updateQty(Product product, int qty) {
    setState(() {
      if (qty <= 0) {
        _cart.remove(product);
      } else {
        _cart[product] = qty;
      }
    });
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await _orderService.placeOrder(outletId: widget.outlet.id, cart: _cart);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order — ${widget.outlet.name}')),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(child: Text('No products found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final qty = _cart[product] ?? 0;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(product.name),
                  subtitle: Text('₹${product.price.toStringAsFixed(2)} • Stock: ${product.stock}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: qty > 0 ? () => _updateQty(product, qty - 1) : null,
                      ),
                      Text('$qty', style: const TextStyle(fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _updateQty(product, qty + 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total: ₹${_total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: (_cart.isEmpty || _isSubmitting) ? null : _submitOrder,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
