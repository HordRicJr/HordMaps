import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class PlacesService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const String _nominatimUrl =
      'https://nominatim.openstreetmap.org/search';

  // Types de lieux avec leurs tags OpenStreetMap et icônes correspondantes
  static const Map<String, Map<String, dynamic>> _placeTypes = {
    'restaurant': {
      'amenity': 'restaurant',
      'icon': Icons.restaurant,
      'label': 'Restaurant',
    },
    'fast_food': {
      'amenity': 'fast_food',
      'icon': Icons.fastfood,
      'label': 'Fast Food',
    },
    'cafe': {'amenity': 'cafe', 'icon': Icons.local_cafe, 'label': 'Café'},
    'pharmacy': {
      'amenity': 'pharmacy',
      'icon': Icons.local_pharmacy,
      'label': 'Pharmacie',
    },
    'hospital': {
      'amenity': 'hospital',
      'icon': Icons.local_hospital,
      'label': 'Hôpital',
    },
    'bank': {
      'amenity': 'bank',
      'icon': Icons.account_balance,
      'label': 'Banque',
    },
    'atm': {'amenity': 'atm', 'icon': Icons.atm, 'label': 'Distributeur'},
    'fuel': {
      'amenity': 'fuel',
      'icon': Icons.local_gas_station,
      'label': 'Station-Service',
    },
    'supermarket': {
      'shop': 'supermarket',
      'icon': Icons.shopping_cart,
      'label': 'Supermarché',
    },
    'bakery': {
      'shop': 'bakery',
      'icon': Icons.bakery_dining,
      'label': 'Boulangerie',
    },
    'school': {'amenity': 'school', 'icon': Icons.school, 'label': 'École'},
    'library': {
      'amenity': 'library',
      'icon': Icons.library_books,
      'label': 'Bibliothèque',
    },
    'post_office': {
      'amenity': 'post_office',
      'icon': Icons.local_post_office,
      'label': 'Poste',
    },
    'parking': {
      'amenity': 'parking',
      'icon': Icons.local_parking,
      'label': 'Parking',
    },
  };

  /// Récupère les lieux proches basés sur la position GPS réelle
  static Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 2.0,
    int maxResults = 15,
  }) async {
    try {
      // Construire la requête Overpass
      String overpassQuery = _buildOverpassQuery(
        latitude,
        longitude,
        radiusKm,
        maxResults,
      );

      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=$overpassQuery',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseOverpassResponse(data, latitude, longitude);
      } else {
        debugPrint('Erreur API Overpass: ${response.statusCode}');
        return _getFallbackPlaces(latitude, longitude);
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des lieux: $e');
      return _getFallbackPlaces(latitude, longitude);
    }
  }

  /// Construit la requête Overpass pour récupérer les lieux d'intérêt
  static String _buildOverpassQuery(
    double lat,
    double lon,
    double radiusKm,
    int maxResults,
  ) {
    double radiusM = radiusKm * 1000;

    // Créer une liste des requêtes pour chaque type de lieu
    List<String> queries = [];

    for (String placeType in _placeTypes.keys) {
      Map<String, dynamic>? typeInfo = _placeTypes[placeType];
      if (typeInfo == null) continue;

      String? key = typeInfo.keys
          .where((k) => k != 'icon' && k != 'label')
          .firstOrNull;
      if (key == null) continue;

      String? value = typeInfo[key];
      if (value == null) continue;

      queries.add('node["$key"="$value"](around:$radiusM,$lat,$lon);');
      queries.add('way["$key"="$value"](around:$radiusM,$lat,$lon);');
    }

    return '''
[out:json][timeout:25];
(
  ${queries.join('\n  ')}
);
out center meta;
''';
  }

  /// Parse la réponse de l'API Overpass
  static List<Map<String, dynamic>> _parseOverpassResponse(
    Map<String, dynamic> data,
    double userLat,
    double userLon,
  ) {
    List<Map<String, dynamic>> places = [];

    if (data['elements'] != null) {
      for (var element in data['elements']) {
        try {
          double placeLat =
              element['lat']?.toDouble() ??
              element['center']?['lat']?.toDouble() ??
              0.0;
          double placeLon =
              element['lon']?.toDouble() ??
              element['center']?['lon']?.toDouble() ??
              0.0;

          if (placeLat == 0.0 || placeLon == 0.0) continue;

          Map<String, dynamic> tags = element['tags'] ?? {};
          String name = tags['name'] ?? _getDefaultName(tags);

          if (name.isEmpty) continue;

          // Déterminer le type de lieu
          Map<String, dynamic>? placeTypeInfo = _getPlaceTypeInfo(tags);
          if (placeTypeInfo == null) continue;

          // Calculer la distance
          double distanceM = Geolocator.distanceBetween(
            userLat,
            userLon,
            placeLat,
            placeLon,
          );

          String distanceStr = distanceM < 1000
              ? '${distanceM.round()}m'
              : '${(distanceM / 1000).toStringAsFixed(1)}km';

          places.add({
            'name': name,
            'type': placeTypeInfo['label'],
            'distance': distanceStr,
            'distanceMeters': distanceM,
            'icon': placeTypeInfo['icon'],
            'latitude': placeLat,
            'longitude': placeLon,
            'isReal': true,
            'address': _getAddress(tags),
            'phone': tags['phone'] ?? '',
            'website': tags['website'] ?? '',
            'openingHours': tags['opening_hours'] ?? '',
          });
        } catch (e) {
          debugPrint('Erreur lors du parsing d\'un élément: $e');
          continue;
        }
      }
    }

    // Trier par distance et limiter le nombre de résultats
    places.sort((a, b) => a['distanceMeters'].compareTo(b['distanceMeters']));
    return places.take(15).toList();
  }

  /// Détermine le type de lieu basé sur les tags OpenStreetMap
  static Map<String, dynamic>? _getPlaceTypeInfo(Map<String, dynamic> tags) {
    for (String placeType in _placeTypes.keys) {
      Map<String, dynamic> typeInfo = _placeTypes[placeType]!;

      for (String key in typeInfo.keys) {
        if (key != 'icon' && key != 'label') {
          if (tags[key] == typeInfo[key]) {
            return {'icon': typeInfo['icon'], 'label': typeInfo['label']};
          }
        }
      }
    }
    return null;
  }

  /// Génère un nom par défaut si aucun nom n'est disponible
  static String _getDefaultName(Map<String, dynamic> tags) {
    // Essayer différents champs de nom
    if (tags['brand'] != null) return tags['brand'];
    if (tags['operator'] != null) return tags['operator'];

    // Générer un nom basé sur le type
    for (String placeType in _placeTypes.keys) {
      Map<String, dynamic> typeInfo = _placeTypes[placeType]!;

      for (String key in typeInfo.keys) {
        if (key != 'icon' && key != 'label' && tags[key] == typeInfo[key]) {
          return typeInfo['label'];
        }
      }
    }

    return 'Lieu d\'intérêt';
  }

  /// Génère une adresse à partir des tags
  static String _getAddress(Map<String, dynamic> tags) {
    List<String> addressParts = [];

    if (tags['addr:housenumber'] != null) {
      addressParts.add(tags['addr:housenumber']);
    }
    if (tags['addr:street'] != null) {
      addressParts.add(tags['addr:street']);
    }
    if (tags['addr:city'] != null) {
      addressParts.add(tags['addr:city']);
    }

    return addressParts.join(' ');
  }

  /// Fournit des lieux de secours en cas d'échec de l'API
  static List<Map<String, dynamic>> _getFallbackPlaces(
    double latitude,
    double longitude,
  ) {
    return [
      {
        'name': 'Lieu proche 1',
        'type': 'Point d\'intérêt',
        'distance': '200m',
        'distanceMeters': 200.0,
        'icon': Icons.place,
        'latitude': latitude + 0.001,
        'longitude': longitude + 0.001,
        'isReal': false,
        'address': 'Adresse non disponible',
        'phone': '',
        'website': '',
        'openingHours': '',
      },
      {
        'name': 'Lieu proche 2',
        'type': 'Point d\'intérêt',
        'distance': '350m',
        'distanceMeters': 350.0,
        'icon': Icons.place,
        'latitude': latitude - 0.001,
        'longitude': longitude - 0.001,
        'isReal': false,
        'address': 'Adresse non disponible',
        'phone': '',
        'website': '',
        'openingHours': '',
      },
    ];
  }

  /// Recherche de lieux par nom/adresse via Nominatim
  static Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLon,
    int limit = 10,
  }) async {
    try {
      Map<String, String> params = {
        'q': query,
        'format': 'json',
        'limit': limit.toString(),
        'addressdetails': '1',
        'extratags': '1',
      };

      if (nearLat != null && nearLon != null) {
        params['lat'] = nearLat.toString();
        params['lon'] = nearLon.toString();
        params['bounded'] = '1';
        params['viewbox'] = _buildViewBox(nearLat, nearLon, 0.1);
      }

      final uri = Uri.parse(_nominatimUrl).replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'HordMaps/1.0 (Flutter App)'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return _parseNominatimResponse(data, nearLat, nearLon);
      }
    } catch (e) {
      debugPrint('Erreur lors de la recherche: $e');
    }

    return [];
  }

  static String _buildViewBox(double lat, double lon, double delta) {
    return '${lon - delta},${lat - delta},${lon + delta},${lat + delta}';
  }

  static List<Map<String, dynamic>> _parseNominatimResponse(
    List<dynamic> data,
    double? userLat,
    double? userLon,
  ) {
    List<Map<String, dynamic>> results = [];

    for (var item in data) {
      try {
        double lat = double.parse(item['lat']);
        double lon = double.parse(item['lon']);

        String distance = '';
        if (userLat != null && userLon != null) {
          double distanceM = Geolocator.distanceBetween(
            userLat,
            userLon,
            lat,
            lon,
          );
          distance = distanceM < 1000
              ? '${distanceM.round()}m'
              : '${(distanceM / 1000).toStringAsFixed(1)}km';
        }

        results.add({
          'name': item['display_name'] ?? 'Lieu inconnu',
          'type': item['type'] ?? 'Lieu',
          'distance': distance,
          'latitude': lat,
          'longitude': lon,
          'address': item['display_name'] ?? '',
          'isReal': true,
          'icon': Icons.place,
        });
      } catch (e) {
        continue;
      }
    }

    return results;
  }
}
