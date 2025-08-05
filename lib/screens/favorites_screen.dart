import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';

import '../features/favorites/providers/favorites_provider.dart';
import '../features/map/screens/map_screen.dart';
import '../shared/services/storage_service.dart';

/// Écran des favoris avec design moderne
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    // Charger les favoris
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesProvider>().loadFavorites();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favoritesProvider = context.watch<FavoritesProvider>();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Mes Favoris',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(isDark),

          // Statistiques
          _buildStatsBar(favoritesProvider, isDark),

          // Liste des favoris
          Expanded(child: _buildFavoritesList(favoritesProvider, isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFavoriteDialog(context),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location),
        label: const Text('Ajouter'),
      ).animate().slideY(begin: 1, duration: 600.ms).fade(),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Rechercher dans les favoris...',
          prefixIcon: Icon(Icons.search, color: const Color(0xFF4CAF50)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
          ),
        ),
      ),
    ).animate().slideY(begin: -1, duration: 500.ms).fade();
  }

  Widget _buildStatsBar(FavoritesProvider provider, bool isDark) {
    final totalFavorites = provider.favorites.length;
    final filteredCount = _getFilteredFavorites(provider).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.favorite,
            label: 'Total',
            value: totalFavorites.toString(),
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(width: 20),
          _buildStatItem(
            icon: Icons.search,
            label: _searchQuery.isNotEmpty ? 'Trouvés' : 'Visibles',
            value: filteredCount.toString(),
            color: const Color(0xFF2196F3),
          ),
        ],
      ),
    ).animate().slideX(begin: -1, duration: 600.ms).fade();
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(FavoritesProvider provider, bool isDark) {
    final filteredFavorites = _getFilteredFavorites(provider);

    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }

    if (filteredFavorites.isEmpty) {
      return _buildEmptyState(_searchQuery.isNotEmpty);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredFavorites.length,
      itemBuilder: (context, index) {
        final favorite = filteredFavorites[index];
        return _buildFavoriteCard(favorite, provider, isDark, index);
      },
    );
  }

  List<Favorite> _getFilteredFavorites(FavoritesProvider provider) {
    if (_searchQuery.isEmpty) {
      return provider.favorites;
    }

    return provider.favorites.where((favorite) {
      final name = favorite.name.toLowerCase();
      final description = (favorite.description ?? '').toLowerCase();
      return name.contains(_searchQuery) || description.contains(_searchQuery);
    }).toList();
  }

  Widget _buildFavoriteCard(
    Favorite favorite,
    FavoritesProvider provider,
    bool isDark,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _navigateToLocation(favorite),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForType(favorite.type),
                    color: const Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        favorite.description ?? 'Aucune description',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${favorite.position.latitude.toStringAsFixed(4)}, ${favorite.position.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'navigate':
                        _navigateToLocation(favorite);
                        break;
                      case 'edit':
                        _showEditFavoriteDialog(context, favorite);
                        break;
                      case 'delete':
                        _confirmDelete(context, favorite, provider);
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'navigate',
                      child: Row(
                        children: [
                          Icon(Icons.navigation, size: 20),
                          SizedBox(width: 8),
                          Text('Naviguer'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 100).ms).slideX(begin: 1, duration: 500.ms).fade();
  }

  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.favorite_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            isSearching ? 'Aucun résultat trouvé' : 'Aucun favori enregistré',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isSearching
                ? 'Essayez avec d\'autres mots-clés'
                : 'Ajoutez vos lieux préférés pour un accès rapide',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (!isSearching) ...[
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => _showAddFavoriteDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              icon: const Icon(Icons.add_location),
              label: const Text('Ajouter un favori'),
            ),
          ],
        ],
      ).animate().scale(duration: 600.ms).fade(),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'restaurant':
        return Icons.restaurant;
      case 'gas_station':
        return Icons.local_gas_station;
      case 'hospital':
        return Icons.local_hospital;
      case 'shopping':
        return Icons.shopping_cart;
      case 'hotel':
        return Icons.hotel;
      case 'school':
        return Icons.school;
      default:
        return Icons.place;
    }
  }

  void _navigateToLocation(Favorite favorite) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  void _showAddFavoriteDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => _AddFavoriteDialog());
  }

  void _showEditFavoriteDialog(BuildContext context, Favorite favorite) {
    showDialog(
      context: context,
      builder: (context) => _EditFavoriteDialog(favorite: favorite),
    );
  }

  void _confirmDelete(
    BuildContext context,
    Favorite favorite,
    FavoritesProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le favori'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${favorite.name}" de vos favoris ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              provider.removeFavorite(favorite.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Favori supprimé'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

/// Dialog pour ajouter un nouveau favori
class _AddFavoriteDialog extends StatefulWidget {
  @override
  State<_AddFavoriteDialog> createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<_AddFavoriteDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedType = 'place';

  final List<Map<String, dynamic>> _types = [
    {'value': 'home', 'label': 'Domicile', 'icon': Icons.home},
    {'value': 'work', 'label': 'Travail', 'icon': Icons.work},
    {'value': 'restaurant', 'label': 'Restaurant', 'icon': Icons.restaurant},
    {
      'value': 'gas_station',
      'label': 'Station-service',
      'icon': Icons.local_gas_station,
    },
    {'value': 'hospital', 'label': 'Hôpital', 'icon': Icons.local_hospital},
    {'value': 'shopping', 'label': 'Shopping', 'icon': Icons.shopping_cart},
    {'value': 'hotel', 'label': 'Hôtel', 'icon': Icons.hotel},
    {'value': 'school', 'label': 'École', 'icon': Icons.school},
    {'value': 'place', 'label': 'Lieu', 'icon': Icons.place},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un favori'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom du lieu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Adresse',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: _types.map((type) {
              return DropdownMenuItem<String>(
                value: type['value'],
                child: Row(
                  children: [
                    Icon(type['icon'], size: 20),
                    const SizedBox(width: 8),
                    Text(type['label']),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _addressController.text.isNotEmpty) {
              context.read<FavoritesProvider>().addFavorite(
                name: _nameController.text,
                description: _addressController.text,
                position: const LatLng(
                  0.0,
                  0.0,
                ), // À remplacer par les vraies coordonnées
                type: _selectedType,
              );
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Favori ajouté avec succès'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

/// Dialog pour modifier un favori existant
class _EditFavoriteDialog extends StatefulWidget {
  final Favorite favorite;

  const _EditFavoriteDialog({required this.favorite});

  @override
  State<_EditFavoriteDialog> createState() => _EditFavoriteDialogState();
}

class _EditFavoriteDialogState extends State<_EditFavoriteDialog> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late String _selectedType;

  final List<Map<String, dynamic>> _types = [
    {'value': 'home', 'label': 'Domicile', 'icon': Icons.home},
    {'value': 'work', 'label': 'Travail', 'icon': Icons.work},
    {'value': 'restaurant', 'label': 'Restaurant', 'icon': Icons.restaurant},
    {
      'value': 'gas_station',
      'label': 'Station-service',
      'icon': Icons.local_gas_station,
    },
    {'value': 'hospital', 'label': 'Hôpital', 'icon': Icons.local_hospital},
    {'value': 'shopping', 'label': 'Shopping', 'icon': Icons.shopping_cart},
    {'value': 'hotel', 'label': 'Hôtel', 'icon': Icons.hotel},
    {'value': 'school', 'label': 'École', 'icon': Icons.school},
    {'value': 'place', 'label': 'Lieu', 'icon': Icons.place},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.favorite.name);
    _addressController = TextEditingController(
      text: widget.favorite.description ?? '',
    );
    _selectedType = widget.favorite.type;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le favori'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom du lieu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Adresse',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: _types.map((type) {
              return DropdownMenuItem<String>(
                value: type['value'],
                child: Row(
                  children: [
                    Icon(type['icon'], size: 20),
                    const SizedBox(width: 8),
                    Text(type['label']),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _addressController.text.isNotEmpty) {
              final updatedFavorite = Favorite(
                id: widget.favorite.id,
                name: _nameController.text,
                description: _addressController.text,
                position: widget.favorite.position,
                type: _selectedType,
                createdAt: widget.favorite.createdAt,
                category: widget.favorite.category,
                tags: widget.favorite.tags,
              );

              context.read<FavoritesProvider>().updateFavorite(updatedFavorite);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Favori modifié avec succès'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: const Text('Modifier'),
        ),
      ],
    );
  }
}
