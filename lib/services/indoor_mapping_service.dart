import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;
import '../../shared/extensions/color_extensions.dart';

/// Modèle d'un niveau de bâtiment
class BuildingLevel {
  final int level;
  final String name;
  final List<IndoorRoom> rooms;
  final List<IndoorPath> paths;
  final LatLng center;

  BuildingLevel({
    required this.level,
    required this.name,
    required this.rooms,
    required this.paths,
    required this.center,
  });
}

/// Modèle d'une pièce intérieure
class IndoorRoom {
  final String id;
  final String name;
  final String type; // office, shop, restaurant, etc.
  final List<LatLng> polygon;
  final Map<String, dynamic> metadata;

  IndoorRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.polygon,
    this.metadata = const {},
  });
}

/// Modèle d'un chemin intérieur
class IndoorPath {
  final String id;
  final List<LatLng> points;
  final String type; // corridor, stairs, elevator, etc.
  final bool isAccessible;

  IndoorPath({
    required this.id,
    required this.points,
    required this.type,
    this.isAccessible = true,
  });
}

/// Modèle d'un bâtiment avec plan intérieur
class IndoorBuilding {
  final String id;
  final String name;
  final LatLng entrance;
  final List<BuildingLevel> levels;
  final String address;
  final Map<String, dynamic> amenities;

  IndoorBuilding({
    required this.id,
    required this.name,
    required this.entrance,
    required this.levels,
    required this.address,
    this.amenities = const {},
  });
}

/// Service de navigation intérieure
class IndoorMappingService extends ChangeNotifier {
  static final IndoorMappingService _instance =
      IndoorMappingService._internal();
  factory IndoorMappingService() => _instance;
  IndoorMappingService._internal();

  final Map<String, IndoorBuilding> _buildings = {};
  IndoorBuilding? _currentBuilding;
  int _currentLevel = 0;
  bool _isIndoorMode = false;

  // Getters
  Map<String, IndoorBuilding> get buildings => Map.unmodifiable(_buildings);
  IndoorBuilding? get currentBuilding => _currentBuilding;
  int get currentLevel => _currentLevel;
  bool get isIndoorMode => _isIndoorMode;

  BuildingLevel? get currentBuildingLevel => _currentBuilding?.levels
      .where((level) => level.level == _currentLevel)
      .firstOrNull;

  /// Active/désactive le mode intérieur
  void toggleIndoorMode() {
    _isIndoorMode = !_isIndoorMode;
    if (!_isIndoorMode) {
      _currentBuilding = null;
      _currentLevel = 0;
    }
    notifyListeners();
  }

  /// Charge les bâtiments simulés pour la démonstration
  void loadSimulatedBuildings() {
    _buildings.clear();

    // Simulation de centres commerciaux et bureaux
    _buildings['mall_01'] = _generateSimulatedMall();
    _buildings['office_01'] = _generateSimulatedOffice();
    _buildings['hospital_01'] = _generateSimulatedHospital();

    notifyListeners();
  }

  /// Recherche de bâtiments à proximité
  List<IndoorBuilding> findNearbyBuildings(
    LatLng position, {
    double radiusKm = 1.0,
  }) {
    const distance = Distance();

    return _buildings.values.where((building) {
      final buildingDistance = distance.as(
        LengthUnit.Kilometer,
        position,
        building.entrance,
      );
      return buildingDistance <= radiusKm;
    }).toList();
  }

  /// Entre dans un bâtiment
  void enterBuilding(String buildingId) {
    if (_buildings.containsKey(buildingId)) {
      _currentBuilding = _buildings[buildingId];
      _currentLevel = 0; // Rez-de-chaussée par défaut
      _isIndoorMode = true;
      notifyListeners();
    }
  }

  /// Sort du bâtiment actuel
  void exitBuilding() {
    _currentBuilding = null;
    _currentLevel = 0;
    _isIndoorMode = false;
    notifyListeners();
  }

  /// Change de niveau dans le bâtiment
  void changeLevel(int level) {
    if (_currentBuilding != null) {
      final availableLevels = _currentBuilding!.levels
          .map((l) => l.level)
          .toList();
      if (availableLevels.contains(level)) {
        _currentLevel = level;
        notifyListeners();
      }
    }
  }

