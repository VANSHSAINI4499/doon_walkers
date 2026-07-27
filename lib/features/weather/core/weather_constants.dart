/// Weather configuration constants for DoonWalkers.
///
/// Default location is set to Dehradun, Uttarakhand, India.
/// Note: Geolocator-based user location detection is reserved as a future enhancement.
abstract final class WeatherConstants {
  /// Default latitude for Dehradun, Uttarakhand (30.3165 N)
  static const double kDefaultLatitude = 30.3165;

  /// Default longitude for Dehradun, Uttarakhand (78.0322 E)
  static const double kDefaultLongitude = 78.0322;

  /// Open-Meteo forecast API base URL (free, no API key required)
  static const String kOpenMeteoApiUrl =
      'https://api.open-meteo.com/v1/forecast';
}
