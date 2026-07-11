import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles authentication. The login screen collects a "Company ID"
/// (e.g. `HUL-2025`) instead of an email address, but Supabase Auth is
/// email/password under the hood. To bridge the two without any extra
/// backend lookup table, a Company ID that isn't already an email address
/// is deterministically mapped to a synthetic email:
///
///   HUL-2025  ->  hul-2025@fmcgsalesforce.app
///
/// This keeps every account addressable by its Company ID while still
/// using Supabase's standard email/password auth underneath. If a real
/// email address is typed instead (contains '@'), it's used as-is — so
/// this also works for teams that create Supabase users with real emails.
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// The synthetic domain used to turn a plain Company ID into a valid
  /// email address for Supabase Auth.
  static const String _syntheticDomain = 'fmcgsalesforce.app';

  /// Normalizes whatever the user typed into the Company ID field into
  /// the email address that is actually stored in Supabase Auth.
  static String companyIdToEmail(String companyIdOrEmail) {
    final input = companyIdOrEmail.trim();
    if (input.contains('@')) {
      return input.toLowerCase();
    }
    final slug = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '$slug@$_syntheticDomain';
  }

  Future<AuthResponse> signIn(String companyId, String password) {
    final email = companyIdToEmail(companyId);
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Creates a brand-new account for the given Company ID/password,
  /// stamped with [fullName] and [role] ('salesperson' or 'admin').
  Future<AuthResponse> signUp(
    String companyId,
    String password, {
    String? fullName,
    String role = 'salesperson',
  }) {
    final email = companyIdToEmail(companyId);
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        'role': role,
      },
    );
  }

  /// Sends a password-reset email for the given Company ID/email.
  /// Note: Company IDs mapped to the synthetic domain won't have a real
  /// inbox — for production use, register users with a real company
  /// email address so this actually delivers a reset link.
  Future<void> resetPassword(String companyId) {
    final email = companyIdToEmail(companyId);
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
}
