import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/map_provider.dart';
import '../../search/providers/search_provider.dart';
import '../../navigation/providers/navigation_provider_basic.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../../shared/widgets/animated_search_bar.dart';
import '../../../shared/widgets/location_button.dart';
import '../../../shared/widgets/map_controls.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/navigation_progress_widget.dart';
import '../../../services/navigation_notification_service.dart';
import '../../../services/navigation_overlay_service.dart';
import '../../../services/background_navigation_service.dart';
import '../../../services/real_time_navigation_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late AnimationController _searchAnimationController;
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Initialiser les services de navigation en arrière-plan
    _initializeNavigationServices();

    // Démarrer les animations d'entrée
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchAnimationController.forward();
      _fabAnimationController.forward();
    });
  }

  /// Initialise les services de navigation en arrière-plan
  Future<void> _initializeNavigationServices() async {
    try {
      await NavigationOverlayService.instance.initialize();
      await BackgroundNavigationService.instance.initialize();
      _startNavigationListener();
    } catch (e) {
      debugPrint('Erreur initialisation services navigation: $e');
    }
  }

  /// Démarre l'écoute des mises à jour de navigation pour l'overlay
  void _startNavigationListener() {
    final realTimeService = RealTimeNavigationService.instance;

    realTimeService.progressStream.listen((progress) {
      if (mounted && progress.remainingDistance > 0) {
        // Afficher l'overlay automatiquement avec les nouvelles données
        NavigationOverlayService.instance.showNavigationOverlay(
          context,
          progress,
          autoHideDuration: const Duration(seconds: 8),
        );

        // Mettre à jour l'overlay système natif (Android)
        NavigationOverlayService.instance.showSystemOverlay(
          title: 'Navigation HordMaps',
          content:
              '${progress.remainingDistance.toStringAsFixed(1)} km restants • ETA: ${_formatDuration(progress.estimatedTimeArrival)}',
          progress: progress.completionPercentage,
        );
      }
    });
  }

  /// Formate une durée en chaîne lisible
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '< 1m';
    }
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        body: Consumer3<MapProvider, SearchProvider, NavigationProvider>(
          builder: (context, mapProvider, searchProvider, navProvider, child) {
            return Stack(
              children: [
                // Carte principale
                _buildMap(mapProvider, navProvider),

                // Barre de recherche animée
                _buildSearchBar(searchProvider, mapProvider),

                // Contrôles de la carte
                _buildMapControls(mapProvider),

                // Bouton de géolocalisation
                _buildLocationButton(mapProvider),

                // Panneau de navigation (si actif)
                if (navProvider.isNavigating)
                  _buildNavigationPanel(navProvider),

                // Widget de progression en temps réel
                if (navProvider.isNavigating)
                  const Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: NavigationProgressWidget(),
                  ),

                // Bouton d'overlay flottant (si navigation active)
                if (navProvider.isNavigating) _buildOverlayControlButton(),

                // Indicateur de chargement
                if (mapProvider.isLoading) _buildLoadingIndicator(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap(MapProvider mapProvider, NavigationProvider navProvider) {
    return FlutterMap(
          mapController: mapProvider.mapController,
          options: MapOptions(
            initialCenter: mapProvider.mapCenter,
            initialZoom: mapProvider.mapZoom,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) {
                mapProvider.updateMapPosition(position.center, position.zoom);
              }
            },
            onTap: (tapPosition, point) {
              // Masquer les résultats de recherche lors du tap
              context.read<SearchProvider>().clearResults();

              // Permettre la sélection de points pour l'itinéraire
              _handleMapTap(point, mapProvider, navProvider);
            },
          ),
          children: [
            // Couche de tuiles OpenStreetMap
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.hordmaps',
              tileProvider: NetworkTileProvider(),
            ),

            // Couche des routes/itinéraires
            if (navProvider.currentRoute != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: navProvider.currentRoute!.points,
                    strokeWidth: 6.0,
                    color: Theme.of(context).primaryColor,
                    borderStrokeWidth: 8.0,
                    borderColor: Colors.white,
                  ),
                ],
              ),

            // Couche des marqueurs
            MarkerLayer(
              markers: [
                // Marqueurs de recherche et généraux
                ...mapProvider.markers,

                // Marqueur de départ
                if (mapProvider.startPoint != null)
                  Marker(
                    point: mapProvider.startPoint!,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                // Marqueur d'arrivée
                if (mapProvider.endPoint != null)
                  Marker(
                    point: mapProvider.endPoint!,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                // Marqueur de position actuelle pendant la navigation
                if (navProvider.isNavigating &&
                    mapProvider.currentLocation != null)
                  Marker(
                    point: mapProvider.currentLocation!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        )
        .animate(controller: _fabAnimationController)
        .fadeIn(duration: 600.ms)
        .scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildSearchBar(
    SearchProvider searchProvider,
    MapProvider mapProvider,
  ) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: AnimatedSearchBar(
        controller: _searchAnimationController,
        onSearch: (query) {
          searchProvider.searchPlaces(query);
        },
        onResultSelected: (result) {
          // Centrer la carte sur le résultat
          mapProvider.mapController.move(result.position, 16);

          // Ajouter un marqueur
          mapProvider.addMarker(
            Marker(
              point: result.position,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.place, color: Colors.white, size: 24),
              ),
            ),
          );

          // Effacer les résultats
          searchProvider.clearResults();
        },
        results: searchProvider.searchResults,
        isLoading: searchProvider.isSearching,
      ),
    );
  }

  Widget _buildMapControls(MapProvider mapProvider) {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.3,
      child:
          MapControls(
                onZoomIn: () {
                  final zoom = mapProvider.mapZoom + 1;
                  mapProvider.mapController.move(mapProvider.mapCenter, zoom);
                  mapProvider.updateMapPosition(mapProvider.mapCenter, zoom);
                },
                onZoomOut: () {
                  final zoom = mapProvider.mapZoom - 1;
                  mapProvider.mapController.move(mapProvider.mapCenter, zoom);
                  mapProvider.updateMapPosition(mapProvider.mapCenter, zoom);
                },
              )
              .animate()
              .slideX(begin: 1, duration: 400.ms, curve: Curves.easeOutCubic)
              .fadeIn(delay: 200.ms),
    );
  }

  Widget _buildLocationButton(MapProvider mapProvider) {
    return Positioned(
      right: 16,
      bottom: 100,
      child:
          LocationButton(
                onPressed: () {
                  mapProvider.centerOnCurrentLocation();
                },
                isFollowing: mapProvider.isFollowingUser,
                onToggleFollow: () {
                  mapProvider.toggleFollowUser();
                },
              )
              .animate(controller: _fabAnimationController)
              .scale(begin: const Offset(0, 0), delay: 100.ms)
              .fadeIn(duration: 300.ms),
    );
  }

  /// Bouton de contrôle d'overlay flottant
  Widget _buildOverlayControlButton() {
    return Positioned(
      right: 16,
      bottom: 200,
      child:
          FloatingActionButton(
                mini: true,
                backgroundColor: Colors.black.withOpacity(0.8),
                foregroundColor: Colors.blue,
                heroTag: "overlay_button",
                onPressed: () async {
                  final overlayService = NavigationOverlayService.instance;

                  if (overlayService.isOverlayVisible) {
                    // Masquer l'overlay
                    await overlayService.hideNavigationOverlay();
                    await overlayService.hideSystemOverlay();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Overlay masqué'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    // Afficher l'overlay persistant
                    await overlayService.showPersistentNavigationOverlay(
                      context,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Overlay navigation activé'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Icon(
                  NavigationOverlayService.instance.isOverlayVisible
                      ? Icons.picture_in_picture
                      : Icons.picture_in_picture_alt,
                ),
              )
              .animate()
              .scale(begin: const Offset(0, 0), delay: 200.ms)
              .fadeIn(duration: 300.ms),
    );
  }

  Widget _buildNavigationPanel(NavigationProvider navProvider) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child:
          NavigationPanel(
                currentStep: navProvider.currentStep,
                totalDistance: navProvider.currentRoute?.totalDistance ?? 0,
                totalDuration:
                    navProvider.currentRoute?.estimatedDuration.inMinutes
                        .toDouble() ??
                    0,
                onStopNavigation: () {
                  navProvider.stopNavigation();
                },
                onNextStep: () {
                  navProvider.moveToNextStep();
                },
                onPreviousStep: () {
                  navProvider.previousStep();
                },
              )
              .animate()
              .slideY(begin: 1, duration: 500.ms, curve: Curves.easeOutCubic)
              .fadeIn(duration: 300.ms),
    );
  }

  Widget _buildLoadingIndicator() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child:
              Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Localisation en cours...',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )
                  .animate(target: 1)
                  .scale(begin: const Offset(0.8, 0.8))
                  .fadeIn(duration: 300.ms),
        ),
      ),
    );
  }

  /// Gère le tap sur la carte pour sélectionner des points d'itinéraire
  void _handleMapTap(
    LatLng point,
    MapProvider mapProvider,
    NavigationProvider navProvider,
  ) {
    // Afficher un dialog pour choisir l'action
    showModalBottomSheet(
      context: context,
      builder: (context) => _RouteSelectionSheet(
        selectedPoint: point,
        onStartPointSelected: () {
          mapProvider.setStartPoint(point);
          Navigator.pop(context);
          _showRouteOptions(mapProvider, navProvider);
        },
        onEndPointSelected: () {
          mapProvider.setEndPoint(point);
          Navigator.pop(context);
          _showRouteOptions(mapProvider, navProvider);
        },
        onAddFavorite: () {
          Navigator.pop(context);
          _addToFavorites(point);
        },
      ),
    );
  }

  /// Affiche les options d'itinéraire avec moyens de transport
  void _showRouteOptions(
    MapProvider mapProvider,
    NavigationProvider navProvider,
  ) {
    if (mapProvider.startPoint != null && mapProvider.endPoint != null) {
      showModalBottomSheet(
        context: context,
        builder: (context) => _TransportModeSheet(
          startPoint: mapProvider.startPoint!,
          endPoint: mapProvider.endPoint!,
          onTransportSelected: (transportMode) {
            Navigator.pop(context);
            _calculateRoute(
              mapProvider.startPoint!,
              mapProvider.endPoint!,
              transportMode,
              navProvider,
            );
          },
        ),
      );
    }
  }

  /// Calcule l'itinéraire avec le moyen de transport choisi
  Future<void> _calculateRoute(
    LatLng start,
    LatLng end,
    String transportMode,
    NavigationProvider navProvider,
  ) async {
    try {
      await navProvider.calculateRoute(
        start,
        end,
        transportMode: transportMode,
      );

      // Démarrer les notifications de navigation
      final notificationService = NavigationNotificationService();
      await notificationService.startNavigation('Vers destination');

      // Afficher notification de début de navigation
      if (mounted) {
        NavigationNotificationService.showInAppNotification(
          context,
          title: 'Itinéraire calculé',
          message: 'Navigation via $transportMode démarrée',
          icon: Icons.navigation,
        );

        // Option pour démarrer la navigation
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Itinéraire calculé'),
            content: Text(
              'Voulez-vous démarrer la navigation via $transportMode ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Plus tard'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  navProvider.startNavigation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Démarrer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de calcul d\'itinéraire: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Ajoute un point aux favoris
  void _addToFavorites(LatLng point) {
    showDialog(
      context: context,
      builder: (context) => _AddFavoriteDialog(
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
  }

  /// Affiche la confirmation de sortie de l'application
  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter l\'application'),
        content: const Text('Voulez-vous vraiment quitter HordMaps ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Arrêter la navigation si active
              final navProvider = context.read<NavigationProvider>();
              if (navProvider.isNavigating) {
                navProvider.stopNavigation();
              }
              // Quitter l'application
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }
}

/// Sheet pour sélectionner une action sur un point de la carte
class _RouteSelectionSheet extends StatelessWidget {
  final LatLng selectedPoint;
  final VoidCallback onStartPointSelected;
  final VoidCallback onEndPointSelected;
  final VoidCallback onAddFavorite;

  const _RouteSelectionSheet({
    required this.selectedPoint,
    required this.onStartPointSelected,
    required this.onEndPointSelected,
    required this.onAddFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Actions disponibles',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.my_location, color: Colors.green),
            title: const Text('Définir comme point de départ'),
            onTap: onStartPointSelected,
          ),
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.red),
            title: const Text('Définir comme destination'),
            onTap: onEndPointSelected,
          ),
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.pink),
            title: const Text('Ajouter aux favoris'),
            onTap: onAddFavorite,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Sheet pour choisir le moyen de transport
class _TransportModeSheet extends StatelessWidget {
  final LatLng startPoint;
  final LatLng endPoint;
  final Function(String) onTransportSelected;

  const _TransportModeSheet({
    required this.startPoint,
    required this.endPoint,
    required this.onTransportSelected,
  });

  @override
  Widget build(BuildContext context) {
    final transportModes = [
      {'name': 'Voiture', 'icon': Icons.directions_car, 'mode': 'driving'},
      {'name': 'Moto', 'icon': Icons.motorcycle, 'mode': 'motorcycle'},
      {'name': 'À pied', 'icon': Icons.directions_walk, 'mode': 'walking'},
      {'name': 'Vélo', 'icon': Icons.directions_bike, 'mode': 'cycling'},
      {
        'name': 'Transport public',
        'icon': Icons.directions_bus,
        'mode': 'transit',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choisir le moyen de transport',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          ...transportModes.map(
            (mode) => ListTile(
              leading: Icon(
                mode['icon'] as IconData,
                color: const Color(0xFF4CAF50),
              ),
              title: Text(mode['name'] as String),
              onTap: () => onTransportSelected(mode['mode'] as String),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Dialog pour ajouter un lieu aux favoris
class _AddFavoriteDialog extends StatefulWidget {
  final double latitude;
  final double longitude;

  const _AddFavoriteDialog({required this.latitude, required this.longitude});

  @override
  State<_AddFavoriteDialog> createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<_AddFavoriteDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter aux favoris'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom du lieu',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveFavorite,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sauvegarder'),
        ),
      ],
    );
  }

  Future<void> _saveFavorite() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nom pour le lieu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final favoritesProvider = context.read<FavoritesProvider>();
      await favoritesProvider.addFavorite(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        position: LatLng(widget.latitude, widget.longitude),
        type: 'custom',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lieu ajouté aux favoris avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
