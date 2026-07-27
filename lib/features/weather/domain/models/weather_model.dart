import 'package:flutter/material.dart';

class WeatherModel {
  final double temperature;
  final int weatherCode;
  final int precipitationProbability;

  const WeatherModel({
    required this.temperature,
    required this.weatherCode,
    required this.precipitationProbability,
  });

  factory WeatherModel.fromOpenMeteoJson(Map<String, dynamic> json) {
    final currentWeather =
        json['current_weather'] as Map<String, dynamic>? ?? {};
    final hourly = json['hourly'] as Map<String, dynamic>? ?? {};
    final precipList = hourly['precipitation_probability'] as List<dynamic>?;

    final temp = (currentWeather['temperature'] as num?)?.toDouble() ?? 20.0;
    final code = (currentWeather['weathercode'] as num?)?.toInt() ?? 0;
    final precip = precipList != null && precipList.isNotEmpty
        ? (precipList.first as num).toInt()
        : 0;

    return WeatherModel(
      temperature: temp,
      weatherCode: code,
      precipitationProbability: precip,
    );
  }

  /// Contextual recommendation label based on temperature and precipitation.
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

  /// Human-readable weather condition name.
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
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return 'Rainy';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'Snowy';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Fair';
    }
  }

  /// Icon representing the weather condition using standard Material icons.
  IconData get conditionIcon {
    switch (weatherCode) {
      case 0:
        return Icons.wb_sunny;
      case 1:
      case 2:
      case 3:
        return Icons.cloud;
      case 45:
      case 48:
        return Icons.cloud_queue;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.grain;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return Icons.ac_unit;
      case 95:
      case 96:
      case 99:
        return Icons.flash_on;
      default:
        return Icons.wb_sunny_outlined;
    }
  }
}
