import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

class Favorite {
  final String id;
  final String name;
  final String? description;
  final LatLng position;
  final String type;
  final DateTime createdAt;
  final String? category;
  final List<String> tags;

  Favorite({
    required this.id,
    required this.name,
    this.description,
    required this.position,
    required this.type,
    required this.createdAt,
    this.category,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'category': category,
      'tags': tags.join(','),
    };
  }

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      position: LatLng(json['latitude'], json['longitude']),
      type: json['type'],
      createdAt: DateTime.parse(json['createdAt']),
      category: json['category'],
      tags: json['tags']?.split(',') ?? [],
    );
  }
}

class SearchHistory {
  final String id;
  final String query;
  final LatLng? position;
  final DateTime timestamp;
  final int frequency;

  SearchHistory({
    required this.id,
    required this.query,
    this.position,
    required this.timestamp,
    this.frequency = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query': query,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'timestamp': timestamp.toIso8601String(),
      'frequency': frequency,
    };
  }

  factory SearchHistory.fromJson(Map<String, dynamic> json) {
    return SearchHistory(
      id: json['id'],
      query: json['query'],
      position: json['latitude'] != null && json['longitude'] != null
          ? LatLng(json['latitude'], json['longitude'])
          : null,
      timestamp: DateTime.parse(json['timestamp']),
      frequency: json['frequency'] ?? 1,
    );
  }
}

class RouteHistory {
  final String id;
  final LatLng start;
  final LatLng end;
  final String startName;
  final String endName;
  final String transportMode;
  final DateTime timestamp;
  final double distance;
  final double duration;

  RouteHistory({
    required this.id,
    required this.start,
    required this.end,
    required this.startName,
    required this.endName,
    required this.transportMode,
    required this.timestamp,
    required this.distance,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startLatitude': start.latitude,
      'startLongitude': start.longitude,
      'endLatitude': end.latitude,
      'endLongitude': end.longitude,
      'startName': startName,
      'endName': endName,
      'transportMode': transportMode,
      'timestamp': timestamp.toIso8601String(),
      'distance': distance,
      'duration': duration,
    };
  }

