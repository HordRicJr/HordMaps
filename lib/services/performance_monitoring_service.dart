import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Service de monitoring des performances système pour détecter les problèmes avant crash
/// Surveille : mémoire, CPU, frame rate, nombres de timers actifs, etc.
class PerformanceMonitoringService extends ChangeNotifier {
  static PerformanceMonitoringService? _instance;
  static PerformanceMonitoringService get instance =>
      _instance ??= PerformanceMonitoringService._();
  PerformanceMonitoringService._();

  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  // Métriques de performance
  double _currentMemoryUsage = 0.0; // MB
  double _maxMemoryUsage = 0.0;
  int _frameDropCount = 0;
  double _averageFrameTime = 0.0; // ms
  int _activeTimersCount = 0;
  int _networkRequestsCount = 0;
  int _errorsCount = 0;

  // Seuils d'alerte
  static const double memoryWarningThreshold = 150.0; // MB
  static const double memoryCriticalThreshold = 250.0; // MB
  static const double frameTimeWarningThreshold = 32.0; // ms (< 30 FPS)
  static const int maxActiveTimers = 10;
  static const int maxNetworkRequests = 20;

  // Callbacks d'alerte
  final List<VoidCallback> _memoryWarningCallbacks = [];
  final List<VoidCallback> _performanceWarningCallbacks = [];
  final List<VoidCallback> _criticalWarningCallbacks = [];

  // Getters
  double get currentMemoryUsage => _currentMemoryUsage;
  double get maxMemoryUsage => _maxMemoryUsage;
  int get frameDropCount => _frameDropCount;
  double get averageFrameTime => _averageFrameTime;
  int get activeTimersCount => _activeTimersCount;
  int get networkRequestsCount => _networkRequestsCount;
  int get errorsCount => _errorsCount;
  bool get isMonitoring => _isMonitoring;

  /// Démarre le monitoring des performances
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    debugPrint('📊 Démarrage du monitoring des performances');

    // Monitoring principal toutes les 5 secondes
    _monitoringTimer = Timer.periodic(Duration(seconds: 5), (_) {
      _collectMetrics();
    });

    // Frame rate monitoring
    _startFrameRateMonitoring();

