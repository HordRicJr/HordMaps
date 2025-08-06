import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service de gestion centralisée des initialisations pour éviter les conflits et crashes
/// Séquence les initialisations avec gestion d'erreurs et retry automatique
class InitializationManager {
  static InitializationManager? _instance;
  static InitializationManager get instance =>
      _instance ??= InitializationManager._();
  InitializationManager._();

  final Map<String, InitializationStatus> _serviceStatus = {};
  final Map<String, Function> _retryCallbacks = {};
  final List<String> _initializationOrder = [];
  bool _isInitializing = false;

  /// Ajoute un service à initialiser
  void registerService(
    String serviceName,
    Future<bool> Function() initFunction, {
    int priority = 5,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    bool critical = false,
  }) {
    _serviceStatus[serviceName] = InitializationStatus(
      name: serviceName,
      initFunction: initFunction,
      priority: priority,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
      critical: critical,
    );

    // Maintenir l'ordre de priorité
    _initializationOrder.add(serviceName);
    _initializationOrder.sort(
      (a, b) =>
          _serviceStatus[a]!.priority.compareTo(_serviceStatus[b]!.priority),
    );
  }

  /// Initialise tous les services dans l'ordre de priorité
  Future<InitializationResult> initializeAll() async {
    if (_isInitializing) {
      debugPrint('⚠️ Initialisation déjà en cours');
      return InitializationResult.inProgress();
    }

    _isInitializing = true;
    debugPrint('🚀 Démarrage de l\'initialisation séquentielle');

    final results = <String, bool>{};
    final errors = <String, String>{};
    final startTime = DateTime.now();

    try {
      for (final serviceName in _initializationOrder) {
        final status = _serviceStatus[serviceName]!;
        debugPrint(
          '🔧 Initialisation de $serviceName (priorité ${status.priority})',
        );

        final result = await _initializeServiceWithRetry(status);
        results[serviceName] = result.success;

        if (!result.success) {
          errors[serviceName] = result.error ?? 'Erreur inconnue';

          if (status.critical) {
            debugPrint(
              '💥 Échec critique pour $serviceName - Arrêt de l\'initialisation',
            );
            break;
          } else {
            debugPrint(
              '⚠️ Échec non-critique pour $serviceName - Continuation',
            );
          }
        }

        // Délai entre les initialisations pour éviter la surcharge
        await Future.delayed(Duration(milliseconds: 200));
      }
    } catch (e) {
      debugPrint('💥 Erreur fatale lors de l\'initialisation: $e');
      errors['fatal'] = e.toString();
    } finally {
      _isInitializing = false;
    }

    final duration = DateTime.now().difference(startTime);
    debugPrint('✅ Initialisation terminée en ${duration.inMilliseconds}ms');

    return InitializationResult(
      success: errors.isEmpty,
      results: results,
      errors: errors,
      duration: duration,
    );
  }

  /// Initialise un service avec retry automatique
  Future<ServiceInitResult> _initializeServiceWithRetry(
    InitializationStatus status,
  ) async {
    for (int attempt = 1; attempt <= status.maxRetries; attempt++) {
      try {
        debugPrint(
          '  - Tentative $attempt/${status.maxRetries} pour ${status.name}',
        );

        final success = await status.initFunction().timeout(
          Duration(seconds: 30),
        ); // Timeout global de 30s

        if (success) {
          debugPrint('  ✅ ${status.name} initialisé avec succès');
          status.isInitialized = true;
          status.lastInitTime = DateTime.now();
          return ServiceInitResult.success();
        } else {
          throw Exception('Initialisation retournée false');
        }
      } catch (e) {
        debugPrint('  ❌ Erreur tentative $attempt pour ${status.name}: $e');
        status.lastError = e.toString();
        status.retryCount = attempt;

        if (attempt < status.maxRetries) {
          debugPrint('  ⏳ Retry dans ${status.retryDelay.inSeconds}s');
          await Future.delayed(status.retryDelay);
        }
      }
    }

    // Tous les retry ont échoué
    return ServiceInitResult.failure(
      status.lastError ?? 'Échec après ${status.maxRetries} tentatives',
    );
  }

