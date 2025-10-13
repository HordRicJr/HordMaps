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
  /// Implémente un pattern de circuit breaker et exponential backoff
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
    // Utiliser le circuit breaker pour protéger contre les cascades d'erreurs
    return ApiCircuitBreaker.execute<RouteResult>(
      'azure_maps_route',
      () async {
        try {
          // Validation des entrées pour éviter les erreurs
          if (start.latitude.isNaN || start.longitude.isNaN || 
              end.latitude.isNaN || end.longitude.isNaN) {
            debugPrint('⚠️ Coordonnées invalides détectées, utilisation du fallback');
            return _createFallbackRoute(
              LatLng(48.8566, 2.3522), // Paris par défaut
              LatLng(48.8566, 2.3522).add(const LatLng(0.01, 0.01)),
              transportMode,
            );
          }

          // Vérifier si la configuration Azure Maps est valide
          if (!AzureMapsConfig.isValid) {
            debugPrint('⚠️ Configuration Azure Maps invalide - clé API manquante');
            throw Exception('Configuration Azure Maps invalide - clé API manquante');
          }

          // Construire la clé de cache unique
          final cacheKey = _buildCacheKey(
            start, end, waypoints, transportMode, 
            avoidTolls, avoidHighways, avoidFerries
          );

          // Vérifier le cache d'abord
          try {
            final cachedRoute = await _getCachedRoute(cacheKey);
            if (cachedRoute != null) {
              debugPrint('📦 Itinéraire Azure Maps trouvé dans le cache');
              return cachedRoute;
            }
          } catch (cacheError) {
            // Continuer même si le cache échoue
            debugPrint('⚠️ Erreur lecture cache: $cacheError');
          }

          debugPrint('🗺️  Calcul d\'itinéraire Azure Maps: $transportMode');
          debugPrint('  📍 Départ: ${start.latitude}, ${start.longitude}');
          debugPrint('  🎯 Arrivée: ${end.latitude}, ${end.longitude}');

          // Préparer les coordonnées pour l'API Azure Maps
          final coordinates = <String>[];
          coordinates.add('${start.longitude},${start.latitude}');
          
          if (waypoints != null && waypoints.isNotEmpty) {
            // Limiter le nombre de waypoints pour éviter les erreurs
            final safeWaypoints = waypoints.take(150).toList();
            for (final waypoint in safeWaypoints) {
              if (!waypoint.latitude.isNaN && !waypoint.longitude.isNaN) {
                coordinates.add('${waypoint.longitude},${waypoint.latitude}');
              }
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
          
          // Implémenter un retry avec exponential backoff
          int retryCount = 0;
          const maxRetries = 3;
          DioException? lastDioError;
          
          while (retryCount < maxRetries) {
            try {
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
                // Vérifier si la réponse contient des routes
                final routes = response.data['routes'] as List?;
                if (routes == null || routes.isEmpty) {
                  debugPrint('⚠️ Réponse Azure Maps sans itinéraires');
                  return _createFallbackRoute(start, end, transportMode);
                }
                
                final routeResult = _parseAzureMapsResponse(
                  response.data, 
                  transportMode,
                  startPoint: start,
                  endPoint: end,
                );
                
                // Mettre en cache pour des utilisations futures
                try {
                  await _cacheRoute(cacheKey, routeResult);
                } catch (cacheError) {
                  // Continuer même si la mise en cache échoue
                  debugPrint('⚠️ Erreur sauvegarde cache: $cacheError');
                }
                
                debugPrint('✅ Itinéraire Azure Maps calculé: ${routeResult.totalDistance.toStringAsFixed(2)}km, ${routeResult.estimatedDuration.inMinutes}min');
                return routeResult;
              } else {
                throw Exception('Erreur API Azure Maps: ${response.statusCode} - ${response.statusMessage}');
              }
            } on DioException catch (e) {
              lastDioError = e;
              
              // Gérer les erreurs spécifiques
              if (e.response?.statusCode == 401) {
                debugPrint('🔑 Erreur d\'authentification Azure Maps');
                throw Exception('Clé API Azure Maps invalide ou accès refusé');
              } else if (e.response?.statusCode == 429) {
                // Rate limiting - attendre plus longtemps avant de réessayer
                final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
                debugPrint('⏱️ Rate limit Azure Maps, attente de ${waitTime.inSeconds}s avant retry');
                await Future.delayed(waitTime);
                retryCount++;
                continue;
              }
              
              // Pour les autres erreurs, backoff exponentiel
              if (retryCount < maxRetries - 1) {
                final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
                debugPrint('🔄 Retry ${retryCount + 1}/$maxRetries dans ${waitTime.inSeconds}s: ${e.message}');
                await Future.delayed(waitTime);
                retryCount++;
              } else {
                debugPrint('❌ Échec après $maxRetries tentatives: ${e.message}');
                break;
              }
            } catch (e) {
              debugPrint('❌ Erreur inattendue: $e');
              break;
            }
          }
          
          // Si on arrive ici, toutes les tentatives ont échoué
          if (lastDioError != null) {
            debugPrint('🔄 Fallback après échec réseau: ${lastDioError.message}');
          }
          
          // Fallback vers un itinéraire simple
          return _createFallbackRoute(start, end, transportMode);
        } catch (e) {
          debugPrint('❌ Erreur calcul itinéraire Azure Maps: $e');
          
          // Enregistrer l'erreur dans le service de récupération
          try {
            AutoRecoveryService().reportError('AzureMapsRouting', e);
          } catch (_) {}
          
          // Fallback vers un itinéraire simple
          return _createFallbackRoute(start, end, transportMode);
        }
      },
      // Valeur de fallback si le circuit breaker est ouvert
      fallbackValue: _createFallbackRoute(start, end, transportMode),
      customTimeout: const Duration(seconds: 45),
    );
  }

  /// Parse la réponse de l'API Azure Maps selon la documentation officielle
  /// Implémente une gestion robuste des erreurs et des données manquantes
  static RouteResult _parseAzureMapsResponse(
    Map<String, dynamic> data,
    String transportMode, {
    LatLng? startPoint,
    LatLng? endPoint,
  }) {
    try {
      // Vérification de sécurité des données d'entrée
      if (data.isEmpty) {
        debugPrint('⚠️ Réponse Azure Maps vide');
        ErrorLoggingService().error(
          'AzureMapsRouting',
          'Réponse Azure Maps vide',
          details: {'data': 'empty'},
        );
        throw Exception('Réponse Azure Maps vide');
      }

      // Vérification de la structure de base de la réponse
      if (!_isValidResponseStructure(data)) {
        debugPrint('⚠️ Structure de réponse Azure Maps invalide');
        ErrorLoggingService().error(
          'AzureMapsRouting',
          'Structure de réponse Azure Maps invalide',
          details: {'keys': data.keys.toList()},
        );
        throw Exception('Structure de réponse Azure Maps invalide');
      }

      final routes = _safeGetList(data, 'routes');
      if (routes.isEmpty) {
        debugPrint('⚠️ Aucun itinéraire trouvé dans la réponse Azure Maps');
        ErrorLoggingService().error(
          'AzureMapsRouting',
          'Aucun itinéraire trouvé dans la réponse Azure Maps',
          details: {'data': data},
        );
        throw Exception('Aucun itinéraire trouvé dans la réponse Azure Maps');
      }

      // Vérifier que la première route est bien un Map
      final route = _safeGetMap(routes.first);
      if (route.isEmpty) {
        debugPrint('⚠️ Format de route invalide dans la réponse Azure Maps');
        ErrorLoggingService().error(
          'AzureMapsRouting',
          'Format de route invalide dans la réponse Azure Maps',
          details: {'route': routes.first},
        );
        throw Exception('Format de route invalide dans la réponse Azure Maps');
      }

      // Vérifier que le summary existe
      final summary = _safeGetMap(route['summary']);
      if (summary.isEmpty) {
        debugPrint('⚠️ Summary manquant dans la réponse Azure Maps');
        ErrorLoggingService().error(
          'AzureMapsRouting',
          'Summary manquant dans la réponse Azure Maps',
          details: {'route': route},
        );
        throw Exception('Summary manquant dans la réponse Azure Maps');
      }

      // Vérifier que les legs existent
      final legs = _safeGetList(route, 'legs');
      if (legs.isEmpty) {
        debugPrint('⚠️ Legs manquants dans la réponse Azure Maps');
        ErrorLoggingService().error(
          'AzureMapsRouting',
          'Legs manquants dans la réponse Azure Maps',
          details: {'route': route},
        );
        throw Exception('Legs manquants dans la réponse Azure Maps');
      }

      // Extraire les informations de base avec vérification de type
      final distanceInMeters = _safeParseInt(summary['lengthInMeters'], 0);
      final durationInSeconds = _safeParseInt(summary['travelTimeInSeconds'], 0);
      
      final totalDistance = distanceInMeters / 1000.0; // Convertir en km
      final estimatedDuration = Duration(seconds: durationInSeconds);

      // Extraire les points de l'itinéraire
      final routePoints = <LatLng>[];
      final steps = <RouteStep>[];

      for (final leg in legs) {
        if (leg is! Map<String, dynamic>) {
          debugPrint('⚠️ Format de leg invalide, ignoré');
          continue;
        }

        // Extraire les points selon la documentation Azure Maps
        final legPoints = leg['points'] as List?;
        if (legPoints != null) {
          for (final point in legPoints) {
            if (point is! Map<String, dynamic>) continue;
            
            try {
              final lat = _safeParseDouble(point['latitude'], 0.0);
              final lng = _safeParseDouble(point['longitude'], 0.0);
              
              // Vérifier que les coordonnées sont valides
              if (lat.abs() <= 90 && lng.abs() <= 180 && 
                  !lat.isNaN && !lng.isNaN) {
                routePoints.add(LatLng(lat, lng));
              }
            } catch (e) {
              debugPrint('⚠️ Point invalide ignoré: $e');
              // Continuer avec le point suivant
            }
          }
        }

        // Extraire les instructions de navigation
        final guidance = leg['guidance'] as Map<String, dynamic>?;
        if (guidance != null) {
          final instructions = guidance['instructions'] as List?;
          if (instructions != null) {
            for (int i = 0; i < instructions.length; i++) {
              try {
                final instruction = instructions[i];
                if (instruction is! Map<String, dynamic>) continue;
                
                final message = instruction['message'] as String? ?? '';
                final maneuver = instruction['maneuver'] as String? ?? 'continue';
                
                // Calculer la distance et durée pour cette étape
                double stepDistance = 0;
                Duration stepDuration = Duration.zero;
                
                if (i < instructions.length - 1) {
                  final currentPoint = instruction['point'] as Map<String, dynamic>?;
                  final nextPoint = instructions[i + 1]['point'] as Map<String, dynamic>?;
                  
                  if (currentPoint != null && nextPoint != null) {
                    try {
                      final startLatitude = _safeParseDouble(currentPoint['latitude'], 0.0);
                      final startLongitude = _safeParseDouble(currentPoint['longitude'], 0.0);
                      final endLatitude = _safeParseDouble(nextPoint['latitude'], 0.0);
                      final endLongitude = _safeParseDouble(nextPoint['longitude'], 0.0);
                      
                      if (!startLatitude.isNaN && !startLongitude.isNaN && 
                          !endLatitude.isNaN && !endLongitude.isNaN) {
                        final startPoint = LatLng(startLatitude, startLongitude);
                        final endPoint = LatLng(endLatitude, endLongitude);
                        stepDistance = _calculateDistance(startPoint, endPoint);
                        stepDuration = _estimateStepDuration(stepDistance, transportMode);
                      }
                    } catch (e) {
                      debugPrint('⚠️ Erreur calcul distance étape: $e');
                      // Utiliser des valeurs par défaut
                      stepDistance = 0.1;
                      stepDuration = const Duration(seconds: 30);
                    }
                  }
                }

                // Obtenir les coordonnées de cette étape
                LatLng stepLocation;
                try {
                  final stepPoint = instruction['point'] as Map<String, dynamic>?;
                  if (stepPoint != null) {
                    final lat = _safeParseDouble(stepPoint['latitude'], 0.0);
                    final lng = _safeParseDouble(stepPoint['longitude'], 0.0);
                    if (!lat.isNaN && !lng.isNaN && lat.abs() <= 90 && lng.abs() <= 180) {
                      stepLocation = LatLng(lat, lng);
                    } else {
                      stepLocation = routePoints.isNotEmpty ? routePoints.first : (startPoint ?? LatLng(0, 0));
                    }
                  } else {
                    stepLocation = routePoints.isNotEmpty ? routePoints.first : (startPoint ?? LatLng(0, 0));
                  }
                } catch (e) {
                  debugPrint('⚠️ Erreur extraction coordonnées étape: $e');
                  stepLocation = routePoints.isNotEmpty ? routePoints.first : (startPoint ?? LatLng(0, 0));
                }

                steps.add(RouteStep(
                  instruction: message,
                  distance: stepDistance,
                  duration: stepDuration,
                  location: stepLocation,
                  type: _parseManeuver(maneuver),
                ));
              } catch (e) {
                debugPrint('⚠️ Erreur traitement instruction $i: $e');
                // Continuer avec l'instruction suivante
              }
            }
          }
        }
      }

      // Si pas de points détaillés, utiliser les points de début et fin
      if (routePoints.isEmpty && startPoint != null && endPoint != null) {
        routePoints.addAll([startPoint, endPoint]);
      }

      // Si toujours pas de points, créer un itinéraire minimal
      if (routePoints.isEmpty) {
        debugPrint('⚠️ Aucun point d\'itinéraire trouvé, création d\'un itinéraire minimal');
        if (startPoint != null) {
          routePoints.add(startPoint);
          if (endPoint != null) {
            routePoints.add(endPoint);
          } else {
            // Ajouter un point légèrement décalé si pas de point d'arrivée
            routePoints.add(LatLng(
              startPoint.latitude + 0.01,
              startPoint.longitude + 0.01,
            ));
          }
        } else {
          // Points par défaut si aucune information
          routePoints.add(LatLng(48.8566, 2.3522)); // Paris
          routePoints.add(LatLng(48.8566, 2.3522).add(const LatLng(0.01, 0.01)));
        }
      }

      // Si pas d'étapes détaillées, créer une étape basique
      if (steps.isEmpty) {
        steps.add(RouteStep(
          instruction: 'Suivre l\'itinéraire vers la destination',
          distance: totalDistance,
          duration: estimatedDuration,
          location: startPoint ?? (routePoints.isNotEmpty ? routePoints.first : LatLng(0, 0)),
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
      
      // Créer un itinéraire de secours en cas d'erreur de parsing
      final fallbackPoints = <LatLng>[];
      if (startPoint != null) fallbackPoints.add(startPoint);
      if (endPoint != null) fallbackPoints.add(endPoint);
      
      // Si aucun point valide, utiliser des coordonnées par défaut
      if (fallbackPoints.isEmpty) {
        fallbackPoints.add(LatLng(48.8566, 2.3522)); // Paris
        fallbackPoints.add(LatLng(48.8566, 2.3522).add(const LatLng(0.01, 0.01)));
      }
      
      // Calculer une distance approximative
      final fallbackDistance = startPoint != null && endPoint != null 
          ? _calculateDistance(startPoint, endPoint) 
          : 1.0;
      
      // Estimer une durée approximative
      final fallbackDuration = _estimateStepDuration(fallbackDistance, transportMode);
      
      return RouteResult(
        points: fallbackPoints,
        totalDistance: fallbackDistance,
        estimatedDuration: fallbackDuration,
        steps: [
          RouteStep(
            instruction: 'Suivre l\'itinéraire vers la destination',
            distance: fallbackDistance,
            duration: fallbackDuration,
            location: fallbackPoints.first,
            type: 'continue',
          ),
        ],
        summary: 'Itinéraire de secours (erreur de parsing)',
      );
    }
  }
  
  /// Convertit en toute sécurité une valeur en int
  static int _safeParseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
  
  /// Convertit en toute sécurité une valeur en double
  static double _safeParseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
  
  /// Vérifie si la structure de la réponse est valide
  static bool _isValidResponseStructure(Map<String, dynamic> data) {
    // Vérifier les clés minimales requises
    if (!data.containsKey('routes')) {
      return false;
    }
    
    // Vérifier que routes est bien une liste
    final routes = data['routes'];
    if (routes is! List) {
      return false;
    }
    
    return true;
  }

  /// Récupère une liste de manière sécurisée
  static List<dynamic> _safeGetList(dynamic data, String key) {
    if (data is! Map) return [];
    
    final value = data[key];
    if (value is List) {
      return value;
    }
    
    return [];
  }

  /// Récupère un Map de manière sécurisée
  static Map<String, dynamic> _safeGetMap(dynamic data) {
    if (data is Map) {
      try {
        return Map<String, dynamic>.from(data);
      } catch (e) {
        // Si la conversion échoue, retourner un map vide
        return {};
      }
    }
    
    return {};
  }
  
  /// Vérifie si une coordonnée est valide
  static bool _isValidCoordinate(double lat, double lng) {
    return !lat.isNaN && !lng.isNaN && lat.abs() <= 90 && lng.abs() <= 180;
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