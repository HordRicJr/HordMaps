import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'cache_service.dart';
import '../models/navigation_models.dart';

/// Service pour le suivi de navigation en temps réel
class RealTimeNavigationService {
  static RealTimeNavigationService? _instance;
  static RealTimeNavigationService get instance =>
      _instance ??= RealTimeNavigationService._();

  RealTimeNavigationService._();

  StreamController<NavigationProgress>? _progressController;
  StreamController<LatLng>? _locationController;
  Timer? _navigationTimer;
  Timer? _locationTimer;

  bool _isNavigating = false;
  LatLng? _currentDestination;
  List<LatLng>? _routePoints;
  int _currentRouteIndex = 0;
  double _totalDistance = 0;
  double _remainingDistance = 0;
  Duration _estimatedTimeArrival = Duration.zero;
  double _averageSpeed = 0; // km/h

  // Configuration
  static const Duration _updateInterval = Duration(seconds: 2);
  static const Duration _locationInterval = Duration(seconds: 1);
  static const double _speedSmoothingFactor = 0.7;
  static const double _minSpeedKmh = 1.0;
  static const double _maxSpeedKmh = 120.0;

  /// Stream pour écouter les mises à jour de progression
  Stream<NavigationProgress> get progressStream =>
      _progressController?.stream ?? const Stream.empty();

  /// Stream pour écouter les mises à jour de position
  Stream<LatLng> get locationStream =>
      _locationController?.stream ?? const Stream.empty();

  /// Getters
  bool get isNavigating => _isNavigating;
  double get remainingDistance => _remainingDistance;
  Duration get estimatedTimeArrival => _estimatedTimeArrival;
  double get averageSpeed => _averageSpeed;
  double get completionPercentage => _totalDistance > 0
      ? (((_totalDistance - _remainingDistance) / _totalDistance) * 100).clamp(
          0,
          100,
        )
      : 0;

  /// Démarre le suivi de navigation
  Future<void> startNavigation({
    RouteResult? route,
    required LatLng destination,
    List<LatLng>? routePoints,
    double? totalDistance,
  }) async {
    await stopNavigation();

    _isNavigating = true;
    _currentDestination = destination;

    // Utiliser les données de la route si fournie, sinon les paramètres directs
    if (route != null) {
      _routePoints = route.points;
      _totalDistance = route.totalDistance;
    } else {
      _routePoints = routePoints ?? [];
      _totalDistance = totalDistance ?? 0;
    }

    _remainingDistance = _totalDistance;
    _currentRouteIndex = 0;
    _averageSpeed = 0;

    _progressController = StreamController<NavigationProgress>.broadcast();
    _locationController = StreamController<LatLng>.broadcast();

    // Démarrer les timers de mise à jour
    _startLocationTracking();
    _startProgressTracking();

    debugPrint(
      'Navigation démarrée vers ${destination.latitude}, ${destination.longitude}',
    );
  }

  /// Arrête le suivi de navigation
  Future<void> stopNavigation() async {
    _isNavigating = false;
    _navigationTimer?.cancel();
    _locationTimer?.cancel();

    await _progressController?.close();
    await _locationController?.close();

    _progressController = null;
    _locationController = null;
    _currentDestination = null;
    _routePoints = null;

    debugPrint('Navigation arrêtée');
  }

  /// Démarre le suivi de position GPS
  void _startLocationTracking() {
    _locationTimer = Timer.periodic(_locationInterval, (timer) async {
      if (!_isNavigating) {
        timer.cancel();
        return;
      }

      try {
        final position = await _getCurrentPosition();
        if (position != null) {
          final currentLocation = LatLng(position.latitude, position.longitude);
          _locationController?.add(currentLocation);

          // Mettre à jour la vitesse moyenne
          _updateSpeed(position.speed);

          // Calculer la distance restante
          _updateRemainingDistance(currentLocation);

          // Vérifier si on est arrivé
          _checkArrival(currentLocation);
        }
      } catch (e) {
        debugPrint('Erreur de géolocalisation: $e');
      }
    });
  }

