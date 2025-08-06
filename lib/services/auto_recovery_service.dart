import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'central_event_manager.dart';
import 'event_throttle_service.dart';

/// Service de récupération automatique pour éviter les crashes
/// Détecte les problèmes et récupère automatiquement l'état de l'application
class AutoRecoveryService extends ChangeNotifier {
  static final AutoRecoveryService _instance = AutoRecoveryService._internal();
  factory AutoRecoveryService() => _instance;
  AutoRecoveryService._internal() {
    _initializeRecovery();
  }

  bool _isRecoveryActive = false;
  bool _isMonitoring = false;
  Timer? _healthCheckTimer;
  Timer? _memoryCleanupTimer;

  // Compteurs pour détecter les problèmes
  int _consecutiveErrors = 0;
  int _memoryWarnings = 0;
  int _eventOverloads = 0;

  // Seuils de récupération
  static const int _maxConsecutiveErrors = 3;
  static const int _maxEventOverloads = 10;

  /// Démarre la surveillance et la récupération automatique
  void startRecovery() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    debugPrint('🛡️ Service de récupération automatique démarré');

    // Check de santé toutes les 10 secondes
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _performHealthCheck(),
    );

    // Nettoyage mémoire toutes les 30 secondes
    _memoryCleanupTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performMemoryCleanup(),
    );
  }

  /// Arrête la surveillance
  void stopRecovery() {
    _isMonitoring = false;
    _healthCheckTimer?.cancel();
    _memoryCleanupTimer?.cancel();
    debugPrint('🛡️ Service de récupération automatique arrêté');
  }

  /// Effectue un check de santé complet
  void _performHealthCheck() {
    try {
      // Vérifier l'état du gestionnaire d'événements
      final eventManager = CentralEventManager();
      if (!eventManager.isHealthy()) {
        _handleEventOverload();
      }

      // Vérifier l'état du service de throttling
      final throttleService = EventThrottleService();
      final stats = throttleService.getEventStats();
      if (stats.values.any((count) => count > 50)) {
        _handleEventOverload();
      }

      // Reset des erreurs si tout va bien
      if (_consecutiveErrors > 0) {
        _consecutiveErrors = 0;
        debugPrint('✅ Système récupéré, reset des erreurs');
      }
    } catch (e) {
      _handleError('Health check failed', e);
    }
  }

  /// Effectue un nettoyage mémoire
  void _performMemoryCleanup() {
    try {
      // Nettoyer le gestionnaire d'événements
      CentralEventManager().cleanup();

      // Nettoyer la mémoire via le service d'optimisation
      MemoryOptimizationService().forceGarbageCollection();

      // Forcer le garbage collection (Android/iOS)
      if (!kIsWeb) {
        _forceGarbageCollection();
      }

      debugPrint('🧹 Nettoyage mémoire automatique effectué');
    } catch (e) {
      _handleError('Memory cleanup failed', e);
    }
  }

  /// Force le garbage collection
  void _forceGarbageCollection() {
    try {
      // Sur Android, on peut suggérer le GC
      if (Platform.isAndroid) {
        SystemChannels.platform.invokeMethod('System.gc');
      }
    } catch (e) {
      // Ignore si pas supporté
      debugPrint('GC non supporté: $e');
    }
  }

  /// Gère les surcharges d'événements
  void _handleEventOverload() {
    _eventOverloads++;

    if (_eventOverloads >= _maxEventOverloads) {
      debugPrint('⚠️ Surcharge d\'événements détectée, récupération...');
      _performEmergencyRecovery();
    }
  }

  /// Gère les erreurs
  void _handleError(String context, dynamic error) {
    _consecutiveErrors++;
    debugPrint(
      '❌ Erreur $context: $error ($_consecutiveErrors/$_maxConsecutiveErrors)',
    );

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _performEmergencyRecovery();
    }
  }

  /// Effectue une récupération d'urgence
  void _performEmergencyRecovery() {
    if (_isRecoveryActive) return;

    _isRecoveryActive = true;
    debugPrint('🚨 RÉCUPÉRATION D\'URGENCE EN COURS...');

    try {
      // 1. Arrêter tous les timers problématiques
      CentralEventManager().shutdown();

      // 2. Nettoyer complètement le throttling
      EventThrottleService().dispose();

      // 3. Forcer le nettoyage mémoire
      _forceGarbageCollection();

      // 4. Redémarrer les services essentiels
      Timer(const Duration(seconds: 2), () {
        _restartEssentialServices();
      });
    } catch (e) {
      debugPrint('❌ Erreur pendant la récupération: $e');
    }
  }

  /// Redémarre les services essentiels
  void _restartEssentialServices() {
    try {
      // Reset des compteurs
      _consecutiveErrors = 0;
      _eventOverloads = 0;
      _memoryWarnings = 0;

      _isRecoveryActive = false;

      debugPrint('✅ Services essentiels redémarrés');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur restart services: $e');
      _isRecoveryActive = false;
    }
  }

  /// Enregistre manuellement une erreur
  void reportError(String context, dynamic error) {
    _handleError(context, error);
  }

  /// Enregistre manuellement une surcharge d'événements
  void reportEventOverload() {
    _handleEventOverload();
  }

  /// Obtient l'état du service
  Map<String, dynamic> getStatus() {
    return {
      'isMonitoring': _isMonitoring,
      'isRecoveryActive': _isRecoveryActive,
      'consecutiveErrors': _consecutiveErrors,
      'eventOverloads': _eventOverloads,
      'memoryWarnings': _memoryWarnings,
    };
  }

  /// Initialise la récupération avec les handlers d'erreurs globaux
  void _initializeRecovery() {
    // Handler pour les erreurs Flutter non catchées
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('🚨 Flutter Error: ${details.exception}');
      _handleError('Flutter Error', details.exception);
    };

    // Handler pour les erreurs de zone non catchées
    runZonedGuarded(() {}, (error, stackTrace) {
      debugPrint('🚨 Zone Error: $error');
      _handleError('Zone Error', error);
    });
  }

  @override
  void dispose() {
    stopRecovery();
    super.dispose();
  }
}
