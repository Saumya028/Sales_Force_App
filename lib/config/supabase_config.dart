class SupabaseConfig {
  // Values come from env.json via `--dart-define-from-file=env.json`
  // (see README section "Environment configuration"). Nothing here is
  // hardcoded or committed to git.
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
