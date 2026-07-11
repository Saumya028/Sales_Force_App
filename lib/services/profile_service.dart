import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Profile> getMyProfile() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(data);
  }
}
