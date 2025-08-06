import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../shared/extensions/color_extensions.dart';

import '../features/map/screens/map_screen.dart';
import '../features/search/providers/search_provider.dart';
import '../features/map/providers/map_provider.dart';
import '../features/settings/settings_screen.dart';
import '../shared/services/map_customization_service.dart';
import '../shared/services/ui_enhancement_service.dart';
import '../shared/services/fluid_navigation_service.dart';
import '../services/voice_guidance_service.dart';
import '../services/places_service.dart';
import '../services/navigation_notification_service.dart';
import '../services/crash_proof_location_service.dart';

/// Page d'accueil moderne HordMaps
class ModernHomePage extends StatefulWidget {
  const ModernHomePage({super.key});

  @override
  State<ModernHomePage> createState() => _ModernHomePageState();
}

class _ModernHomePageState extends State<ModernHomePage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _departController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyPlaces = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();

    // Initialisation différée après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeServices();
      }
    });
  }

  Future<void> _initializeServices() async {
    try {
      // Initialisation séquentielle avec délais pour éviter la surcharge
      await Future.delayed(const Duration(milliseconds: 100));

      // Initialisation de base en premier
      await _getCurrentLocation();

      // Services secondaires avec délai
      await Future.delayed(const Duration(milliseconds: 200));
      VoiceGuidanceService().initialize().catchError((e) {
        debugPrint('Erreur VoiceGuidanceService: $e');
      });

      await Future.delayed(const Duration(milliseconds: 100));
      NavigationNotificationService().initialize().catchError((e) {
        debugPrint('Erreur NavigationNotificationService: $e');
      });

      debugPrint('✅ Services de la page d\'accueil initialisés');
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation des services: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Utiliser notre service de géolocalisation sécurisé
      final locationService = context.read<CrashProofLocationService>();

      // Obtenir la position actuelle (ne crashe jamais)
      final position = await locationService.getCurrentPosition();

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });

        // Charger les lieux à proximité
        await _loadNearbyPlaces();
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la position: $e');
      _generateMockNearbyPlaces();
    }
  }

  Future<void> _loadNearbyPlaces() async {
    if (_currentPosition == null) {
      _generateMockNearbyPlaces();
      return;
    }

    try {
      // Timeout pour éviter les blocages
      final places =
          await PlacesService.getNearbyPlaces(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            radiusKm: 2.0,
            maxResults: 15,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Timeout lors de la récupération des lieux');
              return <Map<String, dynamic>>[];
            },
          );

      if (mounted && places.isNotEmpty) {
        setState(() {
          _nearbyPlaces = places;
        });
      } else {
        // Si aucun lieu trouvé, utiliser les données de secours
        _generateMockNearbyPlaces();
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des lieux proches: $e');
      _generateMockNearbyPlaces();
    }
  }

  void _generateMockNearbyPlaces() {
    // Vérifier que le widget est toujours monté avant de faire setState
    if (!mounted) return;

    // Lieux de secours si la géolocalisation échoue
    setState(() {
      _nearbyPlaces = [
        {
          'name': 'Restaurant Le Central',
          'type': 'Restaurant',
          'distance': '300m',
          'icon': Icons.restaurant,
          'isReal': false,
        },
        {
          'name': 'Pharmacie du Centre',
          'type': 'Pharmacie',
          'distance': '150m',
          'icon': Icons.local_pharmacy,
          'isReal': false,
        },
        {
          'name': 'Carrefour Express',
          'type': 'Supermarché',
          'distance': '500m',
          'icon': Icons.shopping_cart,
          'isReal': false,
        },
        {
          'name': 'Boulangerie Paul',
          'type': 'Boulangerie',
          'distance': '200m',
          'icon': Icons.bakery_dining,
          'isReal': false,
        },
      ];
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _departController.dispose();
    _arrivalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildAppBar(context, isDark),
              _buildSearchSection(context, isDark),
              _buildMapPreview(context, isDark),
              _buildPopularPlaces(context, isDark),
              _buildQuickCategories(context, isDark),
              _buildRecentEvents(context, isDark),
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Logo HordMaps
          Text(
            'HORDMAPS',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.blueGrey[800],
            ),
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.3),

          const Spacer(),

          // Boutons d'action
          Row(
            children: [
              _buildAppBarButton(
                Icons.gps_fixed,
                'Ma position',
                () => _refreshLocation(),
                isDark,
              ),
              const SizedBox(width: 12),
              _buildAppBarButton(
                Icons.settings,
                'Paramètres',
                () => _openSettings(),
                isDark,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildAppBarButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: isDark ? Colors.blue[300] : Colors.blueGrey[700],
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trouver un itinéraire',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Champ départ
          _buildSearchField(
            controller: _departController,
            icon: Icons.radio_button_checked,
            hint: 'D\'où partez-vous ?',
            iconColor: Colors.green,
            isDark: isDark,
          ),

          const SizedBox(height: 12),

          // Champ arrivée
          _buildSearchField(
            controller: _arrivalController,
            icon: Icons.location_on,
            hint: 'Où allez-vous ?',
            iconColor: Colors.red,
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // Bouton rechercher
          SizedBox(
            width: double.infinity,
            child: BouncyButton(
              onPressed: () => _searchRoute(),
              child: UIEnhancementService.modernButton(
                text: 'Rechercher l\'itinéraire',
                onPressed: () => _searchRoute(),
                isDark: isDark,
                backgroundColor: Colors.purple[400],
                icon: Icons.directions,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3);
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required Color iconColor,
    required bool isDark,
  }) {
    return UIEnhancementService.modernTextField(
      controller: controller,
      hint: hint,
      isDark: isDark,
      prefixIcon: icon,
      prefixIconColor: iconColor,
    );
  }

  Widget _buildMapPreview(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 200,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Aperçu de carte simulée
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[100]!, Colors.green[100]!],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 48, color: Colors.blueGrey[600]),
                    const SizedBox(height: 8),
                    Text(
                      'Aperçu de la carte',
                      style: TextStyle(
                        color: Colors.blueGrey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bouton mode sombre
            Positioned(
              top: 12,
              right: 12,
              child: Consumer<MapCustomizationProvider>(
                builder: (context, customization, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        customization.selectedMapStyle == MapStyle.dark
                            ? Icons.light_mode
                            : Icons.dark_mode,
                      ),
                      color: isDark ? Colors.yellow[300] : Colors.orange[600],
                      onPressed: () => customization.toggleMapStyle(),
                    ),
                  );
                },
              ),
            ),

            // Bouton explorer
            Positioned(
              bottom: 12,
              right: 12,
              child: ElevatedButton(
                onPressed: () => _openMap(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Explorer'),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildPopularPlaces(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lieux Proches',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.blueGrey[800],
                ),
              ),
              if (_currentPosition != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withCustomOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: const Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'En temps réel',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_nearbyPlaces.isEmpty)
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Recherche des lieux proches...',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _nearbyPlaces.length,
              itemBuilder: (context, index) {
                final place = _nearbyPlaces[index];
                return Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withCustomOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _navigateToPlace(place),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withCustomOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(
                                    place['icon'] ??
                                        _getPlaceIcon(place['type']!),
                                    color: const Color(0xFF4CAF50),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                place['name']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                place['type']!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    place['distance']!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: const Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (place['isReal'] == true)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .animate(delay: Duration(milliseconds: 500 + index * 100))
                    .fadeIn()
                    .slideX(begin: 0.3);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQuickCategories(BuildContext context, bool isDark) {
    final categories = [
      {'name': 'Transport', 'icon': Icons.directions_bus, 'color': Colors.blue},
      {'name': 'Santé', 'icon': Icons.local_hospital, 'color': Colors.red},
      {'name': 'Éducation', 'icon': Icons.school, 'color': Colors.green},
      {'name': 'Divertissement', 'icon': Icons.movie, 'color': Colors.orange},
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catégories Rapides',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3,
            children: categories.map((category) {
              return Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _searchCategory(category['name'] as String),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (category['color'] as Color)
                                    .withCustomOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                category['icon'] as IconData,
                                color: category['color'] as Color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                category['name'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .animate(
                    delay: Duration(
                      milliseconds: 700 + categories.indexOf(category) * 100,
                    ),
                  )
                  .fadeIn()
                  .scale(begin: const Offset(0.8, 0.8));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEvents(BuildContext context, bool isDark) {
    final events = [
      {
        'name': 'Festival de la rue',
        'distance': 'À 2km de vous',
        'location': 'Place centrale',
      },
      {
        'name': 'Marché nocturne',
        'distance': 'À 1.5km de vous',
        'location': 'Quai des artistes',
      },
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Événements Récents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 12),
          ...events.map((event) {
            return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isDark ? Colors.grey[800] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.event, color: Colors.purple[600]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['name']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event['distance']!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.map,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    event['location']!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _viewOnMap(event['name']!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[400],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Voir',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .animate(
                  delay: Duration(
                    milliseconds: 900 + events.indexOf(event) * 100,
                  ),
                )
                .fadeIn()
                .slideY(begin: 0.3);
          }),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _exploreAround(),
      backgroundColor: const Color(0xFF4CAF50),
      foregroundColor: Colors.white,
      elevation: 8,
      icon: const Icon(Icons.explore_rounded, size: 22),
      label: const Text(
        'Explorer',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ).animate().scale(delay: 1000.ms);
  }

  IconData _getPlaceIcon(String type) {
    switch (type) {
      case 'Restaurant':
        return Icons.restaurant;
      case 'Pharmacie':
        return Icons.local_pharmacy;
      case 'Banque':
        return Icons.account_balance;
      case 'Supermarché':
        return Icons.shopping_cart;
      case 'Boulangerie':
        return Icons.bakery_dining;
      case 'Station-Service':
        return Icons.local_gas_station;
      case 'Parc':
        return Icons.park;
      case 'Santé':
        return Icons.local_hospital;
      case 'Shopping':
        return Icons.shopping_bag;
      default:
        return Icons.place;
    }
  }

  // Actions methods
  void _refreshLocation() {
    _getCurrentLocation();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actualisation de votre position...')),
    );
  }

  void _openSettings() {
    // Navigation vers les paramètres
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _searchRoute() {
    if (_departController.text.isNotEmpty &&
        _arrivalController.text.isNotEmpty) {
      FluidNavigationService.navigateTo(
        context,
        const MapScreen(),
        transition: NavigationTransition.slideFromRight,
      );
    } else {
      UIEnhancementService.showModernSnackBar(
        context: context,
        message: 'Veuillez remplir les deux champs',
        type: SnackBarType.warning,
      );
    }
  }

  void _openMap() {
    FluidNavigationService.navigateTo(
      context,
      const MapScreen(),
      transition: NavigationTransition.scale,
    );
  }

  void _searchCategory(String category) {
    final searchProvider = context.read<SearchProvider>();
    searchProvider.searchPlaces(category);
    // Naviguer vers l'onglet carte (index 1 dans MainNavigationScreen)
    // On doit passer par le parent MainNavigationScreen
    _navigateToMapTab();
  }

  void _viewOnMap(String eventName) {
    // Naviguer vers l'onglet carte
    _navigateToMapTab();
  }

  void _exploreAround() {
    // Naviguer vers l'onglet carte
    _navigateToMapTab();
  }

  void _navigateToMapTab() {
    // Pour l'instant, on va utiliser Navigator pour aller à la carte
    FluidNavigationService.navigateTo(
      context,
      const MapScreen(),
      transition: NavigationTransition.slideFromRight,
    );
  }

  void _navigateToPlace(Map<String, dynamic> place) {
    // Naviguer vers la carte avec le lieu spécifique
    final mapProvider = context.read<MapProvider>();

    // Si le lieu a des coordonnées, centrer la carte dessus
    if (place['latitude'] != null && place['longitude'] != null) {
      final position = LatLng(place['latitude'], place['longitude']);
      mapProvider.mapController.move(position, 16);

      // Ajouter un marqueur pour ce lieu
      mapProvider.addMarker(
        Marker(
          point: position,
          width: 40,
          height: 40,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              place['icon'] ?? Icons.place,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }

    // Naviguer vers la carte
    FluidNavigationService.navigateTo(
      context,
      const MapScreen(),
      transition: NavigationTransition.slideFromBottom,
    );
  }
}
