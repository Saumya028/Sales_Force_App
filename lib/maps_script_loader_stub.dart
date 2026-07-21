/// Non-web platforms don't need a <script> tag — the Maps SDK is wired up
/// natively via AndroidManifest.xml / AppDelegate.swift instead.
Future<void> injectGoogleMapsScript(String apiKey) async {}
