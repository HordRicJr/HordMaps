import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/event_throttle_service.dart';
import '../core/config/environment_config.dart';

/// Types de couches de carte disponibles
enum MapLayerType {
  standard,
  satellite,
  terrain,
  hybrid,
  relief,
  traffic,
  transit,
  bike,
  walking,
}

/// Configuration d'une couche de carte
class MapLayerConfig {
  final MapLayerType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String url;
  final bool isAvailable;

  const MapLayerConfig({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.url,
    this.isAvailable = true,
  });
}

/// Service pour gérer toutes les couches et styles de carte
class CompleteMapLayerService extends ChangeNotifier {
  MapLayerType _currentLayer = MapLayerType.standard;
  bool _is3DEnabled = false;
  bool _showTraffic = false;
  bool _showTransit = false;
  double _tilt = 0.0;
  double _bearing = 0.0;

  MapLayerType get currentLayer => _currentLayer;
  bool get is3DEnabled => _is3DEnabled;
  bool get showTraffic => _showTraffic;
  bool get showTransit => _showTransit;
  double get tilt => _tilt;
  double get bearing => _bearing;

  /// Liste de toutes les couches disponibles - Azure Maps
  static List<MapLayerConfig> get availableLayers => [
    MapLayerConfig(
      type: MapLayerType.standard,
      name: 'Standard',
      description: 'Vue carte classique Azure Maps',
      icon: Icons.map,
      color: Colors.blue,
      url: _getAzureMapsUrl('basic'),
    ),
    MapLayerConfig(
      type: MapLayerType.satellite,
      name: 'Satellite',
      description: 'Images satellite Azure Maps',
      icon: Icons.satellite_alt,
      color: Colors.green,
      url: _getAzureMapsUrl('imagery'),
    ),
    MapLayerConfig(
      type: MapLayerType.terrain,
      name: 'Relief',
      description: 'Carte topographique Azure Maps',
      icon: Icons.terrain,
      color: Colors.brown,
      url: _getAzureMapsUrl('terrain'),
    ),
    MapLayerConfig(
      type: MapLayerType.hybrid,
      name: 'Hybride',
      description: 'Satellite + routes Azure Maps',
      icon: Icons.layers,
      color: Colors.purple,
      url: _getAzureMapsUrl('hybrid'),
    ),
    MapLayerConfig(
      type: MapLayerType.relief,
      name: 'Relief 3D',
      description: 'Relief en 3D Azure Maps',
      icon: Icons.view_in_ar,
      color: Colors.orange,
      url: _getAzureMapsUrl('terrain'),
    ),
    MapLayerConfig(
      type: MapLayerType.traffic,
      name: 'Trafic',
      description: 'Conditions de trafic Azure Maps',
      icon: Icons.traffic,
      color: Colors.red,
      url: _getAzureMapsUrl('basic_night'),
    ),
    MapLayerConfig(
      type: MapLayerType.transit,
      name: 'Transport',
      description: 'Transports en commun Azure Maps',
      icon: Icons.directions_bus,
      color: Colors.indigo,
      url: _getAzureMapsUrl('basic'),
    ),
    MapLayerConfig(
      type: MapLayerType.bike,
      name: 'Vélo',
      description: 'Pistes cyclables Azure Maps',
      icon: Icons.directions_bike,
      color: Colors.teal,
      url: _getAzureMapsUrl('basic'),
    ),
    MapLayerConfig(
      type: MapLayerType.walking,
      name: 'Piéton',
      description: 'Chemins piétons Azure Maps',
      icon: Icons.directions_walk,
      color: Colors.amber,
      url: _getAzureMapsUrl('basic'),
    ),
  ];

  /// Génère l'URL des tuiles Azure Maps pour un style donné
  static String _getAzureMapsUrl(String style) {
    try {
      // Vérifier si la configuration Azure Maps est valide
      if (!AzureMapsConfig.isValid) {
        // Fallback vers Azure Maps standard si pas de configuration
        return AzureTileUrls.standard;
      }
      
      final baseUrl = AzureMapsConfig.renderUrl;
      final apiVersion = AzureMapsConfig.apiVersion;
      final apiKey = AzureMapsConfig.apiKey;
      
      return '$baseUrl/tile/$style/zoom-level/{z}/tile-row/{y}/tile-column/{x}?api-version=$apiVersion&subscription-key=$apiKey';
    } catch (e) {
      // Fallback vers Azure Maps standard en cas d'erreur
      return AzureTileUrls.standard;
    }
  }

  /// Change la couche de carte
  void setLayer(MapLayerType layer) {
    _currentLayer = layer;
    // NOUVEAU: Throttle les changements de couche pour éviter les surcharges
    EventThrottleService().throttle('map_layer_change', () {
      notifyListeners();
    });
  }

  /// Active/désactive la vue 3D
  void toggle3D() {
    _is3DEnabled = !_is3DEnabled;
    if (!_is3DEnabled) {
      _tilt = 0.0;
      _bearing = 0.0;
    }
    EventThrottleService().throttle('map_3d_toggle', () {
      notifyListeners();
    });
  }

  /// Active/désactive le trafic
  void toggleTraffic() {
    _showTraffic = !_showTraffic;
    notifyListeners();
  }

  /// Active/désactive les transports
  void toggleTransit() {
    _showTransit = !_showTransit;
    notifyListeners();
  }

  /// Définit l'inclinaison de la carte (3D)
  void setTilt(double tilt) {
    _tilt = tilt.clamp(0.0, 60.0);
    if (_tilt > 0) _is3DEnabled = true;
    notifyListeners();
  }

  /// Définit la rotation de la carte
  void setBearing(double bearing) {
    _bearing = bearing % 360;
    notifyListeners();
  }

