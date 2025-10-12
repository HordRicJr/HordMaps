import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../services/voice_guidance_service.dart';
import '../../../services/navigation_notification_service.dart';
import '../../../services/real_time_navigation_service.dart';
import '../../../services/background_navigation_service.dart';
import '../../../services/azure_maps_routing_service.dart';
import '../../../services/event_throttle_service.dart';
import '../../../services/central_event_manager.dart';
import '../../../models/navigation_models.dart';

/// Provider de navigation principal consolidé avec toutes les fonctionnalités avancées
/// Gère la navigation temps réel, les notifications, la guidance vocale et les services d'arrière-plan
class NavigationProvider extends ChangeNotifier {
  final Dio _dio = Dio();

  // Services de navigation
  VoiceGuidanceService? _voiceService;
  NavigationNotificationService? _notificationService;
  RealTimeNavigationService? _realTimeService;
  BackgroundNavigationService? _backgroundService;

  // État de la navigation
  RouteResult? _currentRoute;
  LatLng? _startPoint;
  LatLng? _endPoint;
  LatLng? _currentLocation;
  String _destinationName = '';
  bool _isCalculatingRoute = false;
  bool _isNavigating = false;
  bool _isRecalculating = false;
  int _currentStepIndex = 0;
  String _routeProfile = 'driving';

  // Données additionnelles
  Map<String, dynamic>? _trafficData;
  final List<LatLng> _alternativeRoutes = [];
  double _distanceToNextTurn = 0.0;
  Duration _timeToDestination = Duration.zero;
  final double _currentSpeed = 0.0;
  double _remainingDistance = 0.0;

  // Configuration de navigation
  bool _enableVoiceGuidance = true;
  bool _enableTrafficUpdates = true;
  bool _enableAutoReroute = true;
  bool _enableOfflineMode = false;
  String _navigationLanguage = 'fr';

  // Streaming et abonnements
  StreamSubscription<LatLng>? _locationSubscription;

  // Gestionnaire central pour éviter les conflits d'événements
  final CentralEventManager _eventManager = CentralEventManager();

  NavigationProvider() {
    // Initialisation asynchrone différée
    _initializeServices();
  }

  /// Initialise le provider (doit être appelé après la création)
  Future<void> initialize() async {
    await _initializeServices();
  }

  // Getters
  RouteResult? get currentRoute => _currentRoute;
  LatLng? get startPoint => _startPoint;
  LatLng? get endPoint => _endPoint;
  LatLng? get currentLocation => _currentLocation;
  String get destinationName => _destinationName;
  bool get isCalculatingRoute => _isCalculatingRoute;
  bool get isNavigating => _isNavigating;
  bool get isRecalculating => _isRecalculating;
  int get currentStepIndex => _currentStepIndex;
  String get routeProfile => _routeProfile;
  Map<String, dynamic>? get trafficData => _trafficData;
  List<LatLng> get alternativeRoutes => _alternativeRoutes;
  double get distanceToNextTurn => _distanceToNextTurn;
  Duration get timeToDestination => _timeToDestination;
  double get currentSpeed => _currentSpeed;
  double get remainingDistance => _remainingDistance;
  bool get enableVoiceGuidance => _enableVoiceGuidance;
  bool get enableTrafficUpdates => _enableTrafficUpdates;
  bool get enableAutoReroute => _enableAutoReroute;
  bool get enableOfflineMode => _enableOfflineMode;
  String get navigationLanguage => _navigationLanguage;

  /// Étape actuelle de navigation
  RouteStep? get currentStep =>
      _currentRoute != null && _currentStepIndex < _currentRoute!.steps.length
      ? _currentRoute!.steps[_currentStepIndex]
      : null;

  /// Prochaine étape de navigation
  RouteStep? get nextStep =>
      _currentRoute != null &&
          _currentStepIndex + 1 < _currentRoute!.steps.length
      ? _currentRoute!.steps[_currentStepIndex + 1]
      : null;

