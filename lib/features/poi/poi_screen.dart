import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import '../../shared/services/poi_service.dart';
import '../../shared/services/share_service.dart';
import '../../features/map/providers/map_provider.dart';
import '../../../shared/extensions/color_extensions.dart';

class POIScreen extends StatefulWidget {
  const POIScreen({super.key});

  @override
  State<POIScreen> createState() => _POIScreenState();
}

class _POIScreenState extends State<POIScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  POISearchResult? _searchResult;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _performInitialSearch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performInitialSearch() async {
    final mapProvider = context.read<MapProvider>();
    final poiService = context.read<POIService>();

    // Utiliser la position actuelle ou Paris par défaut
    final position = mapProvider.currentLocation ?? LatLng(48.8566, 2.3522);

    final result = await poiService.searchPOIs(position: position);
    if (mounted) {
      setState(() {
        _searchResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Points d\'intérêt'),
        actions: [
          Consumer<POIService>(
            builder: (context, poiService, child) {
              return IconButton(
                icon: poiService.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: poiService.isLoading ? null : _performInitialSearch,
                tooltip: 'Actualiser',
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Recherche'),
            Tab(icon: Icon(Icons.favorite), text: 'Favoris'),
            Tab(icon: Icon(Icons.tune), text: 'Filtres'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSearchTab(), _buildFavoritesTab(), _buildFiltersTab()],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _searchResult == null
              ? const Center(child: CircularProgressIndicator())
              : _buildPOIList(_searchResult!.pois),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher des lieux...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
        ),
        onSubmitted: _performSearch,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    final mapProvider = context.read<MapProvider>();
    final poiService = context.read<POIService>();

    final position = mapProvider.currentLocation ?? LatLng(48.8566, 2.3522);

    final result = await poiService.searchPOIs(
      position: position,
      query: query.isNotEmpty ? query : null,
    );

    if (mounted) {
      setState(() {
        _searchResult = result;
        _searchQuery = query;
      });
    }
  }

  Widget _buildFavoritesTab() {
    return Consumer<POIService>(
      builder: (context, poiService, child) {
        final favoritePOIs = poiService.favoritePOIs;

        if (favoritePOIs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucun favori',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Ajoutez des lieux à vos favoris depuis la recherche',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return _buildPOIList(favoritePOIs);
      },
    );
  }

  Widget _buildFiltersTab() {
    return Consumer<POIService>(
      builder: (context, poiService, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    leading: Icon(Icons.category),
                    title: Text('Catégories'),
                  ),
                  ...POICategory.values.map((category) {
                    final isEnabled = poiService.enabledCategories.contains(
                      category,
                    );
                    return CheckboxListTile(
                      title: Text(poiService.getCategoryName(category)),
                      subtitle: Text(_getCategoryDescription(category)),
                      secondary: Icon(
                        poiService.getCategoryIcon(category),
                        color: poiService.getCategoryColor(category),
                      ),
                      value: isEnabled,
                      onChanged: (value) {
                        final newCategories = Set<POICategory>.from(
                          poiService.enabledCategories,
                        );
                        if (value == true) {
                          newCategories.add(category);
                        } else {
                          newCategories.remove(category);
                        }
                        poiService.setEnabledCategories(newCategories);
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    leading: Icon(Icons.tune),
                    title: Text('Filtres'),
                  ),
                  SwitchListTile(
                    title: const Text('Seulement les lieux ouverts'),
                    subtitle: const Text('Masquer les lieux fermés'),
                    value: poiService.showOnlyOpen,
                    onChanged: poiService.setShowOnlyOpen,
                  ),
                  ListTile(
                    title: const Text('Distance maximale'),
                    subtitle: Text('${poiService.maxDistance.toInt()} km'),
                    trailing: SizedBox(
                      width: 150,
                      child: Slider(
                        value: poiService.maxDistance,
                        min: 1,
                        max: 50,
                        divisions: 49,
                        onChanged: poiService.setMaxDistance,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Nombre de résultats'),
                    subtitle: Text('${poiService.maxResults} résultats'),
                    trailing: SizedBox(
                      width: 150,
                      child: Slider(
                        value: poiService.maxResults.toDouble(),
                        min: 10,
                        max: 100,
                        divisions: 18,
                        onChanged: (value) =>
                            poiService.setMaxResults(value.toInt()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                poiService.clearSearchCache();
                _performInitialSearch();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Filtres appliqués')),
                );
              },
              icon: const Icon(Icons.filter_alt),
              label: const Text('Appliquer les filtres'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPOIList(List<POI> pois) {
    if (pois.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Aucun résultat',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Essayez avec d\'autres mots-clés'
                  : 'Modifiez les filtres pour voir plus de résultats',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: pois.length,
      itemBuilder: (context, index) {
        final poi = pois[index];
        return _buildPOICard(poi)
            .animate()
            .fadeIn(delay: Duration(milliseconds: index * 50))
            .slideX(begin: 0.3, end: 0);
      },
    );
  }

  Widget _buildPOICard(POI poi) {
    final mapProvider = context.read<MapProvider>();
    final userLocation = mapProvider.currentLocation ?? LatLng(48.8566, 2.3522);
    final distance = poi.distanceFrom(userLocation);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showPOIDetails(poi),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context
                          .read<POIService>()
                          .getCategoryColor(poi.category)
                          .withCustomOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      context.read<POIService>().getCategoryIcon(poi.category),
                      color: context.read<POIService>().getCategoryColor(
                        poi.category,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poi.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (poi.address != null)
                          Text(
                            poi.address!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Consumer<POIService>(
                    builder: (context, poiService, child) {
                      final isFavorite = poiService.isFavorite(poi.id);
                      return IconButton(
                        onPressed: () {
                          if (isFavorite) {
                            poiService.removeFromFavorites(poi.id);
                          } else {
                            poiService.addToFavorites(poi.id);
                          }
                        },
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (poi.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  poi.description!,
                  style: TextStyle(color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (poi.rating != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          poi.rating!.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (poi.reviewCount != null)
                          Text(
                            ' (${poi.reviewCount})',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${distance.toStringAsFixed(1)} km',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  if (poi.priceRange != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withCustomOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        poi.priceRange!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (poi.openingHours.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      poi.isOpenNow
                          ? Icons.access_time
                          : Icons.access_time_filled,
                      size: 16,
                      color: poi.isOpenNow ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      poi.isOpenNow ? 'Ouvert' : 'Fermé',
                      style: TextStyle(
                        color: poi.isOpenNow ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPOIDetails(POI poi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildPOIDetailsSheet(poi),
    );
  }

  Widget _buildPOIDetailsSheet(POI poi) {
    final mapProvider = context.read<MapProvider>();
    final userLocation = mapProvider.currentLocation ?? LatLng(48.8566, 2.3522);
    final distance = poi.distanceFrom(userLocation);

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context
                      .read<POIService>()
                      .getCategoryColor(poi.category)
                      .withCustomOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  context.read<POIService>().getCategoryIcon(poi.category),
                  color: context.read<POIService>().getCategoryColor(
                    poi.category,
                  ),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      context.read<POIService>().getCategoryName(poi.category),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Consumer<POIService>(
                builder: (context, poiService, child) {
                  final isFavorite = poiService.isFavorite(poi.id);
                  return IconButton(
                    onPressed: () {
                      if (isFavorite) {
                        poiService.removeFromFavorites(poi.id);
                      } else {
                        poiService.addToFavorites(poi.id);
                      }
                    },
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                      size: 28,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (poi.description != null) ...[
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(poi.description!),
            const SizedBox(height: 16),
          ],
          if (poi.address != null) ...[
            _buildDetailRow(Icons.location_on, 'Adresse', poi.address!),
            const SizedBox(height: 8),
          ],
          if (poi.phone != null) ...[
            _buildDetailRow(Icons.phone, 'Téléphone', poi.phone!),
            const SizedBox(height: 8),
          ],
          _buildDetailRow(
            Icons.straighten,
            'Distance',
            '${distance.toStringAsFixed(1)} km',
          ),
          if (poi.rating != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.star,
              'Note',
              '${poi.rating!.toStringAsFixed(1)} / 5${poi.reviewCount != null ? ' (${poi.reviewCount} avis)' : ''}',
            ),
          ],
          if (poi.openingHours.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Horaires d\'ouverture',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...poi.openingHours.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        entry.key.capitalize(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(entry.value),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    mapProvider.animateToLocation(poi.location);
                    Navigator.pop(context); // Fermer l'écran POI
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Aller'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _sharePOI(poi);
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Partager'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(child: Text(value)),
      ],
    );
  }

  String _getCategoryDescription(POICategory category) {
    switch (category) {
      case POICategory.restaurant:
        return 'Cafés, restaurants, bars';
      case POICategory.hotel:
        return 'Hôtels, auberges, gîtes';
      case POICategory.attraction:
        return 'Sites touristiques, monuments';
      case POICategory.shop:
        return 'Magasins, commerces';
      case POICategory.transport:
        return 'Gares, arrêts, stations';
      case POICategory.health:
        return 'Hôpitaux, pharmacies, cliniques';
      case POICategory.education:
        return 'Écoles, universités, bibliothèques';
      case POICategory.service:
        return 'Banques, postes, services publics';
      case POICategory.entertainment:
        return 'Cinémas, théâtres, concerts';
      case POICategory.sport:
        return 'Gymnases, stades, piscines';
      case POICategory.culture:
        return 'Musées, galeries, centres culturels';
      case POICategory.nature:
        return 'Parcs, jardins, espaces verts';
      default:
        return 'Autres points d\'intérêt';
    }
  }

  void _sharePOI(POI poi) {
    // Utiliser le ShareService pour partager le POI
    ShareService.sharePOI(
      name: poi.name,
      position: poi.location,
      address: poi.address,
      phone: poi.phone,
      website: poi.website,
      description: poi.description,
      context: context,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
