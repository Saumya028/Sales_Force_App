import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/outlet.dart';

class OutletService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String dealerPhotosBucket = 'dealer-photos';

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

  /// Uploads a dealer photo (Shop Front / Business Card) to the public
  /// `dealer-photos` bucket, scoped to the current user's own folder, and
  /// returns its public URL to save on the outlet row.
  Future<String> uploadDealerPhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _client.storage.from(dealerPhotosBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from(dealerPhotosBucket).getPublicUrl(path);
  }

  /// Adds a brand-new dealer discovered on the salesperson's beat and
  /// assigns it to them, so it's immediately available for placing an
  /// order or recording a visit outcome.
  Future<Outlet> createOutlet({
    required String name,
    String? address,
    String? ownerName,
    String? mobileNumber,
    String? gstNumber,
    String? businessType,
    String? shopFrontPhotoUrl,
    String? businessCardPhotoUrl,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final payload = Outlet(
      id: '',
      name: name.trim(),
      address: address?.trim(),
      ownerName: ownerName?.trim(),
      mobileNumber: mobileNumber?.trim(),
      gstNumber: gstNumber?.trim(),
      businessType: businessType,
      shopFrontPhotoUrl: shopFrontPhotoUrl,
      businessCardPhotoUrl: businessCardPhotoUrl,
      latitude: latitude,
      longitude: longitude,
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
