import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../../../models/navigation_models.dart';

/// Provider de navigation basique sans dépendances complexes
class NavigationProvider extends ChangeNotifier {
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
  List<LatLng> _alternativeRoutes = [];
  double _distanceToNextTurn = 0.0;
  Duration _timeToDestination = Duration.zero;
  double _currentSpeed = 0.0;
  double _remainingDistance = 0.0;
  
  // Configuration de navigation
  bool _enableVoiceGuidance = true;
  bool _enableTrafficUpdates = true;
  bool _enableAutoReroute = true;
  bool _enableOfflineMode = false;
  String _navigationLanguage = 'fr';

  NavigationProvider();

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
      _currentRoute != null && _currentStepIndex + 1 < _currentRoute!.steps.length
          ? _currentRoute!.steps[_currentStepIndex + 1]
          : null;

  /// Configure les paramètres de navigation
  void configureNavigation({
    bool? enableVoiceGuidance,
    bool? enableTrafficUpdates,
    bool? enableAutoReroute,
    bool? enableOfflineMode,
    String? navigationLanguage,
  }) {
    if (enableVoiceGuidance != null) _enableVoiceGuidance = enableVoiceGuidance;
    if (enableTrafficUpdates != null) _enableTrafficUpdates = enableTrafficUpdates;
    if (enableAutoReroute != null) _enableAutoReroute = enableAutoReroute;
    if (enableOfflineMode != null) _enableOfflineMode = enableOfflineMode;
    if (navigationLanguage != null) _navigationLanguage = navigationLanguage;
    notifyListeners();
  }

  /// Calcule une route entre deux points
  Future<void> calculateRoute(LatLng start, LatLng end, {String? destinationName}) async {
    _isCalculatingRoute = true;
    _startPoint = start;
    _endPoint = end;
    _destinationName = destinationName ?? 'Destination';
    notifyListeners();

    try {
      // Simulation de calcul de route
      await Future.delayed(Duration(seconds: 1));
      
      // Créer une route simple
      _currentRoute = RouteResult(
        points: [start, end],
        totalDistance: _calculateDistance(start, end),
        estimatedDuration: Duration(minutes: 15),
        steps: [
          RouteStep(
            instruction: 'Dirigez-vous vers $_destinationName',
            distance: _calculateDistance(start, end),
            duration: Duration(minutes: 15),
            location: start,
            type: 'straight',
          ),
        ],
      );

      debugPrint('Route calculée: ${_currentRoute!.distance}m');
    } catch (e) {
      debugPrint('Erreur calcul route: $e');
    } finally {
      _isCalculatingRoute = false;
      notifyListeners();
    }
  }

  /// Démarre la navigation
  Future<void> startNavigation() async {
    if (_currentRoute == null) {
      debugPrint('Aucune route disponible pour démarrer la navigation');
      return;
    }

    try {
      _isNavigating = true;
      _currentStepIndex = 0;
      notifyListeners();

      debugPrint('Navigation démarrée vers $_destinationName');
    } catch (e) {
      debugPrint('Erreur démarrage navigation: $e');
      _isNavigating = false;
      notifyListeners();
    }
  }

  /// Arrête la navigation
  Future<void> stopNavigation() async {
    try {
      _isNavigating = false;
      _currentStepIndex = 0;
      notifyListeners();
      debugPrint('Navigation arrêtée avec succès');
    } catch (e) {
      debugPrint('Erreur arrêt navigation: $e');
    }
  }

  /// Met à jour la position actuelle
  void updateCurrentLocation(LatLng location) {
    _currentLocation = location;
    
    if (_isNavigating && _currentRoute != null && _endPoint != null) {
      _remainingDistance = _calculateDistance(location, _endPoint!);
      
      // Vérifier si nous sommes arrivés (dans un rayon de 50m)
      if (_remainingDistance < 50) {
        _handleArrival();
      }
    }
    
    notifyListeners();
  }

  /// Gère l'arrivée à destination
  Future<void> _handleArrival() async {
    await stopNavigation();
    debugPrint('Arrivée à destination');
  }

  /// Calcule la distance entre deux points (approximation simple)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // mètres
    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLat = (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLng = (point2.longitude - point1.longitude) * (math.pi / 180);

    final double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Remet à zéro la navigation
  void resetNavigation() {
    _currentRoute = null;
    _startPoint = null;
    _endPoint = null;
    _currentLocation = null;
    _destinationName = '';
    _isCalculatingRoute = false;
    _isNavigating = false;
    _isRecalculating = false;
    _currentStepIndex = 0;
    _trafficData = null;
    _alternativeRoutes.clear();
    _distanceToNextTurn = 0.0;
    _timeToDestination = Duration.zero;
    _currentSpeed = 0.0;
    _remainingDistance = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    resetNavigation();
    super.dispose();
  }
}
