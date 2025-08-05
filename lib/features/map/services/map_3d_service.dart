import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// Service pour la simulation d'effets 3D sur la carte
class Map3DService extends ChangeNotifier {
  static Map3DService? _instance;
  static Map3DService get instance => _instance ??= Map3DService._();
  Map3DService._();

  bool _is3DEnabled = false;
  double _buildingHeight = 15.0;
  double _tiltAngle = 0.0;
  double _bearing = 0.0;

  // Getters
  bool get is3DEnabled => _is3DEnabled;
  double get buildingHeight => _buildingHeight;
  double get tiltAngle => _tiltAngle;
  double get bearing => _bearing;

  /// Active/désactive le mode 3D
  void toggle3DMode() {
    _is3DEnabled = !_is3DEnabled;
    notifyListeners();
  }

  /// Définit l'inclinaison de la vue (0-60 degrés)
  void setTilt(double angle) {
    _tiltAngle = math.max(0, math.min(60, angle));
    notifyListeners();
  }

  /// Définit la rotation de la carte (0-360 degrés)
  void setBearing(double bearing) {
    _bearing = bearing % 360;
    notifyListeners();
  }

  /// Définit la hauteur des bâtiments simulés
  void setBuildingHeight(double height) {
    _buildingHeight = math.max(5, math.min(50, height));
    notifyListeners();
  }

  /// Génère des marqueurs 3D simulés pour les bâtiments
  List<Marker> generate3DBuildings(LatLng center, double zoom) {
    if (!_is3DEnabled || zoom < 14) return [];

    final buildings = <Marker>[];
    final random = math.Random(42); // Seed fixe pour consistance

    // Nombre de bâtiments basé sur le zoom
    final buildingCount = (zoom - 14) * 20;

    for (int i = 0; i < buildingCount; i++) {
      // Position aléatoire autour du centre
      final latOffset = (random.nextDouble() - 0.5) * 0.01 / zoom;
      final lngOffset = (random.nextDouble() - 0.5) * 0.01 / zoom;

      final buildingPos = LatLng(
        center.latitude + latOffset,
        center.longitude + lngOffset,
      );

      // Hauteur aléatoire du bâtiment
      final height = random.nextDouble() * _buildingHeight + 5;

      buildings.add(_createBuildingMarker(buildingPos, height));
    }

    return buildings;
  }

