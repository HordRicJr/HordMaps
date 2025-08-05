import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;

/// Modèle de données d'élévation
class ElevationData {
  final LatLng position;
  final double elevation;
  final String source;
  final DateTime timestamp;

  ElevationData({
    required this.position,
    required this.elevation,
    required this.source,
    required this.timestamp,
  });
}

/// Service de gestion des élévations et du relief
class ElevationService extends ChangeNotifier {
  static final ElevationService _instance = ElevationService._internal();
  factory ElevationService() => _instance;
  ElevationService._internal();

  final Dio _dio = Dio();
  final Map<String, ElevationData> _elevationCache = {};
  bool _isEnabled = false;
  double _maxElevation = 0;
  double _minElevation = 0;

  // Getters
  bool get isEnabled => _isEnabled;
  double get maxElevation => _maxElevation;
  double get minElevation => _minElevation;
  Map<String, ElevationData> get elevationCache =>
      Map.unmodifiable(_elevationCache);

  /// Active/désactive le service d'élévation
  void toggleElevation() {
    _isEnabled = !_isEnabled;
    if (!_isEnabled) {
      _elevationCache.clear();
    }
    notifyListeners();
  }

  /// Obtient l'élévation pour un point (API gratuite Open-Elevation)
  Future<ElevationData?> getElevation(LatLng position) async {
    if (!_isEnabled) return null;

    final key =
        '${position.latitude.toStringAsFixed(4)},${position.longitude.toStringAsFixed(4)}';

    // Vérifier le cache
    if (_elevationCache.containsKey(key)) {
      return _elevationCache[key];
    }

    try {
      // API Open-Elevation (gratuite, pas de clé requise)
      final response = await _dio.get(
        'https://api.open-elevation.com/api/v1/lookup',
        queryParameters: {
          'locations': '${position.latitude},${position.longitude}',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data['results'] != null) {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          final elevation = (results[0]['elevation'] as num).toDouble();

          final elevationData = ElevationData(
            position: position,
            elevation: elevation,
            source: 'Open-Elevation',
            timestamp: DateTime.now(),
          );

          _elevationCache[key] = elevationData;
          _updateElevationRange(elevation);
          notifyListeners();
          return elevationData;
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de l\'élévation: $e');
      // Fallback avec simulation si l'API échoue
      return _generateSimulatedElevation(position);
    }

    return null;
  }

  /// Obtient les élévations pour un chemin
  Future<List<ElevationData>> getPathElevations(List<LatLng> points) async {
    if (!_isEnabled || points.isEmpty) return [];

    final elevations = <ElevationData>[];

    for (final point in points) {
      final elevation = await getElevation(point);
      if (elevation != null) {
        elevations.add(elevation);
      }
    }

    return elevations;
  }

  /// Génère un profil d'élévation simulé pour le développement
  ElevationData _generateSimulatedElevation(LatLng position) {
    // Simulation basée sur les coordonnées pour cohérence
    final seed =
        (position.latitude * 1000).toInt() +
        (position.longitude * 1000).toInt();
    final random = math.Random(seed);

    // Élévation simulée entre 0 et 1000m avec variations réalistes
    final baseElevation = random.nextDouble() * 800;
    final variation = (random.nextDouble() - 0.5) * 200;
    final elevation = math.max(0, baseElevation + variation);

    final elevationData = ElevationData(
      position: position,
      elevation: elevation.toDouble(),
      source: 'Simulation',
      timestamp: DateTime.now(),
    );

    final key =
        '${position.latitude.toStringAsFixed(4)},${position.longitude.toStringAsFixed(4)}';
    _elevationCache[key] = elevationData;
    _updateElevationRange(elevation.toDouble());

    return elevationData;
  }

  /// Met à jour les valeurs min/max d'élévation
  void _updateElevationRange(double elevation) {
    if (_elevationCache.length == 1) {
      _maxElevation = elevation;
      _minElevation = elevation;
    } else {
      _maxElevation = math.max(_maxElevation, elevation);
      _minElevation = math.min(_minElevation, elevation);
    }
  }

  /// Génère les courbes de niveau pour une zone
  List<List<LatLng>> generateContourLines(
    LatLng center,
    double radiusKm, {
    int intervals = 50,
  }) {
    if (!_isEnabled) return [];

    final contours = <List<LatLng>>[];
    final gridSize = 20; // Résolution de la grille

    // Grille de points autour du centre
    for (int level = 0; level < 10; level++) {
      final elevationLevel = _minElevation + (level * intervals);
      final contourPoints = <LatLng>[];

      for (int i = 0; i < gridSize; i++) {
        for (int j = 0; j < gridSize; j++) {
          final lat =
              center.latitude +
              (i - gridSize / 2) * (radiusKm / 111.32) / gridSize;
          final lng =
              center.longitude +
              (j - gridSize / 2) *
                  (radiusKm /
                      (111.32 * math.cos(center.latitude * math.pi / 180))) /
                  gridSize;

          final point = LatLng(lat, lng);
          final elevation = _generateSimulatedElevation(point).elevation;

          // Ajouter le point si proche du niveau d'élévation
          if ((elevation - elevationLevel).abs() < intervals / 2) {
            contourPoints.add(point);
          }
        }
      }

      if (contourPoints.isNotEmpty) {
        contours.add(contourPoints);
      }
    }

    return contours;
  }

  /// Calcule la pente entre deux points
  double calculateSlope(ElevationData point1, ElevationData point2) {
    const distance = Distance();
    final horizontalDistance = distance.as(
      LengthUnit.Meter,
      point1.position,
      point2.position,
    );
    final verticalDistance = (point2.elevation - point1.elevation).abs();

    if (horizontalDistance == 0) return 0;

    return math.atan(verticalDistance / horizontalDistance) * (180 / math.pi);
  }

  /// Formate l'élévation pour l'affichage
  String formatElevation(double elevation) {
    if (elevation >= 1000) {
      return '${(elevation / 1000).toStringAsFixed(1)} km';
    } else {
      return '${elevation.toStringAsFixed(0)} m';
    }
  }

  /// Nettoie le cache d'élévations
  void clearCache() {
    _elevationCache.clear();
    _maxElevation = 0;
    _minElevation = 0;
    notifyListeners();
  }

  /// Libère les ressources
  void dispose() {
    _elevationCache.clear();
    _dio.close();
    super.dispose();
  }
}