  /// Vérifie le statut d'un service
  InitializationStatus? getServiceStatus(String serviceName) {
    return _serviceStatus[serviceName];
  }

  /// Vérifie si tous les services critiques sont initialisés
  bool areAllCriticalServicesReady() {
    for (final status in _serviceStatus.values) {
      if (status.critical && !status.isInitialized) {
        return false;
      }
    }
    return true;
  }

  /// Relance l'initialisation d'un service spécifique
  Future<bool> retryService(String serviceName) async {
    final status = _serviceStatus[serviceName];
    if (status == null) {
      debugPrint('Service $serviceName non trouvé');
      return false;
    }

    debugPrint('🔄 Retry manuel pour $serviceName');
    final result = await _initializeServiceWithRetry(status);
    return result.success;
  }

  /// Obtient un rapport détaillé de l'initialisation
  InitializationReport getReport() {
    final initialized = _serviceStatus.values
        .where((s) => s.isInitialized)
        .length;
    final total = _serviceStatus.length;
    final failed = _serviceStatus.values
        .where((s) => s.lastError != null && !s.isInitialized)
        .length;

    return InitializationReport(
      totalServices: total,
      initializedServices: initialized,
      failedServices: failed,
      allCriticalReady: areAllCriticalServicesReady(),
      services: Map.from(_serviceStatus),
    );
  }

  /// Reset l'état d'initialisation (pour tests ou redémarrage)
  void reset() {
    for (final status in _serviceStatus.values) {
      status.isInitialized = false;
      status.lastError = null;
      status.retryCount = 0;
      status.lastInitTime = null;
    }
    _isInitializing = false;
    debugPrint('🔄 État d\'initialisation réinitialisé');
  }

  /// Nettoie les ressources
  void dispose() {
    _serviceStatus.clear();
    _initializationOrder.clear();
    _retryCallbacks.clear();
    _isInitializing = false;
  }
}

/// Statut d'initialisation d'un service
class InitializationStatus {
  final String name;
  final Future<bool> Function() initFunction;
  final int priority;
  final int maxRetries;
  final Duration retryDelay;
  final bool critical;

  bool isInitialized = false;
  String? lastError;
  int retryCount = 0;
  DateTime? lastInitTime;

  InitializationStatus({
    required this.name,
    required this.initFunction,
    required this.priority,
    required this.maxRetries,
    required this.retryDelay,
    required this.critical,
  });

  @override
  String toString() {
    return 'Service($name): ${isInitialized ? "✅" : "❌"} - Priority: $priority, Critical: $critical';
  }
}

/// Résultat d'initialisation d'un service
class ServiceInitResult {
  final bool success;
  final String? error;

  ServiceInitResult.success() : success = true, error = null;
  ServiceInitResult.failure(this.error) : success = false;
}

/// Résultat global d'initialisation
class InitializationResult {
  final bool success;
  final Map<String, bool> results;
  final Map<String, String> errors;
  final Duration duration;

  InitializationResult({
    required this.success,
    required this.results,
    required this.errors,
    required this.duration,
  });

  InitializationResult.inProgress()
    : success = false,
      results = {},
      errors = {'status': 'Initialisation en cours'},
      duration = Duration.zero;

  @override
  String toString() {
    return '''InitializationResult(
  success: $success,
  duration: ${duration.inMilliseconds}ms,
  results: $results,
  errors: $errors
)''';
  }
}

/// Rapport détaillé d'initialisation
class InitializationReport {
  final int totalServices;
  final int initializedServices;
  final int failedServices;
  final bool allCriticalReady;
  final Map<String, InitializationStatus> services;

  InitializationReport({
    required this.totalServices,
    required this.initializedServices,
    required this.failedServices,
    required this.allCriticalReady,
    required this.services,
  });

  double get successRate =>
      totalServices > 0 ? initializedServices / totalServices : 0.0;

  @override
  String toString() {
    return '''InitializationReport(
  Total: $totalServices
  Initialisés: $initializedServices
  Échecs: $failedServices
  Taux de succès: ${(successRate * 100).toStringAsFixed(1)}%
  Services critiques OK: $allCriticalReady
)''';
  }
}