  /// Remet la carte à plat
  void resetCamera() {
    _tilt = 0.0;
    _bearing = 0.0;
    _is3DEnabled = false;
    notifyListeners();
  }

  /// Obtient la configuration de la couche actuelle
  MapLayerConfig getCurrentLayerConfig() {
    return availableLayers.firstWhere(
      (layer) => layer.type == _currentLayer,
      orElse: () => availableLayers.first,
    );
  }

  /// Obtient l'URL de la couche actuelle
  String getCurrentLayerUrl() {
    return getCurrentLayerConfig().url;
  }
}

/// Widget de contrôles complets pour la carte
class CompleteMapControls extends StatefulWidget {
  const CompleteMapControls({super.key});

  @override
  State<CompleteMapControls> createState() => _CompleteMapControlsState();
}

class _CompleteMapControlsState extends State<CompleteMapControls>
    with TickerProviderStateMixin {
  bool _showLayerPanel = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CompleteMapLayerService>(
      builder: (context, layerService, child) {
        return Stack(
          children: [
            // Boutons principaux
            Positioned(
              top: 100,
              right: 16,
              child: Column(
                children: [
                  // Bouton couches
                  _buildMainButton(
                    icon: Icons.layers,
                    onPressed: () => _toggleLayerPanel(),
                    backgroundColor: _showLayerPanel
                        ? Colors.blue
                        : Colors.white,
                    iconColor: _showLayerPanel ? Colors.white : Colors.blue,
                    tooltip: 'Couches de carte',
                  ),
                  const SizedBox(height: 8),

                  // Bouton 3D
                  _buildMainButton(
                    icon: Icons.view_in_ar,
                    onPressed: () => layerService.toggle3D(),
                    backgroundColor: layerService.is3DEnabled
                        ? Colors.purple
                        : Colors.white,
                    iconColor: layerService.is3DEnabled
                        ? Colors.white
                        : Colors.purple,
                    tooltip: 'Vue 3D',
                  ),
                  const SizedBox(height: 8),

                  // Bouton trafic
                  _buildMainButton(
                    icon: Icons.traffic,
                    onPressed: () => layerService.toggleTraffic(),
                    backgroundColor: layerService.showTraffic
                        ? Colors.red
                        : Colors.white,
                    iconColor: layerService.showTraffic
                        ? Colors.white
                        : Colors.red,
                    tooltip: 'Trafic',
                  ),
                  const SizedBox(height: 8),

                  // Bouton transport
                  _buildMainButton(
                    icon: Icons.directions_bus,
                    onPressed: () => layerService.toggleTransit(),
                    backgroundColor: layerService.showTransit
                        ? Colors.indigo
                        : Colors.white,
                    iconColor: layerService.showTransit
                        ? Colors.white
                        : Colors.indigo,
                    tooltip: 'Transport',
                  ),
                  const SizedBox(height: 8),

                  // Bouton reset caméra
                  if (layerService.is3DEnabled ||
                      layerService.tilt > 0 ||
                      layerService.bearing != 0)
                    _buildMainButton(
                      icon: Icons.refresh,
                      onPressed: () => layerService.resetCamera(),
                      backgroundColor: Colors.orange,
                      iconColor: Colors.white,
                      tooltip: 'Reset vue',
                    ),
                ],
              ),
            ),

            // Panel des couches
            if (_showLayerPanel)
              Positioned(
                top: 100,
                right: 80,
                child: _buildLayerPanel(layerService),
              ),

            // Contrôles 3D
            if (layerService.is3DEnabled)
              Positioned(
                bottom: 100,
                right: 16,
                child: _build3DControls(layerService),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMainButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
      ),
    ).animate().scale(
      duration: const Duration(milliseconds: 200),
      curve: Curves.bounceOut,
    );
  }

  Widget _buildLayerPanel(CompleteMapLayerService layerService) {
    return Container(
      width: 280,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.layers, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Couches de carte',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _toggleLayerPanel(),
                  iconSize: 20,
                ),
              ],
            ),
          ),

          // Liste des couches
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: CompleteMapLayerService.availableLayers.length,
              itemBuilder: (context, index) {
                final layer = CompleteMapLayerService.availableLayers[index];
                final isSelected = layer.type == layerService.currentLayer;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: isSelected ? layer.color.withValues(alpha: 0.1) : null,
                  child: ListTile(
                    leading: Icon(
                      layer.icon,
                      color: isSelected ? layer.color : Colors.grey,
                    ),
                    title: Text(
                      layer.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? layer.color : null,
                      ),
                    ),
                    subtitle: Text(
                      layer.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: layer.color)
                        : null,
                    onTap: () {
                      layerService.setLayer(layer.type);
                      _toggleLayerPanel();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ).animate().scale(
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
    );
  }

  Widget _build3DControls(CompleteMapLayerService layerService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar, color: Colors.purple),
              const SizedBox(width: 8),
              const Text(
                'Contrôles 3D',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contrôle d'inclinaison
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rotate_90_degrees_ccw, size: 20),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: Slider(
                  value: layerService.tilt,
                  min: 0,
                  max: 60,
                  divisions: 12,
                  label: '${layerService.tilt.round()}°',
                  onChanged: (value) => layerService.setTilt(value),
                ),
              ),
            ],
          ),

          // Contrôle de rotation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rotate_right, size: 20),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: Slider(
                  value: layerService.bearing,
                  min: 0,
                  max: 360,
                  divisions: 36,
                  label: '${layerService.bearing.round()}°',
                  onChanged: (value) => layerService.setBearing(value),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().slideX(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _toggleLayerPanel() {
    setState(() {
      _showLayerPanel = !_showLayerPanel;
    });

    if (_showLayerPanel) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