  factory RouteHistory.fromJson(Map<String, dynamic> json) {
    return RouteHistory(
      id: json['id'],
      start: LatLng(json['startLatitude'], json['startLongitude']),
      end: LatLng(json['endLatitude'], json['endLongitude']),
      startName: json['startName'],
      endName: json['endName'],
      transportMode: json['transportMode'],
      timestamp: DateTime.parse(json['timestamp']),
      distance: json['distance'],
      duration: json['duration'],
    );
  }
}

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // === FAVORIS ===

  static Future<void> addFavorite(Favorite favorite) async {
    final favorites = await getFavorites();
    favorites.add(favorite);
    final favoritesJson = favorites.map((f) => f.toJson()).toList();
    await _prefs!.setString('favorites', jsonEncode(favoritesJson));
  }

  static Future<List<Favorite>> getFavorites() async {
    final favoritesString = _prefs!.getString('favorites');
    if (favoritesString == null) return [];

    final List<dynamic> favoritesJson = jsonDecode(favoritesString);
    return favoritesJson.map((json) => Favorite.fromJson(json)).toList();
  }

  static Future<void> removeFavorite(String id) async {
    final favorites = await getFavorites();
    favorites.removeWhere((f) => f.id == id);
    final favoritesJson = favorites.map((f) => f.toJson()).toList();
    await _prefs!.setString('favorites', jsonEncode(favoritesJson));
  }

  static Future<void> updateFavorite(Favorite favorite) async {
    final favorites = await getFavorites();
    final index = favorites.indexWhere((f) => f.id == favorite.id);
    if (index != -1) {
      favorites[index] = favorite;
      final favoritesJson = favorites.map((f) => f.toJson()).toList();
      await _prefs!.setString('favorites', jsonEncode(favoritesJson));
    }
  }

  static Future<List<Favorite>> getFavoritesByCategory(String category) async {
    final favorites = await getFavorites();
    return favorites.where((f) => f.category == category).toList();
  }

  // === HISTORIQUE DE RECHERCHE ===

  static Future<void> addSearchHistory(SearchHistory search) async {
    final history = await getSearchHistory();

    // Vérifier si la recherche existe déjà
    final existingIndex = history.indexWhere((h) => h.query == search.query);

    if (existingIndex != -1) {
      // Mettre à jour la fréquence
      history[existingIndex] = SearchHistory(
        id: history[existingIndex].id,
        query: search.query,
        position: search.position,
        timestamp: DateTime.now(),
        frequency: history[existingIndex].frequency + 1,
      );
    } else {
      history.add(search);
    }

    // Garder seulement les 20 dernières
    if (history.length > 20) {
      history.removeRange(0, history.length - 20);
    }

    final historyJson = history.map((h) => h.toJson()).toList();
    await _prefs!.setString('search_history', jsonEncode(historyJson));
  }

  static Future<List<SearchHistory>> getSearchHistory() async {
    final historyString = _prefs!.getString('search_history');
    if (historyString == null) return [];

    final List<dynamic> historyJson = jsonDecode(historyString);
    return historyJson.map((json) => SearchHistory.fromJson(json)).toList();
  }

  static Future<void> clearSearchHistory() async {
    await _prefs!.remove('search_history');
  }

  static Future<List<String>> getSearchSuggestions(String query) async {
    final history = await getSearchHistory();
    return history
        .where((h) => h.query.toLowerCase().contains(query.toLowerCase()))
        .map((h) => h.query)
        .take(5)
        .toList();
  }

  // === HISTORIQUE DES ROUTES ===

  static Future<void> addRouteHistory(RouteHistory route) async {
    final routes = await getRouteHistory();
    routes.add(route);

    // Garder seulement les 20 dernières
    if (routes.length > 20) {
      routes.removeRange(0, routes.length - 20);
    }

    final routesJson = routes.map((r) => r.toJson()).toList();
    await _prefs!.setString('route_history', jsonEncode(routesJson));
  }

  static Future<List<RouteHistory>> getRouteHistory() async {
    final routesString = _prefs!.getString('route_history');
    if (routesString == null) return [];

    final List<dynamic> routesJson = jsonDecode(routesString);
    return routesJson.map((json) => RouteHistory.fromJson(json)).toList();
  }

  // === PRÉFÉRENCES ===

  static Future<void> setThemeMode(String mode) async {
    await _prefs!.setString('theme_mode', mode);
  }

  static String getThemeMode() {
    return _prefs!.getString('theme_mode') ?? 'system';
  }

  static Future<void> setMapStyle(String style) async {
    await _prefs!.setString('map_style', style);
  }

  static String getMapStyle() {
    return _prefs!.getString('map_style') ?? 'standard';
  }

  static Future<void> setLastMapPosition(LatLng position, double zoom) async {
    await _prefs!.setDouble('last_lat', position.latitude);
    await _prefs!.setDouble('last_lng', position.longitude);
    await _prefs!.setDouble('last_zoom', zoom);
  }

  static LatLng? getLastMapPosition() {
    final lat = _prefs!.getDouble('last_lat');
    final lng = _prefs!.getDouble('last_lng');
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }

  static double getLastMapZoom() {
    return _prefs!.getDouble('last_zoom') ?? 13.0;
  }

  static Future<void> setDefaultTransportMode(String mode) async {
    await _prefs!.setString('default_transport_mode', mode);
  }

  static String getDefaultTransportMode() {
    return _prefs!.getString('default_transport_mode') ?? 'driving-car';
  }

  // === MÉTHODES GÉNÉRIQUES POUR CONFIGURATIONS ===

  /// Sauvegarde un Map en JSON
  Future<void> setMap(String key, Map<String, dynamic> value) async {
    await _prefs!.setString(key, jsonEncode(value));
  }

  /// Récupère un Map depuis JSON
  Future<Map<String, dynamic>?> getMap(String key) async {
    final jsonString = _prefs!.getString(key);
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      // Erreur de décodage JSON ignorée silencieusement
      return null;
    }
  }

  /// Sauvegarde une valeur string
  Future<void> setString(String key, String value) async {
    await _prefs!.setString(key, value);
  }

  /// Récupère une valeur string
  Future<String?> getString(String key) async {
    return _prefs!.getString(key);
  }

  /// Sauvegarde une valeur bool
  Future<void> setBool(String key, bool value) async {
    await _prefs!.setBool(key, value);
  }

  /// Récupère une valeur bool
  Future<bool?> getBool(String key) async {
    return _prefs!.getBool(key);
  }

  /// Sauvegarde une valeur double
  Future<void> setDouble(String key, double value) async {
    await _prefs!.setDouble(key, value);
  }

  /// Récupère une valeur double
  Future<double?> getDouble(String key) async {
    return _prefs!.getDouble(key);
  }

  /// Sauvegarde une liste de chaînes
  Future<void> setStringList(String key, List<String> value) async {
    await _prefs!.setStringList(key, value);
  }

  /// Récupère une liste de chaînes
  Future<List<String>?> getStringList(String key) async {
    return _prefs!.getStringList(key);
  }

  /// Sauvegarde une valeur int
  Future<void> setInt(String key, int value) async {
    await _prefs!.setInt(key, value);
  }

  /// Récupère une valeur int
  Future<int?> getInt(String key) async {
    return _prefs!.getInt(key);
  }

  // === GESTION DES DONNÉES DYNAMIQUES ===

  /// Cache des données de géolocalisation
  Future<void> cacheLocationData(String key, Map<String, dynamic> data) async {
    await setString('location_$key', jsonEncode(data));
  }

  /// Récupère les données de géolocalisation en cache
  Future<Map<String, dynamic>?> getCachedLocationData(String key) async {
    final data = await getString('location_$key');
    return data != null ? jsonDecode(data) : null;
  }

  /// Cache des données de routes
  Future<void> cacheRouteData(
    String routeKey,
    Map<String, dynamic> routeData,
  ) async {
    await setString('route_$routeKey', jsonEncode(routeData));
    // Maintenir une liste des routes récentes
    final recentRoutes = await getStringList('recent_routes') ?? [];
    if (!recentRoutes.contains(routeKey)) {
      recentRoutes.insert(0, routeKey);
      if (recentRoutes.length > 50) {
        // Limite à 50 routes récentes
        recentRoutes.removeLast();
      }
      await setStringList('recent_routes', recentRoutes);
    }
  }

  /// Récupère les données de route en cache
  Future<Map<String, dynamic>?> getCachedRouteData(String routeKey) async {
    final data = await getString('route_$routeKey');
    return data != null ? jsonDecode(data) : null;
  }

  /// Cache des données de POI
  Future<void> cachePOIData(String poiId, Map<String, dynamic> poiData) async {
    await setString('poi_$poiId', jsonEncode(poiData));
    // Maintenir une liste des POI récents
    final recentPOIs = await getStringList('recent_pois') ?? [];
    if (!recentPOIs.contains(poiId)) {
      recentPOIs.insert(0, poiId);
      if (recentPOIs.length > 100) {
        // Limite à 100 POI récents
        recentPOIs.removeLast();
      }
      await setStringList('recent_pois', recentPOIs);
    }
  }

  /// Récupère les données de POI en cache
  Future<Map<String, dynamic>?> getCachedPOIData(String poiId) async {
    final data = await getString('poi_$poiId');
    return data != null ? jsonDecode(data) : null;
  }

  /// Cache des données de recherche
  Future<void> cacheSearchResults(
    String query,
    List<Map<String, dynamic>> results,
  ) async {
    await setString('search_${query.hashCode}', jsonEncode(results));
    await setInt(
      'search_timestamp_${query.hashCode}',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Récupère les résultats de recherche en cache
  Future<List<Map<String, dynamic>>?> getCachedSearchResults(
    String query, {
    Duration? maxAge,
  }) async {
    final key = query.hashCode;
    final timestamp = await getInt('search_timestamp_$key');

    if (timestamp != null && maxAge != null) {
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > maxAge) {
        return null; // Cache expiré
      }
    }

    final data = await getString('search_$key');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// Nettoie le cache expiré
  Future<void> cleanExpiredCache() async {
    final keys = _prefs!.getKeys();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (String key in keys) {
      if (key.startsWith('search_timestamp_')) {
        final timestamp = _prefs!.getInt(key);
        if (timestamp != null &&
            (now - timestamp) > Duration(days: 7).inMilliseconds) {
          await _prefs!.remove(key);
          final searchKey = key.replaceFirst('search_timestamp_', 'search_');
          await _prefs!.remove(searchKey);
        }
      }
    }
  }

  /// Obtient la taille approximative du cache
  Future<int> getCacheSize() async {
    int size = 0;
    final keys = _prefs!.getKeys();

    for (String key in keys) {
      final value = _prefs!.get(key);
      if (value is String) {
        size += value.length * 2; // UTF-16
      } else if (value is List<String>) {
        size += value.join().length * 2;
      } else {
        size += 8; // Approximation pour int, double, bool
      }
    }

    return size;
  }

  // === NETTOYAGE ===

  static Future<void> clearAllData() async {
    await _prefs!.clear();
  }

  static Future<void> dispose() async {
    // Rien à faire pour SharedPreferences
  }
}
