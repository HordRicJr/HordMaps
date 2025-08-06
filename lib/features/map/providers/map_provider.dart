import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/crash_proof_location_service.dart';

class MapProvider extends ChangeNotifier {
  final MapController _mapController = MapController();
  final CrashProofLocationService _locationService =
      CrashProofLocationService();

  LatLng? _currentLocation;
  LatLng _mapCenter = LatLng(6.1319, 1.2228); // Lomé par défaut
  double _mapZoom = 13.0;
  bool _isLoading = false;
  bool _isFollowingUser = false;
  final List<Marker> _markers = [];
  final List<Polyline> _routes = [];
  String _tileLayerUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Points d'itinéraire
  LatLng? _startPoint;
  LatLng? _endPoint;

  // Getters
  MapController get mapController => _mapController;
  LatLng? get currentLocation => _currentLocation;
  LatLng get mapCenter => _mapCenter;
  double get mapZoom => _mapZoom;
  bool get isLoading => _isLoading;
  bool get isFollowingUser => _isFollowingUser;
  List<Marker> get markers => _markers;
  List<Polyline> get routes => _routes;
  String get tileLayerUrl => _tileLayerUrl;
  LatLng? get startPoint => _startPoint;
  LatLng? get endPoint => _endPoint;

  /// Initialise le provider de carte
  Future<void> initialize() async {
    await _locationService.initialize();
    await _initializeLocation();
  }

  /// Initialise la géolocalisation
  Future<void> _initializeLocation() async {
    _setLoading(true);

    try {
      // Obtenir la position actuelle
      Position position = await _locationService.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      _currentLocation = latLng;
      _mapCenter = latLng;

      // Ajouter un marqueur pour la position actuelle
      _addCurrentLocationMarker(latLng);

      // Démarrer le suivi de position en temps réel
      await _startLocationTracking();
    } catch (e) {
      debugPrint('Erreur d\'initialisation de la localisation: $e');
      // Utiliser Lomé comme position par défaut
      final defaultLocation = LatLng(6.1319, 1.2228);
      _currentLocation = defaultLocation;
      _mapCenter = defaultLocation;
      _addCurrentLocationMarker(defaultLocation);
    } finally {
      _setLoading(false);
    }
  }

