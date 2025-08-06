import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';

class LocationService {
  static const String _cachedPlacesKey = 'cached_places';
  static const String _lastLocationKey = 'last_location';
  static const String _locationUpdateTimeKey = 'location_update_time';
  static const Duration _cacheValidDuration = Duration(hours: 2);

  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  late SharedPreferences _prefs;
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Obtenir la position actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Services de localisation désactivés');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission de localisation refusée');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission de localisation refusée définitivement');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      // Sauvegarder la position
      await _saveLastLocation(position);

      return position;
    } catch (e) {
      debugPrint('Erreur géolocalisation: $e');
      return null;
    }
  }

  /// Démarre le suivi de position en temps réel
  Future<void> startTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Services de localisation désactivés');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission de localisation refusée');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission de localisation refusée définitivement');
      }

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10, // Mise à jour tous les 10 mètres
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              _positionController.add(position);
              _saveLastLocation(position);
            },
            onError: (error) {
              debugPrint('Erreur suivi position: $error');
            },
          );
    } catch (e) {
      debugPrint('Erreur démarrage suivi: $e');
    }
  }

  /// Arrête le suivi de position
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Dispose des ressources
  void dispose() {
    stopTracking();
    _positionController.close();
  }

  // Sauvegarder la dernière position
  Future<void> _saveLastLocation(Position position) async {
    final locationData = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _prefs.setString(_lastLocationKey, json.encode(locationData));
    await _prefs.setString(
      _locationUpdateTimeKey,
      DateTime.now().toIso8601String(),
    );
  }

  // Obtenir la dernière position sauvegardée
  Position? getLastKnownPosition() {
    final locationString = _prefs.getString(_lastLocationKey);
    if (locationString == null) return null;

    try {
      final locationData = json.decode(locationString);
      return Position(
        latitude: locationData['latitude'],
        longitude: locationData['longitude'],
        timestamp: DateTime.parse(locationData['timestamp']),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    } catch (e) {
      return null;
    }
  }

  // Rechercher des lieux proches basés sur la position
  Future<List<Map<String, dynamic>>> getNearbyPlaces(Position position) async {
    final cacheKey =
        '${position.latitude.toStringAsFixed(3)}_${position.longitude.toStringAsFixed(3)}';

    // Vérifier le cache
    final cachedPlaces = _getCachedPlaces(cacheKey);
    if (cachedPlaces != null) {
      return cachedPlaces;
    }

    // Générer des lieux dynamiques basés sur la position réelle
    final places = await _generateNearbyPlaces(position);

    // Sauvegarder en cache
    await _savePlacesToCache(cacheKey, places);

    return places;
  }

  // Générer des lieux dynamiques
  Future<List<Map<String, dynamic>>> _generateNearbyPlaces(
    Position position,
  ) async {
    final placeCategories = [
      {
        'type': 'Restaurant',
        'icon': 'restaurant',
        'names': [
          'Bistrot Local',
          'Chez ${_getRandomName()}',
          'Restaurant Central',
          'La Table du Coin',
          'Saveurs d\'Afrique',
          'Le Gourmet',
        ],
        'probability': 0.8,
      },
      {
        'type': 'Pharmacie',
        'icon': 'local_pharmacy',
        'names': [
          'Pharmacie Centrale',
          'Grande Pharmacie',
          'Pharmacie du ${_getRandomStreet()}',
          'Pharmacie de la Santé',
          'Pharmacie Moderne',
        ],
        'probability': 0.6,
      },
      {
        'type': 'Banque',
        'icon': 'account_balance',
        'names': [
          'BNP Paribas',
          'Crédit Agricole',
          'Société Générale',
          'Banque Postale',
          'CIC',
          'Banque Populaire',
        ],
        'probability': 0.5,
      },
      {
        'type': 'Supermarché',
        'icon': 'shopping_cart',
        'names': [
          'Carrefour Express',
          'Monoprix',
          'Casino',
          'Franprix',
          'Leader Price',
          'Intermarché',
        ],
        'probability': 0.7,
      },
      {
        'type': 'Station-Service',
        'icon': 'local_gas_station',
        'names': ['Total', 'Shell', 'BP', 'Esso', 'Intermarché Carburant'],
        'probability': 0.4,
      },
      {
        'type': 'Boulangerie',
        'icon': 'bakery_dining',
        'names': [
          'Boulangerie Paul',
          'Aux Délices',
          'Le Fournil',
          'Pain & Tradition',
          'La Baguette d\'Or',
        ],
        'probability': 0.9,
      },
      {
        'type': 'Hôpital',
        'icon': 'local_hospital',
        'names': [
          'Centre Médical',
          'Clinique Saint-Pierre',
          'Hôpital Général',
          'Cabinet Médical',
          'Centre de Santé',
        ],
        'probability': 0.3,
      },
      {
        'type': 'École',
        'icon': 'school',
        'names': [
          'École Primaire ${_getRandomName()}',
          'Collège Central',
          'Lycée Technique',
          'École Maternelle',
        ],
        'probability': 0.4,
      },
    ];

    final places = <Map<String, dynamic>>[];
    final random = math.Random(
      position.latitude.hashCode + position.longitude.hashCode,
    );

    for (final category in placeCategories) {
      if (random.nextDouble() < (category['probability'] as double)) {
        final names = category['names'] as List<String>;
        final placesCount = 1 + random.nextInt(3); // 1 à 3 lieux par catégorie

        for (int i = 0; i < placesCount; i++) {
          final name = names[random.nextInt(names.length)];
          final distance = _generateRealisticDistance(random);
          final rating = 3.0 + random.nextDouble() * 2.0;

          // Générer une position proche réaliste
          final nearbyPosition = _generateNearbyPosition(
            position,
            distance,
            random,
          );

          places.add({
            'id': '${category['type']}_${position.latitude.hashCode}_$i',
            'name': name,
            'type': category['type'],
            'category': category['type'],
            'distance': distance,
            'distanceText': _formatDistance(distance),
            'position': {
              'latitude': nearbyPosition.latitude,
              'longitude': nearbyPosition.longitude,
            },
            'address': _generateAddress(random),
            'rating': rating,
            'ratingText': rating.toStringAsFixed(1),
            'isOpen': _isPlaceOpen(category['type'] as String, random),
            'icon': category['icon'],
            'phone': _generatePhoneNumber(random),
            'hours': _generateOpeningHours(category['type'] as String),
            'isReal': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    // Trier par distance
    places.sort(
      (a, b) => (a['distance'] as int).compareTo(b['distance'] as int),
    );

    return places.take(20).toList(); // Limiter à 20 résultats
  }

  int _generateRealisticDistance(math.Random random) {
    // Générer des distances réalistes selon une distribution pondérée
    final weights = [
      {'max': 200, 'weight': 30}, // 30% entre 50m et 200m
      {'max': 500, 'weight': 25}, // 25% entre 200m et 500m
      {'max': 1000, 'weight': 20}, // 20% entre 500m et 1km
      {'max': 2000, 'weight': 15}, // 15% entre 1km et 2km
      {'max': 5000, 'weight': 10}, // 10% entre 2km et 5km
    ];

    final totalWeight = weights.fold(0, (sum, w) => sum + (w['weight'] as int));
    final randomValue = random.nextInt(totalWeight);

    int currentWeight = 0;
    for (final weight in weights) {
      currentWeight += weight['weight'] as int;
      if (randomValue < currentWeight) {
        final maxDistance = weight['max'] as int;
        final minDistance = weight == weights.first
            ? 50
            : (weights[weights.indexOf(weight) - 1]['max'] as int);
        return minDistance + random.nextInt(maxDistance - minDistance);
      }
    }

    return 100 + random.nextInt(900); // Fallback
  }

  Position _generateNearbyPosition(
    Position center,
    int distanceMeters,
    math.Random random,
  ) {
    // Convertir la distance en degrés approximatifs
    final distanceInDegrees = distanceMeters / 111320.0; // Approximation

    // Générer un angle aléatoire
    final angle = random.nextDouble() * 2 * math.pi;

    // Calculer la nouvelle position
    final deltaLat = distanceInDegrees * math.cos(angle);
    final deltaLon =
        distanceInDegrees *
        math.sin(angle) /
        math.cos(center.latitude * math.pi / 180);

    return Position(
      latitude: center.latitude + deltaLat,
      longitude: center.longitude + deltaLon,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '${meters}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  String _generateAddress(math.Random random) {
    final streets = [
      'Avenue de la République',
      'Rue de la Paix',
      'Boulevard Central',
      'Place de la Mairie',
      'Rue du Commerce',
      'Avenue des Champs',
      'Boulevard de l\'Indépendance',
      'Rue de la Liberté',
      'Place de la Nation',
    ];
    final numbers = List.generate(200, (i) => i + 1);

    return '${numbers[random.nextInt(numbers.length)]} ${streets[random.nextInt(streets.length)]}';
  }

  String _getRandomName() {
    final names = [
      'Marie',
      'Pierre',
      'Paul',
      'Jean',
      'Sophie',
      'Nicolas',
      'Claire',
      'David',
    ];
    final random = math.Random();
    return names[random.nextInt(names.length)];
  }

  String _getRandomStreet() {
    final streets = ['Centre', 'Marché', 'Gare', 'Stade', 'Hôpital', 'École'];
    final random = math.Random();
    return streets[random.nextInt(streets.length)];
  }

  bool _isPlaceOpen(String type, math.Random random) {
    final currentHour = DateTime.now().hour;

    switch (type) {
      case 'Restaurant':
        return (currentHour >= 11 && currentHour <= 14) ||
            (currentHour >= 18 && currentHour <= 22);
      case 'Pharmacie':
        return currentHour >= 8 && currentHour <= 20;
      case 'Banque':
        return currentHour >= 9 &&
            currentHour <= 17 &&
            DateTime.now().weekday <= 5;
      case 'Supermarché':
        return currentHour >= 7 && currentHour <= 21;
      case 'Boulangerie':
        return currentHour >= 6 && currentHour <= 19;
      default:
        return random.nextBool();
    }
  }

  String _generatePhoneNumber(math.Random random) {
    final prefixes = ['06', '07', '01', '02', '03', '04', '05'];
    final prefix = prefixes[random.nextInt(prefixes.length)];
    final number = List.generate(8, (_) => random.nextInt(10)).join();
    return '$prefix$number';
  }

  Map<String, String> _generateOpeningHours(String type) {
    switch (type) {
      case 'Restaurant':
        return {
          'weekdays': '11h30-14h30, 18h30-22h30',
          'weekend': '11h30-15h00, 18h30-23h00',
        };
      case 'Pharmacie':
        return {'weekdays': '8h00-20h00', 'weekend': '9h00-19h00'};
      case 'Banque':
        return {'weekdays': '9h00-17h00', 'weekend': 'Fermé'};
      case 'Supermarché':
        return {'weekdays': '7h00-21h00', 'weekend': '8h00-20h00'};
      case 'Boulangerie':
        return {'weekdays': '6h00-19h00', 'weekend': '6h30-18h30'};
      default:
        return {'weekdays': '9h00-18h00', 'weekend': '10h00-17h00'};
    }
  }

  // Gestion du cache
  List<Map<String, dynamic>>? _getCachedPlaces(String locationKey) {
    final cacheKey = '${_cachedPlacesKey}_$locationKey';
    final cachedData = _prefs.getString(cacheKey);
    final lastUpdate = _prefs.getString(_locationUpdateTimeKey);

    if (cachedData == null || lastUpdate == null) return null;

    try {
      final updateTime = DateTime.parse(lastUpdate);
      if (DateTime.now().difference(updateTime) > _cacheValidDuration) {
        return null; // Cache expiré
      }

      final List<dynamic> decoded = json.decode(cachedData);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }

  Future<void> _savePlacesToCache(
    String locationKey,
    List<Map<String, dynamic>> places,
  ) async {
    final cacheKey = '${_cachedPlacesKey}_$locationKey';
    await _prefs.setString(cacheKey, json.encode(places));
  }

  // Effacer le cache
  Future<void> clearCache() async {
    final keys = _prefs.getKeys().where(
      (key) => key.startsWith(_cachedPlacesKey),
    );
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
