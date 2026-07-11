import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/outlet.dart';

class OutletService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Returns outlets assigned to the currently logged-in salesperson.
  Future<List<Outlet>> getMyOutlets() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('outlets')
        .select()
        .eq('assigned_salesperson_id', userId)
        .order('name');
    return (data as List).map((e) => Outlet.fromJson(e)).toList();
  }

  /// Adds a brand-new shop discovered on the salesperson's beat and
  /// assigns it to them, so it's immediately available for placing an
  /// order or recording a visit outcome.
  Future<Outlet> createOutlet({
    required String name,
    String? address,
    String? contactPerson,
    String? contactNumber,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final payload = Outlet(
      id: '',
      name: name.trim(),
      address: address?.trim(),
      contactPerson: contactPerson?.trim(),
      contactNumber: contactNumber?.trim(),
    ).toInsertJson()
      ..['assigned_salesperson_id'] = userId;

    final data = await _client
        .from('outlets')
        .insert(payload)
        .select()
        .single();
    return Outlet.fromJson(data);
  }
}
