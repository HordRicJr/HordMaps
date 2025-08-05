import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

class CacheService extends ChangeNotifier {
  static CacheService? _instance;
  static SharedPreferences? _prefs;

  CacheService._();

  static CacheService get instance {
    _instance ??= CacheService._();
    return _instance!;
  }

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Cache des lieux proches
  static const String _nearbyPlacesKey = 'nearby_places';
  static const String _lastLocationKey = 'last_location';
  static const String _cacheTimestampKey = 'cache_timestamp';

  // Durée de validité du cache (30 minutes)
  static const Duration cacheValidityDuration = Duration(minutes: 30);

  /// Sauvegarde les lieux proches dans le cache
  Future<void> cacheNearbyPlaces(
    List<Map<String, dynamic>> places,
    double latitude,
    double longitude,
  ) async {
    try {
      final cacheData = {
        'places': places,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _prefs?.setString(_nearbyPlacesKey, jsonEncode(cacheData));
      await _prefs?.setDouble('${_lastLocationKey}_lat', latitude);
      await _prefs?.setDouble('${_lastLocationKey}_lng', longitude);
      await _prefs?.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde du cache: $e');
    }
  }

  /// Récupère les lieux proches depuis le cache
  Future<List<Map<String, dynamic>>?> getCachedNearbyPlaces(
    double latitude,
    double longitude,
  ) async {
    try {
      final cachedDataString = _prefs?.getString(_nearbyPlacesKey);
      if (cachedDataString == null) return null;

      final cachedData = jsonDecode(cachedDataString) as Map<String, dynamic>;
      final timestamp = cachedData['timestamp'] as int;
      final cachedLat = cachedData['latitude'] as double;
      final cachedLng = cachedData['longitude'] as double;

      // Vérifier si le cache est encore valide
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > cacheValidityDuration.inMilliseconds) {
        return null;
      }

      // Vérifier si la position n'a pas trop changé (rayon de 500m)
      final distance = _calculateDistance(
        latitude,
        longitude,
        cachedLat,
        cachedLng,
      );
      if (distance > 500) {
        return null;
      }

      final places = (cachedData['places'] as List)
          .map((place) => Map<String, dynamic>.from(place))
          .toList();

      return places;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du cache: $e');
      return null;
    }
  }

  /// Cache des événements récents
  static const String _recentEventsKey = 'recent_events';