  /// Génère les polygones pour le niveau actuel
  List<Polygon> getCurrentLevelPolygons() {
    final currentLevel = currentBuildingLevel;
    if (currentLevel == null) return [];

    final polygons = <Polygon>[];

    // Polygones des pièces
    for (final room in currentLevel.rooms) {
      polygons.add(
        Polygon(
          points: room.polygon,
          color: _getRoomColor(room.type).withCustomOpacity(0.3),
          borderColor: _getRoomColor(room.type),
          borderStrokeWidth: 2.0,
          label: room.name,
        ),
      );
    }

    return polygons;
  }

  /// Génère les polylignes pour le niveau actuel
  List<Polyline> getCurrentLevelPaths() {
    final currentLevel = currentBuildingLevel;
    if (currentLevel == null) return [];

    final polylines = <Polyline>[];

    for (final path in currentLevel.paths) {
      polylines.add(
        Polyline(
          points: path.points,
          color: _getPathColor(path.type),
          strokeWidth: path.type == 'corridor' ? 3.0 : 2.0,
          pattern: path.isAccessible
              ? StrokePattern.solid()
              : StrokePattern.dotted(),
        ),
      );
    }

    return polylines;
  }

  /// Recherche de pièces par nom ou type
  List<IndoorRoom> searchRooms(String query) {
    if (_currentBuilding == null) return [];

    final allRooms = _currentBuilding!.levels
        .expand((level) => level.rooms)
        .toList();

    return allRooms.where((room) {
      return room.name.toLowerCase().contains(query.toLowerCase()) ||
          room.type.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  /// Navigation intérieure entre deux pièces
  List<LatLng> findIndoorRoute(IndoorRoom from, IndoorRoom to) {
    // Algorithme de navigation simplifié
    // Dans une vraie implémentation, on utiliserait A* ou Dijkstra

    final fromCenter = _getRoomCenter(from);
    final toCenter = _getRoomCenter(to);

    // Route directe simplifiée
    return [fromCenter, toCenter];
  }

  /// Génère un centre commercial simulé
  IndoorBuilding _generateSimulatedMall() {
    final center = const LatLng(6.1319, 1.2228); // Lomé, Togo

    final groundFloor = BuildingLevel(
      level: 0,
      name: 'Rez-de-chaussée',
      center: center,
      rooms: [
        IndoorRoom(
          id: 'shop_01',
          name: 'Apple Store',
          type: 'shop',
          polygon: _generateRectangle(center, 30, 20),
        ),
        IndoorRoom(
          id: 'shop_02',
          name: 'Zara',
          type: 'shop',
          polygon: _generateRectangle(
            LatLng(center.latitude + 0.0001, center.longitude),
            40,
            25,
          ),
        ),
        IndoorRoom(
          id: 'restaurant_01',
          name: 'McDonald\'s',
          type: 'restaurant',
          polygon: _generateRectangle(
            LatLng(center.latitude - 0.0001, center.longitude),
            35,
            30,
          ),
        ),
      ],
      paths: [
        IndoorPath(
          id: 'corridor_main',
          points: [
            LatLng(center.latitude - 0.0002, center.longitude - 0.0002),
            LatLng(center.latitude + 0.0002, center.longitude + 0.0002),
          ],
          type: 'corridor',
        ),
      ],
    );

    return IndoorBuilding(
      id: 'mall_01',
      name: 'Centre Commercial 2 Février',
      entrance: center,
      address: 'Boulevard du 13 Janvier, Lomé',
      levels: [groundFloor],
      amenities: {'parking': true, 'wifi': true, 'accessibility': true},
    );
  }

  /// Génère un immeuble de bureaux simulé
  IndoorBuilding _generateSimulatedOffice() {
    final center = const LatLng(48.8606, 2.3376); // Louvre

    final floors = <BuildingLevel>[];

    for (int i = 0; i < 5; i++) {
      floors.add(
        BuildingLevel(
          level: i,
          name: 'Étage $i',
          center: center,
          rooms: [
            IndoorRoom(
              id: 'office_${i}_01',
              name: 'Bureau ${i * 10 + 1}',
              type: 'office',
              polygon: _generateRectangle(center, 20, 15),
            ),
            IndoorRoom(
              id: 'office_${i}_02',
              name: 'Salle de réunion ${i * 10 + 2}',
              type: 'meeting',
              polygon: _generateRectangle(
                LatLng(center.latitude + 0.0001, center.longitude),
                25,
                20,
              ),
            ),
          ],
          paths: [
            IndoorPath(
              id: 'corridor_$i',
              points: [
                LatLng(center.latitude - 0.0001, center.longitude - 0.0001),
                LatLng(center.latitude + 0.0001, center.longitude + 0.0001),
              ],
              type: 'corridor',
            ),
          ],
        ),
      );
    }

    return IndoorBuilding(
      id: 'office_01',
      name: 'Tour de Bureaux',
      entrance: center,
      address: '456 Avenue des Champs',
      levels: floors,
    );
  }

  /// Génère un hôpital simulé
  IndoorBuilding _generateSimulatedHospital() {
    final center = const LatLng(48.8534, 2.3488); // Notre-Dame

    final groundFloor = BuildingLevel(
      level: 0,
      name: 'Accueil',
      center: center,
      rooms: [
        IndoorRoom(
          id: 'reception',
          name: 'Accueil',
          type: 'reception',
          polygon: _generateRectangle(center, 40, 20),
        ),
        IndoorRoom(
          id: 'emergency',
          name: 'Urgences',
          type: 'emergency',
          polygon: _generateRectangle(
            LatLng(center.latitude + 0.0001, center.longitude),
            50,
            30,
          ),
        ),
        IndoorRoom(
          id: 'pharmacy',
          name: 'Pharmacie',
          type: 'pharmacy',
          polygon: _generateRectangle(
            LatLng(center.latitude - 0.0001, center.longitude),
            25,
            15,
          ),
        ),
      ],
      paths: [
        IndoorPath(
          id: 'main_corridor',
          points: [
            LatLng(center.latitude - 0.0002, center.longitude),
            LatLng(center.latitude + 0.0002, center.longitude),
          ],
          type: 'corridor',
          isAccessible: true,
        ),
      ],
    );

    return IndoorBuilding(
      id: 'hospital_01',
      name: 'Hôpital Central',
      entrance: center,
      address: '789 Boulevard de l\'Hôpital',
      levels: [groundFloor],
      amenities: {'accessibility': true, 'parking': true, 'emergency': true},
    );
  }

  /// Génère un rectangle de coordonnées
  List<LatLng> _generateRectangle(
    LatLng center,
    double widthMeters,
    double heightMeters,
  ) {
    const double metersPerDegree = 111320;

    final halfWidth = widthMeters / (2 * metersPerDegree);
    final halfHeight =
        heightMeters /
        (2 * metersPerDegree * math.cos(center.latitude * math.pi / 180));

    return [
      LatLng(center.latitude - halfHeight, center.longitude - halfWidth),
      LatLng(center.latitude + halfHeight, center.longitude - halfWidth),
      LatLng(center.latitude + halfHeight, center.longitude + halfWidth),
      LatLng(center.latitude - halfHeight, center.longitude + halfWidth),
    ];
  }

  /// Obtient le centre d'une pièce
  LatLng _getRoomCenter(IndoorRoom room) {
    if (room.polygon.isEmpty) return const LatLng(0, 0);

    double lat = 0, lng = 0;
    for (final point in room.polygon) {
      lat += point.latitude;
      lng += point.longitude;
    }

    return LatLng(lat / room.polygon.length, lng / room.polygon.length);
  }

  /// Obtient la couleur d'une pièce selon son type
  Color _getRoomColor(String type) {
    switch (type) {
      case 'shop':
        return Colors.blue;
      case 'restaurant':
        return Colors.orange;
      case 'office':
        return Colors.green;
      case 'meeting':
        return Colors.purple;
      case 'reception':
        return Colors.cyan;
      case 'emergency':
        return Colors.red;
      case 'pharmacy':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  /// Obtient la couleur d'un chemin selon son type
  Color _getPathColor(String type) {
    switch (type) {
      case 'corridor':
        return Colors.blue;
      case 'stairs':
        return Colors.orange;
      case 'elevator':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
