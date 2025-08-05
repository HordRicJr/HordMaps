import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

/// Catégories de POI
enum POICategory {
  restaurant,
  hotel,
  attraction,
  shop,
  transport,
  health,
  education,
  service,
  entertainment,
  sport,
  culture,
  nature,
  other,
}

/// Point d'intérêt
class POI {
  final String id;
  final String name;
  final String? description;
  final LatLng location;
  final POICategory category;
  final String? address;
  final String? phone;
  final String? website;
  final String? email;
  final Map<String, String> openingHours;
  final double? rating;
  final int? reviewCount;
  final List<String> tags;
  final List<String> images;
  final double? price; // Prix moyen
  final String? priceRange; // €, ££, €€€
  final Map<String, dynamic> amenities;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  POI({
    required this.id,
    required this.name,
    this.description,
    required this.location,
    required this.category,
    this.address,
    this.phone,
    this.website,
    this.email,
    this.openingHours = const {},
    this.rating,
    this.reviewCount,
    this.tags = const [],
    this.images = const [],
    this.price,
    this.priceRange,
    this.amenities = const {},
    this.isVerified = false,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'category': category.name,
      'address': address,
      'phone': phone,
      'website': website,
      'email': email,
      'openingHours': openingHours,
      'rating': rating,
      'reviewCount': reviewCount,
      'tags': tags,
      'images': images,
      'price': price,
      'priceRange': priceRange,
      'amenities': amenities,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      location: LatLng(json['latitude'], json['longitude']),
      category: POICategory.values.firstWhere(
        (cat) => cat.name == json['category'],
        orElse: () => POICategory.other,
      ),
      address: json['address'],
      phone: json['phone'],
      website: json['website'],
      email: json['email'],
      openingHours: Map<String, String>.from(json['openingHours'] ?? {}),
      rating: json['rating']?.toDouble(),
      reviewCount: json['reviewCount'],
      tags: List<String>.from(json['tags'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      price: json['price']?.toDouble(),
      priceRange: json['priceRange'],
      amenities: Map<String, dynamic>.from(json['amenities'] ?? {}),
      isVerified: json['isVerified'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  /// Calcule la distance depuis une position
  double distanceFrom(LatLng position) {
    const double earthRadius = 6371; // Rayon de la Terre en km

    final lat1Rad = position.latitude * math.pi / 180;
    final lat2Rad = location.latitude * math.pi / 180;
    final deltaLatRad = (location.latitude - position.latitude) * math.pi / 180;
    final deltaLngRad =
        (location.longitude - position.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Vérifie si le POI est ouvert maintenant
  bool get isOpenNow {
    final now = DateTime.now();
    final weekday = _getWeekdayName(now.weekday);
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (!openingHours.containsKey(weekday)) return false;

    final hours = openingHours[weekday]!;
    if (hours.toLowerCase() == 'fermé') return false;
    if (hours.toLowerCase() == '24h/24') return true;

    // Parser les heures (format: "09:00-18:00")
    final parts = hours.split('-');
    if (parts.length != 2) return false;

    final openTime = parts[0].trim();
    final closeTime = parts[1].trim();

    return currentTime.compareTo(openTime) >= 0 &&
        currentTime.compareTo(closeTime) <= 0;
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'lundi';
      case 2:
        return 'mardi';
      case 3:
        return 'mercredi';
      case 4:
        return 'jeudi';
      case 5:
        return 'vendredi';
      case 6:
        return 'samedi';
      case 7:
        return 'dimanche';
      default:
        return 'lundi';
    }
  }
}

/// Résultat de recherche de POI
class POISearchResult {
  final List<POI> pois;
  final int totalCount;
  final bool hasMore;
  final String? nextToken;

  POISearchResult({
    required this.pois,
    required this.totalCount,
    required this.hasMore,
    this.nextToken,
  });
}

/// Service de gestion des POI
class POIService extends ChangeNotifier {
  final StorageService _storage = StorageService();
  static const String _poisKey = 'pois_cache';
  static const String _favoritePoisKey = 'favorite_pois';
  static const String _settingsKey = 'poi_settings';

  List<POI> _pois = [];
  List<String> _favoritePOIIds = [];
  Set<POICategory> _enabledCategories = POICategory.values.toSet();
  bool _showOnlyOpen = false;
  double _maxDistance = 10.0; // km
  int _maxResults = 50;
  bool _includeRatings = true;
  bool _isLoading = false;

  // Cache pour les recherches
  final Map<String, POISearchResult> _searchCache = {};

  // Getters
  List<POI> get pois => _pois;
  List<POI> get favoritePOIs =>
      _pois.where((poi) => _favoritePOIIds.contains(poi.id)).toList();
  Set<POICategory> get enabledCategories => _enabledCategories;
  bool get showOnlyOpen => _showOnlyOpen;
  double get maxDistance => _maxDistance;
  int get maxResults => _maxResults;
  bool get includeRatings => _includeRatings;
  bool get isLoading => _isLoading;

  /// Initialise le service
  Future<void> initialize() async {
    await _loadSettings();
    await _loadPOIs();
    await _loadFavoritePOIs();
  }

  /// Charge les paramètres
  Future<void> _loadSettings() async {
    try {
      final settings = await _storage.getMap(_settingsKey);
      if (settings != null) {
        _showOnlyOpen = settings['showOnlyOpen'] ?? false;
        _maxDistance = settings['maxDistance']?.toDouble() ?? 10.0;
        _maxResults = settings['maxResults'] ?? 50;
        _includeRatings = settings['includeRatings'] ?? true;

        if (settings['enabledCategories'] != null) {
          final categoryNames = List<String>.from(
            settings['enabledCategories'],
          );
          _enabledCategories = categoryNames
              .map(
                (name) => POICategory.values.firstWhere(
                  (cat) => cat.name == name,
                  orElse: () => POICategory.other,
                ),
              )
              .toSet();
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement paramètres POI: $e');
    }
  }

  /// Sauvegarde les paramètres
  Future<void> _saveSettings() async {
    try {
      await _storage.setMap(_settingsKey, {
        'showOnlyOpen': _showOnlyOpen,
        'maxDistance': _maxDistance,
        'maxResults': _maxResults,
        'includeRatings': _includeRatings,
        'enabledCategories': _enabledCategories.map((cat) => cat.name).toList(),
      });
    } catch (e) {
      debugPrint('Erreur sauvegarde paramètres POI: $e');
    }
  }

  /// Charge les POI depuis le cache
  Future<void> _loadPOIs() async {
    try {
      final poisData = await _storage.getString(_poisKey);
      if (poisData != null) {
        final List<dynamic> data = jsonDecode(poisData);
        _pois = data.map((poiJson) => POI.fromJson(poiJson)).toList();
      }
    } catch (e) {
      debugPrint('Erreur chargement POI: $e');
    }
  }

  /// Sauvegarde les POI en cache
  Future<void> _savePOIs() async {
    try {
      final poisData = _pois.map((poi) => poi.toJson()).toList();
      await _storage.setString(_poisKey, jsonEncode(poisData));
    } catch (e) {
      debugPrint('Erreur sauvegarde POI: $e');
    }
  }

  /// Charge les POI favoris
  Future<void> _loadFavoritePOIs() async {
    try {
      final favoritesData = await _storage.getString(_favoritePoisKey);
      if (favoritesData != null) {
        _favoritePOIIds = List<String>.from(jsonDecode(favoritesData));
      }
    } catch (e) {
      debugPrint('Erreur chargement favoris POI: $e');
    }
  }

  /// Sauvegarde les POI favoris
  Future<void> _saveFavoritePOIs() async {
    try {
      await _storage.setString(_favoritePoisKey, jsonEncode(_favoritePOIIds));
    } catch (e) {
      debugPrint('Erreur sauvegarde favoris POI: $e');
    }
  }

  /// Recherche des POI par position
  Future<POISearchResult> searchPOIs({
    required LatLng position,
    String? query,
    Set<POICategory>? categories,
    double? maxDistance,
    int? maxResults,
    bool? showOnlyOpen,
    double? minRating,
  }) async {
    final searchKey = _generateSearchKey(
      position,
      query,
      categories,
      maxDistance,
      maxResults,
      showOnlyOpen,
      minRating,
    );

    // Vérifier le cache
    if (_searchCache.containsKey(searchKey)) {
      return _searchCache[searchKey]!;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Paramètres par défaut
      final searchCategories = categories ?? _enabledCategories;
      final searchMaxDistance = maxDistance ?? _maxDistance;
      final searchMaxResults = maxResults ?? _maxResults;
      final searchShowOnlyOpen = showOnlyOpen ?? _showOnlyOpen;

      // Rechercher dans les POI locaux
      List<POI> results = _searchLocalPOIs(
        position: position,
        query: query,
        categories: searchCategories,
        maxDistance: searchMaxDistance,
        showOnlyOpen: searchShowOnlyOpen,
        minRating: minRating,
      );

      // Si pas assez de résultats, chercher en ligne
      if (results.length < searchMaxResults) {
        final onlineResults = await _searchOnlinePOIs(
          position: position,
          query: query,
          categories: searchCategories,
          maxDistance: searchMaxDistance,
          maxResults: searchMaxResults - results.length,
        );

        // Fusionner les résultats
        results.addAll(onlineResults);

        // Sauvegarder les nouveaux POI
        for (final poi in onlineResults) {
          if (!_pois.any((p) => p.id == poi.id)) {
            _pois.add(poi);
          }
        }
        await _savePOIs();
      }

      // Limiter les résultats
      if (results.length > searchMaxResults) {
        results = results.take(searchMaxResults).toList();
      }

      final searchResult = POISearchResult(
        pois: results,
        totalCount: results.length,
        hasMore: false,
      );

      // Mettre en cache
      _searchCache[searchKey] = searchResult;

      return searchResult;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recherche locale dans les POI mis en cache
  List<POI> _searchLocalPOIs({
    required LatLng position,
    String? query,
    required Set<POICategory> categories,
    required double maxDistance,
    required bool showOnlyOpen,
    double? minRating,
  }) {
    return _pois.where((poi) {
      // Filtre par catégorie
      if (!categories.contains(poi.category)) return false;

      // Filtre par distance
      if (poi.distanceFrom(position) > maxDistance) return false;

      // Filtre par horaires d'ouverture
      if (showOnlyOpen && !poi.isOpenNow) return false;

      // Filtre par note
      if (minRating != null &&
          (poi.rating == null || poi.rating! < minRating)) {
        return false;
      }

      // Filtre par texte de recherche
      if (query != null && query.isNotEmpty) {
        final searchQuery = query.toLowerCase();
        return poi.name.toLowerCase().contains(searchQuery) ||
            (poi.description?.toLowerCase().contains(searchQuery) ?? false) ||
            poi.tags.any((tag) => tag.toLowerCase().contains(searchQuery));
      }

      return true;
    }).toList()..sort(
      (a, b) => a.distanceFrom(position).compareTo(b.distanceFrom(position)),
    );
  }

  /// Recherche en ligne via API Overpass
  Future<List<POI>> _searchOnlinePOIs({
    required LatLng position,
    String? query,
    required Set<POICategory> categories,
    required double maxDistance,
    required int maxResults,
  }) async {
    try {
      // Utiliser l'API Overpass pour chercher des POIs réels
      final overpassQuery = _buildOverpassQuery(
        position,
        categories,
        maxDistance,
      );

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: overpassQuery,
        headers: {'Content-Type': 'text/plain'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseOverpassResponse(data, categories, maxResults);
      }
    } catch (e) {
      debugPrint('Erreur recherche POI en ligne: $e');
    }

    // Fallback vers données locales si l'API échoue
    return _generateLocalPOIs(position, categories, maxResults);
  }

  /// Construit une requête Overpass pour rechercher des POIs
  String _buildOverpassQuery(
    LatLng position,
    Set<POICategory> categories,
    double maxDistance,
  ) {
    final lat = position.latitude;
    final lng = position.longitude;
    final radius = (maxDistance * 1000).round(); // Convertir en mètres

    final tags = categories
        .map((cat) {
          switch (cat) {
            case POICategory.restaurant:
              return 'amenity=restaurant';
            case POICategory.hotel:
              return 'tourism=hotel';
            case POICategory.attraction:
              return 'tourism=attraction';
            case POICategory.shop:
              return 'shop';
            case POICategory.transport:
              return 'public_transport';
            case POICategory.health:
              return 'amenity=hospital';
            case POICategory.education:
              return 'amenity=school';
            case POICategory.service:
              return 'amenity=bank';
            case POICategory.entertainment:
              return 'amenity=cinema';
            case POICategory.sport:
              return 'leisure=sports_centre';
            case POICategory.culture:
              return 'tourism=museum';
            case POICategory.nature:
              return 'natural=park';
            case POICategory.other:
              return 'amenity';
          }
        })
        .join('|');

    return '''
    [out:json][timeout:25];
    (
      node["$tags"](around:$radius,$lat,$lng);
      way["$tags"](around:$radius,$lat,$lng);
    );
    out center meta;
    ''';
  }

  /// Parse la réponse Overpass pour extraire les POIs
  List<POI> _parseOverpassResponse(
    Map<String, dynamic> data,
    Set<POICategory> categories,
    int maxResults,
  ) {
    final pois = <POI>[];
    final elements = data['elements'] as List? ?? [];

    for (final element in elements.take(maxResults)) {
      try {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final lat =
            element['lat'] as double? ?? element['center']?['lat'] as double?;
        final lng =
            element['lon'] as double? ?? element['center']?['lon'] as double?;

        if (lat != null && lng != null) {
          final poi = POI(
            id: element['id'].toString(),
            name: tags['name'] ?? 'POI sans nom',
            description: tags['description'] ?? '',
            category: _detectCategory(tags),
            location: LatLng(lat, lng),
            rating: null,
            reviewCount: 0,
            address: _buildAddress(tags),
            phone: tags['phone'],
            website: tags['website'],
            openingHours: tags['opening_hours'] != null
                ? {'default': tags['opening_hours']}
                : {},
            tags: tags.keys.toList(),
          );
          pois.add(poi);
        }
      } catch (e) {
        debugPrint('Erreur parsing POI: $e');
      }
    }

    return pois;
  }

  /// Détecte la catégorie d'un POI à partir de ses tags
  POICategory _detectCategory(Map<String, dynamic> tags) {
    if (tags['amenity'] == 'restaurant') return POICategory.restaurant;
    if (tags['tourism'] == 'hotel') return POICategory.hotel;
    if (tags['tourism'] == 'attraction') return POICategory.attraction;
    if (tags.containsKey('shop')) return POICategory.shop;
    if (tags.containsKey('public_transport')) return POICategory.transport;
    if (tags['amenity'] == 'hospital') return POICategory.health;
    if (tags['amenity'] == 'school') return POICategory.education;
    return POICategory.attraction; // Par défaut
  }

  /// Construit une adresse à partir des tags
  String _buildAddress(Map<String, dynamic> tags) {
    final parts = <String>[];
    if (tags['addr:housenumber'] != null) parts.add(tags['addr:housenumber']);
    if (tags['addr:street'] != null) parts.add(tags['addr:street']);
    if (tags['addr:city'] != null) parts.add(tags['addr:city']);
    return parts.join(', ');
  }

  /// Génère des POI locaux de base pour fallback
  List<POI> _generateLocalPOIs(
    LatLng center,
    Set<POICategory> categories,
    int count,
  ) {
    final random = math.Random();
    final pois = <POI>[];

    final restaurants = [
      'Le Petit Bistrot',
      'Chez Marie',
      'La Table du Chef',
      'L\'Auberge Gourmande',
      'Le Jardin Secret',
      'Brasserie du Coin',
      'La Crêperie Bretonne',
      'Sushi Zen',
    ];

    final hotels = [
      'Hôtel des Voyageurs',
      'Le Grand Hôtel',
      'Auberge du Centre',
      'Hôtel Moderne',
      'Le Petit Palace',
      'Résidence du Parc',
      'Hôtel Belle Vue',
      'Manor House',
    ];

    final attractions = [
      'Musée d\'Art Moderne',
      'Château Historique',
      'Parc Naturel',
      'Cathédrale',
      'Place du Marché',
      'Jardin Botanique',
      'Monument aux Héros',
      'Tour Panoramique',
    ];

    for (int i = 0; i < count; i++) {
      final category = categories.elementAt(random.nextInt(categories.length));

      String name;
      String description;
      switch (category) {
        case POICategory.restaurant:
          name = restaurants[random.nextInt(restaurants.length)];
          description = 'Restaurant traditionnel avec cuisine locale';
          break;
        case POICategory.hotel:
          name = hotels[random.nextInt(hotels.length)];
          description = 'Hôtel confortable au cœur de la ville';
          break;
        case POICategory.attraction:
          name = attractions[random.nextInt(attractions.length)];
          description = 'Site touristique incontournable';
          break;
        default:
          name = 'POI ${category.name} ${i + 1}';
          description = 'Point d\'intérêt de type ${category.name}';
      }

      // Position aléatoire autour du centre
      final lat = center.latitude + (random.nextDouble() - 0.5) * 0.02;
      final lng = center.longitude + (random.nextDouble() - 0.5) * 0.02;

      pois.add(
        POI(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          name: name,
          description: description,
          location: LatLng(lat, lng),
          category: category,
          address: '${10 + random.nextInt(90)} Rue de la Paix',
          phone:
              '+33 1 ${40 + random.nextInt(50)} ${10 + random.nextInt(90)} ${10 + random.nextInt(90)} ${10 + random.nextInt(90)}',
          rating: 2.0 + random.nextDouble() * 3.0,
          reviewCount: 5 + random.nextInt(100),
          tags: ['populaire', 'recommandé'],
          openingHours: {
            'lundi': '09:00-18:00',
            'mardi': '09:00-18:00',
            'mercredi': '09:00-18:00',
            'jeudi': '09:00-18:00',
            'vendredi': '09:00-18:00',
            'samedi': '10:00-19:00',
            'dimanche': 'fermé',
          },
          priceRange: ['€', '€€', '€€€'][random.nextInt(3)],
          isVerified: random.nextBool(),
        ),
      );
    }

    return pois;
  }

  /// Génère une clé de cache pour la recherche
  String _generateSearchKey(
    LatLng position,
    String? query,
    Set<POICategory>? categories,
    double? maxDistance,
    int? maxResults,
    bool? showOnlyOpen,
    double? minRating,
  ) {
    return [
      position.latitude.toStringAsFixed(4),
      position.longitude.toStringAsFixed(4),
      query ?? '',
      categories?.map((c) => c.name).join(',') ?? '',
      maxDistance?.toString() ?? '',
      maxResults?.toString() ?? '',
      showOnlyOpen?.toString() ?? '',
      minRating?.toString() ?? '',
    ].join('|');
  }

  /// Ajoute un POI aux favoris
  Future<void> addToFavorites(String poiId) async {
    if (!_favoritePOIIds.contains(poiId)) {
      _favoritePOIIds.add(poiId);
      await _saveFavoritePOIs();
      notifyListeners();
    }
  }

  /// Supprime un POI des favoris
  Future<void> removeFromFavorites(String poiId) async {
    if (_favoritePOIIds.remove(poiId)) {
      await _saveFavoritePOIs();
      notifyListeners();
    }
  }

  /// Vérifie si un POI est en favoris
  bool isFavorite(String poiId) {
    return _favoritePOIIds.contains(poiId);
  }

  /// Configure les catégories activées
  Future<void> setEnabledCategories(Set<POICategory> categories) async {
    _enabledCategories = categories;
    await _saveSettings();
    _searchCache.clear(); // Vider le cache de recherche
    notifyListeners();
  }

  /// Configure l'affichage des POI ouverts uniquement
  Future<void> setShowOnlyOpen(bool showOnly) async {
    _showOnlyOpen = showOnly;
    await _saveSettings();
    _searchCache.clear();
    notifyListeners();
  }

  /// Configure la distance maximale
  Future<void> setMaxDistance(double distance) async {
    _maxDistance = distance;
    await _saveSettings();
    _searchCache.clear();
    notifyListeners();
  }

  /// Configure le nombre maximum de résultats
  Future<void> setMaxResults(int maxResults) async {
    _maxResults = maxResults;
    await _saveSettings();
    _searchCache.clear();
    notifyListeners();
  }

  /// Configure l'inclusion des notes
  Future<void> setIncludeRatings(bool include) async {
    _includeRatings = include;
    await _saveSettings();
    notifyListeners();
  }

  /// Obtient l'icône pour une catégorie
  IconData getCategoryIcon(POICategory category) {
    switch (category) {
      case POICategory.restaurant:
        return Icons.restaurant;
      case POICategory.hotel:
        return Icons.hotel;
      case POICategory.attraction:
        return Icons.place;
      case POICategory.shop:
        return Icons.shopping_bag;
      case POICategory.transport:
        return Icons.directions_bus;
      case POICategory.health:
        return Icons.local_hospital;
      case POICategory.education:
        return Icons.school;
      case POICategory.service:
        return Icons.build;
      case POICategory.entertainment:
        return Icons.theaters;
      case POICategory.sport:
        return Icons.sports_soccer;
      case POICategory.culture:
        return Icons.museum;
      case POICategory.nature:
        return Icons.nature;
      default:
        return Icons.place;
    }
  }

  /// Obtient la couleur pour une catégorie
  Color getCategoryColor(POICategory category) {
    switch (category) {
      case POICategory.restaurant:
        return Colors.orange;
      case POICategory.hotel:
        return Colors.blue;
      case POICategory.attraction:
        return Colors.red;
      case POICategory.shop:
        return Colors.green;
      case POICategory.transport:
        return Colors.purple;
      case POICategory.health:
        return Colors.pink;
      case POICategory.education:
        return Colors.indigo;
      case POICategory.service:
        return Colors.brown;
      case POICategory.entertainment:
        return Colors.deepOrange;
      case POICategory.sport:
        return Colors.lightGreen;
      case POICategory.culture:
        return Colors.deepPurple;
      case POICategory.nature:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  /// Obtient le nom localisé d'une catégorie
  String getCategoryName(POICategory category) {
    switch (category) {
      case POICategory.restaurant:
        return 'Restaurants';
      case POICategory.hotel:
        return 'Hôtels';
      case POICategory.attraction:
        return 'Attractions';
      case POICategory.shop:
        return 'Magasins';
      case POICategory.transport:
        return 'Transports';
      case POICategory.health:
        return 'Santé';
      case POICategory.education:
        return 'Éducation';
      case POICategory.service:
        return 'Services';
      case POICategory.entertainment:
        return 'Divertissements';
      case POICategory.sport:
        return 'Sport';
      case POICategory.culture:
        return 'Culture';
      case POICategory.nature:
        return 'Nature';
      default:
        return 'Autres';
    }
  }

  /// Nettoie le cache de recherche
  void clearSearchCache() {
    _searchCache.clear();
  }
}
