import 'package:doon_walkers/features/weather/data/repositories/weather_repository.dart';
import 'package:doon_walkers/features/weather/domain/models/weather_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository();
});

final weatherProvider = FutureProvider<WeatherModel>((ref) async {
  final repository = ref.watch(weatherRepositoryProvider);
  return repository.fetchCurrentWeather();
});