  /// Initialise tous les services de navigation
  Future<void> _initializeServices() async {
    try {
      _voiceService = VoiceGuidanceService();
      _notificationService = NavigationNotificationService();
      _realTimeService = RealTimeNavigationService.instance;
      _backgroundService = BackgroundNavigationService.instance;

      // Initialiser les services qui le nécessitent
      await _voiceService?.initialize();
      await _notificationService?.initialize();
    } catch (e) {
      // Erreur d'initialisation ignorée silencieusement
    }
  }

  /// Configure les paramètres de navigation
  void configureNavigation({
    bool? enableVoiceGuidance,
    bool? enableTrafficUpdates,
    bool? enableAutoReroute,
    bool? enableOfflineMode,
    String? navigationLanguage,
  }) {
    if (enableVoiceGuidance != null) {
      _enableVoiceGuidance = enableVoiceGuidance;
    }
    if (enableTrafficUpdates != null) {
      _enableTrafficUpdates = enableTrafficUpdates;
    }
    if (enableAutoReroute != null) {
      _enableAutoReroute = enableAutoReroute;
    }
    if (enableOfflineMode != null) {
      _enableOfflineMode = enableOfflineMode;
    }
    if (navigationLanguage != null) {
      _navigationLanguage = navigationLanguage;
    }

    notifyListeners();
  }

  /// Change le profil de route (conduite, marche, vélo)
  void setRouteProfile(String profile) {
    if (_routeProfile != profile) {
      _routeProfile = profile;

      // NOUVEAU: Throttle pour éviter les recalculs excessifs
      EventThrottleService().throttle('route_profile_change', () {
        notifyListeners();

        // Recalculer la route si elle existe
        if (_startPoint != null && _endPoint != null) {
          calculateRoute(_startPoint!, _endPoint!);
        }
      });
    }
  }

  /// Définit le point de départ
  void setStartPoint(LatLng point) {
    _startPoint = point;
    notifyListeners();
  }

  /// Définit le point de destination
  void setDestination(LatLng destination, {String name = ''}) {
    _endPoint = destination;
    _destinationName = name;
    notifyListeners();
  }

  /// Met à jour la position actuelle
  void updateCurrentLocation(LatLng location) {
    _currentLocation = location;

    if (_isNavigating && _currentRoute != null) {
      _updateNavigationProgress();
      _checkForRerouting();
    }

    // NOUVEAU: Throttle les mises à jour de position pour éviter les surcharges
    EventThrottleService().throttle('navigation_update', () {
      notifyListeners();
    });
  }

  /// Calcule un itinéraire entre deux points avec options avancées
  Future<void> calculateRoute(
    LatLng start,
    LatLng end, {
    String? transportMode,
    bool includeAlternatives = false,
    bool avoidTolls = false,
    bool avoidHighways = false,
  }) async {
    _startPoint = start;
    _endPoint = end;
    _isCalculatingRoute = true;
    notifyListeners();

    try {
      // Calculer une nouvelle route avec Azure Maps
      final route = await AzureMapsRoutingService.calculateRoute(
        start: start,
        end: end,
        transportMode: transportMode ?? _routeProfile,
        avoidTolls: avoidTolls,
        avoidHighways: avoidHighways,
      );

      _currentRoute = route;

      // Obtenir les données de trafic si activées
      if (_enableTrafficUpdates && _currentRoute != null) {
        await _updateTrafficData();
      }

      // Calculer la distance restante
      _remainingDistance = _currentRoute?.totalDistance ?? 0.0;
      _timeToDestination = _currentRoute?.estimatedDuration ?? Duration.zero;

      debugPrint('Route calculée avec succès');
    } catch (e) {
      debugPrint('Erreur de calcul d\'itinéraire: $e');
      _createDirectRoute(start, end);
    } finally {
      _isCalculatingRoute = false;
      notifyListeners();
    }
  }

  /// Met à jour les données de trafic
  Future<void> _updateTrafficData() async {
    if (_currentRoute == null) return;

    try {
      // TODO: Implémenter les données de trafic avec Azure Maps Traffic API
      // _trafficData = await AzureMapsRoutingService.getTrafficData(
      //   _currentRoute!.points,
      // );

      // Pour l'instant, utiliser les données de route existantes
      // Ajuster le temps estimé selon le trafic
      if (_trafficData != null && _trafficData!['delay'] != null) {
        final delaySeconds = (_trafficData!['delay'] as num).toInt();
        _timeToDestination = Duration(
          seconds: _timeToDestination.inSeconds + delaySeconds,
        );
      }
    } catch (e) {
      debugPrint('Erreur mise à jour trafic: $e');
    }
  }

