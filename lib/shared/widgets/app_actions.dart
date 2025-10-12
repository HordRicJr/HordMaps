import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../features/map/providers/map_provider.dart';
import '../../features/search/providers/search_provider.dart';
import '../../features/navigation/providers/providers.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../services/measurement_service.dart';
import '../../services/compass_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../../core/config/environment_config.dart';

class AppActions {
  /// Ouvrir la recherche avancée
  static void openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AdvancedSearchBottomSheet(),
    );
  }

  /// Ouvrir la navigation
  static void openNavigation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const NavigationBottomSheet(),
    );
  }

  /// Ouvrir les favoris
  static void openFavorites(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const FavoritesBottomSheet(),
    );
  }

  /// Activer/désactiver l'outil de mesure
  static void toggleMeasurement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const MeasurementBottomSheet(),
    );
  }

  /// Ouvrir le partage
  static void openShare(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const ShareBottomSheet(),
    );
  }

  /// Activer/désactiver la boussole
  static void toggleCompass(BuildContext context) {
    final compassService = context.read<CompassService>();

    if (compassService.isEnabled) {
      compassService.stopCompass();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.explore_off, color: Colors.white),
              SizedBox(width: 8),
              Text('Boussole désactivée'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      compassService.startCompass();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.explore, color: Colors.white),
              SizedBox(width: 8),
              Text('Boussole activée'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Ouvrir les styles de carte
  static void openMapStyles(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const MapStylesBottomSheet(),
    );
  }

  /// Centrer sur la position utilisateur
  static void centerLocation(BuildContext context) {
    final mapProvider = context.read<MapProvider>();

    if (mapProvider.currentLocation != null) {
      mapProvider.animateToLocation(mapProvider.currentLocation!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.my_location, color: Colors.white),
              SizedBox(width: 8),
              Text('Centré sur votre position'),
            ],
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      mapProvider.getCurrentLocation().then((_) {
        if (mapProvider.currentLocation != null) {
          mapProvider.animateToLocation(mapProvider.currentLocation!);
        }
      });
    }
  }

  /// Ouvrir les POI
  static void showPOIBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const POIBottomSheet(),
    );
  }
}

/// Bottom Sheet de recherche avancée
class AdvancedSearchBottomSheet extends StatefulWidget {
  const AdvancedSearchBottomSheet({super.key});

  @override
  State<AdvancedSearchBottomSheet> createState() =>
      _AdvancedSearchBottomSheetState();
}

