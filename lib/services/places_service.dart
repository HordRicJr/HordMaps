import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/config/environment_config.dart';

class PlacesService {



  /// Récupère les lieux proches basés sur la position GPS réelle
  static Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 2.0,
    int maxResults = 15,
  }) async {
    try {
      // Utiliser Azure Maps Search POI API
      final response = await http.get(
        Uri.parse('${AzureMapsConfig.searchUrl}/poi/json').replace(
          queryParameters: {
            'api-version': AzureMapsConfig.apiVersion,
            'subscription-key': AzureMapsConfig.apiKey,
            'lat': latitude.toString(),
            'lon': longitude.toString(),
            'radius': (radiusKm * 1000).round().toString(), // Convertir km en m
            'limit': maxResults.toString(),
            'language': 'fr-FR',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseAzureMapsResponse(data, latitude, longitude);
      } else {
        debugPrint('Erreur API Azure Maps: ${response.statusCode}');
        return _getFallbackPlaces(latitude, longitude);
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des lieux: $e');
      return _getFallbackPlaces(latitude, longitude);
    }
  }



  /// Parse la réponse de l'API Azure Maps
  static List<Map<String, dynamic>> _parseAzureMapsResponse(
    Map<String, dynamic> data,
    double userLat,
    double userLon,
  ) {
    List<Map<String, dynamic>> places = [];

    if (data['results'] != null) {
      for (var result in data['results']) {
        try {
          final position = result['position'] as Map<String, dynamic>? ?? {};
          double placeLat = position['lat']?.toDouble() ?? 0.0;
          double placeLon = position['lon']?.toDouble() ?? 0.0;

          if (placeLat == 0.0 || placeLon == 0.0) continue;

          final poi = result['poi'] as Map<String, dynamic>? ?? {};
          final address = result['address'] as Map<String, dynamic>? ?? {};
          String name = poi['name'] ?? address['freeformAddress'] ?? '';

          if (name.isEmpty) continue;

          // Déterminer le type de lieu à partir des catégories Azure Maps
          Map<String, dynamic> placeTypeInfo = _getAzurePlaceTypeInfo(result);

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
            'address': address['freeformAddress'] ?? '',
            'phone': poi['phone'] ?? '',
            'website': poi['url'] ?? '',
            'openingHours': '', // Azure Maps ne fournit pas les heures d'ouverture dans cette API
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

  /// Détermine le type de lieu basé sur les données Azure Maps
  static Map<String, dynamic> _getAzurePlaceTypeInfo(Map<String, dynamic> result) {
    final poi = result['poi'] as Map<String, dynamic>? ?? {};
    final categories = poi['categories'] as List<dynamic>? ?? [];
    
    // Mapper les catégories Azure Maps vers nos types de lieux
    for (String category in categories) {
      switch (category.toLowerCase()) {
        case 'restaurant':
        case 'food':
          return {'icon': Icons.restaurant, 'label': 'Restaurant'};
        case 'gas station':
        case 'petrol station':
          return {'icon': Icons.local_gas_station, 'label': 'Station-service'};
        case 'pharmacy':
          return {'icon': Icons.local_pharmacy, 'label': 'Pharmacie'};
        case 'hospital':
        case 'medical':
          return {'icon': Icons.local_hospital, 'label': 'Hôpital'};
        case 'bank':
        case 'atm':
          return {'icon': Icons.account_balance, 'label': 'Banque'};
        case 'hotel':
        case 'accommodation':
          return {'icon': Icons.hotel, 'label': 'Hôtel'};
        case 'school':
        case 'education':
          return {'icon': Icons.school, 'label': 'École'};
        case 'shopping':
        case 'supermarket':
          return {'icon': Icons.shopping_cart, 'label': 'Supermarché'};
        case 'cafe':
          return {'icon': Icons.local_cafe, 'label': 'Café'};
      }
    }
    
    // Type par défaut
    return {'icon': Icons.place, 'label': 'Lieu d\'intérêt'};
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

  /// Recherche de lieux par nom/adresse via Azure Maps
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

      final uri = Uri.parse('${AzureMapsConfig.searchUrl}/address/json').replace(queryParameters: {
        'api-version': AzureMapsConfig.apiVersion,
        'subscription-key': AzureMapsConfig.apiKey,
        'query': params['q'] ?? '',
        'language': 'fr-FR',
        ...params,
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'HordMaps/1.0 (Flutter App)'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return _parseAzureMapsSearchResponse(responseData, nearLat ?? 0.0, nearLon ?? 0.0);
      }
    } catch (e) {
      debugPrint('Erreur lors de la recherche: $e');
    }

    return [];
  }

  static String _buildViewBox(double lat, double lon, double delta) {
    return '${lon - delta},${lat - delta},${lon + delta},${lat + delta}';
  }

  static List<Map<String, dynamic>> _parseAzureMapsSearchResponse(
    Map<String, dynamic> data,
    double userLat,
    double userLon,
  ) {
    List<Map<String, dynamic>> results = [];
    final List<dynamic> items = data['results'] ?? [];

    for (var item in items) {
      try {
        final position = item['position'] as Map<String, dynamic>? ?? {};
        final address = item['address'] as Map<String, dynamic>? ?? {};
        final poi = item['poi'] as Map<String, dynamic>? ?? {};
        
        double lat = position['lat']?.toDouble() ?? 0.0;
        double lon = position['lon']?.toDouble() ?? 0.0;

        String distance = '';
        if (lat != 0.0 && lon != 0.0) {
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

        String name = poi['name'] ?? address['freeformAddress'] ?? 'Lieu inconnu';
        
        results.add({
          'name': name,
          'type': item['type'] ?? 'POI',
          'distance': distance,
          'latitude': lat,
          'longitude': lon,
          'address': address['freeformAddress'] ?? '',
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
