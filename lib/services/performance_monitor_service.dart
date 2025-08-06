import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Service de monitoring des performances pour détecter les problèmes
class PerformanceMonitorService extends ChangeNotifier {
  static final PerformanceMonitorService _instance =
      PerformanceMonitorService._internal();
  factory PerformanceMonitorService() => _instance;
  PerformanceMonitorService._internal();

  // Métriques de performance
  final List<FrameTimingInfo> _frameTimings = [];
  final Map<String, PerformanceMetric> _metrics = {};
  final List<String> _performanceLog = [];

  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  DateTime? _appStartTime;

  // Seuils de performance
  static const int _targetFps = 60;
  static const double _maxFrameTime = 16.67; // ms pour 60fps
  static const int _maxMemoryMb = 200;
  static const int _maxCpuPercent = 80;

  /// Démarre le monitoring des performances
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _appStartTime = DateTime.now();

    debugPrint('📊 Démarrage du monitoring des performances');

    // Monitoring des frames
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

    // Monitoring périodique
    _monitoringTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _collectSystemMetrics();
    });

    // Monitoring des gestes et événements
    _setupEventMonitoring();
  }

  /// Arrête le monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);

    debugPrint('📊 Arrêt du monitoring des performances');
    _generateReport();
  }

  /// Callback pour les timings de frames
  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final frameTime = timing.totalSpan.inMicroseconds / 1000.0; // en ms

      _frameTimings.add(
        FrameTimingInfo(
          timestamp: DateTime.now(),
          frameTime: frameTime,
          buildTime: timing.buildDuration.inMicroseconds / 1000.0,
          rasterTime: timing.rasterDuration.inMicroseconds / 1000.0,
        ),
      );

      // Garder seulement les 100 dernières mesures
      if (_frameTimings.length > 100) {
        _frameTimings.removeAt(0);
      }

      // Détecter les frames lentes
      if (frameTime > _maxFrameTime * 2) {
        _logPerformanceIssue(
          'Frame lente détectée: ${frameTime.toStringAsFixed(2)}ms',
        );
      }
    }

    notifyListeners();
  }

  /// Collecte les métriques système
  void _collectSystemMetrics() {
    final now = DateTime.now();

    // Simuler la collecte de métriques (en réalité il faudrait utiliser des APIs natives)
    _metrics['memory_usage'] = PerformanceMetric(
      name: 'Utilisation mémoire',
      value: _getEstimatedMemoryUsage(),
      unit: 'MB',
      timestamp: now,
      isWarning: _getEstimatedMemoryUsage() > _maxMemoryMb,
    );

    _metrics['cpu_usage'] = PerformanceMetric(
      name: 'Utilisation CPU',
      value: _getEstimatedCpuUsage(),
      unit: '%',
      timestamp: now,
      isWarning: _getEstimatedCpuUsage() > _maxCpuPercent,
    );

    _metrics['fps'] = PerformanceMetric(
      name: 'FPS moyen',
      value: _getAverageFps(),
      unit: 'fps',
      timestamp: now,
      isWarning: _getAverageFps() < _targetFps * 0.8,
    );

    // Vérifier les problèmes de performance
    _checkPerformanceThresholds();
  }

  /// Configuration du monitoring des événements
  void _setupEventMonitoring() {
    // Monitoring des gestes
    SystemChannels.system.setMessageHandler((message) async {
      if (message is Map && message['type'] == 'memoryPressure') {
        _logPerformanceIssue('Pression mémoire détectée');
      }
      return null;
    });
  }

  /// Vérifie les seuils de performance
  void _checkPerformanceThresholds() {
    final fps = _getAverageFps();
    final memory = _getEstimatedMemoryUsage();

    if (fps < _targetFps * 0.5) {
      _logPerformanceIssue('FPS très bas: ${fps.toStringAsFixed(1)} fps');
    }

    if (memory > _maxMemoryMb * 1.5) {
      _logPerformanceIssue(
        'Utilisation mémoire élevée: ${memory.toStringAsFixed(1)} MB',
      );
    }

    final recentSlowFrames = _frameTimings
        .where((frame) => frame.frameTime > _maxFrameTime * 3)
        .length;

    if (recentSlowFrames > 5) {
      _logPerformanceIssue(
        'Nombreuses frames lentes détectées: $recentSlowFrames',
      );
    }
  }

  /// Estime l'utilisation mémoire (simulation)
  double _getEstimatedMemoryUsage() {
    // En réalité, il faudrait utiliser une API native pour obtenir la vraie valeur
    final baseUsage = 50.0; // MB de base
    final variableUsage = _frameTimings.length * 0.1;
    return baseUsage + variableUsage;
  }

  /// Estime l'utilisation CPU (simulation)
  double _getEstimatedCpuUsage() {
    final recentFrames = _frameTimings.length > 10
        ? _frameTimings.sublist(_frameTimings.length - 10)
        : _frameTimings;
    if (recentFrames.isEmpty) return 20.0;

    final avgFrameTime =
        recentFrames.map((f) => f.frameTime).reduce((a, b) => a + b) /
        recentFrames.length;

    // Convertir le temps de frame en pourcentage CPU approximatif
    return (avgFrameTime / _maxFrameTime * 40).clamp(10.0, 90.0);
  }

  /// Calcule le FPS moyen
  double _getAverageFps() {
    final recentFrames = _frameTimings.length > 30
        ? _frameTimings.sublist(_frameTimings.length - 30)
        : _frameTimings;
    if (recentFrames.isEmpty) return 60.0;

    final avgFrameTime =
        recentFrames.map((f) => f.frameTime).reduce((a, b) => a + b) /
        recentFrames.length;

    return 1000.0 / avgFrameTime;
  }

  /// Log un problème de performance
  void _logPerformanceIssue(String issue) {
    final timestamp = DateTime.now();
    final logEntry = '${timestamp.toIso8601String()}: $issue';

    _performanceLog.add(logEntry);
    debugPrint('⚠️ Performance: $issue');

    // Garder seulement les 50 dernières entrées
    if (_performanceLog.length > 50) {
      _performanceLog.removeAt(0);
    }

    developer.log(
      issue,
      name: 'PerformanceMonitor',
      level: 900, // Warning level
    );
  }

  /// Génère un rapport de performance
  void _generateReport() {
    if (_frameTimings.isEmpty) return;

    final avgFps = _getAverageFps();
    final minFrameTime = _frameTimings
        .map((f) => f.frameTime)
        .reduce((a, b) => a < b ? a : b);
    final maxFrameTime = _frameTimings
        .map((f) => f.frameTime)
        .reduce((a, b) => a > b ? a : b);
    final slowFrames = _frameTimings
        .where((f) => f.frameTime > _maxFrameTime * 2)
        .length;

    final report =
        '''
📊 RAPPORT DE PERFORMANCE
=======================
Durée de monitoring: ${DateTime.now().difference(_appStartTime!).inSeconds}s
Frames analysées: ${_frameTimings.length}

FPS moyen: ${avgFps.toStringAsFixed(1)} fps
Frame la plus rapide: ${minFrameTime.toStringAsFixed(2)}ms
Frame la plus lente: ${maxFrameTime.toStringAsFixed(2)}ms
Frames lentes (>${(_maxFrameTime * 2).toStringAsFixed(1)}ms): $slowFrames

Mémoire estimée: ${_getEstimatedMemoryUsage().toStringAsFixed(1)} MB
CPU estimé: ${_getEstimatedCpuUsage().toStringAsFixed(1)}%

Problèmes détectés: ${_performanceLog.length}
''';

    debugPrint(report);

    // Enregistrer dans les logs de performance
    _performanceLog.add(report);
  }

  /// Obtient les métriques actuelles
  Map<String, PerformanceMetric> getCurrentMetrics() {
    return Map.from(_metrics);
  }

  /// Obtient les logs de performance
  List<String> getPerformanceLogs() {
    return List.from(_performanceLog);
  }

  /// Obtient les informations sur les frames
  List<FrameTimingInfo> getFrameTimings() {
    return List.from(_frameTimings);
  }

  /// Nettoie les données de performance
  void clearData() {
    _frameTimings.clear();
    _metrics.clear();
    _performanceLog.clear();
    notifyListeners();
    debugPrint('📊 Données de performance nettoyées');
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

/// Informations sur le timing d'une frame
class FrameTimingInfo {
  final DateTime timestamp;
  final double frameTime;
  final double buildTime;
  final double rasterTime;

  FrameTimingInfo({
    required this.timestamp,
    required this.frameTime,
    required this.buildTime,
    required this.rasterTime,
  });
}

/// Métrique de performance
class PerformanceMetric {
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;
  final bool isWarning;

  PerformanceMetric({
    required this.name,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.isWarning = false,
  });
}