  /// Crée une route directe entre deux points (fallback)
  void _createDirectRoute(LatLng start, LatLng end) {
    final points = [start, end];
    final distance = _calculateDistance(start, end);

    final steps = [
      RouteStep(
        instruction: 'Dirigez-vous vers la destination',
        distance: distance,
        duration: Duration(seconds: (distance / 50 * 3600).toInt()),
        location: start,
        type: 'straight',
      ),
      RouteStep(
        instruction: 'Vous êtes arrivé à destination',
        distance: 0,
        duration: Duration.zero,
        location: end,
        type: 'arrive',
      ),
    ];

    _currentRoute = RouteResult(
      points: points,
      totalDistance: distance,
      estimatedDuration: Duration(seconds: (distance / 50 * 3600).toInt()),
      steps: steps,
      summary: 'Route directe vers la destination',
    );
  }

  /// Démarre la navigation en temps réel avec tous les services
  Future<void> startNavigation() async {
    if (_currentRoute == null) {
      debugPrint('Aucune route disponible pour démarrer la navigation');
      return;
    }

    try {
      _isNavigating = true;
      _currentStepIndex = 0;
      notifyListeners();

      // Initialiser et démarrer tous les services
      await _backgroundService?.initialize();

      if (_endPoint != null) {
        await _backgroundService?.startBackgroundNavigation(
          destination: _endPoint!,
          destinationName: _destinationName,
          routePoints: _currentRoute!.points,
          totalDistance: _currentRoute!.totalDistance,
        );
      }

      await _realTimeService?.startNavigation(
        routePoints: _currentRoute!.points,
        totalDistance: _currentRoute!.totalDistance,
        destination: _endPoint!,
      );

      await _notificationService?.startNavigation(_destinationName);

      if (_enableVoiceGuidance) {
        await _voiceService?.speak(
          'Navigation démarrée vers $_destinationName',
        );
      }

      // Démarrer le suivi de position
      _startLocationTracking();

      // Démarrer les timers de mise à jour
      _startNavigationTimers();

      debugPrint('Navigation démarrée avec succès');
    } catch (e) {
      debugPrint('Erreur démarrage navigation: $e');
      _isNavigating = false;
      notifyListeners();
    }
  }

