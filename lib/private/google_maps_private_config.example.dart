// Copy to google_maps_private_config.dart (git-ignored).
// Use a Places API (New) key restricted to your app's package / bundle IDs.
class GoogleMapsPrivateConfig {
  const GoogleMapsPrivateConfig._();

  static const String googlePlacesApiKey = 'YOUR_PLACES_API_KEY';

  static const String googleMapsApiKey = googlePlacesApiKey;

  static const String googleDirectionsApiKey = googlePlacesApiKey;

  static bool get hasValidPlacesApiKey {
    final key = googlePlacesApiKey.trim();

    return key.isNotEmpty &&
        key != 'YOUR_PLACES_API_KEY' &&
        key != 'YOUR_API_KEY_HERE';
  }

  static bool get hasValidDirectionsApiKey {
    return hasValidPlacesApiKey;
  }
}
