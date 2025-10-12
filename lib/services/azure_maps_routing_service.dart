import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/config/environment_config.dart';
import 'cache_service.dart';
import '../models/navigation_models.dart';


/// Service de routage utilisant Azure Maps pour calculer des itinéraires
/// Basé sur la documentation officielle Azure Maps Route Directions API
class AzureMapsRoutingService {
  static const String _routeCacheKey = 'azure_maps_route';
  static const Duration _cacheValidDuration = Duration(minutes: 15);

  static final _dio = Dio();

  /// Profils de transport disponibles pour Azure Maps
  static const Map<String, Map<String, dynamic>> transportProfiles = {
    'driving': {
      'azure': 'car',
      'icon': Icons.directions_car,
      'name': 'Voiture',
      'speed': 50.0, // km/h moyenne
    },
    'motorcycle': {
      'azure': 'motorcycle',
      'icon': Icons.motorcycle,
      'name': 'Moto',
      'speed': 45.0,
    },
    'walking': {
      'azure': 'pedestrian',
      'icon': Icons.directions_walk,
      'name': 'À pied',
      'speed': 5.0,
    },
    'cycling': {
      'azure': 'bicycle',
      'icon': Icons.directions_bike,  
      'name': 'Vélo',
      'speed': 15.0,
    },
    'truck': {
      'azure': 'truck',
      'icon': Icons.local_shipping,
      'name': 'Camion',
      'speed': 40.0,
    },
    'bus': {
      'azure': 'bus',
      'icon': Icons.directions_bus,
      'name': 'Bus',
      'speed': 35.0,
    },
  };

  /// Calcule un itinéraire avec Azure Maps Route Directions API
  static Future<RouteResult> calculateRoute({
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
    String transportMode = 'driving',
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool avoidFerries = false,
    String language = 'fr-FR',
  }) async {
    try {
      // Vérifier si la configuration Azure Maps est valide
      if (!AzureMapsConfig.isValid) {
        throw Exception('Configuration Azure Maps invalide - clé API manquante');
      }

      // Construire la clé de cache unique
      final cacheKey = _buildCacheKey(
        start, end, waypoints, transportMode, 
        avoidTolls, avoidHighways, avoidFerries
      );

      // Vérifier le cache d'abord
      final cachedRoute = await _getCachedRoute(cacheKey);
      if (cachedRoute != null) {
        debugPrint('📦 Itinéraire Azure Maps trouvé dans le cache');
        return cachedRoute;
      }

      debugPrint('🗺️  Calcul d\'itinéraire Azure Maps: $transportMode');
      debugPrint('  📍 Départ: ${start.latitude}, ${start.longitude}');
      debugPrint('  🎯 Arrivée: ${end.latitude}, ${end.longitude}');

      // Préparer les coordonnées pour l'API Azure Maps
      final coordinates = <String>[];
      coordinates.add('${start.longitude},${start.latitude}');
      
      if (waypoints != null && waypoints.isNotEmpty) {
        for (final waypoint in waypoints) {
          coordinates.add('${waypoint.longitude},${waypoint.latitude}');
        }
      }
      
      coordinates.add('${end.longitude},${end.latitude}');
      final coordinatesParam = coordinates.join(':');

      // Construire les paramètres selon la documentation Azure Maps
      final queryParams = <String, dynamic>{
        'api-version': AzureMapsConfig.apiVersion,
        'subscription-key': AzureMapsConfig.apiKey,
        'query': coordinatesParam,
        'travelMode': transportProfiles[transportMode]?['azure'] ?? 'car',
        'language': language,
        'instructionsType': 'text',
        'computeBestOrder': 'false',
        'routeRepresentation': 'polyline',
        'computeTravelTimeFor': 'all',
      };

      // Ajouter les options d'évitement selon la documentation
      final avoid = <String>[];
      if (avoidTolls) avoid.add('tollRoads');
      if (avoidHighways) avoid.add('motorways');
      if (avoidFerries) avoid.add('ferries');
      if (avoid.isNotEmpty) {
        queryParams['avoid'] = avoid.join(',');
      }

      // Construire l'URL selon la documentation Azure Maps
      final url = '${AzureMapsConfig.routeUrl}/directions/json';
      
      final response = await _dio.get(
        url, 
        queryParameters: queryParams,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: AzureMapsUtils.getStandardHeaders(),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final routeResult = _parseAzureMapsResponse(
          response.data, 
          transportMode,
          startPoint: start,
          endPoint: end,
        );
        
        // Mettre en cache pour des utilisations futures
        await _cacheRoute(cacheKey, routeResult);
        
        debugPrint('✅ Itinéraire Azure Maps calculé: ${routeResult.totalDistance.toStringAsFixed(2)}km, ${routeResult.estimatedDuration.inMinutes}min');
        return routeResult;
      } else {
        throw Exception('Erreur API Azure Maps: ${response.statusCode} - ${response.statusMessage}');
      }
    } on DioException catch (e) {
      debugPrint('❌ Erreur réseau Azure Maps: ${e.message}');
      if (e.response?.statusCode == 401) {
        throw Exception('Clé API Azure Maps invalide ou accès refusé');
      } else if (e.response?.statusCode == 429) {
        throw Exception('Limite de requêtes Azure Maps dépassée');
      }
      
      // Fallback vers un itinéraire simple en cas d'erreur réseau
      return _createFallbackRoute(start, end, transportMode);
    } catch (e) {
      debugPrint('❌ Erreur calcul itinéraire Azure Maps: $e');
      
      // Fallback vers un itinéraire simple
      return _createFallbackRoute(start, end, transportMode);
    }
  }

