import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// Point de mesure
class MeasurementPoint {
  final LatLng position;
  final String label;
  final DateTime createdAt;

  MeasurementPoint({
    required this.position,
    required this.label,
    required this.createdAt,
  });
}

/// Mode de mesure
enum MeasurementMode { none, distance, area }

/// Service de mesure interactif
class MeasurementService extends ChangeNotifier {
  static final MeasurementService _instance = MeasurementService._internal();
  factory MeasurementService() => _instance;
  MeasurementService._internal();

  static const Distance _distance = Distance();

  MeasurementMode _currentMode = MeasurementMode.none;
  List<LatLng> _currentPoints = [];
  List<MeasurementPoint> _measurementPoints = [];
  double _currentDistance = 0.0;
  double _currentArea = 0.0;

  /// Mode de mesure actuel
  MeasurementMode get currentMode => _currentMode;

  /// Points de mesure actuels
  List<LatLng> get currentPoints => _currentPoints;

  /// Points de mesure sauvegardés
  List<MeasurementPoint> get measurementPoints => _measurementPoints;

  /// Distance actuelle mesurée
  double get currentDistance => _currentDistance;

  /// Aire actuelle mesurée
  double get currentArea => _currentArea;

  /// Si une mesure est en cours
  bool get isMeasuring => _currentMode != MeasurementMode.none;

  /// Démarre la mesure de distance
  void startDistanceMeasurement() {
    _currentMode = MeasurementMode.distance;
    _currentPoints.clear();
    _currentDistance = 0.0;
    notifyListeners();
  }

  /// Démarre la mesure d'aire
  void startAreaMeasurement() {
    _currentMode = MeasurementMode.area;
    _currentPoints.clear();
    _currentArea = 0.0;
    notifyListeners();
  }

  /// Ajoute un point de mesure
  void addMeasurementPoint(LatLng point) {
    if (_currentMode == MeasurementMode.none) return;

    _currentPoints.add(point);

    if (_currentMode == MeasurementMode.distance) {
      _calculateCurrentDistance();
    } else if (_currentMode == MeasurementMode.area) {
      _calculateCurrentArea();
    }

    notifyListeners();
  }

  /// Supprime le dernier point
  void removeLastPoint() {
    if (_currentPoints.isNotEmpty) {
      _currentPoints.removeLast();

      if (_currentMode == MeasurementMode.distance) {
        _calculateCurrentDistance();
      } else if (_currentMode == MeasurementMode.area) {
        _calculateCurrentArea();
      }

      notifyListeners();
    }
  }

  /// Finalise la mesure
  void finalizeMeasurement() {
    if (_currentPoints.isNotEmpty && _currentMode != MeasurementMode.none) {
      String label;
      if (_currentMode == MeasurementMode.distance) {
        label = 'Distance: ${formatDistance(_currentDistance)}';
      } else {
        label = 'Aire: ${formatArea(_currentArea)}';
      }

      _measurementPoints.add(
        MeasurementPoint(
          position: _currentPoints.first,
          label: label,
          createdAt: DateTime.now(),
        ),
      );
    }

    _currentMode = MeasurementMode.none;
    _currentPoints.clear();
    _currentDistance = 0.0;
    _currentArea = 0.0;
    notifyListeners();
  }

  /// Efface toutes les mesures
  void clearMeasurements() {
    _currentMode = MeasurementMode.none;
    _currentPoints.clear();
    _measurementPoints.clear();
    _currentDistance = 0.0;
    _currentArea = 0.0;
    notifyListeners();
  }

  /// Calcule la distance actuelle
  void _calculateCurrentDistance() {
    if (_currentPoints.length < 2) {
      _currentDistance = 0.0;
      return;
    }

    _currentDistance = 0.0;
    for (int i = 0; i < _currentPoints.length - 1; i++) {
      _currentDistance += _distance.as(
        LengthUnit.Meter,
        _currentPoints[i],
        _currentPoints[i + 1],
      );
    }
  }

  /// Calcule l'aire actuelle
  void _calculateCurrentArea() {
    if (_currentPoints.length < 3) {
      _currentArea = 0.0;
      return;
    }

    // Fermer le polygone pour le calcul
    List<LatLng> polygon = List.from(_currentPoints);
    if (polygon.first.latitude != polygon.last.latitude ||
        polygon.first.longitude != polygon.last.longitude) {
      polygon.add(polygon.first);
    }

    double area = 0.0;
    for (int i = 0; i < polygon.length - 1; i++) {
      double lat1 = polygon[i].latitude * math.pi / 180;
      double lat2 = polygon[i + 1].latitude * math.pi / 180;
      double lon1 = polygon[i].longitude * math.pi / 180;
      double lon2 = polygon[i + 1].longitude * math.pi / 180;

      area += (lon2 - lon1) * (2 + math.sin(lat1) + math.sin(lat2));
    }

    area = area.abs() * 6378137 * 6378137 / 2; // Rayon de la Terre
    _currentArea = area;
  }

  /// Formate une distance pour l'affichage
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(1)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  /// Formate une aire pour l'affichage
  static String formatArea(double squareMeters) {
    if (squareMeters < 10000) {
      return '${squareMeters.toStringAsFixed(1)} m²';
    } else if (squareMeters < 1000000) {
      return '${(squareMeters / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${(squareMeters / 1000000).toStringAsFixed(2)} km²';
    }
  }

  /// Calcule la distance entre deux points
  static double calculateDistance(LatLng point1, LatLng point2) {
    return _distance.as(LengthUnit.Meter, point1, point2);
  }

  /// Calcule l'aire d'un polygone (en mètres carrés)
  static double calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;

    // Fermer le polygone si nécessaire
    List<LatLng> polygon = List.from(points);
    if (polygon.first.latitude != polygon.last.latitude ||
        polygon.first.longitude != polygon.last.longitude) {
      polygon.add(polygon.first);
    }

    double area = 0.0;
    for (int i = 0; i < polygon.length - 1; i++) {
      double lat1 = polygon[i].latitude * math.pi / 180;
      double lat2 = polygon[i + 1].latitude * math.pi / 180;
      double lon1 = polygon[i].longitude * math.pi / 180;
      double lon2 = polygon[i + 1].longitude * math.pi / 180;

      area += (lon2 - lon1) * (2 + math.sin(lat1) + math.sin(lat2));
    }

    area = area.abs() * 6378137 * 6378137 / 2;
    return area;
  }

  @override
  void dispose() {
    clearMeasurements();
    super.dispose();
  }
}
