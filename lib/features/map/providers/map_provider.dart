import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/location_service.dart';
import '../../../../shared/extensions/color_extensions.dart';

class MapProvider extends ChangeNotifier {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService.instance;

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

  MapProvider() {
    _initializeLocation();
  }

  /// Initialise la géolocalisation
  Future<void> _initializeLocation() async {
    _setLoading(true);

    try {
      // Obtenir la position actuelle
      Position? position = await _locationService.getCurrentPosition();
      if (position != null) {
        final latLng = LatLng(position.latitude, position.longitude);
        _currentLocation = latLng;
        _mapCenter = latLng;

        // Ajouter un marqueur pour la position actuelle
        _addCurrentLocationMarker(latLng);

        // Démarrer le suivi de position en temps réel
        await _startLocationTracking();
      }
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
      await _locationService.startTracking();
      _locationService.positionStream.listen((position) {
        final latLng = LatLng(position.latitude, position.longitude);
        updateCurrentLocation(latLng);
      });
    } catch (e) {
      debugPrint('Erreur démarrage suivi position: $e');
    }
  }

  /// Met à jour la position actuelle
  void updateCurrentLocation(LatLng newPosition) {
    _currentLocation = newPosition;

    // Mettre à jour le marqueur de position actuelle
    _addCurrentLocationMarker(newPosition);

    // Si le mode suivi est activé, centrer la carte
    if (_isFollowingUser) {
      _animateToPosition(newPosition);
    }

    notifyListeners();
  }

  /// Ajoute ou met à jour le marqueur de position actuelle
  void _addCurrentLocationMarker(LatLng position) {
    // Supprimer l'ancien marqueur de position actuelle
    _markers.removeWhere((marker) => marker.point == position);

    // Ajouter le nouveau marqueur
    _markers.add(
      Marker(
        point: position,
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withCustomOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  /// Active/désactive le mode suivi de l'utilisateur
  void toggleFollowUser() {
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
      Position? position = await _locationService.getCurrentPosition();
      if (position != null) {
        final latLng = LatLng(position.latitude, position.longitude);
        _currentLocation = latLng;
        _addCurrentLocationMarker(latLng);
        await _animateToPosition(latLng);
      }
    }
  }

  /// Obtient la position actuelle (rafraîchit si nécessaire)
  Future<LatLng?> getCurrentLocation() async {
    if (_currentLocation == null) {
      Position? position = await _locationService.getCurrentPosition();
      if (position != null) {
        final latLng = LatLng(position.latitude, position.longitude);
        _currentLocation = latLng;
        _addCurrentLocationMarker(latLng);
        notifyListeners();
      }
    }
    return _currentLocation;
  }

  /// Anime la carte vers une position donnée
  Future<void> _animateToPosition(LatLng position, {double? zoom}) async {
    _mapCenter = position;
    if (zoom != null) {
      _mapZoom = zoom;
    }

    // Animation fluide vers la nouvelle position
    _mapController.move(position, _mapZoom);
    notifyListeners();
  }

  /// Navigue vers une position spécifique (méthode publique)
  Future<void> animateToLocation(LatLng position, {double? zoom}) async {
    await _animateToPosition(position, zoom: zoom);
  }

  /// Met à jour la position et le zoom de la carte
  void updateMapPosition(LatLng center, double zoom) {
    _mapCenter = center;
    _mapZoom = zoom;
    notifyListeners();
  }

  /// Ajoute un marqueur personnalisé
  void addMarker(Marker marker) {
    _markers.add(marker);
    notifyListeners();
  }

  /// Supprime un marqueur
  void removeMarker(LatLng point) {
    _markers.removeWhere((marker) => marker.point == point);
    notifyListeners();
  }

  /// Ajoute une route (polyline)
  void addRoute(Polyline route) {
    _routes.add(route);
    notifyListeners();
  }

  /// Supprime toutes les routes
  void clearRoutes() {
    _routes.clear();
    notifyListeners();
  }

  /// Met à jour l'état de chargement
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Change le style de carte (tiles)
  void changeMapStyle(String tileUrl) {
    _tileLayerUrl = tileUrl;
    notifyListeners();
  }

  /// Définit le point de départ pour l'itinéraire
  void setStartPoint(LatLng point) {
    _startPoint = point;
    _addRouteMarker(point, 'start');
    notifyListeners();
  }

  /// Définit le point d'arrivée pour l'itinéraire
  void setEndPoint(LatLng point) {
    _endPoint = point;
    _addRouteMarker(point, 'end');
    notifyListeners();
  }

  /// Ajoute un marqueur pour les points d'itinéraire
  void _addRouteMarker(LatLng point, String type) {
    // Supprimer l'ancien marqueur du même type
    _markers.removeWhere(
      (marker) =>
          (marker.child as Container).decoration != null &&
          (marker.child as Container).decoration is BoxDecoration,
    );

    final color = type == 'start' ? Colors.green : Colors.red;
    final icon = type == 'start' ? Icons.my_location : Icons.location_on;

    _markers.add(
      Marker(
        point: point,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withCustomOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  /// Efface les points d'itinéraire
  void clearRoutePoints() {
    _startPoint = null;
    _endPoint = null;
    // Supprimer les marqueurs d'itinéraire
    _markers.removeWhere(
      (marker) =>
          (marker.child as Container).decoration != null &&
          (marker.child as Container).decoration is BoxDecoration,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    // Le LocationService est singleton, pas besoin de dispose
    super.dispose();
  }
}