  /// Parse la réponse de l'API Azure Maps selon la documentation officielle
  static RouteResult _parseAzureMapsResponse(
    Map<String, dynamic> data,
    String transportMode, {
    LatLng? startPoint,
    LatLng? endPoint,
  }) {
    try {
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        throw Exception('Aucun itinéraire trouvé dans la réponse Azure Maps');
      }

      final route = routes.first as Map<String, dynamic>;
      final summary = route['summary'] as Map<String, dynamic>;
      final legs = route['legs'] as List;

      // Extraire les informations de base selon la structure Azure Maps
      final distanceInMeters = summary['lengthInMeters'] as int;
      final durationInSeconds = summary['travelTimeInSeconds'] as int;
      
      final totalDistance = distanceInMeters / 1000.0; // Convertir en km
      final estimatedDuration = Duration(seconds: durationInSeconds);

      // Extraire les points de l'itinéraire
      final routePoints = <LatLng>[];
      final steps = <RouteStep>[];

      for (final leg in legs) {
        // Extraire les points selon la documentation Azure Maps
        final legPoints = leg['points'] as List?;
        if (legPoints != null) {
          for (final point in legPoints) {
            final lat = point['latitude'] as double;
            final lng = point['longitude'] as double;
            routePoints.add(LatLng(lat, lng));
          }
        }

        // Extraire les instructions de navigation
        final guidance = leg['guidance'] as Map<String, dynamic>?;
        if (guidance != null) {
          final instructions = guidance['instructions'] as List?;
          if (instructions != null) {
            for (int i = 0; i < instructions.length; i++) {
              final instruction = instructions[i] as Map<String, dynamic>;
              final message = instruction['message'] as String? ?? '';
              final maneuver = instruction['maneuver'] as String? ?? 'continue';
              
              // Calculer la distance et durée pour cette étape
              double stepDistance = 0;
              Duration stepDuration = Duration.zero;
              
              if (i < instructions.length - 1) {
                final currentPoint = instruction['point'] as Map<String, dynamic>?;
                final nextPoint = instructions[i + 1]['point'] as Map<String, dynamic>?;
                
                if (currentPoint != null && nextPoint != null) {
                  final startPoint = LatLng(
                    currentPoint['latitude'] as double,
                    currentPoint['longitude'] as double,
                  );
                  final endPoint = LatLng(
                    nextPoint['latitude'] as double,
                    nextPoint['longitude'] as double,
                  );
                  stepDistance = _calculateDistance(startPoint, endPoint);
                  stepDuration = _estimateStepDuration(stepDistance, transportMode);
                }
              }

              // Obtenir les coordonnées de cette étape
              final stepPoint = instruction['point'] as Map<String, dynamic>?;
              final stepLocation = stepPoint != null 
                ? LatLng(
                    stepPoint['latitude'] as double,
                    stepPoint['longitude'] as double,
                  )
                : (routePoints.isNotEmpty ? routePoints.first : (startPoint ?? LatLng(0, 0)));

              steps.add(RouteStep(
                instruction: message,
                distance: stepDistance,
                duration: stepDuration,
                location: stepLocation,
                type: _parseManeuver(maneuver),
              ));
            }
          }
        }
      }

      // Si pas de points détaillés, utiliser les points de début et fin
      if (routePoints.isEmpty && startPoint != null && endPoint != null) {
        routePoints.addAll([startPoint, endPoint]);
      }

      // Si pas d'étapes détaillées, créer une étape basique
      if (steps.isEmpty) {
        steps.add(RouteStep(
          instruction: 'Suivre l\'itinéraire vers la destination',
          distance: totalDistance,
          duration: estimatedDuration,
          location: startPoint ?? LatLng(0, 0),
          type: 'continue',
        ));
      }

      return RouteResult(
        points: routePoints,
        totalDistance: totalDistance,
        estimatedDuration: estimatedDuration,
        steps: steps,
        summary: 'Itinéraire calculé avec Azure Maps',
      );
    } catch (e) {
      debugPrint('❌ Erreur parsing réponse Azure Maps: $e');
      throw Exception('Erreur lors du parsing de la réponse Azure Maps: $e');
    }
  }

  /// Parse le type de manœuvre Azure Maps vers notre système
  static String _parseManeuver(String azureManeuver) {
    switch (azureManeuver.toLowerCase()) {
      case 'turn_left':
      case 'bear_left':
      case 'sharp_left':
        return 'turn-left';
      case 'turn_right':
      case 'bear_right':
      case 'sharp_right':
        return 'turn-right';
      case 'continue':
      case 'go_straight':
        return 'continue';
      case 'u_turn':
        return 'uturn';
      case 'roundabout_enter':
        return 'roundabout-enter';
      case 'roundabout_exit':
        return 'roundabout-exit';
      case 'arrive':
        return 'arrive';
      case 'depart':
        return 'depart';
      default:
        return 'continue';
    }
  }

  /// Calcule la distance entre deux points (formule de Haversine)
  static double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // Rayon de la Terre en km
    
    final double lat1Rad = start.latitude * math.pi / 180;
    final double lat2Rad = end.latitude * math.pi / 180;
    final double deltaLatRad = (end.latitude - start.latitude) * math.pi / 180;
    final double deltaLngRad = (end.longitude - start.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Estime la durée d'une étape selon le mode de transport
  static Duration _estimateStepDuration(double distanceKm, String transportMode) {
    final profile = transportProfiles[transportMode];
    final speed = profile?['speed'] ?? 50.0;
    final hours = distanceKm / speed;
    return Duration(milliseconds: (hours * 3600 * 1000).round());
  }

  /// Crée un itinéraire de fallback en ligne droite
  static RouteResult _createFallbackRoute(
    LatLng start,
    LatLng end,
    String transportMode,
  ) {
    debugPrint('🔄 Création d\'un itinéraire de fallback Azure Maps');
    
    final distance = _calculateDistance(start, end);
    final profile = transportProfiles[transportMode];
    final speed = profile?['speed'] ?? 50.0;
    final duration = Duration(seconds: (distance / speed * 3600).round());

    return RouteResult(
      points: [start, end],
      totalDistance: distance,
      estimatedDuration: duration,
      steps: [
        RouteStep(
          instruction: 'Suivre la direction vers la destination',
          distance: distance,
          duration: duration,
          location: start,
          type: 'continue',
        ),
      ],
      summary: 'Itinéraire de fallback Azure Maps (ligne droite)',
    );
  }

  /// Construit une clé de cache unique pour la requête
  static String _buildCacheKey(
    LatLng start, 
    LatLng end, 
    List<LatLng>? waypoints,
    String transportMode,
    bool avoidTolls,
    bool avoidHighways,
    bool avoidFerries,
  ) {
    String key = 'azure_${start.latitude.toStringAsFixed(4)}_${start.longitude.toStringAsFixed(4)}_'
        '${end.latitude.toStringAsFixed(4)}_${end.longitude.toStringAsFixed(4)}_$transportMode';
    
    if (waypoints != null && waypoints.isNotEmpty) {
      for (final wp in waypoints) {
        key += '_${wp.latitude.toStringAsFixed(4)}_${wp.longitude.toStringAsFixed(4)}';
      }
    }
    
    if (avoidTolls) key += '_notolls';
    if (avoidHighways) key += '_nohighways';
    if (avoidFerries) key += '_noferries';
    
    return key;
  }

  /// Récupère un itinéraire du cache
  static Future<RouteResult?> _getCachedRoute(String cacheKey) async {
    try {
      final cachedData = await CacheService.instance.getFromCache('$_routeCacheKey:$cacheKey');
      if (cachedData != null) {
        final timestamp = DateTime.parse(cachedData['timestamp'] as String);
        if (DateTime.now().difference(timestamp) < _cacheValidDuration) {
          final routeData = cachedData['route'] as Map<String, dynamic>;
          return _routeFromCache(routeData);
        }
      }
    } catch (e) {
      debugPrint('Erreur lecture cache Azure Maps: $e');
    }
    return null;
  }

  /// Met en cache un itinéraire calculé
  static Future<void> _cacheRoute(String cacheKey, RouteResult route) async {
    try {
      final cacheData = {
        'route': _routeToCache(route),
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await CacheService.instance.saveToCache('$_routeCacheKey:$cacheKey', cacheData);
    } catch (e) {
      debugPrint('Erreur sauvegarde cache Azure Maps: $e');
    }
  }

  /// Convertit une RouteResult en format cache
  static Map<String, dynamic> _routeToCache(RouteResult route) {
    return {
      'points': route.points.map((p) => [p.latitude, p.longitude]).toList(),
      'totalDistance': route.totalDistance,
      'estimatedDuration': route.estimatedDuration.inMilliseconds,
      'steps': route.steps.map((step) => {
        'instruction': step.instruction,
        'distance': step.distance,
        'duration': step.duration.inMilliseconds,
        'location': [step.location.latitude, step.location.longitude],
        'type': step.type,
        'modifier': step.modifier,
      }).toList(),
      'summary': route.summary,
    };
  }

  /// Parse une route depuis le format cache
  static RouteResult _routeFromCache(Map<String, dynamic> data) {
    final pointsList = data['points'] as List;
    final points = pointsList.map((p) => LatLng(p[0] as double, p[1] as double)).toList();

    final stepsList = data['steps'] as List;
    final steps = stepsList.map((stepData) {
      final stepMap = stepData as Map<String, dynamic>;
      final locationList = stepMap['location'] as List;
      return RouteStep(
        instruction: stepMap['instruction'] as String,
        distance: stepMap['distance'] as double,
        duration: Duration(milliseconds: stepMap['duration'] as int),
        location: LatLng(locationList[0] as double, locationList[1] as double),
        type: stepMap['type'] as String,
        modifier: stepMap['modifier'] as String? ?? '',
      );
    }).toList();

    return RouteResult(
      points: points,
      totalDistance: data['totalDistance'] as double,
      estimatedDuration: Duration(milliseconds: data['estimatedDuration'] as int),
      steps: steps,
      summary: data['summary'] as String? ?? '',
    );
  }

  /// Nettoie le cache des itinéraires expirés
  static Future<void> cleanExpiredCache() async {
    try {
      debugPrint('🧹 Nettoyage du cache Azure Maps');
      // Cette méthode sera appelée périodiquement par un service de maintenance
      // Pour l'instant, le nettoyage se fait automatiquement lors de la lecture
    } catch (e) {
      debugPrint('Erreur nettoyage cache Azure Maps: $e');
    }
  }

  /// Obtient les informations sur un profil de transport
  static Map<String, dynamic>? getTransportProfile(String transportMode) {
    return transportProfiles[transportMode];
  }

  /// Liste tous les modes de transport disponibles
  static List<String> getAvailableTransportModes() {
    return transportProfiles.keys.toList();
  }

  /// Vérifie la disponibilité du service Azure Maps
  static Future<bool> checkServiceAvailability() async {
    try {
      if (!AzureMapsConfig.isValid) {
        return false;
      }

      final response = await _dio.get(
        '${AzureMapsConfig.searchUrl}/address/json',
        queryParameters: {
          'api-version': AzureMapsConfig.apiVersion,
          'subscription-key': AzureMapsConfig.apiKey,
          'query': 'test',
          'limit': '1',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Service Azure Maps indisponible: $e');
      return false;
    }
  }

  /// Obtenir des informations sur les limites du service
  static Map<String, dynamic> getServiceLimits() {
    return {
      'maxWaypoints': 150,
      'maxDistance': 1000, // km
      'supportedModes': ['car', 'truck', 'taxi', 'bus', 'pedestrian', 'bicycle'],
      'rateLimits': {
        'requestsPerSecond': 10,
        'requestsPerMonth': 125000,
      },
      'features': [
        'real_time_traffic',
        'turn_by_turn_directions',
        'alternative_routes',
        'route_optimization',
        'truck_routing',
      ],
    };
  }
}