  /// Démarre le suivi de progression
  void _startProgressTracking() {
    _navigationTimer = Timer.periodic(_updateInterval, (timer) {
      if (!_isNavigating) {
        timer.cancel();
        return;
      }

      _updateEstimatedTime();
      _broadcastProgress();
    });
  }

  /// Obtient la position GPS actuelle
  Future<Position?> _getCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('Erreur getCurrentPosition: $e');
      return null;
    }
  }

  /// Met à jour la vitesse moyenne avec lissage
  void _updateSpeed(double speedMps) {
    final speedKmh = (speedMps * 3.6).clamp(_minSpeedKmh, _maxSpeedKmh);

    if (_averageSpeed == 0) {
      _averageSpeed = speedKmh;
    } else {
      _averageSpeed =
          (_averageSpeed * _speedSmoothingFactor) +
          (speedKmh * (1 - _speedSmoothingFactor));
    }
  }

  /// Met à jour la distance restante jusqu'à destination
  void _updateRemainingDistance(LatLng currentLocation) {
    if (_currentDestination == null) return;

    final distance = const Distance();
    _remainingDistance = distance.as(
      LengthUnit.Kilometer,
      currentLocation,
      _currentDestination!,
    );

    // Mettre à jour l'index de route si on a des points de route
    if (_routePoints != null && _routePoints!.isNotEmpty) {
      _updateRouteProgress(currentLocation);
    }
  }

  /// Met à jour la progression sur la route
  void _updateRouteProgress(LatLng currentLocation) {
    if (_routePoints == null || _routePoints!.isEmpty) return;

    final distance = const Distance();
    double minDistanceToRoute = double.infinity;
    int closestIndex = _currentRouteIndex;

    // Trouver le point de route le plus proche
    for (int i = _currentRouteIndex; i < _routePoints!.length; i++) {
      final distanceToPoint = distance.as(
        LengthUnit.Meter,
        currentLocation,
        _routePoints![i],
      );

      if (distanceToPoint < minDistanceToRoute) {
        minDistanceToRoute = distanceToPoint;
        closestIndex = i;
      }
    }

    // Mettre à jour l'index si on a avancé significativement
    if (closestIndex > _currentRouteIndex && minDistanceToRoute < 100) {
      _currentRouteIndex = closestIndex;
    }
  }

  /// Met à jour le temps estimé d'arrivée
  void _updateEstimatedTime() {
    if (_remainingDistance <= 0 || _averageSpeed <= 0) {
      _estimatedTimeArrival = Duration.zero;
      return;
    }

    final hoursRemaining = _remainingDistance / _averageSpeed;
    _estimatedTimeArrival = Duration(
      milliseconds: (hoursRemaining * 3600 * 1000).round(),
    );
  }

  /// Vérifie si on est arrivé à destination
  void _checkArrival(LatLng currentLocation) {
    if (_currentDestination == null) return;

    const double arrivalThresholdMeters = 50.0;
    final distance = const Distance();
    final distanceToDestination = distance.as(
      LengthUnit.Meter,
      currentLocation,
      _currentDestination!,
    );

    if (distanceToDestination <= arrivalThresholdMeters) {
      _onArrival();
    }
  }

  /// Gère l'arrivée à destination
  void _onArrival() {
    debugPrint('Arrivée à destination détectée');

    _progressController?.add(
      NavigationProgress(
        remainingDistance: 0,
        estimatedTimeArrival: Duration.zero,
        averageSpeed: _averageSpeed,
        completionPercentage: 100,
        currentLocation: _currentDestination!,
        isArrived: true,
      ),
    );

    stopNavigation();
  }

  /// Diffuse les informations de progression
  void _broadcastProgress() {
    if (_progressController == null || _currentDestination == null) return;

    _progressController!.add(
      NavigationProgress(
        remainingDistance: _remainingDistance,
        estimatedTimeArrival: _estimatedTimeArrival,
        averageSpeed: _averageSpeed,
        completionPercentage: completionPercentage,
        currentLocation: _currentDestination!,
        isArrived: false,
      ),
    );
  }

  /// Mode test pour la navigation (utile pour les tests et démos)
  Future<void> testNavigation({
    required LatLng start,
    required LatLng destination,
    required List<LatLng> routePoints,
    required double totalDistance,
    Duration duration = const Duration(minutes: 10),
  }) async {
    await startNavigation(
      destination: destination,
      routePoints: routePoints,
      totalDistance: totalDistance,
    );

    // Mode test : mouvement le long de la route
    final steps = duration.inSeconds ~/ _locationInterval.inSeconds;

    for (int i = 0; i < steps && _isNavigating; i++) {
      await Future.delayed(_locationInterval);

      if (!_isNavigating) break;

      // Calculer la position interpolée
      final progress = i / steps;
      final currentLocation = _interpolatePosition(
        start,
        destination,
        progress,
      );

      // Mode test : vitesse réaliste variable
      final testSpeed = 30.0 + (Random().nextDouble() * 20 - 10); // 20-50 km/h
      _updateSpeed(testSpeed / 3.6); // Convertir en m/s

      _locationController?.add(currentLocation);
      _updateRemainingDistance(currentLocation);
    }

    if (_isNavigating) {
      _onArrival();
    }
  }

  /// Interpole la position entre deux points
  LatLng _interpolatePosition(LatLng start, LatLng end, double progress) {
    final lat = start.latitude + (end.latitude - start.latitude) * progress;
    final lng = start.longitude + (end.longitude - start.longitude) * progress;
    return LatLng(lat, lng);
  }

  /// Sauvegarde l'état de navigation dans le cache
  Future<void> saveNavigationState() async {
    if (!_isNavigating || _currentDestination == null) return;

    final state = {
      'destination': {
        'lat': _currentDestination!.latitude,
        'lng': _currentDestination!.longitude,
      },
      'totalDistance': _totalDistance,
      'remainingDistance': _remainingDistance,
      'averageSpeed': _averageSpeed,
      'routeIndex': _currentRouteIndex,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await CacheService.instance.saveToCache('navigation_state', state);
  }

  /// Restaure l'état de navigation depuis le cache
  Future<bool> restoreNavigationState() async {
    try {
      final state = await CacheService.instance.getFromCache(
        'navigation_state',
      );
      if (state == null) return false;

      final destinationData = state['destination'] as Map<String, dynamic>;
      final destination = LatLng(
        destinationData['lat'] as double,
        destinationData['lng'] as double,
      );

      _currentDestination = destination;
      _totalDistance = state['totalDistance'] as double;
      _remainingDistance = state['remainingDistance'] as double;
      _averageSpeed = state['averageSpeed'] as double;
      _currentRouteIndex = state['routeIndex'] as int;

      return true;
    } catch (e) {
      debugPrint('Erreur restauration navigation: $e');
      return false;
    }
  }

  /// Nettoie les ressources
  void dispose() {
    stopNavigation();
  }
}

/// Classe représentant l'état de progression de navigation
class NavigationProgress {
  final double remainingDistance;
  final Duration estimatedTimeArrival;
  final double averageSpeed;
  final double completionPercentage;
  final LatLng currentLocation;
  final bool isArrived;

  const NavigationProgress({
    required this.remainingDistance,
    required this.estimatedTimeArrival,
    required this.averageSpeed,
    required this.completionPercentage,
    required this.currentLocation,
    required this.isArrived,
  });

  @override
  String toString() {
    return 'NavigationProgress('
        'remaining: ${remainingDistance.toStringAsFixed(2)}km, '
        'eta: ${estimatedTimeArrival.inMinutes}min, '
        'speed: ${averageSpeed.toStringAsFixed(1)}km/h, '
        'progress: ${completionPercentage.toStringAsFixed(1)}%'
        ')';
  }
}
