import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../services/cache_service.dart';
import '../services/location_service.dart';

/// Modèle pour un lieu favori
class FavoritePlace {
  final String id;
  final String name;
  final String address;
  final LatLng position;
  final String category;
  final String? description;
  final DateTime createdAt;

  const FavoritePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
    required this.category,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'category': category,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      position: LatLng(json['latitude'], json['longitude']),
      category: json['category'],
      description: json['description'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
    );
  }
}

/// Contrôleur MVC pour la gestion des favoris et POI
class FavoritesController extends ChangeNotifier {
  static FavoritesController? _instance;
  static FavoritesController get instance =>
      _instance ??= FavoritesController._();
  FavoritesController._();

  // Services
  final CacheService _cacheService = CacheService.instance;
  final LocationService _locationService = LocationService.instance;

  // État privé
  List<FavoritePlace> _favorites = [];
  final Map<String, List<FavoritePlace>> _categorizedFavorites = {};
  bool _isLoading = false;
  String? _lastError;

  // Catégories prédéfinies
  static const List<String> categories = [
    'Maison',
    'Travail',
    'Restaurant',
    'Shopping',
    'Loisirs',
    'Santé',
    'Transport',
    'Autres',
  ];

  // Getters
  List<FavoritePlace> get favorites => _favorites;
  Map<String, List<FavoritePlace>> get categorizedFavorites =>
      _categorizedFavorites;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// Ajoute un lieu aux favoris
  Future<bool> addFavorite({
    required String name,
    required String address,
    required LatLng position,
    required String category,
    String? description,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Vérifier si le lieu n'existe pas déjà
      final exists = _favorites.any(
        (fav) =>
            fav.name.toLowerCase() == name.toLowerCase() &&
            fav.position.latitude.toStringAsFixed(6) ==
                position.latitude.toStringAsFixed(6) &&
            fav.position.longitude.toStringAsFixed(6) ==
                position.longitude.toStringAsFixed(6),
      );

      if (exists) {
        _setError('Ce lieu est déjà dans vos favoris');
        return false;
      }

      final favorite = FavoritePlace(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        address: address,
        position: position,
        category: category,
        description: description,
        createdAt: DateTime.now(),
      );

      _favorites.add(favorite);
      _organizeFavoritesByCategory();
      await _saveFavorites();

      debugPrint('✅ Favori ajouté: $name');
      return true;
    } catch (e) {
      _setError('Erreur ajout favori: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Supprime un favori
  Future<bool> removeFavorite(String id) async {
    try {
      _setLoading(true);
      _clearError();

      _favorites.removeWhere((fav) => fav.id == id);
      _organizeFavoritesByCategory();
      await _saveFavorites();

      debugPrint('✅ Favori supprimé: $id');
      return true;
    } catch (e) {
      _setError('Erreur suppression favori: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Met à jour un favori
  Future<bool> updateFavorite(FavoritePlace updatedFavorite) async {
    try {
      _setLoading(true);
      _clearError();

      final index = _favorites.indexWhere(
        (fav) => fav.id == updatedFavorite.id,
      );
      if (index != -1) {
        _favorites[index] = updatedFavorite;
        _organizeFavoritesByCategory();
        await _saveFavorites();

        debugPrint('✅ Favori mis à jour: ${updatedFavorite.name}');
        return true;
      } else {
        _setError('Favori non trouvé');
        return false;
      }
    } catch (e) {
      _setError('Erreur mise à jour favori: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Recherche dans les favoris
  List<FavoritePlace> searchFavorites(String query) {
    if (query.trim().isEmpty) return _favorites;

    final lowercaseQuery = query.toLowerCase();
    return _favorites
        .where(
          (fav) =>
              fav.name.toLowerCase().contains(lowercaseQuery) ||
              fav.address.toLowerCase().contains(lowercaseQuery) ||
              fav.category.toLowerCase().contains(lowercaseQuery) ||
              (fav.description?.toLowerCase().contains(lowercaseQuery) ??
                  false),
        )
        .toList();
  }

  /// Obtient les favoris par catégorie
  List<FavoritePlace> getFavoritesByCategory(String category) {
    return _categorizedFavorites[category] ?? [];
  }

  /// Obtient les favoris les plus proches
  List<FavoritePlace> getNearbyFavorites({double radiusKm = 10.0}) {
    try {
      // Obtenir la position actuelle depuis le LocationService
      final currentPosition = _locationService.getLastKnownPosition();
      if (currentPosition == null) {
        debugPrint('⚠️ Position actuelle non disponible');
        return _favorites; // Retourner tous les favoris si pas de position
      }

      final currentLatLng = LatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      // Filtrer les favoris par distance
      final nearbyFavorites = _favorites.where((fav) {
        final distance = _calculateDistance(currentLatLng, fav.position);
        return distance <= radiusKm;
      }).toList();

      // Trier par distance (plus proche en premier)
      nearbyFavorites.sort((a, b) {
        final distanceA = _calculateDistance(currentLatLng, a.position);
        final distanceB = _calculateDistance(currentLatLng, b.position);
        return distanceA.compareTo(distanceB);
      });

      return nearbyFavorites;
    } catch (e) {
      debugPrint('⚠️ Erreur favoris proches: $e');
      return [];
    }
  }

  /// Importe des favoris depuis un fichier JSON
  Future<bool> importFavorites(String jsonData) async {
    try {
      _setLoading(true);
      _clearError();

      // Parse le JSON et importe les favoris
      final List<dynamic> jsonList = jsonDecode(jsonData);
      final List<FavoritePlace> importedFavorites = jsonList
          .map((json) => FavoritePlace.fromJson(json as Map<String, dynamic>))
          .toList();

      // Ajoute les nouveaux favoris (évite les doublons)
      for (final favorite in importedFavorites) {
        final exists = _favorites.any(
          (fav) =>
              fav.name.toLowerCase() == favorite.name.toLowerCase() &&
              fav.position.latitude.toStringAsFixed(6) ==
                  favorite.position.latitude.toStringAsFixed(6) &&
              fav.position.longitude.toStringAsFixed(6) ==
                  favorite.position.longitude.toStringAsFixed(6),
        );

        if (!exists) {
          _favorites.add(favorite);
        }
      }

      _organizeFavoritesByCategory();
      await _saveFavorites();

      debugPrint('✅ Favoris importés: ${importedFavorites.length} nouveaux');
      return true;
    } catch (e) {
      _setError('Erreur importation: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Exporte les favoris vers JSON
  String exportFavorites() {
    try {
      final favoritesJson = _favorites.map((fav) => fav.toJson()).toList();
      final jsonString = jsonEncode(favoritesJson);
      debugPrint('✅ Favoris exportés: ${_favorites.length} favoris');
      return jsonString;
    } catch (e) {
      _setError('Erreur exportation: $e');
      return '';
    }
  }

  /// Charge les favoris depuis le cache
  Future<void> loadFavorites() async {
    try {
      _setLoading(true);
      _clearError();

      final favoritesData = await _cacheService.getData('favorites');
      if (favoritesData != null && favoritesData is List) {
        _favorites = favoritesData
            .map((data) => FavoritePlace.fromJson(data))
            .toList();

        _organizeFavoritesByCategory();
        debugPrint('✅ ${_favorites.length} favoris chargés');
      }
    } catch (e) {
      _setError('Erreur chargement favoris: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Sauvegarde les favoris
  Future<void> _saveFavorites() async {
    try {
      final favoritesData = _favorites.map((fav) => fav.toJson()).toList();
      await _cacheService.saveData('favorites', favoritesData);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde favoris: $e');
    }
  }

  /// Organise les favoris par catégorie
  void _organizeFavoritesByCategory() {
    _categorizedFavorites.clear();

    for (final category in categories) {
      _categorizedFavorites[category] = [];
    }

    for (final favorite in _favorites) {
      final category = favorite.category;
      if (_categorizedFavorites.containsKey(category)) {
        _categorizedFavorites[category]!.add(favorite);
      } else {
        _categorizedFavorites['Autres']!.add(favorite);
      }
    }
  }

  /// Calcule la distance entre deux points
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Rayon de la Terre en km

    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    final a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  /// Obtient la distance d'un favori depuis la position actuelle
  double? getDistanceToFavorite(FavoritePlace favorite) {
    try {
      final currentPosition = _locationService.getLastKnownPosition();
      if (currentPosition == null) return null;

      final currentLatLng = LatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );
      return _calculateDistance(currentLatLng, favorite.position);
    } catch (e) {
      debugPrint('⚠️ Erreur calcul distance: $e');
      return null;
    }
  }

  // Méthodes utilitaires
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _lastError = error;
    notifyListeners();
    debugPrint('❌ FavoritesController Error: $error');
  }

  void _clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Initialise le contrôleur
  Future<void> initialize() async {
    await loadFavorites();
    debugPrint(
      '✅ FavoritesController initialisé avec ${_favorites.length} favoris',
    );
  }

  /// Nettoie les ressources
  @override
  Future<void> dispose() async {
    await _saveFavorites();
    super.dispose();
  }
}
