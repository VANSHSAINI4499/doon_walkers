import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WeatherModel {
  final double temperature;
  final int weatherCode;
  final int precipitationProbability;
  final double windSpeed;

  const WeatherModel({
    required this.temperature,
    required this.weatherCode,
    required this.precipitationProbability,
    this.windSpeed = 0.0,
  });

  factory WeatherModel.fromOpenMeteoJson(Map<String, dynamic> json) {
    final current = json['current_weather'] as Map<String, dynamic>? ?? {};
    final hourly = json['hourly'] as Map<String, dynamic>? ?? {};

    final precipList =
        (hourly['precipitation_probability'] as List<dynamic>?) ?? [];
    final int currentPrecip =
        precipList.isNotEmpty ? (precipList.first as num).toInt() : 0;

    return WeatherModel(
      temperature: (current['temperature'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (current['weathercode'] as num?)?.toInt() ?? 0,
      precipitationProbability: currentPrecip,
      windSpeed: (current['windspeed'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory WeatherModel.fromJson(Map<String, dynamic> json) =>
      WeatherModel.fromOpenMeteoJson(json);

  String get recommendationLabel {
    if (precipitationProbability >= 50) {
      return 'Pack a raincoat';
    } else if (temperature >= 25) {
      return 'Great day for a trek';
    } else if (temperature <= 10) {
      return 'Cold day ahead — layer up';
    } else {
      return 'Good trekking weather';
    }
  }

  String get conditionName {
    switch (weatherCode) {
      case 0:
        return 'Clear Sky';
      case 1:
      case 2:
      case 3:
        return 'Partly Cloudy';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rainy';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Showers';
      case 85:
      case 86:
        return 'Snow Showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Fair';
    }
  }

  IconData get conditionIcon {
    switch (weatherCode) {
      case 0:
        return LucideIcons.sun;
      case 1:
      case 2:
      case 3:
        return LucideIcons.cloud;
      case 45:
      case 48:
        return LucideIcons.cloudFog;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return LucideIcons.cloudRain;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return LucideIcons.cloudSnow;
      case 95:
      case 96:
      case 99:
        return LucideIcons.cloudLightning;
      default:
        return LucideIcons.cloudSun;
    }
  }
}
