import 'dart:html' as html;

/// Adds the Google Maps JavaScript API <script> tag to <head> at runtime,
/// replacing the old static tag that used to live in web/index.html.
void injectGoogleMapsScript(String apiKey) {
  if (apiKey.isEmpty) {
    // Fails loudly in the browser console rather than silently showing a
    // blank/broken map — same MissingKeyMapError Google's own loader gives.
    // ignore: avoid_print
    print('MAPS_API_KEY is empty — pass --dart-define-from-file=env.json');
    return;
  }
  html.document.head!.append(
    html.ScriptElement()
      ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
      ..type = 'text/javascript',
  );
}
