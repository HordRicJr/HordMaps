import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'cache_service.dart';
import '../models/navigation_models.dart';

/// Service de routing avancé avec OpenStreetMap et cache
class OpenStreetMapRoutingService {
  static final Dio _dio = Dio();
  static const String _orsUrl =
      'https://api.openrouteservice.org/v2/directions';
  static const String _osrmUrl = 'https://router.project-osrm.org/route/v1';

  // Clés de cache
  static const String _routeCacheKey = 'cached_routes';
  static const Duration _cacheValidDuration = Duration(minutes: 15);

  /// Profils de transport disponibles
  static const Map<String, Map<String, dynamic>> transportProfiles = {
    'driving': {
      'osrm': 'driving',
      'ors': 'driving-car',
      'icon': Icons.directions_car,
      'name': 'Voiture',
      'speed': 50.0, // km/h moyenne
    },
    'motorcycle': {
      'osrm': 'driving',
      'ors': 'driving-car',
      'icon': Icons.motorcycle,
      'name': 'Moto',
      'speed': 45.0,
    },
    'walking': {
      'osrm': 'foot',
      'ors': 'foot-walking',
      'icon': Icons.directions_walk,
      'name': 'À pied',
      'speed': 5.0,
    },
    'cycling': {
      'osrm': 'cycling',
      'ors': 'cycling-regular',
      'icon': Icons.directions_bike,
      'name': 'Vélo',
      'speed': 15.0,
    },
    'transit': {
      'osrm': null,
      'ors': null,
      'icon': Icons.directions_bus,
      'name': 'Transport public',
      'speed': 25.0,
    },
  };

  /// Calcule un itinéraire avec fallbacks multiples
  static Future<RouteResult> calculateRoute({
    required LatLng start,
    required LatLng end,
    required String transportMode,
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool includeTraffic = true,
  }) async {
    // Vérifier le cache d'abord
    final cacheKey =
        '${start.latitude},${start.longitude}-${end.latitude},${end.longitude}-$transportMode';
    final cachedRoute = await _getCachedRoute(cacheKey);
    if (cachedRoute != null) {
      return cachedRoute;
    }

    try {
      // Essayer OSRM d'abord (gratuit et rapide)
      final osrmResult = await _calculateOSRMRoute(start, end, transportMode);
      if (osrmResult != null) {
        await _cacheRoute(cacheKey, osrmResult);
        return osrmResult;
      }

      // Fallback sur OpenRouteService
      final orsResult = await _calculateORSRoute(start, end, transportMode);
      if (orsResult != null) {
        await _cacheRoute(cacheKey, orsResult);
        return orsResult;
      }

      // Fallback final : route directe
      return _createDirectRoute(start, end, transportMode);
    } catch (e) {
      debugPrint('Erreur de calcul d\'itinéraire: $e');
      return _createDirectRoute(start, end, transportMode);
    }
  }

