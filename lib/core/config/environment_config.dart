import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service de configuration d'environnement pour Azure Maps
/// Charge les variables d'environnement depuis le fichier .env
class EnvironmentConfig {
  static bool _isInitialized = false;

  /// Initialise la configuration en chargeant le fichier .env
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await dotenv.load(fileName: '.env');
      _isInitialized = true;
      debugPrint('Configuration d\'environnement chargée: ${dotenv.env.keys.length} variables');
    } catch (e) {
      debugPrint('Erreur lors du chargement de la configuration: $e');
      _isInitialized = true; // Continue même en cas d'erreur
    }
  }

  /// Obtient une variable d'environnement
  static String? get(String key) {
    if (!_isInitialized) {
      debugPrint('Configuration non initialisée. Appelez EnvironmentConfig.initialize() d\'abord.');
      return null;
    }
    return dotenv.env[key];
  }

  /// Obtient une variable d'environnement avec une valeur par défaut
  static String getOrDefault(String key, String defaultValue) {
    return get(key) ?? defaultValue;
  }

  /// Validation de la configuration
  static bool validateConfiguration() {
    if (!_isInitialized) {
      debugPrint('❌ Configuration non initialisée');
      return false;
    }
    
    if (!AzureMapsConfig.isValid) {
      debugPrint('❌ Configuration Azure Maps invalide - aucune clé API trouvée');
      return false;
    }
    
    debugPrint('✅ Configuration Azure Maps valide');
    debugPrint('  - Resource Group: ${AzureMapsConfig.resourceGroup}');
    debugPrint('  - Resource Name: ${AzureMapsConfig.resourceName}');
    debugPrint('  - API Version: ${AzureMapsConfig.apiVersion}');
    debugPrint('  - Regions: ${AzureMapsConfig.regions.length} régions configurées');
    debugPrint('  - Primary Key: ${_maskSensitiveData(AzureMapsConfig.primaryKey)}');
    debugPrint('  - Secondary Key: ${_maskSensitiveData(AzureMapsConfig.secondaryKey)}');
    
    return true;
  }

  /// Masque les données sensibles pour les logs
  static String _maskSensitiveData(String data) {
    if (data.isEmpty) return '✗ (vide)';
    if (data.length <= 8) return '✓ (configurée)';
    return '✓ ${data.substring(0, 4)}***${data.substring(data.length - 4)}';
  }
}

/// Configuration Azure Maps
class AzureMapsConfig {
  /// Client ID pour l'authentification Microsoft Entra ID
  static String get clientId => EnvironmentConfig.get('AZURE_MAPS_CLIENT_ID') ?? '';
  
  /// Clé principale pour l'authentification par clé partagée
  static String get primaryKey => EnvironmentConfig.get('AZURE_MAPS_PRIMARY_KEY') ?? '';
  
  /// Clé secondaire pour l'authentification par clé partagée
  static String get secondaryKey => EnvironmentConfig.get('AZURE_MAPS_SECONDARY_KEY') ?? '';
  
  /// Nom de la ressource Azure Maps
  static String get resourceName => EnvironmentConfig.get('AZURE_MAPS_RESOURCE_NAME') ?? 'maps';
  
  /// Groupe de ressources Azure Maps
  static String get resourceGroup => EnvironmentConfig.get('AZURE_MAPS_RESOURCE_GROUP') ?? 'HordMaps';
  
  /// ID de l'abonnement Azure
  static String get subscriptionId => EnvironmentConfig.get('AZURE_MAPS_SUBSCRIPTION_ID') ?? '';
  
  /// URL de base pour les API Azure Maps
  static String get baseUrl => EnvironmentConfig.get('AZURE_MAPS_BASE_URL') ?? 'https://atlas.microsoft.com';
  
  /// URL pour les API de recherche
  static String get searchUrl => EnvironmentConfig.get('AZURE_MAPS_SEARCH_URL') ?? 'https://atlas.microsoft.com/search';
  
  /// URL pour les API de routage
  static String get routeUrl => EnvironmentConfig.get('AZURE_MAPS_ROUTE_URL') ?? 'https://atlas.microsoft.com/route';
  
  /// URL pour les API de rendu de carte
  static String get renderUrl => EnvironmentConfig.get('AZURE_MAPS_RENDER_URL') ?? 'https://atlas.microsoft.com/map';
  
  /// Version de l'API Azure Maps
  static String get apiVersion => EnvironmentConfig.get('AZURE_MAPS_API_VERSION') ?? '1.0';
  
  /// Régions configurées
  static List<String> get regions {
    final regionsStr = EnvironmentConfig.get('AZURE_MAPS_REGIONS') ?? '';
    return regionsStr.split(',').map((r) => r.trim()).where((r) => r.isNotEmpty).toList();
  }
  
  /// Vérifie si la configuration Azure Maps est valide
  static bool get isValid {
    return primaryKey.isNotEmpty || clientId.isNotEmpty;
  }
  
  /// Obtient la clé API à utiliser (primaire par défaut, secondaire en fallback)
  static String get apiKey {
    return primaryKey.isNotEmpty ? primaryKey : secondaryKey;
  }
}

/// Configuration des URLs de tuiles Azure Maps
class AzureTileUrls {
  /// URL de base pour les tuiles de carte
  static String get base => '${AzureMapsConfig.renderUrl}/tile';
  
  /// URL pour les tuiles de carte standard
  static String get standard => '$base/basic/zoom-level/{z}/tile-row/{y}/tile-column/{x}?api-version=${AzureMapsConfig.apiVersion}&subscription-key=${AzureMapsConfig.apiKey}';
  
  /// URL pour les tuiles satellite
  static String get satellite => '$base/imagery/zoom-level/{z}/tile-row/{y}/tile-column/{x}?api-version=${AzureMapsConfig.apiVersion}&subscription-key=${AzureMapsConfig.apiKey}';
  
  /// URL pour les tuiles hybrides (satellite + routes)
  static String get hybrid => '$base/hybrid/zoom-level/{z}/tile-row/{y}/tile-column/{x}?api-version=${AzureMapsConfig.apiVersion}&subscription-key=${AzureMapsConfig.apiKey}';
  
  /// URL pour les tuiles de nuit
  static String get dark => '$base/basic_night/zoom-level/{z}/tile-row/{y}/tile-column/{x}?api-version=${AzureMapsConfig.apiVersion}&subscription-key=${AzureMapsConfig.apiKey}';
  
  /// URL pour les tuiles de relief
  static String get terrain => '$base/terrain/zoom-level/{z}/tile-row/{y}/tile-column/{x}?api-version=${AzureMapsConfig.apiVersion}&subscription-key=${AzureMapsConfig.apiKey}';
}

/// Méthodes utilitaires pour les requêtes Azure Maps
class AzureMapsUtils {
  /// Génère les paramètres de requête standard pour Azure Maps
  static Map<String, String> getStandardParams() {
    return {
      'api-version': AzureMapsConfig.apiVersion,
      'subscription-key': AzureMapsConfig.apiKey,
    };
  }
  
  /// Génère les headers HTTP pour les requêtes Azure Maps
  static Map<String, String> getStandardHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
  
  /// Construit une URL complète avec les paramètres de base
  static String buildUrl(String endpoint, [Map<String, String>? additionalParams]) {
    final params = getStandardParams();
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }
    
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    final separator = endpoint.contains('?') ? '&' : '?';
    return '$endpoint$separator$queryString';
  }
}