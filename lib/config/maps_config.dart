class MapsConfig {
  // Same key that goes in AndroidManifest.xml / iOS AppDelegate, but read
  // here from env.json via `--dart-define-from-file=env.json`. Used on web
  // to inject the Google Maps <script> tag at startup — see
  // lib/web/maps_script_loader.dart and main.dart.
  static const String apiKey = String.fromEnvironment('MAPS_API_KEY');
}