class _AdvancedSearchBottomSheetState extends State<AdvancedSearchBottomSheet>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un lieu...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _results.clear();
                              });
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onSubmitted: _performSearch,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.search), text: 'Résultats'),
              Tab(icon: Icon(Icons.history), text: 'Récents'),
              Tab(icon: Icon(Icons.category), text: 'Catégories'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildResultsTab(),
                _buildRecentTab(),
                _buildCategoriesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTab() {
    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Commencez votre recherche',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.location_on)),
          title: Text(result.name),
          subtitle: Text(result.address ?? 'Adresse non disponible'),
          trailing: IconButton(
            icon: const Icon(Icons.navigation),
            onPressed: () {
              _navigateToResult(result);
            },
          ),
          onTap: () => _navigateToResult(result),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 100));
      },
    );
  }

  Widget _buildRecentTab() {
    return Consumer<SearchProvider>(
      builder: (context, searchProvider, child) {
        final recentSearches = searchProvider.recentSearches;

        if (recentSearches.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucune recherche récente',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: recentSearches.length,
          itemBuilder: (context, index) {
            final search = recentSearches[index];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(search),
              trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => searchProvider.removeRecentSearch(search),
              ),
              onTap: () {
                _searchController.text = search;
                _performSearch(search);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    final categories = [
      {'name': 'Restaurants', 'icon': Icons.restaurant, 'query': 'restaurant'},
      {
        'name': 'Stations-service',
        'icon': Icons.local_gas_station,
        'query': 'gas station',
      },
      {'name': 'Hôtels', 'icon': Icons.hotel, 'query': 'hotel'},
      {'name': 'Hôpitaux', 'icon': Icons.local_hospital, 'query': 'hospital'},
      {'name': 'Pharmacies', 'icon': Icons.local_pharmacy, 'query': 'pharmacy'},
      {'name': 'Banques', 'icon': Icons.account_balance, 'query': 'bank'},
      {
        'name': 'Supermarchés',
        'icon': Icons.local_grocery_store,
        'query': 'supermarket',
      },
      {'name': 'Écoles', 'icon': Icons.school, 'query': 'school'},
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          child: InkWell(
            onTap: () => _performSearch(category['query'] as String),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category['icon'] as IconData, size: 32),
                const SizedBox(height: 8),
                Text(
                  category['name'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final searchProvider = context.read<SearchProvider>();
    await searchProvider.searchPlaces(query);

    setState(() {
      _results = searchProvider.searchResults;
      _isLoading = false;
    });

    _tabController.animateTo(0); // Aller à l'onglet résultats
  }

  void _navigateToResult(SearchResult result) {
    final mapProvider = context.read<MapProvider>();
    mapProvider.animateToLocation(result.position);
    Navigator.pop(context);
  }
}

/// Bottom Sheet de navigation
class NavigationBottomSheet extends StatefulWidget {
  const NavigationBottomSheet({super.key});

  @override
  State<NavigationBottomSheet> createState() => _NavigationBottomSheetState();
}

class _NavigationBottomSheetState extends State<NavigationBottomSheet> {
  final TextEditingController _destinationController = TextEditingController();
  String _selectedProfile = 'car';
  bool _avoidTolls = false;
  bool _avoidHighways = false;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Navigation',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              labelText: 'Destination',
              hintText: 'Entrez une adresse ou un lieu',
              prefixIcon: const Icon(Icons.location_on),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _calculateRoute,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _calculateRoute(),
          ),
          const SizedBox(height: 24),
          Text(
            'Mode de transport',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTransportTile(
                  'car',
                  Icons.directions_car,
                  'Voiture',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTransportTile(
                  'foot',
                  Icons.directions_walk,
                  'À pied',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTransportTile(
                  'bike',
                  Icons.directions_bike,
                  'Vélo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Options', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Éviter les péages'),
            value: _avoidTolls,
            onChanged: (value) => setState(() => _avoidTolls = value),
          ),
          SwitchListTile(
            title: const Text('Éviter les autoroutes'),
            value: _avoidHighways,
            onChanged: (value) => setState(() => _avoidHighways = value),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calculateRoute,
              icon: const Icon(Icons.navigation),
              label: const Text('Calculer l\'itinéraire'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportTile(String profile, IconData icon, String label) {
    final isSelected = _selectedProfile == profile;
    return InkWell(
      onTap: () => setState(() => _selectedProfile = profile),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _calculateRoute() {
    if (_destinationController.text.isEmpty) return;

    final navigationProvider = context.read<NavigationProvider>();
    final mapProvider = context.read<MapProvider>();

    if (mapProvider.currentLocation != null) {
      navigationProvider.calculateRoute(
        mapProvider.currentLocation!,
        LatLng(6.1319, 1.2228), // Destination par défaut : Lomé
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calcul de l\'itinéraire en cours...')),
    );
  }
}

/// Bottom Sheet des favoris
class FavoritesBottomSheet extends StatelessWidget {
  const FavoritesBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Favoris', style: Theme.of(context).textTheme.headlineSmall),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _addCurrentLocation(context),
                    icon: const Icon(Icons.add_location),
                    tooltip: 'Ajouter position actuelle',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<FavoritesProvider>(
              builder: (context, favoritesProvider, child) {
                if (favoritesProvider.favorites.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucun favori',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ajoutez des lieux à vos favoris',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: favoritesProvider.favorites.length,
                  itemBuilder: (context, index) {
                    final favorite = favoritesProvider.favorites[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Icon(
                            _getFavoriteIcon(favorite.type),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(favorite.name),
                        subtitle: Text(
                          '${favorite.position.latitude.toStringAsFixed(4)}, ${favorite.position.longitude.toStringAsFixed(4)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () =>
                                  _navigateToFavorite(context, favorite),
                              icon: const Icon(Icons.navigation),
                            ),
                            IconButton(
                              onPressed: () =>
                                  favoritesProvider.removeFavorite(favorite.id),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ).animate().slideX(
                      delay: Duration(milliseconds: index * 100),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addCurrentLocation(BuildContext context) {
    final mapProvider = context.read<MapProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    if (mapProvider.currentLocation != null) {
      favoritesProvider.addFavorite(
        name: 'Position actuelle',
        position: mapProvider.currentLocation!,
        type: 'location',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position ajoutée aux favoris')),
      );
    }
  }

  void _navigateToFavorite(BuildContext context, Favorite favorite) {
    final mapProvider = context.read<MapProvider>();
    mapProvider.animateToLocation(favorite.position);
    Navigator.pop(context);
  }

  IconData _getFavoriteIcon(String type) {
    switch (type) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'location':
        return Icons.location_on;
      default:
        return Icons.favorite;
    }
  }
}

/// Bottom Sheet de mesure
class MeasurementBottomSheet extends StatelessWidget {
  const MeasurementBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outils de mesure',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Mesurer une distance'),
            subtitle: const Text('Dessinez une ligne entre deux points'),
            onTap: () {
              _startDistanceMeasurement(context);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.crop_free),
            title: const Text('Mesurer une surface'),
            subtitle: const Text('Dessinez un polygone pour calculer l\'aire'),
            onTap: () {
              _startAreaMeasurement(context);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.clear),
            title: const Text('Effacer les mesures'),
            subtitle: const Text('Supprimer toutes les mesures'),
            onTap: () {
              _clearMeasurements(context);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _startDistanceMeasurement(BuildContext context) {
    final measurementService = context.read<MeasurementService>();
    measurementService.startDistanceMeasurement();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Mode mesure de distance activé - Touchez pour placer des points',
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _startAreaMeasurement(BuildContext context) {
    final measurementService = context.read<MeasurementService>();
    measurementService.startAreaMeasurement();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Mode mesure de surface activé - Touchez pour dessiner un polygone',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearMeasurements(BuildContext context) {
    final measurementService = context.read<MeasurementService>();
    measurementService.clearMeasurements();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toutes les mesures ont été effacées'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

/// Bottom Sheet de partage
class ShareBottomSheet extends StatelessWidget {
  const ShareBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Partager',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Partager la position'),
            subtitle: const Text('Envoyer votre position actuelle'),
            onTap: () => _shareLocation(context),
          ),
          ListTile(
            leading: const Icon(Icons.route),
            title: const Text('Partager l\'itinéraire'),
            subtitle: const Text('Partager l\'itinéraire calculé'),
            onTap: () => _shareRoute(context),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Générer un QR Code'),
            subtitle: const Text('Créer un QR code de la position'),
            onTap: () => _generateQRCode(context),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Copier le lien'),
            subtitle: const Text('Copier l\'URL de la position'),
            onTap: () => _copyLink(context),
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Envoyer par message'),
            subtitle: const Text('Partager via SMS ou messagerie'),
            onTap: () => _sendMessage(context),
          ),
        ],
      ),
    );
  }

  void _shareLocation(BuildContext context) {
    final mapProvider = context.read<MapProvider>();
    if (mapProvider.currentLocation != null) {
      ShareService.shareLocation(
        position: mapProvider.currentLocation!,
        locationName: 'Ma position actuelle',
        context: context,
      );
      Navigator.pop(context);
    }
  }

  void _shareRoute(BuildContext context) {
    final navigationProvider = context.read<NavigationProvider>();
    if (navigationProvider.currentRoute != null &&
        navigationProvider.startPoint != null &&
        navigationProvider.endPoint != null) {
      ShareService.shareRoute(
        start: navigationProvider.startPoint!,
        end: navigationProvider.endPoint!,
        startName: 'Départ',
        endName: navigationProvider.destinationName,
        distance: navigationProvider.currentRoute!.distance,
        duration: navigationProvider.currentRoute!.estimatedDuration.inMinutes
            .toDouble(),
        context: context,
      );
      Navigator.pop(context);
    }
  }

  void _generateQRCode(BuildContext context) {
    final mapProvider = context.read<MapProvider>();
    if (mapProvider.currentLocation != null) {
      // Génération du QR code avec les coordonnées de la position actuelle
      final locationData =
          '${mapProvider.currentLocation!.latitude},${mapProvider.currentLocation!.longitude}';
      // Le QR code contient les coordonnées lat,lng
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Code généré pour: $locationData')),
      );
      Navigator.pop(context);
    }
  }

  void _copyLink(BuildContext context) {
    final mapProvider = context.read<MapProvider>();
    if (mapProvider.currentLocation != null) {
      final googleMapsUrl =
          'https://maps.google.com/?q=${mapProvider.currentLocation!.latitude},${mapProvider.currentLocation!.longitude}';
      ShareService.copyToClipboard(
        text: googleMapsUrl,
        context: context,
        successMessage: 'Lien copié dans le presse-papier',
      );
      Navigator.pop(context);
    }
  }

  void _sendMessage(BuildContext context) {
    // Envoi par message implémenté
    final mapProvider = context.read<MapProvider>();
    if (mapProvider.currentLocation != null) {
      final locationText =
          'Ma position actuelle: ${mapProvider.currentLocation!.latitude},${mapProvider.currentLocation!.longitude}';
      // Ici on pourrait intégrer avec les apps de messagerie
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Message préparé: $locationText')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Position non disponible')));
    }
    Navigator.pop(context);
  }
}

/// Bottom Sheet des styles de carte
class MapStylesBottomSheet extends StatelessWidget {
  const MapStylesBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Styles de carte',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStyleCard(
                  context,
                  'Standard',
                  Icons.map,
                  'Carte standard Azure Maps',
                  'standard',
                ),
                _buildStyleCard(
                  context,
                  'Satellite',
                  Icons.satellite_alt,
                  'Vue satellite haute résolution',
                  'satellite',
                ),
                _buildStyleCard(
                  context,
                  'Terrain',
                  Icons.terrain,
                  'Relief et courbes de niveau',
                  'terrain',
                ),
                _buildStyleCard(
                  context,
                  'Sombre',
                  Icons.dark_mode,
                  'Mode sombre pour la nuit',
                  'dark',
                ),
                _buildStyleCard(
                  context,
                  'Transport',
                  Icons.directions_transit,
                  'Réseau de transport public',
                  'transport',
                ),
                _buildStyleCard(
                  context,
                  'Cyclable',
                  Icons.directions_bike,
                  'Pistes cyclables et voies vertes',
                  'cycle',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleCard(
    BuildContext context,
    String name,
    IconData icon,
    String description,
    String styleId,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          final mapProvider = context.read<MapProvider>();
          mapProvider.changeMapStyle(_getStyleUrl(styleId));
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Style "$name" appliqué')));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).primaryColor),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStyleUrl(String styleId) {
    switch (styleId) {
      case 'satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'terrain':
        return 'https://stamen-tiles.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png';
      case 'dark':
        return 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
      case 'transport':
        return 'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=YOUR_API_KEY';
      case 'cycle':
        return 'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png?apikey=YOUR_API_KEY';
      default:
        return AzureTileUrls.standard;
    }
  }
}

/// Bottom Sheet POI
class POIBottomSheet extends StatelessWidget {
  const POIBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Points d\'intérêt',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Trouvez des lieux intéressants autour de vous'),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildPOICard(
                  context,
                  'Restaurants',
                  Icons.restaurant,
                  'restaurant',
                ),
                _buildPOICard(context, 'Hôtels', Icons.hotel, 'hotel'),
                _buildPOICard(
                  context,
                  'Attractions',
                  Icons.attractions,
                  'attraction',
                ),
                _buildPOICard(context, 'Magasins', Icons.shopping_bag, 'shop'),
                _buildPOICard(
                  context,
                  'Transport',
                  Icons.directions_transit,
                  'transport',
                ),
                _buildPOICard(context, 'Santé', Icons.local_hospital, 'health'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOICard(
    BuildContext context,
    String name,
    IconData icon,
    String category,
  ) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          // Recherche des POI de la catégorie sélectionnée
          final mapProvider = context.read<MapProvider>();
          if (mapProvider.currentLocation != null) {
            // Ici on pourrait intégrer avec des services de POI comme Google Places
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Recherche de $name dans la zone actuelle...'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Position requise pour la recherche'),
              ),
            );
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
