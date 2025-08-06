import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class WeatherData {
  final double temperature;
  final String condition;
  final String description;
  final double humidity;
  final double windSpeed;
  final double windDirection;
  final double pressure;
  final double visibility;
  final int cloudiness;
  final String icon;
  final DateTime timestamp;
  final String cityName;

  WeatherData({
    required this.temperature,
    required this.condition,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.pressure,
    required this.visibility,
    required this.cloudiness,
    required this.icon,
    required this.timestamp,
    required this.cityName,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['main']['temp'] - 273.15), // Kelvin to Celsius
      condition: json['weather'][0]['main'],
      description: json['weather'][0]['description'],
      humidity: json['main']['humidity'].toDouble(),
      windSpeed: json['wind']['speed'].toDouble(),
      windDirection: json['wind']['deg']?.toDouble() ?? 0.0,
      pressure: json['main']['pressure'].toDouble(),
      visibility:
          (json['visibility'] ?? 10000).toDouble() / 1000, // meters to km
      cloudiness: json['clouds']['all'],
      icon: json['weather'][0]['icon'],
      timestamp: DateTime.now(),
      cityName: json['name'] ?? '',
    );
  }
}

class WeatherForecast {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final String condition;
  final String icon;
  final double precipitationChance;

  WeatherForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
    required this.icon,
    required this.precipitationChance,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      date: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      tempMin: (json['temp']['min'] - 273.15),
      tempMax: (json['temp']['max'] - 273.15),
      condition: json['weather'][0]['main'],
      icon: json['weather'][0]['icon'],
      precipitationChance: (json['pop'] ?? 0.0) * 100,
    );
  }
}

class WeatherAlert {
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String severity;
  final String event;

  WeatherAlert({
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.severity,
    required this.event,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      title: json['event'] ?? '',
      description: json['description'] ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(json['start'] * 1000),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['end'] * 1000),
      severity: json['severity'] ?? 'moderate',
      event: json['event'] ?? '',
    );
  }
}

class HordWeatherService {
  final Dio _dio = Dio();

  // Utilisez votre propre clé API OpenWeatherMap ou intégrez avec HordWeather
  static const String _apiKey = 'YOUR_OPENWEATHER_API_KEY';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  /// Obtient les données météo actuelles pour une position
  Future<WeatherData?> getCurrentWeather(LatLng position) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/weather',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'appid': _apiKey,
          'lang': 'fr',
        },
      );

      if (response.statusCode == 200) {
        return WeatherData.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des données météo: $e');
    }
    return null;
  }

  /// Obtient les prévisions météo pour 7 jours
  Future<List<WeatherForecast>> getWeatherForecast(LatLng position) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/onecall',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'appid': _apiKey,
          'exclude': 'minutely,hourly',
          'lang': 'fr',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> dailyData = response.data['daily'];
        return dailyData.map((json) => WeatherForecast.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des prévisions: $e');
    }
    return [];
  }

  /// Obtient les alertes météo
  Future<List<WeatherAlert>> getWeatherAlerts(LatLng position) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/onecall',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'appid': _apiKey,
          'exclude': 'current,minutely,hourly,daily',
          'lang': 'fr',
        },
      );

      if (response.statusCode == 200) {
        final alertsData = response.data['alerts'];
        if (alertsData != null) {
          return (alertsData as List)
              .map((json) => WeatherAlert.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des alertes: $e');
    }
    return [];
  }

  /// Vérifie si les conditions météo sont favorables pour un trajet
  bool isWeatherSuitableForRoute(WeatherData weather, String transportMode) {
    switch (transportMode) {
      case 'walking':
        // Éviter la marche par temps de pluie forte ou neige
        return !['Rain', 'Snow', 'Thunderstorm'].contains(weather.condition) ||
            weather.description.contains('light');

      case 'cycling':
        // Éviter le vélo par mauvais temps ou vent fort
        return !['Rain', 'Snow', 'Thunderstorm'].contains(weather.condition) &&
            weather.windSpeed < 10; // m/s

      case 'driving':
        // La conduite est généralement possible sauf conditions extrêmes
        return weather.visibility > 1 && // > 1km de visibilité
            !weather.description.contains('heavy');

      default:
        return true;
    }
  }

  /// Suggère le meilleur mode de transport selon la météo
  String suggestTransportMode(WeatherData weather) {
    if (weather.condition == 'Clear' && weather.windSpeed < 5) {
      return 'cycling'; // Temps idéal pour le vélo
    } else if (['Rain', 'Snow', 'Thunderstorm'].contains(weather.condition)) {
      return 'driving'; // Utiliser la voiture par mauvais temps
    } else {
      return 'walking'; // Temps correct pour marcher
    }
  }

  /// Formate la température
  String formatTemperature(double temperature) {
    return '${temperature.round()}°C';
  }

  /// Obtient l'icône météo
  String getWeatherIcon(String condition, bool isDay) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return isDay ? '☀️' : '🌙';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  void dispose() {
    _dio.close();
  }
}
