import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'central_event_manager.dart';
import 'auto_recovery_service.dart';
import 'event_throttle_service.dart';
import 'performance_monitor_service.dart';
import 'safe_location_service.dart';

/// Coordinateur principal de tous les services pour assurer la fluidité
/// Gère l'initialisation, la coordination et la surveillance globale
class AppServiceCoordinator {
  static final AppServiceCoordinator _instance =
      AppServiceCoordinator._internal();
  factory AppServiceCoordinator() => _instance;
  AppServiceCoordinator._internal();

  bool _isInitialized = false;
  bool _isShuttingDown = false;

  // Services principaux
  late final CentralEventManager _eventManager;
  late final AutoRecoveryService _recoveryService;
  late final EventThrottleService _throttleService;
  late final PerformanceMonitorService _performanceService;
  late final SafeLocationService _locationService;

  /// Initialise tous les services de manière coordonnée
  Future<void> initializeAllServices() async {
    if (_isInitialized) return;

    debugPrint('🚀 Initialisation coordonnée des services...');

    try {
      // 1. Initialiser le gestionnaire d'événements central en premier
      _eventManager = CentralEventManager();

      // 2. Initialiser le service de throttling
      _throttleService = EventThrottleService();

      // 3. Initialiser le monitoring de performance
      _performanceService = PerformanceMonitorService();
      _performanceService.startMonitoring();

      // 4. Initialiser le service de localisation sécurisé
      _locationService = SafeLocationService.instance;
      await _locationService.initialize();

      // 5. Démarrer le service de récupération automatique en dernier
      _recoveryService = AutoRecoveryService();
      _recoveryService.startRecovery();

      // 6. Configurer la surveillance croisée
      _setupCrossServiceMonitoring();

      _isInitialized = true;
      debugPrint('✅ Tous les services initialisés avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des services: $e');
      _recoverFromInitializationError();
    }
  }

  /// Configure la surveillance croisée entre services
  void _setupCrossServiceMonitoring() {
    // Programmer un nettoyage périodique coordonné
    _eventManager.registerPeriodicTimer(
      'global_cleanup',
      const Duration(minutes: 5),
      (_) => _performCoordinatedCleanup(),
    );

    // Surveiller la santé globale du système
    _eventManager.registerPeriodicTimer(
      'health_monitor',
      const Duration(seconds: 30),
      (_) => _monitorGlobalHealth(),
    );
  }

  /// Effectue un nettoyage coordonné de tous les services
  void _performCoordinatedCleanup() {
    try {
      debugPrint('🧹 Nettoyage coordonné en cours...');

      // Nettoyer dans l'ordre de dépendance
      _eventManager.cleanup();
      MemoryOptimizationService().forceGarbageCollection();

      // Forcer le garbage collection système
      if (!kIsWeb) {
        SystemChannels.platform
            .invokeMethod('System.gc')
            .catchError((_) => null);
      }

      debugPrint('✅ Nettoyage coordonné terminé');
    } catch (e) {
      debugPrint('❌ Erreur nettoyage coordonné: $e');
      _recoveryService.reportError('Coordinated cleanup', e);
    }
  }

  /// Surveille la santé globale du système
  void _monitorGlobalHealth() {
    try {
      final eventManagerHealth = _eventManager.isHealthy();
      final eventStats = _throttleService.getEventStats();
      final totalEvents = eventStats.values.fold(
        0,
        (sum, count) => sum + count,
      );

      if (!eventManagerHealth || totalEvents > 200) {
        debugPrint('⚠️ Surcharge détectée (events: $totalEvents)');
        _recoveryService.reportEventOverload();
      }

      // Log périodique de l'état
      if (DateTime.now().second % 60 == 0) {
        _logSystemStatus();
      }
    } catch (e) {
      debugPrint('❌ Erreur monitoring santé: $e');
      _recoveryService.reportError('Health monitoring', e);
    }
  }

