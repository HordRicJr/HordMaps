import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../shared/extensions/color_extensions.dart';

import '../services/advanced_location_service.dart';
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

      // Rafraîchir les données en parallèle
      await Future.wait([
        locationService.refreshNearbyPlaces(),
        locationService.updateWeatherData(),
        Future.delayed(const Duration(milliseconds: 500)), // Animation minimale
      ]);

      HapticFeedback.lightImpact();
      _showSuccessSnackBar('Données mises à jour');
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la mise à jour: $e');
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
                    _buildSearchCard(),
                    const SizedBox(height: 16),
                    _buildWeatherCard(locationService),
                    const SizedBox(height: 16),
                    _buildQuickActionsSection(),
                    const SizedBox(height: 16),
                    _buildRecentRoutesSection(),
                    const SizedBox(height: 16),
                    _buildNearbyPlacesSection(locationService),
                    const SizedBox(height: 20),
                    _buildLocationStatusCard(locationService),
                    const SizedBox(height: 100), // Espace pour le FAB
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDynamicAppBar(AdvancedLocationService locationService) {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatingController.value * 2),
              child: const Text(
                'HordMaps',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              ),
            );
          },
        ),
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Effet de parallaxe avec les données temps réel
              Positioned(
                top: 60,
                right: 16,
                child: _buildLocationStatusIndicator(locationService),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildDynamicGreeting(locationService),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AnimatedBuilder(
          animation: _refreshController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _refreshController.value * 2 * 3.14159,
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isRefreshing ? null : _refreshData,
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            _showSettingsBottomSheet();
          },
        ),
      ],
    );
  }

  Widget _buildLocationStatusIndicator(
    AdvancedLocationService locationService,
  ) {
    if (locationService.currentPosition == null) {
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

    String location = 'Localisation en cours...';
    if (locationService.currentAddress.isNotEmpty) {
      location = locationService.currentAddress;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              greeting,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.place, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                location,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Où voulez-vous aller ?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2);
  }

  Widget _buildWeatherCard(AdvancedLocationService locationService) {
    if (locationService.currentWeather == null) {
      return Card(
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Chargement de la météo...'),
            ],
          ),
        ),
      );
    }

    return const WeatherWidget().animate().fadeIn(
      duration: 800.ms,
      delay: 200.ms,
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const QuickActionsGrid(),
      ],
    ).animate().fadeIn(duration: 800.ms, delay: 400.ms);
  }

  Widget _buildRecentRoutesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trajets récents',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                // Navigation vers l'historique complet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Historique complet bientôt disponible'),
                  ),
                );
              },
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const RecentRoutesList(),
      ],
    ).animate().fadeIn(duration: 800.ms, delay: 600.ms);
  }

  Widget _buildNearbyPlacesSection(AdvancedLocationService locationService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Près de vous',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (locationService.nearbyPlaces.isNotEmpty)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mode exploration bientôt disponible'),
                    ),
                  );
                },
                child: const Text('Explorer'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const NearbyPlacesList(),
      ],
    ).animate().fadeIn(duration: 800.ms, delay: 800.ms);
  }

  Widget _buildLocationStatusCard(AdvancedLocationService locationService) {
    if (locationService.currentPosition == null) {
      return Card(
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.location_searching,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 8),
              const Text(
                'Recherche de votre position...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                'Assurez-vous que le GPS est activé',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Position mise à jour',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Précision: ${locationService.accuracy.toStringAsFixed(1)}m',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${locationService.nearbyPlaces.length} lieux trouvés',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_floatingController.value * 0.1),
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Navigation'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      },
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Paramètres rapides',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Actualiser les données'),
              subtitle: const Text('Mettre à jour la position et les lieux'),
              onTap: () {
                Navigator.pop(context);
                _refreshData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Permissions de localisation'),
              subtitle: const Text('Gérer les autorisations GPS'),
              onTap: () {
                Navigator.pop(context);
                openAppSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('À propos'),
              subtitle: const Text('Version et informations'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'HordMaps',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.map, size: 32, color: Colors.white),
      ),
      children: const [
        Text(
          'Application de navigation dynamique utilisant OpenStreetMap et des services de géolocalisation temps réel.\n\n'
          'Fonctionnalités:\n'
          '• Géolocalisation précise temps réel\n'
          '• Découverte de lieux près de vous\n'
          '• Météo locale intégrée\n'
          '• Navigation intelligent\n'
          '• Interface entièrement dynamique',
        ),
      ],
    );
  }
}
