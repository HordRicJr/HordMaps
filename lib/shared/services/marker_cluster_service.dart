import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

/// Configuration pour le clustering des marqueurs
class ClusterConfig {
  final int maxClusterRadius;
  final int disableClusteringAtZoom;
  final Size size;
  final Color backgroundColor;
  final Color textColor;
  final double borderRadius;
  final bool showCount;

  const ClusterConfig({
    this.maxClusterRadius = 80,
    this.disableClusteringAtZoom = 15,
    this.size = const Size(40, 40),
    this.backgroundColor = Colors.blue,
    this.textColor = Colors.white,
    this.borderRadius = 20.0,
    this.showCount = true,
  });
}

/// Type de marqueur personnalisé
enum MarkerCategory {
  favorite('Favori', Icons.favorite, Colors.red),
  restaurant('Restaurant', Icons.restaurant, Colors.orange),
  hotel('Hôtel', Icons.hotel, Colors.blue),
  gasStation('Station-service', Icons.local_gas_station, Colors.green),
  hospital('Hôpital', Icons.local_hospital, Colors.red),
  school('École', Icons.school, Colors.purple),
  shopping('Shopping', Icons.shopping_cart, Colors.pink),
  park('Parc', Icons.park, Colors.green),
  transport('Transport', Icons.directions_bus, Colors.indigo),
  tourist('Touristique', Icons.camera_alt, Colors.cyan),
  custom('Personnalisé', Icons.place, Colors.grey);

  const MarkerCategory(this.label, this.icon, this.defaultColor);
  final String label;
  final IconData icon;
  final Color defaultColor;
}

/// Données d'un marqueur personnalisé
class CustomMarker {
  final String id;
  final LatLng position;
  final String title;
  final String? description;
  final MarkerCategory category;
  final Color? customColor;
  final IconData? customIcon;
  final double? customSize;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool isVisible;

  CustomMarker({
    required this.id,
    required this.position,
    required this.title,
    this.description,
    this.category = MarkerCategory.custom,
    this.customColor,
    this.customIcon,
    this.customSize,
    this.metadata,
    DateTime? createdAt,
    this.isVisible = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get effectiveColor => customColor ?? category.defaultColor;
  IconData get effectiveIcon => customIcon ?? category.icon;
  double get effectiveSize => customSize ?? 40.0;

  CustomMarker copyWith({
    String? id,
    LatLng? position,
    String? title,
    String? description,
    MarkerCategory? category,
    Color? customColor,
    IconData? customIcon,
    double? customSize,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    bool? isVisible,
  }) {
    return CustomMarker(
      id: id ?? this.id,
      position: position ?? this.position,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      customColor: customColor ?? this.customColor,
      customIcon: customIcon ?? this.customIcon,
      customSize: customSize ?? this.customSize,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'title': title,
      'description': description,
      'category': category.name,
      'customColor': customColor?.value,
      'customIcon': customIcon?.codePoint,
      'customSize': customSize,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'isVisible': isVisible,
    };
  }

  factory CustomMarker.fromJson(Map<String, dynamic> json) {
    return CustomMarker(
      id: json['id'],
      position: LatLng(json['latitude'], json['longitude']),
      title: json['title'],
      description: json['description'],
      category: MarkerCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => MarkerCategory.custom,
      ),
      customColor: json['customColor'] != null
          ? Color(json['customColor'])
          : null,
      customIcon: json['customIcon'] != null
          ? IconData(json['customIcon'], fontFamily: 'MaterialIcons')
          : null,
      customSize: json['customSize']?.toDouble(),
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['createdAt']),
      isVisible: json['isVisible'] ?? true,
    );
  }
}

