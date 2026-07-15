/// Injects the Google Maps JS script tag on web at startup, using the key
/// from MapsConfig (env.json) instead of a hardcoded tag in index.html.
/// No-op on Android/iOS — see maps_script_loader_stub.dart.
export 'maps_script_loader_stub.dart'
    if (dart.library.html) 'maps_script_loader_web.dart';