  /// Log l'état du système
  void _logSystemStatus() {
    try {
      final eventStats = _eventManager.getStats();
      final throttleStats = _throttleService.getEventStats();
      final recoveryStatus = _recoveryService.getStatus();

      debugPrint('📊 État système:');
      debugPrint('   - Timers actifs: ${eventStats['activeTimers']}');
      debugPrint('   - Subscriptions: ${eventStats['activeSubscriptions']}');
      debugPrint(
        '   - Events throttlés: ${throttleStats.values.fold(0, (a, b) => a + b)}',
      );
      debugPrint(
        '   - Récupération: ${recoveryStatus['isRecoveryActive'] ? 'ACTIVE' : 'OK'}',
      );
    } catch (e) {
      debugPrint('❌ Erreur log status: $e');
    }
  }

  /// Récupère d'une erreur d'initialisation
  void _recoverFromInitializationError() {
    debugPrint('🚨 Récupération d\'erreur d\'initialisation...');

    // Réinitialiser les services un par un
    Timer(const Duration(seconds: 3), () async {
      try {
        await initializeAllServices();
      } catch (e) {
        debugPrint('❌ Échec de récupération: $e');
      }
    });
  }

  /// Obtient l'état global de tous les services
  Map<String, dynamic> getGlobalStatus() {
    if (!_isInitialized) {
      return {'initialized': false, 'error': 'Services not initialized'};
    }

    try {
      return {
        'initialized': _isInitialized,
        'shuttingDown': _isShuttingDown,
        'eventManager': _eventManager.getStats(),
        'throttling': _throttleService.getEventStats(),
        'recovery': _recoveryService.getStatus(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Arrête tous les services de manière coordonnée
  Future<void> shutdownAllServices() async {
    if (_isShuttingDown || !_isInitialized) return;

    _isShuttingDown = true;
    debugPrint('🛑 Arrêt coordonné des services...');

    try {
      // Arrêter dans l'ordre inverse de l'initialisation
      _recoveryService.stopRecovery();
      _performanceService.stopMonitoring();
      _locationService.dispose();
      _throttleService.dispose();
      _eventManager.shutdown();

      _isInitialized = false;
      debugPrint('✅ Tous les services arrêtés proprement');
    } catch (e) {
      debugPrint('❌ Erreur arrêt services: $e');
    } finally {
      _isShuttingDown = false;
    }
  }

  /// Force un redémarrage de tous les services
  Future<void> restartAllServices() async {
    debugPrint('🔄 Redémarrage complet des services...');

    await shutdownAllServices();
    await Future.delayed(const Duration(seconds: 2));
    await initializeAllServices();

    debugPrint('✅ Redémarrage terminé');
  }

  /// Optimise automatiquement les performances
  void optimizePerformance() {
    try {
      // Nettoyage agressif
      _performCoordinatedCleanup();

      debugPrint('⚡ Optimisation des performances activée');
    } catch (e) {
      debugPrint('❌ Erreur optimisation: $e');
    }
  }

  /// Vérifie si tous les services sont opérationnels
  bool get isHealthy {
    if (!_isInitialized || _isShuttingDown) return false;

    try {
      return _eventManager.isHealthy() &&
          !_recoveryService.getStatus()['isRecoveryActive'];
    } catch (e) {
      return false;
    }
  }

  /// Accesseurs pour les services (read-only)
  CentralEventManager get eventManager => _eventManager;
  AutoRecoveryService get recoveryService => _recoveryService;
  EventThrottleService get throttleService => _throttleService;
  PerformanceMonitorService get performanceService => _performanceService;
  SafeLocationService get locationService => _locationService;
}

/// Extension pour simplifier l'utilisation dans l'application
extension AppServiceCoordinatorExtension on Object {
  /// Accès rapide au coordinateur
  AppServiceCoordinator get services => AppServiceCoordinator();
}
