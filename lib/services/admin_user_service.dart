import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import 'auth_service.dart';

class AdminUserService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Returns every salesperson profile (any status), sorted by name.
  /// Relies on the "Admin can view all profiles" policy.
  Future<List<Profile>> getAllSalesmen() async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('role', 'salesperson')
        .order('full_name');
    return (data as List).map((e) => Profile.fromJson(e)).toList();
  }

  /// Creates a brand-new salesperson account.
  ///
  /// IMPORTANT: `supabase.auth.signUp` signs the *new* user in on this
  /// same client, which would otherwise kick the admin out of their own
  /// session. There's no service-role key available on a Flutter client,
  /// so instead we snapshot the admin's current refresh token before
  /// signing up, then restore it immediately afterwards.
  Future<void> createSalesman({
    required String companyId,
    required String password,
    required String fullName,
  }) async {
    final adminSession = _client.auth.currentSession;
    final adminRefreshToken = adminSession?.refreshToken;

    try {
      final email = AuthService.companyIdToEmail(companyId);
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'salesperson',
        },
      );
    } finally {
      // Always try to restore the admin's own session, whether or not
      // signUp succeeded or actually swapped the session.
      if (adminRefreshToken != null) {
        try {
          await _client.auth.setSession(adminRefreshToken);
        } catch (_) {
          // If this fails the admin will simply be prompted to log back
          // in — better than silently leaving them on the new account.
        }
      }
    }
  }

  /// Soft-deletes ("removes") a salesperson: flips their profile to
  /// 'inactive'. AuthGate signs them out and blocks re-login while
  /// inactive, without deleting any of their historical orders/outlets.
  Future<void> setSalesmanStatus(String salespersonId, String status) async {
    await _client.from('profiles').update({'status': status}).eq('id', salespersonId);
  }
}
