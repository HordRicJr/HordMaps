import 'package:flutter/material.dart';
import 'storage_service.dart';

/// Styles de carte disponibles
enum MapStyle {
  standard('Standard', 'https://atlas.microsoft.com/map/tile?api-version=2.0&tilesetId=microsoft.base.labels'),
  dark(
    'Sombre',
    'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png',
  ),
  satellite(
    'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ),
  terrain(
    'Relief',
    'https://stamen-tiles.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png',
  ),
  cycling('Cyclable', 'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png');

  const MapStyle(this.name, this.urlTemplate);
  final String name;
  final String urlTemplate;
}

/// Types de marqueurs
enum MarkerType {
  classic('Classique', Icons.location_on),
  modern('Moderne', Icons.place),
  pin('Épingle', Icons.push_pin),
  star('Étoile', Icons.star),
  circle('Cercle', Icons.circle);

  const MarkerType(this.name, this.icon);
  final String name;
  final IconData icon;
}

/// Configuration de la carte
class MapConfiguration {
  final MapStyle style;
  final MarkerType markerType;
  final Color primaryColor;
  final Color accentColor;
  final double markerSize;
  final bool showTraffic;
  final bool showTransit;
  final bool show3D;
  final double animationSpeed;
  final bool enableRotation;
  final bool enableTilt;

  const MapConfiguration({
    this.style = MapStyle.standard,
    this.markerType = MarkerType.classic,
    this.primaryColor = Colors.blue,
    this.accentColor = Colors.orange,
    this.markerSize = 40.0,
    this.showTraffic = false,
    this.showTransit = false,
    this.show3D = false,
    this.animationSpeed = 1.0,
    this.enableRotation = true,
    this.enableTilt = true,
  });

  MapConfiguration copyWith({
    MapStyle? style,
    MarkerType? markerType,
    Color? primaryColor,
    Color? accentColor,
    double? markerSize,
    bool? showTraffic,
    bool? showTransit,
    bool? show3D,
    double? animationSpeed,
    bool? enableRotation,
    bool? enableTilt,
  }) {
    return MapConfiguration(
      style: style ?? this.style,
      markerType: markerType ?? this.markerType,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      markerSize: markerSize ?? this.markerSize,
      showTraffic: showTraffic ?? this.showTraffic,
      showTransit: showTransit ?? this.showTransit,
      show3D: show3D ?? this.show3D,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      enableRotation: enableRotation ?? this.enableRotation,
      enableTilt: enableTilt ?? this.enableTilt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'style': style.name,
      'markerType': markerType.name,
      'primaryColor': primaryColor.toARGB32(),
      'accentColor': accentColor.toARGB32(),
      'markerSize': markerSize,
      'showTraffic': showTraffic,
      'showTransit': showTransit,
      'show3D': show3D,
      'animationSpeed': animationSpeed,
      'enableRotation': enableRotation,
      'enableTilt': enableTilt,
    };
  }

  factory MapConfiguration.fromJson(Map<String, dynamic> json) {
    return MapConfiguration(
      style: MapStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => MapStyle.standard,
      ),
      markerType: MarkerType.values.firstWhere(
        (m) => m.name == json['markerType'],
        orElse: () => MarkerType.classic,
      ),
      primaryColor: Color(json['primaryColor'] ?? Colors.blue.toARGB32()),
      accentColor: Color(json['accentColor'] ?? Colors.orange.toARGB32()),
      markerSize: json['markerSize']?.toDouble() ?? 40.0,
      showTraffic: json['showTraffic'] ?? false,
      showTransit: json['showTransit'] ?? false,
      show3D: json['show3D'] ?? false,
      animationSpeed: json['animationSpeed']?.toDouble() ?? 1.0,
      enableRotation: json['enableRotation'] ?? true,
      enableTilt: json['enableTilt'] ?? true,
    );
  }
}

/// Service de personnalisation de la carte
class MapCustomizationService {
  static const String _configKey = 'map_configuration';
  final StorageService _storage = StorageService();

  MapConfiguration _configuration = const MapConfiguration();
  MapConfiguration get configuration => _configuration;

  /// Initialise le service
  Future<void> initialize() async {
    await _loadConfiguration();
  }