  /// Démarre le suivi de position GPS
  void _startLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = _realTimeService?.locationStream.listen(
      (location) {
        updateCurrentLocation(location);
      },
      onError: (error) {
        debugPrint('Erreur suivi GPS: $error');
      },
    );
  }

  /// Démarre les timers de navigation
  void _startNavigationTimers() {
    // Timer de navigation principal (mise à jour chaque seconde) via gestionnaire central
    _eventManager.registerPeriodicTimer(
      'navigation_main_update',
      Duration(seconds: 1),
      (timer) {
        if (_isNavigating) {
          _updateNavigationProgress();
        }
      },
    );

    // Timer de mise à jour du trafic (toutes les 2 minutes) via gestionnaire central
    if (_enableTrafficUpdates) {
      _eventManager.registerPeriodicTimer(
        'navigation_traffic_update',
        Duration(minutes: 2),
        (timer) {
          if (_isNavigating) {
            _updateTrafficData();
          }
        },
      );
    }
  }

  /// Met à jour le progrès de navigation
  void _updateNavigationProgress() {
    if (_currentLocation == null || _currentRoute == null) return;

    // Calculer la distance restante
    _remainingDistance = _calculateRemainingDistance();

    // Calculer la distance jusqu'au prochain virage
    _distanceToNextTurn = _calculateDistanceToNextTurn();

    // Estimer le temps restant
    _timeToDestination = _estimateRemainingTime();

    // Vérifier si on doit passer à l'étape suivante
    _checkStepProgress();

    notifyListeners();
  }

  /// Calcule la distance restante jusqu'à la destination
  double _calculateRemainingDistance() {
    if (_currentLocation == null || _currentRoute == null) return 0.0;

    double totalDistance = 0.0;
    bool foundCurrentPosition = false;

    for (int i = 0; i < _currentRoute!.points.length - 1; i++) {
      final point1 = _currentRoute!.points[i];
      final point2 = _currentRoute!.points[i + 1];

      if (!foundCurrentPosition) {
        final distanceToPoint = _calculateDistance(_currentLocation!, point1);
        if (distanceToPoint < 0.05) {
          // 50 mètres de tolérance
          foundCurrentPosition = true;
          totalDistance += _calculateDistance(_currentLocation!, point2);
        }
      } else {
        totalDistance += _calculateDistance(point1, point2);
      }
    }

    return foundCurrentPosition ? totalDistance : _remainingDistance;
  }

  /// Calcule la distance jusqu'au prochain virage
  double _calculateDistanceToNextTurn() {
    if (_currentLocation == null || currentStep == null) return 0.0;
    return _calculateDistance(_currentLocation!, currentStep!.location);
  }

  /// Estime le temps restant
  Duration _estimateRemainingTime() {
    if (_remainingDistance <= 0) return Duration.zero;

    double estimatedSpeedKmh = _routeProfile == 'walking'
        ? 5.0
        : _routeProfile == 'cycling'
        ? 15.0
        : 50.0;

    if (_currentSpeed > 0) {
      estimatedSpeedKmh = _currentSpeed * 3.6; // m/s vers km/h
    }

    final timeHours = _remainingDistance / estimatedSpeedKmh;
    return Duration(seconds: (timeHours * 3600).round());
  }

  /// Vérifie le progrès de l'étape actuelle
  void _checkStepProgress() {
    if (_currentLocation == null || currentStep == null) return;

    final distanceToStep = _calculateDistance(
      _currentLocation!,
      currentStep!.location,
    );

    // Si on est proche de l'étape actuelle (moins de 30 mètres), passer à la suivante
    if (distanceToStep < 0.03) {
      moveToNextStep();
    }
  }

  /// Vérifie si un recalcul de route est nécessaire
  void _checkForRerouting() {
    if (!_enableAutoReroute ||
        _currentLocation == null ||
        _currentRoute == null) {
      return;
    }

    // Calculer la distance minimale à la route
    double minDistanceToRoute = double.infinity;

    for (final point in _currentRoute!.points) {
      final distance = _calculateDistance(_currentLocation!, point);
      if (distance < minDistanceToRoute) {
        minDistanceToRoute = distance;
      }
    }

    // Si on est trop loin de la route (plus de 100 mètres), recalculer
    if (minDistanceToRoute > 0.1 && !_isRecalculating) {
      _recalculateRoute();
    }
  }

  /// Recalcule automatiquement la route
  Future<void> _recalculateRoute() async {
    if (_currentLocation == null || _endPoint == null || _isRecalculating) {
      return;
    }

    _isRecalculating = true;
    notifyListeners();

    try {
      await calculateRoute(_currentLocation!, _endPoint!);

      if (_enableVoiceGuidance) {
        await _voiceService?.speak('Route recalculée');
      }

      await _notificationService?.updateNavigationInstruction(
        'Route recalculée',
        _remainingDistance.round(),
      );

      debugPrint('Route recalculée automatiquement');
    } catch (e) {
      debugPrint('Erreur recalcul route: $e');
    } finally {
      _isRecalculating = false;
      notifyListeners();
    }
  }

  /// Passe à l'étape suivante avec annonces
  Future<void> moveToNextStep() async {
    if (_currentRoute != null &&
        _currentStepIndex < _currentRoute!.steps.length - 1) {
      _currentStepIndex++;

      if (_isNavigating) {
        final step = _currentRoute!.steps[_currentStepIndex];

        if (_enableVoiceGuidance) {
          await _voiceService?.announceNavigation(
            step.instruction,
            step.distance.round(),
          );
        }

        await _notificationService?.updateNavigationInstruction(
          step.instruction,
          step.distance.round(),
        );
      }

      notifyListeners();
    } else if (_currentRoute != null &&
        _currentStepIndex >= _currentRoute!.steps.length - 1) {
      // Arrivée à destination
      await _handleArrival();
    }
  }

  /// Gère l'arrivée à destination
  Future<void> _handleArrival() async {
    if (_enableVoiceGuidance) {
      await _voiceService?.announceArrival();
    }

    await _notificationService?.showArrivalNotification();
    await stopNavigation();

    debugPrint('Arrivée à destination');
  }

  /// Revient à l'étape précédente
  void previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      notifyListeners();
    }
  }

  /// Arrête la navigation et tous les services associés
  Future<void> stopNavigation() async {
    if (!_isNavigating) return;

    try {
      _isNavigating = false;
      _currentStepIndex = 0;

      // Arrêter tous les timers et abonnements via gestionnaire central
      _eventManager.cancelTimer('navigation_main_update');
      _eventManager.cancelTimer('navigation_traffic_update');
      _locationSubscription?.cancel();
      _locationSubscription = null;

      // Arrêter tous les services
      await _realTimeService?.stopNavigation();
      await _backgroundService?.stopBackgroundNavigation();
      await _notificationService?.stopNavigation();

      if (_enableVoiceGuidance) {
        await _voiceService?.speak('Navigation arrêtée');
      }

      notifyListeners();
      debugPrint('Navigation arrêtée avec succès');
    } catch (e) {
      debugPrint('Erreur arrêt navigation: $e');
    }
  }

  /// Efface la route actuelle et remet à zéro
  void clearRoute() {
    _currentRoute = null;
    _startPoint = null;
    _endPoint = null;
    _destinationName = '';
    _isNavigating = false;
    _currentStepIndex = 0;
    _remainingDistance = 0.0;
    _distanceToNextTurn = 0.0;
    _timeToDestination = Duration.zero;
    _alternativeRoutes.clear();
    _trafficData = null;

    notifyListeners();
  }

  /// Calcule la distance entre deux points en kilomètres
  double _calculateDistance(LatLng start, LatLng end) {
    const distance = 6371; // Rayon de la Terre en kilomètres

    final lat1Rad = start.latitude * math.pi / 180;
    final lat2Rad = end.latitude * math.pi / 180;
    final deltaLatRad = (end.latitude - start.latitude) * math.pi / 180;
    final deltaLngRad = (end.longitude - start.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return distance * c;
  }

  /// Formate la distance pour l'affichage
  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()} m';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceInKm.round()} km';
    }
  }

  /// Formate la durée pour l'affichage
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else if (minutes > 0) {
      return '${minutes}min';
    } else {
      return '${seconds}s';
    }
  }

  /// Obtient des informations de performance de navigation
  Map<String, dynamic> getNavigationStats() {
    return {
      'routeProfile': _routeProfile,
      'totalDistance': _currentRoute?.totalDistance ?? 0.0,
      'remainingDistance': _remainingDistance,
      'estimatedTotalTime': _currentRoute?.estimatedDuration.inSeconds ?? 0,
      'remainingTime': _timeToDestination.inSeconds,
      'currentSpeed': _currentSpeed,
      'averageSpeed':
          _currentRoute?.totalDistance != null &&
              _timeToDestination.inSeconds > 0
          ? (_currentRoute!.totalDistance /
                (_timeToDestination.inSeconds / 3600))
          : 0.0,
      'stepsCompleted': _currentStepIndex,
      'totalSteps': _currentRoute?.steps.length ?? 0,
      'progressPercentage': _currentRoute?.steps.isNotEmpty == true
          ? (_currentStepIndex / _currentRoute!.steps.length * 100)
          : 0.0,
    };
  }

  @override
  void dispose() {
    // Arrêt coordonné des services
    _stopAllServices();
    // Nettoyer via le gestionnaire central
    _eventManager.cancelTimersByPrefix('navigation_');
    _locationSubscription?.cancel();
    _dio.close();
    super.dispose();
  }

  /// Arrête tous les services de façon sécurisée
  void _stopAllServices() {
    try {
      _realTimeService?.stopNavigation();
      _backgroundService?.stopBackgroundNavigation();
      _notificationService?.stopNavigation();
    } catch (e) {
      debugPrint('Erreur arrêt services navigation: $e');
    }
  }
}