  /// Démarre le suivi de la position utilisateur
  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startLocationTracking();
      _locationService.positionStream.listen((position) {
        final latLng = LatLng(position.latitude, position.longitude);
        updateCurrentLocation(latLng);
      });
    } catch (e) {
      debugPrint('Erreur démarrage suivi position: $e');
    }
  }

  /// Met à jour la position actuelle de l'utilisateur
  void updateCurrentLocation(LatLng newPosition) {
    _currentLocation = newPosition;

    // Mettre à jour le marqueur de position
    _addCurrentLocationMarker(newPosition);

    // Centrer automatiquement si on suit l'utilisateur
    if (_isFollowingUser) {
      _animateToPosition(newPosition);
    }

    notifyListeners();
  }

  /// Ajoute un marqueur pour la position actuelle
  void _addCurrentLocationMarker(LatLng position) {
    // Supprimer l'ancien marqueur de position
    _markers.removeWhere((marker) => marker.point == position);

    // Ajouter le nouveau marqueur
    _markers.add(
      Marker(
        point: position,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  /// Active/désactive le mode de suivi utilisateur
  void toggleUserFollowing() {
    _isFollowingUser = !_isFollowingUser;

    if (_isFollowingUser && _currentLocation != null) {
      _animateToPosition(_currentLocation!);
    }

    notifyListeners();
  }

  /// Centre la carte sur la position actuelle
  Future<void> centerOnCurrentLocation() async {
    if (_currentLocation != null) {
      await _animateToPosition(_currentLocation!);
    } else {
      // Essayer d'obtenir la position actuelle
      Position position = await _locationService.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      _currentLocation = latLng;
      _addCurrentLocationMarker(latLng);
      await _animateToPosition(latLng);
    }
  }

  /// Obtient la position actuelle (rafraîchit si nécessaire)
  Future<LatLng?> getCurrentLocation() async {
    if (_currentLocation == null) {
      Position position = await _locationService.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      _currentLocation = latLng;
      _addCurrentLocationMarker(latLng);
      notifyListeners();
    }
    return _currentLocation;
  }

  /// Anime la carte vers une position donnée
  Future<void> _animateToPosition(LatLng position, {double? zoom}) async {
    _mapCenter = position;
    if (zoom != null) {
      _mapZoom = zoom;
    }

    // Animation fluide vers la position
    _mapController.move(position, _mapZoom);
    notifyListeners();
  }

  /// Met à jour le centre et zoom de la carte
  void updateMapPosition(LatLng center, double zoom) {
    // Désactiver le suivi si l'utilisateur bouge manuellement la carte
    if (_isFollowingUser) {
      _isFollowingUser = false;
    }

    _mapCenter = center;
    _mapZoom = zoom;
    notifyListeners();
  }

  /// Anime la carte vers une location (alias pour _animateToPosition)
  Future<void> animateToLocation(LatLng location, {double? zoom}) async {
    await _animateToPosition(location, zoom: zoom);
  }

  /// Change le style de carte
  void changeMapStyle(String url) {
    changeTileLayer(url);
  }

  /// Ajoute un marqueur à la carte
  void addMarker(Marker marker) {
    _markers.add(marker);
    notifyListeners();
  }

  /// Supprime un marqueur de la carte
  void removeMarkerAt(LatLng point) {
    _markers.removeWhere((marker) => marker.point == point);
    notifyListeners();
  }

  /// Ajoute une route (polyline) à la carte
  void addRoute(Polyline route) {
    _routes.add(route);
    notifyListeners();
  }

  /// Supprime toutes les routes
  void clearRoutes() {
    _routes.clear();
    notifyListeners();
  }

  /// Supprime tous les marqueurs sauf celui de la position actuelle
  void clearMarkers({bool keepCurrentLocation = true}) {
    if (keepCurrentLocation && _currentLocation != null) {
      final currentLocationMarker = _markers.firstWhere(
        (marker) => marker.point == _currentLocation,
        orElse: () => _markers.first,
      );
      _markers.clear();
      _markers.add(currentLocationMarker);
    } else {
      _markers.clear();
    }
    notifyListeners();
  }

  /// Définit le point de départ pour un itinéraire
  void setStartPoint(LatLng point) {
    _startPoint = point;
    notifyListeners();
  }

  /// Définit le point d'arrivée pour un itinéraire
  void setEndPoint(LatLng point) {
    _endPoint = point;
    notifyListeners();
  }

  /// Efface les points d'itinéraire
  void clearRoutePoints() {
    _startPoint = null;
    _endPoint = null;
    notifyListeners();
  }

  /// Change l'URL des tuiles de carte
  void changeTileLayer(String url) {
    _tileLayerUrl = url;
    notifyListeners();
  }

  /// Zoom avant
  void zoomIn() {
    if (_mapZoom < 18) {
      _mapZoom += 1;
      _mapController.move(_mapCenter, _mapZoom);
      notifyListeners();
    }
  }

  /// Zoom arrière
  void zoomOut() {
    if (_mapZoom > 3) {
      _mapZoom -= 1;
      _mapController.move(_mapCenter, _mapZoom);
      notifyListeners();
    }
  }

  /// Définit l'état de chargement
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Obtient les informations de diagnostic du service de localisation
  Map<String, dynamic> getLocationDiagnostic() {
    return _locationService.getDiagnostic();
  }

  /// Force un rafraîchissement des permissions de localisation
  Future<void> refreshLocationPermissions() async {
    await _locationService.refreshStatus();
    notifyListeners();
  }

  @override
  void dispose() {
    _locationService.stopLocationTracking();
    super.dispose();
  }
}
