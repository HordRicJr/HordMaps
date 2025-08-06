import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../extensions/color_extensions.dart';
import 'dart:math' as math;

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

class MeasurementService {
  static const Distance _distance = Distance();

  /// Calcule la distance entre deux points
  static double calculateDistance(LatLng point1, LatLng point2) {
    return _distance.as(LengthUnit.Meter, point1, point2);
  }

  /// Calcule la distance totale d'un chemin
  static double calculatePathDistance(List<LatLng> points) {
    if (points.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += calculateDistance(points[i], points[i + 1]);
    }
    return totalDistance;
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
      area +=
          _toRadians(polygon[i].longitude) *
              math.sin(_toRadians(polygon[i + 1].latitude)) -
          _toRadians(polygon[i + 1].longitude) *
              math.sin(_toRadians(polygon[i].latitude));
    }

    area = area.abs() / 2.0;
    const double earthRadius = 6371000; // mètres
    return area * earthRadius * earthRadius;
  }

  /// Convertit des degrés en radians
  static double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Calcule le centre d'un groupe de points
  static LatLng calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return LatLng(0, 0);

    double lat = 0.0;
    double lng = 0.0;

    for (LatLng point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }

    return LatLng(lat / points.length, lng / points.length);
  }

  /// Formate une distance pour l'affichage
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(1)} m';
    } else if (meters < 10000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
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

  /// Calcule le cap entre deux points
  static double calculateBearing(LatLng start, LatLng end) {
    final startLat = _toRadians(start.latitude);
    final startLng = _toRadians(start.longitude);
    final endLat = _toRadians(end.latitude);
    final endLng = _toRadians(end.longitude);

    final deltaLng = endLng - startLng;

    final y = math.sin(deltaLng) * math.cos(endLat);
    final x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(deltaLng);

    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  /// Convertit un cap en direction cardinale
  static String bearingToDirection(double bearing) {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSO',
      'SO',
      'OSO',
      'O',
      'ONO',
      'NO',
      'NNO',
    ];

    final index = ((bearing + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }
}

/// Widget pour les outils de mesure
class MeasurementTools extends StatefulWidget {
  final Function(List<LatLng>) onMeasurement;
  final VoidCallback onClear;

  const MeasurementTools({
    super.key,
    required this.onMeasurement,
    required this.onClear,
  });

  @override
  State<MeasurementTools> createState() => _MeasurementToolsState();
}

class _MeasurementToolsState extends State<MeasurementTools> {
  String _mode = 'distance'; // distance, area
  final List<LatLng> _points = [];
  double? _result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sélecteur de mode
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _mode = 'distance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mode == 'distance'
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                  ),
                  child: const Text('Distance'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _mode = 'area'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mode == 'area'
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                  ),
                  child: const Text('Surface'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Informations
          if (_points.isNotEmpty) ...[
            Text(
              'Points: ${_points.length}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              Text(
                _mode == 'distance'
                    ? 'Distance: ${MeasurementService.formatDistance(_result!)}'
                    : 'Surface: ${MeasurementService.formatArea(_result!)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),

          // Instructions
          Text(
            _mode == 'distance'
                ? 'Tapez sur la carte pour ajouter des points de mesure'
                : 'Tapez pour créer un polygone et mesurer la surface',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _points.isNotEmpty ? _clear : null,
                  child: const Text('Effacer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _points.length >= 2 ? _calculate : null,
                  child: const Text('Calculer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _calculate() {
    if (_points.length < 2) return;

    setState(() {
      if (_mode == 'distance') {
        _result = MeasurementService.calculatePathDistance(_points);
      } else {
        if (_points.length >= 3) {
          _result = MeasurementService.calculatePolygonArea(_points);
        }
      }
    });
  }

  void _clear() {
    setState(() {
      _points.clear();
      _result = null;
    });
    widget.onClear();
  }
}

/// Provider pour la gestion des mesures
class MeasurementProvider extends ChangeNotifier {
  bool _isActive = false;
  String _mode = 'distance';
  final List<LatLng> _points = [];
  final List<Marker> _markers = [];
  final List<Polyline> _lines = [];
  final List<Polygon> _polygons = [];
  double? _result;

  // Getters
  bool get isActive => _isActive;
  String get mode => _mode;
  List<LatLng> get points => _points;
  List<Marker> get markers => _markers;
  List<Polyline> get lines => _lines;
  List<Polygon> get polygons => _polygons;
  double? get result => _result;

  void setMode(String mode) {
    _mode = mode;
    _clearMeasurement();
    notifyListeners();
  }

  void startMeasurement() {
    _isActive = true;
    _clearMeasurement();
    notifyListeners();
  }

  void stopMeasurement() {
    _isActive = false;
    _clearMeasurement();
    notifyListeners();
  }

  void addPoint(LatLng point) {
    if (!_isActive) return;

    _points.add(point);
    _updateVisuals();
    _calculate();
    notifyListeners();
  }

  void _updateVisuals() {
    _markers.clear();
    _lines.clear();
    _polygons.clear();

    // Ajouter les marqueurs
    for (int i = 0; i < _points.length; i++) {
      _markers.add(
        Marker(
          point: _points[i],
          width: 24,
          height: 24,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Ajouter les lignes/polygones
    if (_points.length >= 2) {
      if (_mode == 'distance') {
        _lines.add(
          Polyline(points: _points, strokeWidth: 3, color: Colors.red),
        );
      } else if (_mode == 'area' && _points.length >= 3) {
        _polygons.add(
          Polygon(
            points: _points,
            borderStrokeWidth: 3,
            borderColor: Colors.red,
            color: Colors.red.withCustomOpacity(0.3),
          ),
        );
      }
    }
  }

  void _calculate() {
    if (_points.length < 2) return;

    if (_mode == 'distance') {
      _result = MeasurementService.calculatePathDistance(_points);
    } else if (_mode == 'area' && _points.length >= 3) {
      _result = MeasurementService.calculatePolygonArea(_points);
    }
  }

  void _clearMeasurement() {
    _points.clear();
    _markers.clear();
    _lines.clear();
    _polygons.clear();
    _result = null;
  }

  String getFormattedResult() {
    if (_result == null) return '';

    if (_mode == 'distance') {
      return MeasurementService.formatDistance(_result!);
    } else {
      return MeasurementService.formatArea(_result!);
    }
  }
}
