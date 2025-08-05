import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../shared/services/poi_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<Map<String, dynamic>> _nearbyPlaces = [];
  String _selectedCategory = 'all';
  bool _isLoading = true;
  Position? _currentPosition;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'name': 'Tout', 'icon': Icons.explore},
    {'id': 'restaurant', 'name': 'Restaurants', 'icon': Icons.restaurant},
    {'id': 'hotel', 'name': 'Hôtels', 'icon': Icons.hotel},
    {'id': 'attraction', 'name': 'Attractions', 'icon': Icons.place},
    {'id': 'shop', 'name': 'Shopping', 'icon': Icons.shopping_cart},
    {'id': 'transport', 'name': 'Transport', 'icon': Icons.directions_transit},
    {'id': 'health', 'name': 'Santé', 'icon': Icons.local_hospital},
    {'id': 'education', 'name': 'Éducation', 'icon': Icons.school},
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _loadDefaultPlaces();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await _loadDefaultPlaces();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await _loadDefaultPlaces();
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      await _loadNearbyPlaces();
    } catch (e) {
      debugPrint('Erreur géolocalisation: $e');
      await _loadDefaultPlaces();
    }
  }

  Future<void> _loadNearbyPlaces() async {
    setState(() => _isLoading = true);

    try {
      // Utiliser le service POI pour rechercher des lieux réels
      final poiService = Provider.of<POIService>(context, listen: false);

      if (_currentPosition != null) {
        // Recherche avec position réelle
        final result = await poiService.searchPOIs(
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          maxDistance: 2000,
          maxResults: 20,
        );

        if (result.pois.isNotEmpty) {
          setState(() {
            _nearbyPlaces = _convertPOIsToPlaces(result.pois);
            _isLoading = false;
          });
          return;
        }
      }

      // Fallback: utiliser des lieux par défaut pour Lomé
      await _loadDefaultPlaces();
    } catch (e) {
      debugPrint('Erreur chargement lieux: $e');
      await _loadDefaultPlaces();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _convertPOIsToPlaces(List<POI> pois) {
    return pois.map((poi) {
      double distance = 0;
      if (_currentPosition != null) {
        distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          poi.location.latitude,
          poi.location.longitude,
        );
      }

      return {
        'id': poi.id,
        'name': poi.name,
        'category': _mapPOITypeToCategory(poi.category.name),
        'categoryName': _mapPOITypeToCategoryName(poi.category.name),
        'distance': distance.toInt(),
        'distanceText': distance < 1000
            ? '${distance.toInt()}m'
            : '${(distance / 1000).toStringAsFixed(1)}km',
        'rating': poi.rating ?? (4.0 + (poi.name.hashCode % 20) / 20.0),
        'ratingText': (poi.rating ?? (4.0 + (poi.name.hashCode % 20) / 20.0))
            .toStringAsFixed(1),
        'address': poi.address ?? 'Lomé, Togo',
        'isOpen': true,
        'icon': _getCategoryIcon(_mapPOITypeToCategory(poi.category.name)),
      };
    }).toList();
  }

  String _mapPOITypeToCategory(String poiType) {
    switch (poiType.toLowerCase()) {
      case 'restaurant':
      case 'cafe':
      case 'fast_food':
        return 'restaurant';
      case 'hotel':
      case 'guest_house':
        return 'hotel';
      case 'shop':
      case 'supermarket':
      case 'mall':
        return 'shop';
      case 'hospital':
      case 'clinic':
      case 'health':
        return 'health';
      case 'school':
      case 'university':
      case 'education':
        return 'education';
      case 'bus_station':
      case 'taxi_stand':
      case 'transport':
        return 'transport';
      default:
        return 'attraction';
    }
  }

  String _mapPOITypeToCategoryName(String poiType) {
    switch (_mapPOITypeToCategory(poiType)) {
      case 'restaurant':
        return 'Restaurants';
      case 'hotel':
        return 'Hôtels';
      case 'shop':
        return 'Shopping';
      case 'health':
        return 'Santé';
      case 'education':
        return 'Éducation';
      case 'transport':
        return 'Transport';
      default:
        return 'Attractions';
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'restaurant':
        return Icons.restaurant;
      case 'hotel':
        return Icons.hotel;
      case 'shop':
        return Icons.shopping_cart;
      case 'health':
        return Icons.local_hospital;
      case 'education':
        return Icons.school;
      case 'transport':
        return Icons.directions_transit;
      default:
        return Icons.place;
    }
  }

  Future<void> _loadDefaultPlaces() async {
    // Lieux par défaut pour Lomé et environs
    final defaultPlaces = [
      {
        'id': 'lome_market',
        'name': 'Grand Marché de Lomé',
        'category': 'shop',
        'categoryName': 'Shopping',
        'distance': 1200,
        'distanceText': '1.2km',
        'rating': 4.2,
        'ratingText': '4.2',
        'address': 'Boulevard du 13 Janvier, Lomé',
        'isOpen': true,
        'icon': Icons.shopping_cart,
      },
      {
        'id': 'independence_monument',
        'name': 'Monument de l\'Indépendance',
        'category': 'attraction',
        'categoryName': 'Attractions',
        'distance': 800,
        'distanceText': '800m',
        'rating': 4.5,
        'ratingText': '4.5',
        'address': 'Place de l\'Indépendance, Lomé',
        'isOpen': true,
        'icon': Icons.place,
      },
      {
        'id': 'beach_lome',
        'name': 'Plage de Lomé',
        'category': 'attraction',
        'categoryName': 'Attractions',
        'distance': 2100,
        'distanceText': '2.1km',
        'rating': 4.0,
        'ratingText': '4.0',
        'address': 'Front de mer, Lomé',
        'isOpen': true,
        'icon': Icons.beach_access,
      },
      {
        'id': 'restaurant_akodessewa',
        'name': 'Restaurant Akodessewa',
        'category': 'restaurant',
        'categoryName': 'Restaurants',
        'distance': 1500,
        'distanceText': '1.5km',
        'rating': 4.3,
        'ratingText': '4.3',
        'address': 'Quartier Akodessewa, Lomé',
        'isOpen': true,
        'icon': Icons.restaurant,
      },
      {
        'id': 'hotel_sarakawa',
        'name': 'Hôtel Sarakawa',
        'category': 'hotel',
        'categoryName': 'Hôtels',
        'distance': 1800,
        'distanceText': '1.8km',
        'rating': 4.4,
        'ratingText': '4.4',
        'address': 'Avenue Sarakawa, Lomé',
        'isOpen': true,
        'icon': Icons.hotel,
      },
      {
        'id': 'chu_campus',
        'name': 'CHU Campus',
        'category': 'health',
        'categoryName': 'Santé',
        'distance': 3200,
        'distanceText': '3.2km',
        'rating': 4.1,
        'ratingText': '4.1',
        'address': 'Campus Universitaire, Lomé',
        'isOpen': true,
        'icon': Icons.local_hospital,
      },
    ];

    setState(() {
      _nearbyPlaces = defaultPlaces;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Explorer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _refreshLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Categories Filter
          _buildCategoriesFilter(isDark).animate().slideX(),

          // Places List
          Expanded(
            child: _isLoading
                ? _buildLoadingState(isDark)
                : _buildPlacesList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesFilter(bool isDark) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['id'];

          return GestureDetector(
                onTap: () => _selectCategory(category['id'] as String),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        category['icon'] as IconData,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF4CAF50),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              .animate(delay: Duration(milliseconds: 100 * index))
              .fadeIn()
              .slideX(begin: 0.3);
        },
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 16),
          Text(
            'Recherche des lieux proches...',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList(bool isDark) {
    final filteredPlaces = _selectedCategory == 'all'
        ? _nearbyPlaces
        : _nearbyPlaces
              .where((place) => place['category'] == _selectedCategory)
              .toList();

    if (filteredPlaces.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPlaces.length,
      itemBuilder: (context, index) {
        final place = filteredPlaces[index];
        return _buildPlaceCard(place, isDark)
            .animate(delay: Duration(milliseconds: 100 * index))
            .fadeIn()
            .slideY(begin: 0.3);
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun lieu trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez une autre catégorie',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            place['icon'] as IconData,
            color: const Color(0xFF4CAF50),
          ),
        ),
        title: Text(
          place['name'] as String,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              place['address'] as String,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Distance
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    place['distanceText'] as String,
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Rating
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      place['ratingText'] as String,
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Status
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: (place['isOpen'] as bool)
                        ? Colors.green
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  (place['isOpen'] as bool) ? 'Ouvert' : 'Fermé',
                  style: TextStyle(
                    color: (place['isOpen'] as bool)
                        ? Colors.green
                        : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _navigateToPlace(place),
          icon: const Icon(Icons.directions, color: Color(0xFF4CAF50)),
        ),
        onTap: () => _showPlaceDetails(place),
      ),
    );
  }

  void _selectCategory(String categoryId) {
    setState(() => _selectedCategory = categoryId);
  }

  void _refreshLocation() {
    _initializeLocation();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Actualisation de la position...'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _navigateToPlace(Map<String, dynamic> place) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation vers ${place['name']}'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  void _showPlaceDetails(Map<String, dynamic> place) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  place['icon'] as IconData,
                  color: const Color(0xFF4CAF50),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    place['name'] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Adresse: ${place['address']}'),
            const SizedBox(height: 8),
            Text('Distance: ${place['distanceText']}'),
            const SizedBox(height: 8),
            Text('Note: ${place['ratingText']}/5'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToPlace(place);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Itinéraire'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
