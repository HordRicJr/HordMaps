import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/transport_models.dart';
import '../../features/navigation/providers/provider_navigation.dart';
import '../../services/cache_service.dart';
import '../../services/azure_maps_routing_service.dart';
import '../../services/location_service.dart';
import '../../services/voice_guidance_service.dart';

/// Contrôleur principal MVC pour l'application HordMaps
/// Coordonne tous les services et gère l'état global de l'application
class AppController extends ChangeNotifier {
  static AppController? _instance;
  static AppController get instance => _instance ??= AppController._();

  AppController._();

  // Services
  final CacheService _cacheService = CacheService.instance;
  final LocationService _locationService = LocationService.instance;
  final VoiceGuidanceService _voiceService = VoiceGuidanceService();

  // Providers
  NavigationProvider? _navigationProvider;

  // État de l'application
  bool _isInitialized = false;
  String? _lastError;
  bool _isLoading = false;

  // Getters pour les services
  CacheService get cacheService => _cacheService;
  LocationService get locationService => _locationService;
  VoiceGuidanceService get voiceService => _voiceService;
  NavigationProvider? get navigationProvider => _navigationProvider;

  // Getters pour l'état
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  bool get isLoading => _isLoading;

  /// Initialise tous les services de l'application
  Future<bool> initializeApp() async {
    if (_isInitialized) return true;

    try {
      _setLoading(true);
      _clearError();

      // Initialisation séquentielle des services
      await _initializeCache();
      await _initializeLocation();
      await _initializeVoiceService();
      await _initializeRouting();

      _isInitialized = true;
      debugPrint('✅ AppController: Application initialisée avec succès');
      return true;
    } catch (e) {
      _setError('Erreur d\'initialisation: $e');
      debugPrint('❌ AppController: Erreur d\'initialisation - $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Initialise le cache
  Future<void> _initializeCache() async {
    try {
      // CacheService utilise SharedPreferences et n'a pas besoin d'init
      debugPrint('✅ Cache Service prêt');
    } catch (e) {
      debugPrint('⚠️ Erreur cache service: $e');
      // Le cache n'est pas critique, on continue
    }
  }

  /// Initialise le service de localisation
  Future<void> _initializeLocation() async {
    try {
      // LocationService n'a pas besoin d'init spécial
      debugPrint('✅ Location Service prêt');
    } catch (e) {
      debugPrint('⚠️ Erreur location service: $e');
      // Pas critique pour l'instant
    }
  }

  /// Initialise le service de guidage vocal
  Future<void> _initializeVoiceService() async {
    try {
      // VoiceGuidanceService n'a pas besoin d'init spécial
      debugPrint('✅ Voice Service prêt');
    } catch (e) {
      debugPrint('⚠️ Erreur voice service: $e');
      // Le voice service n'est pas critique, on continue
    }
  }

  /// Initialise le service de routage
  Future<void> _initializeRouting() async {
    try {
      // Le service de routage n'a pas besoin d'initialisation spéciale
      debugPrint('✅ Routing Service prêt');
    } catch (e) {
      debugPrint('⚠️ Erreur routing service: $e');
      // On continue même si le routage a des problèmes
    }
  }

  /// Définit le NavigationProvider (appelé depuis main.dart)
  void setNavigationProvider(NavigationProvider provider) {
    _navigationProvider = provider;
    debugPrint('✅ NavigationProvider attaché au AppController');
  }

  /// Obtient la position actuelle
  Future<LatLng?> getCurrentPosition() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        return LatLng(position.latitude, position.longitude);
      }
      return null;
    } catch (e) {
      _setError('Erreur de géolocalisation: $e');
      return null;
    }
  }

  /// Démarre la navigation
  Future<bool> startNavigation() async {
    if (_navigationProvider == null) {
      _setError('NavigationProvider non disponible');
      return false;
    }

    try {
      _setLoading(true);
      await _navigationProvider!.startNavigation();
      return true;
    } catch (e) {
      _setError('Erreur de démarrage navigation: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Arrête la navigation
  Future<void> stopNavigation() async {
    if (_navigationProvider != null) {
      await _navigationProvider!.stopNavigation();
    }
  }

  /// Met en pause la navigation
  Future<void> pauseNavigation() async {
    if (_navigationProvider != null) {
      // NavigationProvider n'a pas de pause, on arrête la navigation
      await _navigationProvider!.stopNavigation();
    }
  }

  /// Calcule un itinéraire
  Future<dynamic> calculateRoute({
    required LatLng start,
    required LatLng end,
    TransportMode? transportMode,
    Map<String, dynamic>? options,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Utiliser le mode de transport par défaut si non spécifié
      transportMode ??= TransportMode.car;

      // Calculer la route avec Azure Maps
      final result = await AzureMapsRoutingService.calculateRoute(
        start: start,
        end: end,
        transportMode: transportMode.id,
        avoidTolls: options?['avoidTolls'] ?? false,
        avoidHighways: options?['avoidHighways'] ?? false,
        avoidFerries: options?['avoidFerries'] ?? false,
      );

      // Sauvegarder en cache si possible
      try {
        await _cacheService.saveRoute('last_route', result);
      } catch (e) {
        debugPrint('⚠️ Erreur sauvegarde cache: $e');
      }

      return result;
    } catch (e) {
      _setError('Erreur de calcul d\'itinéraire: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Recherche des lieux
  Future<List<dynamic>> searchPlaces(String query) async {
    try {
      // TODO: Implémenter la recherche de lieux
      // Pour l'instant, retourner une liste vide
      return [];
    } catch (e) {
      _setError('Erreur de recherche: $e');
      return [];
    }
  }

  /// Sauvegarde l'état de l'application
  Future<void> saveAppState() async {
    try {
      final state = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'initialized': _isInitialized,
        'voice_enabled': _voiceService.isEnabled,
      };

      await _cacheService.saveData('app_state', state);
    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde état: $e');
    }
  }

  /// Restaure l'état de l'application
  Future<void> restoreAppState() async {
    try {
      final state = await _cacheService.getData('app_state');
      if (state != null) {
        // Restaurer les préférences utilisateur
        if (state['voice_enabled'] == false) {
          // VoiceGuidanceService n'a pas de méthode disable simple
          debugPrint('Voice guidance désactivé dans les préférences');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur restauration état: $e');
    }
  }

  /// Nettoie les ressources
  @override
  Future<void> dispose() async {
    try {
      await saveAppState();
      await _navigationProvider?.stopNavigation();
      // Les autres services n'ont pas de méthode dispose spéciale
      _isInitialized = false;
      debugPrint('✅ AppController: Ressources nettoyées');
    } catch (e) {
      debugPrint('⚠️ Erreur nettoyage: $e');
    }
    super.dispose();
  }

  // Méthodes privées pour la gestion d'état
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _lastError = error;
    notifyListeners();
    debugPrint('❌ AppController Error: $error');
  }

  void _clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Méthode pour redémarrer l'application en cas d'erreur critique
  Future<bool> restart() async {
    try {
      _isInitialized = false;
      _clearError();
      return await initializeApp();
    } catch (e) {
      _setError('Erreur de redémarrage: $e');
      return false;
    }
  }

  /// Vérifie l'état de santé de l'application
  Map<String, dynamic> getHealthStatus() {
    return {
      'initialized': _isInitialized,
      'loading': _isLoading,
      'error': _lastError,
      'location_service': true, // Simplifié
      'voice_service': _voiceService.isEnabled,
      'navigation_active': _navigationProvider?.isNavigating ?? false,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
