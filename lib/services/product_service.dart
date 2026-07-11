import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class ProductService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Product>> getAllProducts() async {
    final data = await _client.from('products').select().order('name');
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }
}
