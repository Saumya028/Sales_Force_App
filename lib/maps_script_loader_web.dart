import 'dart:async';
import 'dart:html' as html;

/// Adds the Google Maps JavaScript API <script> tag to <head> at runtime,
/// using the key from MapsConfig (env.json) instead of a hardcoded tag in
/// web/index.html — and waits for it to actually finish loading before
/// returning, so no widget can try to use `google.maps` before it exists.
/// (Without this wait, any screen that renders a GoogleMap the moment it
/// opens — e.g. Admin's Live Tracking detail screen — can race ahead of
/// the script and throw "Cannot read properties of undefined (reading
/// 'maps')".)
Future<void> injectGoogleMapsScript(String apiKey) async {
  if (apiKey.isEmpty) {
    // Fails loudly in the browser console rather than silently showing a
    // blank/broken map — same MissingKeyMapError Google's own loader gives.
    // ignore: avoid_print
    print('MAPS_API_KEY is empty — pass --dart-define-from-file=env.json');
    return;
  }

  // Guards against double-injection on Flutter web hot restart, which
  // re-runs main() without a full page reload.
  if (html.document.querySelector('script[data-google-maps-loader]') != null) {
    return;
  }

  final completer = Completer<void>();
  final script = html.ScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
    ..type = 'text/javascript'
    ..setAttribute('data-google-maps-loader', 'true');

  script.onLoad.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });
  script.onError.listen((event) {
    // ignore: avoid_print
    print('Failed to load the Google Maps script — check MAPS_API_KEY and network access.');
    // Completes (rather than completeError) so a broken/offline Maps load
    // doesn't block the rest of the app from starting — only map screens
    // will be affected.
    if (!completer.isCompleted) completer.complete();
  });

  html.document.head!.append(script);
  await completer.future;
}
