import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../../../core/config/environment_config.dart';

class SearchResult {
  final String name;
  final String displayName;
  final LatLng position;
  final String type;
  final String? address;

  SearchResult({
    required this.name,
    required this.displayName,
    required this.position,
    required this.type,
    this.address,
  });

  factory SearchResult.fromAzureMaps(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    final position = json['position'] as Map<String, dynamic>? ?? {};
    
    return SearchResult(
      name: address['freeformAddress'] ?? json['poi']?['name'] ?? '',
      displayName: address['freeformAddress'] ?? json['poi']?['name'] ?? '',
      position: LatLng(
        position['lat']?.toDouble() ?? 0.0,
        position['lon']?.toDouble() ?? 0.0,
      ),
      type: json['type'] ?? 'POI',
      address: address['freeformAddress'],
    );
  }
}

class SearchProvider extends ChangeNotifier {
  final Dio _dio = Dio();

  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  SearchResult? _selectedResult;
  List<String> _recentSearches = [];

  // Getters
  List<SearchResult> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;
  SearchResult? get selectedResult => _selectedResult;
  List<String> get recentSearches => _recentSearches;

  /// Recherche des lieux via Azure Maps Search API
  Future<void> searchPlaces(String query) async {
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    _searchQuery = query;
    _isSearching = true;
    notifyListeners();

    try {
      final response = await _dio.get(
        '${AzureMapsConfig.searchUrl}/address/json',
        queryParameters: {
          'api-version': AzureMapsConfig.apiVersion,
          'subscription-key': AzureMapsConfig.apiKey,
          'query': query,
          'limit': 10,
          'language': 'fr-FR',
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        final results = responseData['results'] as List<dynamic>? ?? [];
        _searchResults = results
            .map((json) => SearchResult.fromAzureMaps(json))
            .toList();
      } else {
        _searchResults = [];
      }
    } catch (e) {
      debugPrint('Erreur de recherche: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Recherche des lieux à proximité d'une position
  Future<void> searchNearby(LatLng position, String category) async {
    _isSearching = true;
    notifyListeners();

    try {
      final response = await _dio.get(
        '${AzureMapsConfig.searchUrl}/nearby/json',
        queryParameters: {
          'api-version': AzureMapsConfig.apiVersion,
          'subscription-key': AzureMapsConfig.apiKey,
          'lat': position.latitude,
          'lon': position.longitude,
          'radius': 1000,
          'limit': 20,
          'categorySet': _mapCategoryToAzure(category),
          'language': 'fr-FR',
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        final results = responseData['results'] as List<dynamic>? ?? [];
        _searchResults = results
            .map((json) => SearchResult.fromAzureMaps(json))
            .toList();
      } else {
        _searchResults = [];
      }
    } catch (e) {
      debugPrint('Erreur de recherche à proximité: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Géocodage inverse : obtenir l'adresse à partir des coordonnées
  Future<String?> reverseGeocode(LatLng position) async {
    try {
      final response = await _dio.get(
        '${AzureMapsConfig.searchUrl}/address/reverse/json',
        queryParameters: {
          'api-version': AzureMapsConfig.apiVersion,
          'subscription-key': AzureMapsConfig.apiKey,
          'query': '${position.latitude},${position.longitude}',
          'language': 'fr-FR',
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        final addresses = responseData['addresses'] as List<dynamic>? ?? [];
        if (addresses.isNotEmpty) {
          final address = addresses.first['address'] as Map<String, dynamic>? ?? {};
          return address['freeformAddress'] ?? '';
        }
      }
    } catch (e) {
      debugPrint('Erreur de géocodage inverse: $e');
    }
    return null;
  }

  /// Sélectionne un résultat de recherche
  void selectResult(SearchResult result) {
    _selectedResult = result;
    notifyListeners();
  }

  /// Efface la sélection
  void clearSelection() {
    _selectedResult = null;
    notifyListeners();
  }

  /// Efface la recherche
  void _clearSearch() {
    _searchResults = [];
    _searchQuery = '';
    _selectedResult = null;
    notifyListeners();
  }

  /// Efface tous les résultats
  void clearResults() {
    _clearSearch();
  }

  /// Supprime une recherche récente
  void removeRecentSearch(String search) {
    _recentSearches.remove(search);
    notifyListeners();
  }

  /// Ajoute une recherche récente
  void addRecentSearch(String search) {
    if (search.isEmpty) return;

    _recentSearches.remove(search); // Supprime s'il existe déjà
    _recentSearches.insert(0, search); // Ajoute en premier

    // Limite à 10 recherches récentes
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.take(10).toList();
    }

    notifyListeners();
  }

  /// Mappe les catégories de recherche vers les categorySet Azure Maps
  String _mapCategoryToAzure(String category) {
    switch (category.toLowerCase()) {
      case 'restaurant':
        return '7315';
      case 'hotel':
        return '7314';
      case 'hospital':
        return '7321';
      case 'school':
        return '7372';
      case 'bank':
        return '7328';
      case 'gas_station':
        return '7311';
      case 'pharmacy':
        return '7326';
      case 'supermarket':
        return '7332';
      case 'cafe':
        return '7315025';
      case 'atm':
        return '7397';
      default:
        return '7315'; // Restaurant par défaut
    }
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