  /// Charge la configuration depuis le stockage
  Future<void> _loadConfiguration() async {
    try {
      final configData = await _storage.getMap(_configKey);
      if (configData != null) {
        _configuration = MapConfiguration.fromJson(configData);
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de la configuration: $e');
    }
  }

  /// Sauvegarde la configuration
  Future<void> _saveConfiguration() async {
    try {
      await _storage.setMap(_configKey, _configuration.toJson());
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde de la configuration: $e');
    }
  }

  /// Met à jour le style de carte
  Future<void> updateMapStyle(MapStyle style) async {
    _configuration = _configuration.copyWith(style: style);
    await _saveConfiguration();
  }

  /// Met à jour le type de marqueur
  Future<void> updateMarkerType(MarkerType markerType) async {
    _configuration = _configuration.copyWith(markerType: markerType);
    await _saveConfiguration();
  }

  /// Met à jour les couleurs
  Future<void> updateColors({Color? primaryColor, Color? accentColor}) async {
    _configuration = _configuration.copyWith(
      primaryColor: primaryColor,
      accentColor: accentColor,
    );
    await _saveConfiguration();
  }

  /// Met à jour la taille des marqueurs
  Future<void> updateMarkerSize(double size) async {
    _configuration = _configuration.copyWith(markerSize: size);
    await _saveConfiguration();
  }

  /// Met à jour les options d'affichage
  Future<void> updateDisplayOptions({
    bool? showTraffic,
    bool? showTransit,
    bool? show3D,
  }) async {
    _configuration = _configuration.copyWith(
      showTraffic: showTraffic,
      showTransit: showTransit,
      show3D: show3D,
    );
    await _saveConfiguration();
  }

  /// Met à jour les paramètres d'animation
  Future<void> updateAnimationSettings({
    double? animationSpeed,
    bool? enableRotation,
    bool? enableTilt,
  }) async {
    _configuration = _configuration.copyWith(
      animationSpeed: animationSpeed,
      enableRotation: enableRotation,
      enableTilt: enableTilt,
    );
    await _saveConfiguration();
  }

  /// Remet la configuration par défaut
  Future<void> resetToDefault() async {
    _configuration = const MapConfiguration();
    await _saveConfiguration();
  }

  /// Exporte la configuration
  Map<String, dynamic> exportConfiguration() {
    return _configuration.toJson();
  }

  /// Importe une configuration
  Future<void> importConfiguration(Map<String, dynamic> config) async {
    try {
      _configuration = MapConfiguration.fromJson(config);
      await _saveConfiguration();
    } catch (e) {
      debugPrint('Erreur lors de l\'importation de la configuration: $e');
      throw Exception('Configuration invalide');
    }
  }
}

/// Provider pour la personnalisation de la carte
class MapCustomizationProvider extends ChangeNotifier {
  final MapCustomizationService _service = MapCustomizationService();

  MapConfiguration get configuration => _service.configuration;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Initialise le provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.initialize();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Met à jour le style de carte
  Future<void> updateMapStyle(MapStyle style) async {
    await _service.updateMapStyle(style);
    notifyListeners();
  }

  /// Bascule entre les styles de carte (standard <-> sombre)
  Future<void> toggleMapStyle() async {
    final currentStyle = configuration.style;
    final newStyle = currentStyle == MapStyle.standard
        ? MapStyle.dark
        : MapStyle.standard;
    await updateMapStyle(newStyle);
  }

  /// Getter pour le style de carte actuel
  MapStyle get selectedMapStyle => configuration.style;

  /// Met à jour le type de marqueur
  Future<void> updateMarkerType(MarkerType markerType) async {
    await _service.updateMarkerType(markerType);
    notifyListeners();
  }

  /// Met à jour les couleurs
  Future<void> updateColors({Color? primaryColor, Color? accentColor}) async {
    await _service.updateColors(
      primaryColor: primaryColor,
      accentColor: accentColor,
    );
    notifyListeners();
  }

  /// Met à jour la taille des marqueurs
  Future<void> updateMarkerSize(double size) async {
    await _service.updateMarkerSize(size);
    notifyListeners();
  }

  /// Met à jour les options d'affichage
  Future<void> updateDisplayOptions({
    bool? showTraffic,
    bool? showTransit,
    bool? show3D,
  }) async {
    await _service.updateDisplayOptions(
      showTraffic: showTraffic,
      showTransit: showTransit,
      show3D: show3D,
    );
    notifyListeners();
  }

  /// Met à jour les paramètres d'animation
  Future<void> updateAnimationSettings({
    double? animationSpeed,
    bool? enableRotation,
    bool? enableTilt,
  }) async {
    await _service.updateAnimationSettings(
      animationSpeed: animationSpeed,
      enableRotation: enableRotation,
      enableTilt: enableTilt,
    );
    notifyListeners();
  }

  /// Remet la configuration par défaut
  Future<void> resetToDefault() async {
    await _service.resetToDefault();
    notifyListeners();
  }

  /// Exporte la configuration
  Map<String, dynamic> exportConfiguration() {
    return _service.exportConfiguration();
  }

  /// Importe une configuration
  Future<void> importConfiguration(Map<String, dynamic> config) async {
    await _service.importConfiguration(config);
    notifyListeners();
  }
}
