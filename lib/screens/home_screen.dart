import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:permission_handler/permission_handler.dart';
import '../../shared/extensions/color_extensions.dart';

import '../services/advanced_location_service.dart';
import '../services/navigation_overlay_service.dart';
import '../widgets/weather_widget.dart';
import '../widgets/recent_routes_list.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/nearby_places_list.dart';
import '../features/search/screens/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _refreshController;
  late AnimationController _floatingController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationService();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocationService() async {
    final locationService = Provider.of<AdvancedLocationService>(
      context,
      listen: false,
    );

    // Vérifier et demander les permissions
    final hasPermission = await _checkLocationPermissions();
    if (!hasPermission) {
      _showPermissionDialog();
      return;
    }

    // Vérifier les permissions overlay (Android 15)
    await _checkOverlayPermissions();

    // Initialiser les services de géolocalisation
    try {
      await locationService.initialize();
      await locationService.startLocationTracking();
      await _refreshData();
    } catch (e) {
      _showErrorSnackBar('Erreur d\'initialisation de la géolocalisation: $e');
    }
  }

  Future<bool> _checkLocationPermissions() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    }
    return status.isGranted;
  }

  Future<void> _checkOverlayPermissions() async {
    try {
      final overlayService = NavigationOverlayService.instance;
      final hasOverlayPermission = await overlayService.hasOverlayPermission();

      if (!hasOverlayPermission) {
        _showOverlayPermissionDialog();
      }
    } catch (e) {
      debugPrint('Erreur vérification permissions overlay: $e');
    }
  }

  void _showOverlayPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.layers, color: Colors.orange),
            SizedBox(width: 8),
            Text('Permission overlay requise'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pour une navigation optimale, HordMaps a besoin de la permission d\'affichage par-dessus d\'autres applications.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '⚠️ Sur Android 15, cette permission peut apparaître "grisée" ou "désactivée".',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestOverlayPermissionWithFallback();
            },
            child: const Text('Paramètres'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _forceOverlayPermissionDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Forcer'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestOverlayPermissionWithFallback() async {
    try {
      final overlayService = NavigationOverlayService.instance;
      await overlayService.requestOverlayPermission();
    } catch (e) {
      debugPrint('Erreur demande permission overlay: $e');
      await _openOverlaySettings();
    }
  }

  Future<void> _forceOverlayPermissionDialog() async {
    try {
      final overlayService = NavigationOverlayService.instance;
      await overlayService.forceOverlayPermission();
    } catch (e) {
      debugPrint('Erreur force permission overlay: $e');
      _showSnackBar(
        'Impossible d\'ouvrir les paramètres overlay automatiquement. Veuillez les ouvrir manuellement.',
      );
    }
  }

  Future<void> _openOverlaySettings() async {
    try {
      final overlayService = NavigationOverlayService.instance;
      await overlayService.openOverlaySettings();
    } catch (e) {
      debugPrint('Erreur ouverture paramètres overlay: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Text('Autorisation requise'),
          ],
        ),
        content: const Text(
          'HordMaps a besoin d\'accéder à votre position pour vous offrir des fonctionnalités de navigation et découvrir les lieux près de vous.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop(); // Fermer l'app
            },
            child: const Text('Quitter'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    _refreshController.forward();

    try {
      final locationService = Provider.of<AdvancedLocationService>(
        context,
        listen: false,
      );
      await locationService.loadLocationData();
      _showSuccessSnackBar('Données mises à jour');
    } catch (e) {
      _showErrorSnackBar('Erreur de mise à jour: $e');
    } finally {
      _refreshController.reverse();
      setState(() => _isRefreshing = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Réessayer',
          textColor: Colors.white,
          onPressed: _refreshData,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AdvancedLocationService>(
        builder: (context, locationService, child) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildDynamicAppBar(locationService),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const WeatherWidget(),
                    const SizedBox(height: 20),
                    const QuickActionsGrid(),
                    const SizedBox(height: 20),
                    const RecentRoutesList(),
                    const SizedBox(height: 20),
                    const NearbyPlacesList(),
                    const SizedBox(height: 100), // Espace pour le FAB
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatingController.value * 2),
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, _) =>
                        const SearchScreen(),
                    transitionsBuilder: (context, animation, _, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Rechercher'),
              backgroundColor: Theme.of(context).primaryColor,
              heroTag: "search_fab",
            ),
          );
        },
      ),
    );
  }

  Widget _buildDynamicAppBar(AdvancedLocationService locationService) {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withCustomOpacity(0.8),
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildDynamicGreeting(locationService),
                  const SizedBox(height: 8),
                  _buildLocationStatus(locationService),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        AnimatedBuilder(
          animation: _refreshController,
          builder: (context, child) {
            return IconButton(
              icon: Transform.rotate(
                angle: _refreshController.value * 2 * 3.14159,
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
              onPressed: _isRefreshing ? null : _refreshData,
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocationStatus(AdvancedLocationService locationService) {
    if (!locationService.isInitialized ||
        locationService.lastKnownPosition == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withCustomOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_searching, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              'Localisation...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withCustomOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text('Connecté', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDynamicGreeting(AdvancedLocationService locationService) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData icon;

    if (hour < 12) {
      greeting = 'Bonjour';
      icon = Icons.wb_sunny;
    } else if (hour < 18) {
      greeting = 'Bon après-midi';
      icon = Icons.wb_sunny_outlined;
    } else {
      greeting = 'Bonsoir';
      icon = Icons.nights_stay;
    }

    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 8),
        Text(
          greeting,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
