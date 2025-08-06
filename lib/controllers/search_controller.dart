import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../services/places_service.dart';
import '../services/location_service.dart';
import '../services/cache_service.dart';

/// Contrôleur MVC pour la recherche de lieux et POI
class SearchController extends ChangeNotifier {
  static SearchController? _instance;
  static SearchController get instance => _instance ??= SearchController._();
  SearchController._();

  // Services
  final LocationService _locationService = LocationService.instance;
  final CacheService _cacheService = CacheService.instance;

  // État privé
  List<dynamic> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  String? _lastError;
  String _currentQuery = '';

  // Getters
  List<dynamic> get searchResults => _searchResults;
  List<String> get searchHistory => _searchHistory;
  bool get isSearching => _isSearching;
  String? get lastError => _lastError;
  String get currentQuery => _currentQuery;

  /// Recherche de lieux par texte
  Future<void> searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      _setLoading(true);
      _clearError();
      _currentQuery = query;

      // Vérifier le cache d'abord
      final cacheKey = 'search_$query';
      final cachedResults = await _cacheService.getData(cacheKey);

      if (cachedResults != null && cachedResults is List) {
        _searchResults = cachedResults;
        notifyListeners();
        return;
      }

      // Obtenir la position actuelle pour les recherches à proximité
      final currentPosition = await _locationService.getCurrentPosition();

      List<dynamic> results = [];

      if (currentPosition != null) {
        // Recherche de lieux à proximité
        final nearbyPlaces = await PlacesService.getNearbyPlaces(
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
          radiusKm: 5.0,
        );
        results.addAll(nearbyPlaces);
      }

      // Recherche générale par nom
      final generalResults = await PlacesService.searchPlaces(query);
      results.addAll(generalResults);

      // Supprimer les doublons
      _searchResults = _removeDuplicates(results);

      // Sauvegarder en cache
      await _cacheService.saveData(cacheKey, _searchResults);

      // Ajouter à l'historique
      await _addToHistory(query);

      debugPrint('✅ Recherche "$query": ${_searchResults.length} résultats');
    } catch (e) {
      _setError('Erreur de recherche: $e');
      debugPrint('❌ Erreur recherche: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Recherche de lieux par coordonnées
  Future<void> searchByCoordinates(double lat, double lng) async {
    try {
      _setLoading(true);
      _clearError();

      final results = await PlacesService.getNearbyPlaces(
        latitude: lat,
        longitude: lng,
      );
      _searchResults = results;

      debugPrint(
        '✅ Recherche par coordonnées: ${_searchResults.length} résultats',
      );
    } catch (e) {
      _setError('Erreur de géocodage: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Recherche de POI par catégorie
  Future<void> searchPOIByCategory(String category, {LatLng? center}) async {
    try {
      _setLoading(true);
      _clearError();

      LatLng? searchCenter = center;
      if (searchCenter == null) {
        final position = await _locationService.getCurrentPosition();
        if (position != null) {
          searchCenter = LatLng(position.latitude, position.longitude);
        }
      }

      if (searchCenter == null) {
        throw Exception('Position non disponible pour la recherche');
      }

      final results = await PlacesService.getNearbyPlaces(
        latitude: searchCenter.latitude,
        longitude: searchCenter.longitude,
        radiusKm: 3.0,
      );

      _searchResults = results;
      debugPrint('✅ POI "$category": ${_searchResults.length} résultats');
    } catch (e) {
      _setError('Erreur recherche POI: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Efface les résultats de recherche
  void clearResults() {
    _searchResults = [];
    _currentQuery = '';
    _clearError();
    notifyListeners();
  }

  /// Charge l'historique des recherches
  Future<void> loadSearchHistory() async {
    try {
      final history = await _cacheService.getData('search_history');
      if (history != null && history is List) {
        _searchHistory = List<String>.from(history);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement historique: $e');
    }
  }

  /// Efface l'historique des recherches
  Future<void> clearHistory() async {
    try {
      _searchHistory = [];
      await _cacheService.saveData('search_history', _searchHistory);
      notifyListeners();
      debugPrint('✅ Historique effacé');
    } catch (e) {
      debugPrint('⚠️ Erreur effacement historique: $e');
    }
  }

  /// Supprime un élément de l'historique
  Future<void> removeFromHistory(String query) async {
    try {
      _searchHistory.remove(query);
      await _cacheService.saveData('search_history', _searchHistory);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Erreur suppression historique: $e');
    }
  }

  /// Recherche rapide dans les favoris
  Future<void> searchInFavorites(String query) async {
    try {
      final favorites = await _cacheService.getData('favorites');
      if (favorites != null && favorites is List) {
        _searchResults = favorites
            .where(
              (fav) => fav['name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _setError('Erreur recherche favoris: $e');
    }
  }

  // Méthodes privées
  List<dynamic> _removeDuplicates(List<dynamic> results) {
    final Map<String, dynamic> uniqueResults = {};

    for (final result in results) {
      final key =
          result['name']?.toString() ??
          result['display_name']?.toString() ??
          '';
      if (key.isNotEmpty && !uniqueResults.containsKey(key)) {
        uniqueResults[key] = result;
      }
    }

    return uniqueResults.values.toList();
  }

  Future<void> _addToHistory(String query) async {
    try {
      if (!_searchHistory.contains(query)) {
        _searchHistory.insert(0, query);

        // Limiter l'historique à 50 éléments
        if (_searchHistory.length > 50) {
          _searchHistory = _searchHistory.take(50).toList();
        }

        await _cacheService.saveData('search_history', _searchHistory);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur ajout historique: $e');
    }
  }

  void _setLoading(bool loading) {
    if (_isSearching != loading) {
      _isSearching = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _lastError = error;
    notifyListeners();
    debugPrint('❌ SearchController Error: $error');
  }

  void _clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Initialise le contrôleur
  Future<void> initialize() async {
    await loadSearchHistory();
    debugPrint('✅ SearchController initialisé');
  }

  /// Sauvegarde l'état
  Future<void> saveState() async {
    try {
      final state = {
        'last_query': _currentQuery,
        'search_history': _searchHistory,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _cacheService.saveData('search_state', state);
    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde état recherche: $e');
    }
  }

  /// Restaure l'état
  Future<void> restoreState() async {
    try {
      final state = await _cacheService.getData('search_state');
      if (state != null) {
        _currentQuery = state['last_query'] ?? '';
        if (state['search_history'] != null) {
          _searchHistory = List<String>.from(state['search_history']);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur restauration état recherche: $e');
    }
  }
}
