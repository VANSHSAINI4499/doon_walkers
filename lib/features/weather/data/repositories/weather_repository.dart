import 'package:dio/dio.dart';
import 'package:doon_walkers/features/weather/core/weather_constants.dart';
import 'package:doon_walkers/features/weather/domain/models/weather_model.dart';

class WeatherRepository {
  WeatherRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// In-memory cache of the last successful weather response.
  WeatherModel? _cachedWeather;

  WeatherModel? get cachedWeather => _cachedWeather;

  Future<WeatherModel> fetchCurrentWeather({
    double latitude = WeatherConstants.kDefaultLatitude,
    double longitude = WeatherConstants.kDefaultLongitude,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        WeatherConstants.kOpenMeteoApiUrl,
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'current_weather': 'true',
          'hourly': 'precipitation_probability',
          'temperature_unit': 'celsius',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final model = WeatherModel.fromOpenMeteoJson(response.data!);
        _cachedWeather = model;
        return model;
      }

      if (_cachedWeather != null) {
        return _cachedWeather!;
      }

      throw Exception('Failed to load weather: HTTP ${response.statusCode}');
    } catch (e) {
      if (_cachedWeather != null) {
        return _cachedWeather!;
      }
      rethrow;
    }
  }
}