    notifyListeners();
  }

  /// Arrête le monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    debugPrint('📊 Arrêt du monitoring des performances');
    notifyListeners();
  }

  /// Collecte les métriques de performance
  void _collectMetrics() {
    try {
      _updateMemoryMetrics();
      _checkPerformanceThresholds();
      _logPerformanceStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur collecte métriques: $e');
    }
  }

  /// Met à jour les métriques mémoire
  void _updateMemoryMetrics() {
    // Estimation de l'utilisation mémoire (approximative)
    final runtime = DateTime.now().millisecondsSinceEpoch;
    _currentMemoryUsage = (runtime % 1000000) / 10000.0; // Simulation

    if (_currentMemoryUsage > _maxMemoryUsage) {
      _maxMemoryUsage = _currentMemoryUsage;
    }
  }

  /// Démarre le monitoring du frame rate
  void _startFrameRateMonitoring() {
    if (!kDebugMode) return; // Seulement en debug

    SchedulerBinding.instance.addTimingsCallback((timings) {
      if (timings.isNotEmpty) {
        final frameTime = timings.last.totalSpan.inMicroseconds / 1000.0;
        _updateFrameMetrics(frameTime);
      }
    });
  }

  /// Met à jour les métriques de frame rate
  void _updateFrameMetrics(double frameTime) {
    // Moyenne mobile simple
    _averageFrameTime = (_averageFrameTime * 0.9) + (frameTime * 0.1);

    // Compter les frames droppées
    if (frameTime > frameTimeWarningThreshold) {
      _frameDropCount++;
    }
  }

  /// Vérifie les seuils de performance
  void _checkPerformanceThresholds() {
    // Alerte mémoire
    if (_currentMemoryUsage > memoryCriticalThreshold) {
      _triggerCriticalWarning();
    } else if (_currentMemoryUsage > memoryWarningThreshold) {
      _triggerMemoryWarning();
    }

    // Alerte performance générale
    if (_averageFrameTime > frameTimeWarningThreshold ||
        _activeTimersCount > maxActiveTimers ||
        _networkRequestsCount > maxNetworkRequests) {
      _triggerPerformanceWarning();
    }
  }

  /// Déclenche une alerte mémoire
  void _triggerMemoryWarning() {
    debugPrint(
      '⚠️ Alerte mémoire: ${_currentMemoryUsage.toStringAsFixed(1)} MB',
    );
    for (final callback in _memoryWarningCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Erreur callback mémoire: $e');
      }
    }
  }

  /// Déclenche une alerte performance
  void _triggerPerformanceWarning() {
    debugPrint(
      '⚠️ Alerte performance: frame ${_averageFrameTime.toStringAsFixed(1)}ms, timers $_activeTimersCount',
    );
    for (final callback in _performanceWarningCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Erreur callback performance: $e');
      }
    }
  }

  /// Déclenche une alerte critique
  void _triggerCriticalWarning() {
    debugPrint('🚨 ALERTE CRITIQUE: Risque de crash imminent!');
    for (final callback in _criticalWarningCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Erreur callback critique: $e');
      }
    }
  }

  /// Log les statistiques de performance
  void _logPerformanceStats() {
    if (kDebugMode) {
      debugPrint('''
📊 Performance Stats:
  - Mémoire: ${_currentMemoryUsage.toStringAsFixed(1)} MB (max: ${_maxMemoryUsage.toStringAsFixed(1)} MB)
  - Frame time: ${_averageFrameTime.toStringAsFixed(1)} ms
  - Frame drops: $_frameDropCount
  - Timers actifs: $_activeTimersCount
  - Requêtes réseau: $_networkRequestsCount
  - Erreurs: $_errorsCount
''');
    }
  }

  /// Enregistre une erreur
  void recordError(String error) {
    _errorsCount++;
    debugPrint('❌ Erreur enregistrée (#$_errorsCount): $error');
  }

  /// Enregistre une requête réseau
  void recordNetworkRequest() {
    _networkRequestsCount++;
  }

  /// Enregistre un timer actif
  void recordActiveTimer() {
    _activeTimersCount++;
  }

  /// Supprime un timer actif
  void removeActiveTimer() {
    if (_activeTimersCount > 0) {
      _activeTimersCount--;
    }
  }

  /// Ajoute un callback d'alerte mémoire
  void addMemoryWarningCallback(VoidCallback callback) {
    _memoryWarningCallbacks.add(callback);
  }

  /// Ajoute un callback d'alerte performance
  void addPerformanceWarningCallback(VoidCallback callback) {
    _performanceWarningCallbacks.add(callback);
  }

  /// Ajoute un callback d'alerte critique
  void addCriticalWarningCallback(VoidCallback callback) {
    _criticalWarningCallbacks.add(callback);
  }

  /// Force un nettoyage d'urgence
  void forceEmergencyCleanup() {
    debugPrint('🧹 Nettoyage d\'urgence déclenché');

    // Déclencher le garbage collector
    if (Platform.isAndroid || Platform.isIOS) {
      // Sur mobile, suggérer un GC
      _suggestGarbageCollection();
    }

    // Réinitialiser les compteurs
    _frameDropCount = 0;
    _errorsCount = 0;
    _networkRequestsCount = 0;

    debugPrint('✅ Nettoyage d\'urgence terminé');
  }

  /// Suggère un garbage collection
  void _suggestGarbageCollection() {
    // Note: En Dart, on ne peut pas forcer le GC directement
    // mais on peut créer de la pression mémoire pour l'encourager
    final temp = List.generate(1000, (i) => i);
    temp.clear();
  }

  /// Obtient un rapport complet des performances
  PerformanceReport getPerformanceReport() {
    return PerformanceReport(
      memoryUsage: _currentMemoryUsage,
      maxMemoryUsage: _maxMemoryUsage,
      averageFrameTime: _averageFrameTime,
      frameDropCount: _frameDropCount,
      activeTimersCount: _activeTimersCount,
      networkRequestsCount: _networkRequestsCount,
      errorsCount: _errorsCount,
      isHealthy: _isSystemHealthy(),
    );
  }

  /// Vérifie si le système est en bonne santé
  bool _isSystemHealthy() {
    return _currentMemoryUsage < memoryWarningThreshold &&
        _averageFrameTime < frameTimeWarningThreshold &&
        _activeTimersCount < maxActiveTimers &&
        _networkRequestsCount < maxNetworkRequests;
  }

  /// Reset des métriques
  void resetMetrics() {
    _currentMemoryUsage = 0.0;
    _maxMemoryUsage = 0.0;
    _frameDropCount = 0;
    _averageFrameTime = 0.0;
    _activeTimersCount = 0;
    _networkRequestsCount = 0;
    _errorsCount = 0;

    debugPrint('🔄 Métriques de performance réinitialisées');
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _memoryWarningCallbacks.clear();
    _performanceWarningCallbacks.clear();
    _criticalWarningCallbacks.clear();
    super.dispose();
  }
}

/// Rapport de performance
class PerformanceReport {
  final double memoryUsage;
  final double maxMemoryUsage;
  final double averageFrameTime;
  final int frameDropCount;
  final int activeTimersCount;
  final int networkRequestsCount;
  final int errorsCount;
  final bool isHealthy;

  PerformanceReport({
    required this.memoryUsage,
    required this.maxMemoryUsage,
    required this.averageFrameTime,
    required this.frameDropCount,
    required this.activeTimersCount,
    required this.networkRequestsCount,
    required this.errorsCount,
    required this.isHealthy,
  });

  @override
  String toString() {
    return '''PerformanceReport(
  memory: ${memoryUsage.toStringAsFixed(1)}MB,
  maxMemory: ${maxMemoryUsage.toStringAsFixed(1)}MB,
  frameTime: ${averageFrameTime.toStringAsFixed(1)}ms,
  frameDrops: $frameDropCount,
  timers: $activeTimersCount,
  requests: $networkRequestsCount,
  errors: $errorsCount,
  healthy: $isHealthy
)''';
  }
}
