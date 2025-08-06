import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/services/storage_service.dart';
import '../../../../shared/extensions/color_extensions.dart';

class FavoritesProvider extends ChangeNotifier {
  List<Favorite> _favorites = [];
  bool _isLoading = false;
  String _selectedCategory = 'all';

  // Getters
  List<Favorite> get favorites => _selectedCategory == 'all'
      ? _favorites
      : _favorites.where((f) => f.category == _selectedCategory).toList();
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  List<String> get categories {
    final cats = _favorites
        .map((f) => f.category ?? 'Sans catégorie')
        .toSet()
        .toList();
    cats.sort();
    return ['all', ...cats];
  }

  /// Initialise en chargeant les favoris
  Future<void> initialize() async {
    await loadFavorites();
  }

  /// Charge tous les favoris
  Future<void> loadFavorites() async {
    _setLoading(true);
    try {
      _favorites = await StorageService.getFavorites();
    } catch (e) {
      // Erreur de chargement ignorée silencieusement
    } finally {
      _setLoading(false);
    }
  }

  /// Ajoute un favori
  Future<void> addFavorite({
    required String name,
    String? description,
    required LatLng position,
    required String type,
    String? category,
    List<String> tags = const [],
  }) async {
    final favorite = Favorite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      position: position,
      type: type,
      createdAt: DateTime.now(),
      category: category,
      tags: tags,
    );

    try {
      await StorageService.addFavorite(favorite);
      _favorites.add(favorite);
      notifyListeners();
    } catch (e) {
      // Erreur d'ajout ignorée silencieusement
    }
  }

  /// Supprime un favori
  Future<void> removeFavorite(String id) async {
    try {
      await StorageService.removeFavorite(id);
      _favorites.removeWhere((f) => f.id == id);
      notifyListeners();
    } catch (e) {
      // Erreur de suppression ignorée silencieusement
    }
  }

  /// Met à jour un favori
  Future<void> updateFavorite(Favorite favorite) async {
    try {
      await StorageService.updateFavorite(favorite);
      final index = _favorites.indexWhere((f) => f.id == favorite.id);
      if (index != -1) {
        _favorites[index] = favorite;
        notifyListeners();
      }
    } catch (e) {
      // Erreur de mise à jour ignorée silencieusement
    }
  }

  /// Vérifie si une position est en favori
  bool isFavorite(LatLng position) {
    return _favorites.any(
      (f) =>
          (f.position.latitude - position.latitude).abs() < 0.0001 &&
          (f.position.longitude - position.longitude).abs() < 0.0001,
    );
  }

  /// Change la catégorie sélectionnée
  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Recherche dans les favoris
  List<Favorite> searchFavorites(String query) {
    if (query.isEmpty) return favorites;

    final lowercaseQuery = query.toLowerCase();
    return favorites
        .where(
          (f) =>
              f.name.toLowerCase().contains(lowercaseQuery) ||
              (f.description?.toLowerCase().contains(lowercaseQuery) ??
                  false) ||
              f.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery)),
        )
        .toList();
  }

  /// Met à jour l'état de chargement
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

/// Widget pour afficher la liste des favoris
class FavoritesList extends StatelessWidget {
  final List<Favorite> favorites;
  final Function(Favorite) onFavoriteSelected;
  final Function(Favorite)? onFavoriteEdit;
  final Function(Favorite)? onFavoriteDelete;

  const FavoritesList({
    super.key,
    required this.favorites,
    required this.onFavoriteSelected,
    this.onFavoriteEdit,
    this.onFavoriteDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun favori',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Appuyez longuement sur la carte pour ajouter un lieu',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        return _buildFavoriteItem(context, favorite);
      },
    );
  }

  Widget _buildFavoriteItem(BuildContext context, Favorite favorite) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withCustomOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIconForType(favorite.type),
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          favorite.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (favorite.description != null) ...[
              Text(favorite.description!),
              const SizedBox(height: 4),
            ],
            if (favorite.category != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withCustomOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  favorite.category!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'navigate',
              child: Row(
                children: [
                  Icon(Icons.navigation),
                  SizedBox(width: 8),
                  Text('Naviguer'),
                ],
              ),
            ),
            if (onFavoriteEdit != null)
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ],
                ),
              ),
            if (onFavoriteDelete != null)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'navigate':
                onFavoriteSelected(favorite);
                break;
              case 'edit':
                onFavoriteEdit?.call(favorite);
                break;
              case 'delete':
                onFavoriteDelete?.call(favorite);
                break;
            }
          },
        ),
        onTap: () => onFavoriteSelected(favorite),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant;
      case 'hotel':
        return Icons.hotel;
      case 'hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'park':
        return Icons.park;
      case 'shop':
        return Icons.store;
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      default:
        return Icons.place;
    }
  }
}
