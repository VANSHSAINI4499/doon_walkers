import 'package:doon_walkers/features/weather/domain/models/weather_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeatherModel & Recommendation Tests', () {
    test('Parses Open-Meteo JSON response correctly', () {
      final json = {
        'current_weather': {
          'temperature': 28.5,
          'weathercode': 0,
        },
        'hourly': {
          'precipitation_probability': [10, 20, 30],
        },
      };

      final model = WeatherModel.fromOpenMeteoJson(json);
      expect(model.temperature, 28.5);
      expect(model.weatherCode, 0);
      expect(model.precipitationProbability, 10);
      expect(model.conditionName, 'Clear Sky');
      expect(model.conditionIcon, Icons.wb_sunny);
      expect(model.recommendationLabel, 'Great day for a trek');
    });

    test('Recommends raincoat when precipitation probability >= 50', () {
      const model = WeatherModel(
        temperature: 22.0,
        weatherCode: 61,
        precipitationProbability: 75,
      );

      expect(model.recommendationLabel, 'Pack a raincoat');
      expect(model.conditionName, 'Rainy');
      expect(model.conditionIcon, Icons.grain);
    });

    test('Recommends layer up when temperature <= 10', () {
      const model = WeatherModel(
        temperature: 8.0,
        weatherCode: 3,
        precipitationProbability: 20,
      );

      expect(model.recommendationLabel, 'Cold day ahead — layer up');
      expect(model.conditionName, 'Partly Cloudy');
    });

    test('Recommends good trekking weather for mild temperature', () {
      const model = WeatherModel(
        temperature: 18.0,
        weatherCode: 1,
        precipitationProbability: 15,
      );

      expect(model.recommendationLabel, 'Good trekking weather');
    });
  });
}
