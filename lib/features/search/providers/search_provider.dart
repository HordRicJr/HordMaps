import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';

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

  factory SearchResult.fromNominatim(Map<String, dynamic> json) {
    return SearchResult(
      name: json['name'] ?? json['display_name'] ?? '',
      displayName: json['display_name'] ?? '',
      position: LatLng(double.parse(json['lat']), double.parse(json['lon'])),
      type: json['type'] ?? json['class'] ?? '',
      address: json['display_name'],
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

  /// Recherche des lieux via Nominatim (OpenStreetMap)
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
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 10,
          'addressdetails': 1,
          'extratags': 1,
          'namedetails': 1,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _searchResults = data
            .map((json) => SearchResult.fromNominatim(json))
            .toList();
      } else {
        _searchResults = [];
      }
    } catch (e) {
      print('Erreur de recherche: $e');
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
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'format': 'json',
          'limit': 20,
          'radius': 1000, // 1km
          'amenity': category,
          'addressdetails': 1,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _searchResults = data
            .map((json) => SearchResult.fromNominatim(json))
            .toList();
      } else {
        _searchResults = [];
      }
    } catch (e) {
      print('Erreur de recherche à proximité: $e');
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
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'format': 'json',
          'addressdetails': 1,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['display_name'];
      }
    } catch (e) {
      print('Erreur de géocodage inverse: $e');
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

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