  Future<void> cacheRecentEvents(List<Map<String, dynamic>> events) async {
    try {
      final cacheData = {
        'events': events,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await _prefs?.setString(_recentEventsKey, jsonEncode(cacheData));
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde des événements: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> getCachedRecentEvents() async {
    try {
      final cachedDataString = _prefs?.getString(_recentEventsKey);
      if (cachedDataString == null) return null;

      final cachedData = jsonDecode(cachedDataString) as Map<String, dynamic>;
      final timestamp = cachedData['timestamp'] as int;

      // Cache valide pendant 1 heure
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > Duration(hours: 1).inMilliseconds) {
        return null;
      }

      final events = (cachedData['events'] as List)
          .map((event) => Map<String, dynamic>.from(event))
          .toList();

      return events;
    } catch (e) {
      debugPrint('Erreur lors de la récupération des événements: $e');
      return null;
    }
  }

  /// Cache des catégories
  static const String _categoriesKey = 'categories_data';

  Future<void> cacheCategoriesData(
    String categoryId,
    List<Map<String, dynamic>> places,
  ) async {
    try {
      final cacheData = {
        'places': places,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await _prefs?.setString(
        '${_categoriesKey}_$categoryId',
        jsonEncode(cacheData),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde de la catégorie: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> getCachedCategoriesData(
    String categoryId,
  ) async {
    try {
      final cachedDataString = _prefs?.getString(
        '${_categoriesKey}_$categoryId',
      );
      if (cachedDataString == null) return null;

      final cachedData = jsonDecode(cachedDataString) as Map<String, dynamic>;
      final timestamp = cachedData['timestamp'] as int;

      // Cache valide pendant 2 heures
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > Duration(hours: 2).inMilliseconds) {
        return null;
      }

      final places = (cachedData['places'] as List)
          .map((place) => Map<String, dynamic>.from(place))
          .toList();

      return places;
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la catégorie: $e');
      return null;
    }
  }

  /// Préférences utilisateur
  Future<void> saveUserPreference(String key, dynamic value) async {
    try {
      if (value is String) {
        await _prefs?.setString('user_pref_$key', value);
      } else if (value is int) {
        await _prefs?.setInt('user_pref_$key', value);
      } else if (value is double) {
        await _prefs?.setDouble('user_pref_$key', value);
      } else if (value is bool) {
        await _prefs?.setBool('user_pref_$key', value);
      } else {
        await _prefs?.setString('user_pref_$key', jsonEncode(value));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde de la préférence: $e');
    }
  }

  T? getUserPreference<T>(String key, T defaultValue) {
    try {
      final prefKey = 'user_pref_$key';

      if (T == String) {
        return _prefs?.getString(prefKey) as T? ?? defaultValue;
      } else if (T == int) {
        return _prefs?.getInt(prefKey) as T? ?? defaultValue;
      } else if (T == double) {
        return _prefs?.getDouble(prefKey) as T? ?? defaultValue;
      } else if (T == bool) {
        return _prefs?.getBool(prefKey) as T? ?? defaultValue;
      } else {
        final stringValue = _prefs?.getString(prefKey);
        if (stringValue != null) {
          return jsonDecode(stringValue) as T;
        }
        return defaultValue;
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la préférence: $e');
      return defaultValue;
    }
  }

  /// Nettoyage du cache
  Future<void> clearCache() async {
    try {
      await _prefs?.remove(_nearbyPlacesKey);
      await _prefs?.remove(_recentEventsKey);

      // Supprimer tous les caches de catégories
      final keys = _prefs?.getKeys() ?? <String>{};
      for (final key in keys) {
        if (key.startsWith(_categoriesKey)) {
          await _prefs?.remove(key);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors du nettoyage du cache: $e');
    }
  }

  /// Calcul de distance entre deux points (en mètres)
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000; // Rayon de la Terre en mètres
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a =
        (dLat / 2).sin() * (dLat / 2).sin() +
        lat1.toRadians().cos() *
            lat2.toRadians().cos() *
            (dLng / 2).sin() *
            (dLng / 2).sin();

    final double c = 2 * (a.sqrt().asin());
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  /// Cache des routes récentes
  static const String _recentRoutesKey = 'recent_routes';

  static Future<void> saveRecentRoute(RecentRoute route) async {
    try {
      final routes = await getRecentRoutes();

      // Supprimer les doublons basés sur les mêmes points de départ/arrivée
      routes.removeWhere(
        (r) =>
            r.destination == route.destination &&
            r.departure == route.departure,
      );

      // Ajouter la nouvelle route en tête
      routes.insert(0, route);

      // Limiter à 20 routes récentes
      if (routes.length > 20) {
        routes.removeRange(20, routes.length);
      }

      final jsonList = routes.map((r) => r.toJson()).toList();
      await _prefs?.setString(_recentRoutesKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Erreur sauvegarde route récente: $e');
    }
  }

  static Future<List<RecentRoute>> getRecentRoutes() async {
    try {
      final jsonString = _prefs?.getString(_recentRoutesKey);

      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => RecentRoute.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erreur récupération routes récentes: $e');
      return [];
    }
  }

  /// Méthodes génériques de cache pour l'OSM Routing Service
  Future<Map<String, dynamic>?> getFromCache(String key) async {
    try {
      final cachedDataString = _prefs?.getString('cache_$key');
      if (cachedDataString == null) return null;

      final cachedData = jsonDecode(cachedDataString) as Map<String, dynamic>;
      final timestamp = cachedData['timestamp'] as int;

      // Vérifier si le cache est encore valide (15 minutes pour les routes)
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      const routeCacheValidityMs = 15 * 60 * 1000; // 15 minutes

      if (cacheAge > routeCacheValidityMs) {
        await _prefs?.remove('cache_$key');
        return null;
      }

      return cachedData['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du cache: $e');
      return null;
    }
  }

  /// Sauvegarde des données dans le cache générique
  Future<void> saveToCache(String key, Map<String, dynamic> data) async {
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _prefs?.setString('cache_$key', jsonEncode(cacheData));
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde du cache: $e');
    }
  }
}

extension on double {
  double toRadians() => this * (3.141592653589793 / 180.0);
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double sqrt() => math.sqrt(this);
  double asin() => math.asin(this);
}

class RecentRoute {
  final String id;
  final String departure;
  final String destination;
  final double? departureLatitude;
  final double? departureLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final double distance; // en mètres
  final int duration; // en secondes
  final DateTime timestamp;
  final String routeType;
  final String? vehicleType;

  RecentRoute({
    required this.id,
    required this.departure,
    required this.destination,
    this.departureLatitude,
    this.departureLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    required this.distance,
    required this.duration,
    required this.timestamp,
    required this.routeType,
    this.vehicleType,
  });

  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.round()} m';
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  void updateDistanceFromCurrentLocation(double currentLat, double currentLng) {
    if (destinationLatitude != null && destinationLongitude != null) {
      // Distance calculée si nécessaire, pour l'instant on garde la distance d'origine
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'departure': departure,
      'destination': destination,
      'departureLatitude': departureLatitude,
      'departureLongitude': departureLongitude,
      'destinationLatitude': destinationLatitude,
      'destinationLongitude': destinationLongitude,
      'distance': distance,
      'duration': duration,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'routeType': routeType,
      'vehicleType': vehicleType,
    };
  }

  factory RecentRoute.fromJson(Map<String, dynamic> json) {
    return RecentRoute(
      id: json['id'] as String,
      departure: json['departure'] as String,
      destination: json['destination'] as String,
      departureLatitude: json['departureLatitude'] as double?,
      departureLongitude: json['departureLongitude'] as double?,
      destinationLatitude: json['destinationLatitude'] as double?,
      destinationLongitude: json['destinationLongitude'] as double?,
      distance: (json['distance'] as num).toDouble(),
      duration: json['duration'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      routeType: json['routeType'] as String,
      vehicleType: json['vehicleType'] as String?,
    );
  }
}