  /// Crée un marqueur de bâtiment avec effet 3D
  Marker _createBuildingMarker(LatLng position, double height) {
    final shadowOffset = _calculateShadowOffset(height);

    return Marker(
      point: position,
      width: 20,
      height: height + 10,
      child: Stack(
        children: [
          // Ombre du bâtiment
          Positioned(
            left: shadowOffset.dx,
            top: shadowOffset.dy,
            child: Container(
              width: 12,
              height: height,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Bâtiment principal
          Container(
            width: 12,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey[300]!, Colors.grey[600]!],
              ),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.grey[400]!, width: 0.5),
            ),
          ),
          // Reflet de lumière
          Positioned(
            left: 2,
            top: 2,
            child: Container(
              width: 3,
              height: height * 0.6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Calcule l'offset de l'ombre basé sur l'inclinaison
  Offset _calculateShadowOffset(double height) {
    final shadowLength = height * 0.3 * math.sin(_tiltAngle * math.pi / 180);
    final bearingRad = _bearing * math.pi / 180;

    return Offset(
      shadowLength * math.cos(bearingRad),
      shadowLength * math.sin(bearingRad),
    );
  }

  /// Génère des marqueurs de relief/élévation
  List<Marker> generateElevationMarkers(LatLng center, double zoom) {
    if (!_is3DEnabled || zoom < 10) return [];

    final elevations = <Marker>[];
    final random = math.Random(123);

    // Simulation de courbes de niveau
    for (int i = 0; i < 15; i++) {
      final angle = i * 24.0; // 15 points * 24° = 360°
      final distance = 0.005 + random.nextDouble() * 0.01;

      final elevationPos = LatLng(
        center.latitude + distance * math.cos(angle * math.pi / 180),
        center.longitude + distance * math.sin(angle * math.pi / 180),
      );

      elevations.add(_createElevationMarker(elevationPos, 100 + i * 20));
    }

    return elevations;
  }

  /// Crée un marqueur d'élévation
  Marker _createElevationMarker(LatLng position, double elevation) {
    return Marker(
      point: position,
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Colors.brown.withOpacity(0.3), Colors.transparent],
          ),
        ),
        child: Center(
          child: Text(
            '${elevation.toInt()}m',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
        ),
      ),
    );
  }

  /// Génère des polylines de relief
  List<Polyline> generateReliefPolylines(LatLng center) {
    if (!_is3DEnabled) return [];

    final polylines = <Polyline>[];
    final random = math.Random(456);

    // Lignes de crête
    for (int i = 0; i < 5; i++) {
      final points = <LatLng>[];
      final baseAngle = i * 72.0; // 5 lignes * 72° = 360°

      for (int j = 0; j < 10; j++) {
        final distance = 0.002 + j * 0.001;
        final angleVariation = (random.nextDouble() - 0.5) * 20;
        final finalAngle = baseAngle + angleVariation;

        points.add(
          LatLng(
            center.latitude + distance * math.cos(finalAngle * math.pi / 180),
            center.longitude + distance * math.sin(finalAngle * math.pi / 180),
          ),
        );
      }

      polylines.add(
        Polyline(
          points: points,
          strokeWidth: 2.0,
          color: const Color.fromRGBO(121, 85, 72, 1).withOpacity(0.6),
          pattern: const StrokePattern.dotted(), // Ligne pointillée
        ),
      );
    }

    return polylines;
  }

  /// Applique une transformation de perspective à la vue
  Matrix4 getPerspectiveTransform() {
    if (!_is3DEnabled) return Matrix4.identity();

    final transform = Matrix4.identity();

    // Rotation selon l'inclinaison
    transform.rotateX(-_tiltAngle * math.pi / 180);

    // Rotation selon l'orientation
    transform.rotateZ(_bearing * math.pi / 180);

    // Légère perspective
    transform.setEntry(3, 2, -0.001);

    return transform;
  }

  /// Simule des données d'altitude pour une position
  double getSimulatedElevation(LatLng position) {
    // Algorithme de bruit de Perlin simplifié
    final x = position.longitude * 1000;
    final y = position.latitude * 1000;

    final noise1 = math.sin(x * 0.01) * math.cos(y * 0.01);
    final noise2 = math.sin(x * 0.02) * math.cos(y * 0.02) * 0.5;
    final noise3 = math.sin(x * 0.05) * math.cos(y * 0.05) * 0.25;

    final elevation = (noise1 + noise2 + noise3) * 500 + 300;
    return math.max(0, elevation);
  }

  /// Génère un profil d'élévation pour un itinéraire
  List<double> generateElevationProfile(List<LatLng> routePoints) {
    return routePoints.map((point) => getSimulatedElevation(point)).toList();
  }

  /// Calcule la pente entre deux points
  double calculateSlope(LatLng start, LatLng end) {
    final startElevation = getSimulatedElevation(start);
    final endElevation = getSimulatedElevation(end);

    const distance = Distance();
    final horizontalDistance = distance.as(LengthUnit.Meter, start, end);

    if (horizontalDistance == 0) return 0;

    final verticalDistance = endElevation - startElevation;
    return (verticalDistance / horizontalDistance) * 100; // Pourcentage
  }

  /// Sauvegarde les paramètres 3D
  Map<String, dynamic> toJson() {
    return {
      'is3DEnabled': _is3DEnabled,
      'buildingHeight': _buildingHeight,
      'tiltAngle': _tiltAngle,
      'bearing': _bearing,
    };
  }

  /// Charge les paramètres 3D
  void fromJson(Map<String, dynamic> json) {
    _is3DEnabled = json['is3DEnabled'] ?? false;
    _buildingHeight = json['buildingHeight']?.toDouble() ?? 15.0;
    _tiltAngle = json['tiltAngle']?.toDouble() ?? 0.0;
    _bearing = json['bearing']?.toDouble() ?? 0.0;
  }
}