  /// Calcul avec OSRM (gratuit)
  static Future<RouteResult?> _calculateOSRMRoute(
    LatLng start,
    LatLng end,
    String transportMode,
  ) async {
    try {
      final profile = transportProfiles[transportMode]?['osrm'];
      if (profile == null) return null;

      final url =
          '$_osrmUrl/$profile/${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
      final response = await _dio.get(
        url,
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
          'annotations': 'true',
        },
      );

      if (response.statusCode == 200) {
        return _parseOSRMResponse(response.data, transportMode);
      }
    } catch (e) {
      debugPrint('Erreur OSRM: $e');
    }
    return null;
  }

  /// Calcul avec OpenRouteService
  static Future<RouteResult?> _calculateORSRoute(
    LatLng start,
    LatLng end,
    String transportMode,
  ) async {
    try {
      final profile = transportProfiles[transportMode]?['ors'];
      if (profile == null) return null;

      final response = await _dio.post(
        '$_orsUrl/$profile/geojson',
        data: {
          'coordinates': [
            [start.longitude, start.latitude],
            [end.longitude, end.latitude],
          ],
          'instructions': true,
          'units': 'km',
        },
        options: Options(
          headers: {
            'Accept': 'application/json, application/geo+json',
            'Content-Type': 'application/json; charset=utf-8',
          },
        ),
      );

      if (response.statusCode == 200) {
        return _parseORSResponse(response.data, transportMode);
      }
    } catch (e) {
      debugPrint('Erreur ORS: $e');
    }
    return null;
  }

  /// Parse la réponse OSRM
  static RouteResult _parseOSRMResponse(
    Map<String, dynamic> data,
    String transportMode,
  ) {
    final route = data['routes'][0];
    final geometry = route['geometry']['coordinates'] as List;

    final points = geometry
        .map<LatLng>(
          (coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()),
        )
        .toList();

    final steps = <RouteStep>[];
    final legs = route['legs'] as List;

    for (final leg in legs) {
      final legSteps = leg['steps'] as List;
      for (final step in legSteps) {
        steps.add(
          RouteStep(
            instruction: step['maneuver']['instruction'] ?? 'Continuer',
            distance: (step['distance'] ?? 0.0).toDouble() / 1000, // en km
            duration: Duration(seconds: (step['duration'] ?? 0.0).toInt()),
            location: LatLng(
              step['maneuver']['location'][1].toDouble(),
              step['maneuver']['location'][0].toDouble(),
            ),
            type: step['maneuver']['type'] ?? 'straight',
          ),
        );
      }
    }

    return RouteResult(
      points: points,
      steps: steps,
      totalDistance: (route['distance'] ?? 0.0).toDouble() / 1000,
      estimatedDuration: Duration(seconds: (route['duration'] ?? 0.0).toInt()),
    );
  }

  /// Parse la réponse OpenRouteService
  static RouteResult _parseORSResponse(
    Map<String, dynamic> data,
    String transportMode,
  ) {
    final feature = data['features'][0];
    final geometry = feature['geometry']['coordinates'] as List;
    final properties = feature['properties'];

    final points = geometry
        .map<LatLng>(
          (coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()),
        )
        .toList();

    final steps = <RouteStep>[];
    if (properties['segments'] != null) {
      final segments = properties['segments'] as List;
      for (final segment in segments) {
        if (segment['steps'] != null) {
          final segmentSteps = segment['steps'] as List;
          for (final step in segmentSteps) {
            steps.add(
              RouteStep(
                instruction: step['instruction'] ?? 'Continuer',
                distance: (step['distance'] ?? 0.0).toDouble() / 1000,
                duration: Duration(seconds: (step['duration'] ?? 0.0).toInt()),
                location: points[step['way_points'][0] ?? 0],
                type: step['type']?.toString() ?? 'straight',
              ),
            );
          }
        }
      }
    }

    return RouteResult(
      points: points,
      steps: steps,
      totalDistance:
          (properties['summary']['distance'] ?? 0.0).toDouble() / 1000,
      estimatedDuration: Duration(
        seconds: (properties['summary']['duration'] ?? 0.0).toInt(),
      ),
    );
  }

  /// Crée une route directe en cas d'échec
  static RouteResult _createDirectRoute(
    LatLng start,
    LatLng end,
    String transportMode,
  ) {
    final points = [start, end];
    final distance = const Distance().as(LengthUnit.Kilometer, start, end);
    final speed = transportProfiles[transportMode]?['speed'] ?? 50.0;
    final duration = (distance / speed) * 3600; // en secondes

    return RouteResult(
      points: points,
      steps: [
        RouteStep(
          instruction: 'Dirigez-vous vers la destination',
          distance: distance,
          duration: Duration(seconds: duration.toInt()),
          location: start,
          type: 'straight',
        ),
      ],
      totalDistance: distance,
      estimatedDuration: Duration(seconds: duration.toInt()),
    );
  }

  /// Récupère les données de trafic en temps réel
  static Future<Map<String, dynamic>> getTrafficData(
    List<LatLng> routePoints,
  ) async {
    final cacheKey = 'traffic_${routePoints.length}_${DateTime.now().hour}';
    final cached = await CacheService.instance.getFromCache(cacheKey);

    if (cached != null &&
        DateTime.now().difference(DateTime.parse(cached['timestamp'])) <
            _cacheValidDuration) {
      return cached;
    }

    try {
      // Simulation de données de trafic (remplacer par API réelle)
      final trafficData = _generateTrafficData(routePoints);

      await CacheService.instance.saveToCache(cacheKey, {
        ...trafficData,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return trafficData;
    } catch (e) {
      debugPrint('Erreur récupération trafic: $e');
      return {};
    }
  }

  /// Génère des données de trafic simulées
  static Map<String, dynamic> _generateTrafficData(List<LatLng> routePoints) {
    final random = math.Random();
    final incidents = <Map<String, dynamic>>[];
    final congestion = <Map<String, dynamic>>[];

    // Simulation d'incidents
    for (int i = 0; i < routePoints.length ~/ 10; i++) {
      final pointIndex = random.nextInt(routePoints.length);
      incidents.add({
        'id': 'incident_$i',
        'position': routePoints[pointIndex],
        'type': ['accident', 'travaux', 'embouteillage'][random.nextInt(3)],
        'severity': ['faible', 'modéré', 'élevé'][random.nextInt(3)],
        'description': 'Incident sur votre itinéraire',
        'delay': random.nextInt(20) + 5, // 5-25 minutes
      });
    }

    // Simulation de congestion
    for (int i = 0; i < routePoints.length; i += 5) {
      final speed =
          random.nextDouble() * 0.8 + 0.2; // 20-100% de la vitesse normale
      congestion.add({
        'position': routePoints[i],
        'speedRatio': speed,
        'level': speed > 0.7
            ? 'fluide'
            : speed > 0.4
            ? 'dense'
            : 'très dense',
      });
    }

    return {
      'incidents': incidents,
      'congestion': congestion,
      'averageDelay':
          incidents.fold(0, (sum, inc) => sum + (inc['delay'] as int)) /
          math.max(incidents.length, 1),
    };
  }

  /// Cache une route calculée
  static Future<void> _cacheRoute(String key, RouteResult route) async {
    await CacheService.instance.saveToCache('$_routeCacheKey:$key', {
      'route': {
        'points': route.points.map((p) => [p.latitude, p.longitude]).toList(),
        'totalDistance': route.totalDistance,
        'estimatedDuration': route.estimatedDuration.inSeconds,
        'steps': route.steps
            .map(
              (s) => {
                'instruction': s.instruction,
                'distance': s.distance,
                'duration': s.duration.inSeconds,
                'location': [s.location.latitude, s.location.longitude],
                'type': s.type,
              },
            )
            .toList(),
        'summary': route.summary,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Récupère une route du cache
  static Future<RouteResult?> _getCachedRoute(String key) async {
    try {
      final cached = await CacheService.instance.getFromCache(
        '$_routeCacheKey:$key',
      );
      if (cached != null) {
        final timestamp = DateTime.parse(cached['timestamp']);
        if (DateTime.now().difference(timestamp) < _cacheValidDuration) {
          return RouteResult.fromJson(cached['route']);
        }
      }
    } catch (e) {
      debugPrint('Erreur lecture cache: $e');
    }
    return null;
  }
}