/// Service de gestion du clustering des marqueurs
class MarkerClusterService {
  /// Crée un layer de clustering pour flutter_map
  static MarkerClusterLayerWidget createClusterLayer({
    required List<CustomMarker> markers,
    required ClusterConfig config,
    required Function(CustomMarker) onMarkerTap,
  }) {
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: config.maxClusterRadius,
        disableClusteringAtZoom: config.disableClusteringAtZoom,
        size: config.size,
        markers: markers
            .where((marker) => marker.isVisible)
            .map((marker) => _createFlutterMapMarker(marker, onMarkerTap))
            .toList(),
        builder: (context, markers) =>
            _buildClusterWidget(context, markers, config),
      ),
    );
  }

  /// Crée un marqueur Flutter Map à partir d'un CustomMarker
  static Marker _createFlutterMapMarker(
    CustomMarker customMarker,
    Function(CustomMarker) onTap,
  ) {
    return Marker(
      point: customMarker.position,
      width: customMarker.effectiveSize,
      height: customMarker.effectiveSize,
      child: GestureDetector(
        onTap: () => onTap(customMarker),
        child: Container(
          decoration: BoxDecoration(
            color: customMarker.effectiveColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            customMarker.effectiveIcon,
            color: Colors.white,
            size: customMarker.effectiveSize * 0.6,
          ),
        ),
      ),
    );
  }

  /// Construit le widget de cluster
  static Widget _buildClusterWidget(
    BuildContext context,
    List<Marker> markers,
    ClusterConfig config,
  ) {
    return Container(
      width: config.size.width,
      height: config.size.height,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: config.showCount
            ? Text(
                markers.length.toString(),
                style: TextStyle(
                  color: config.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: config.size.width * 0.3,
                ),
              )
            : Icon(
                Icons.location_on,
                color: config.textColor,
                size: config.size.width * 0.6,
              ),
      ),
    );
  }

  /// Filtre les marqueurs par catégorie
  static List<CustomMarker> filterByCategory(
    List<CustomMarker> markers,
    List<MarkerCategory> categories,
  ) {
    if (categories.isEmpty) return markers;
    return markers
        .where((marker) => categories.contains(marker.category))
        .toList();
  }

  /// Filtre les marqueurs par zone géographique
  static List<CustomMarker> filterByBounds(
    List<CustomMarker> markers,
    LatLngBounds bounds,
  ) {
    return markers.where((marker) => bounds.contains(marker.position)).toList();
  }

  /// Trouve les marqueurs proches d'un point
  static List<CustomMarker> findNearbyMarkers(
    List<CustomMarker> markers,
    LatLng center,
    double radiusMeters,
  ) {
    const Distance distance = Distance();
    return markers.where((marker) {
      final dist = distance.as(LengthUnit.Meter, center, marker.position);
      return dist <= radiusMeters;
    }).toList();
  }

  /// Groupe les marqueurs par catégorie
  static Map<MarkerCategory, List<CustomMarker>> groupByCategory(
    List<CustomMarker> markers,
  ) {
    final Map<MarkerCategory, List<CustomMarker>> grouped = {};
    for (final marker in markers) {
      grouped.putIfAbsent(marker.category, () => []).add(marker);
    }
    return grouped;
  }

  /// Calcule les statistiques des marqueurs
  static Map<String, dynamic> calculateStats(List<CustomMarker> markers) {
    final grouped = groupByCategory(markers);
    final stats = <String, dynamic>{
      'total': markers.length,
      'visible': markers.where((m) => m.isVisible).length,
      'byCategory': {},
    };

    for (final entry in grouped.entries) {
      stats['byCategory'][entry.key.label] = entry.value.length;
    }

    return stats;
  }

  /// Exporte les marqueurs en JSON
  static List<Map<String, dynamic>> exportMarkers(List<CustomMarker> markers) {
    return markers.map((marker) => marker.toJson()).toList();
  }

  /// Importe les marqueurs depuis JSON
  static List<CustomMarker> importMarkers(List<dynamic> jsonList) {
    return jsonList
        .cast<Map<String, dynamic>>()
        .map((json) => CustomMarker.fromJson(json))
        .toList();
  }
}

/// Provider pour la gestion des marqueurs et clustering
class MarkerClusterProvider extends ChangeNotifier {
  final List<CustomMarker> _markers = [];
  ClusterConfig _config = const ClusterConfig();
  List<MarkerCategory> _visibleCategories = MarkerCategory.values;
  LatLngBounds? _currentBounds;

  List<CustomMarker> get markers => List.unmodifiable(_markers);
  ClusterConfig get config => _config;
  List<MarkerCategory> get visibleCategories =>
      List.unmodifiable(_visibleCategories);

  List<CustomMarker> get visibleMarkers {
    var filtered = MarkerClusterService.filterByCategory(
      _markers,
      _visibleCategories,
    );
    if (_currentBounds != null) {
      filtered = MarkerClusterService.filterByBounds(filtered, _currentBounds!);
    }
    return filtered;
  }

  Map<String, dynamic> get stats =>
      MarkerClusterService.calculateStats(_markers);

  /// Ajoute un marqueur
  void addMarker(CustomMarker marker) {
    _markers.add(marker);
    notifyListeners();
  }

  /// Supprime un marqueur
  void removeMarker(String id) {
    _markers.removeWhere((marker) => marker.id == id);
    notifyListeners();
  }

  /// Met à jour un marqueur
  void updateMarker(String id, CustomMarker updatedMarker) {
    final index = _markers.indexWhere((marker) => marker.id == id);
    if (index != -1) {
      _markers[index] = updatedMarker;
      notifyListeners();
    }
  }

  /// Toggle la visibilité d'une catégorie
  void toggleCategory(MarkerCategory category) {
    if (_visibleCategories.contains(category)) {
      _visibleCategories.remove(category);
    } else {
      _visibleCategories.add(category);
    }
    notifyListeners();
  }

  /// Met à jour la configuration du clustering
  void updateConfig(ClusterConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  /// Met à jour les bounds actuelles
  void updateBounds(LatLngBounds? bounds) {
    _currentBounds = bounds;
    notifyListeners();
  }

  /// Trouve les marqueurs proches
  List<CustomMarker> findNearby(LatLng center, double radiusMeters) {
    return MarkerClusterService.findNearbyMarkers(
      _markers,
      center,
      radiusMeters,
    );
  }

  /// Vide tous les marqueurs
  void clearMarkers() {
    _markers.clear();
    notifyListeners();
  }

  /// Charge les marqueurs depuis une source de données
  void loadMarkers(List<CustomMarker> markers) {
    _markers.clear();
    _markers.addAll(markers);
    notifyListeners();
  }

  /// Exporte les marqueurs
  List<Map<String, dynamic>> exportMarkers() {
    return MarkerClusterService.exportMarkers(_markers);
  }

  /// Importe les marqueurs
  void importMarkers(List<dynamic> jsonList) {
    final importedMarkers = MarkerClusterService.importMarkers(jsonList);
    loadMarkers(importedMarkers);
  }
}
