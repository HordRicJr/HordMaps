import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'error_logging_service.dart';

/// Service d'optimisation de la mémoire pour éviter les fuites et les crashs
/// Surveille et optimise l'utilisation de la mémoire dans l'application
class MemoryOptimizationService {
  static final MemoryOptimizationService _instance = MemoryOptimizationService._internal();
  factory MemoryOptimizationService() => _instance;
  MemoryOptimizationService._internal() {
    _initializeMemoryWatcher();
  }

  // Ressources à surveiller
  final Set<StreamSubscription> _subscriptions = <StreamSubscription>{};
  final Set<Timer> _timers = <Timer>{};
  final Queue<dynamic> _objectPool = Queue<dynamic>();
  final Map<String, int> _resourceCounts = {};
  
  // Limites et configuration
  final int _maxPoolSize = 100;
  final int _maxImageCacheSize = 100 * 1024 * 1024; // 100 MB
  final int _maxSubscriptions = 50;
  final int _maxTimers = 30;
  
  // État du service
  bool _isLowMemory = false;
  int _memoryWarningCount = 0;
  DateTime? _lastMemoryWarning;
  Timer? _memoryWatchTimer;

  /// Enregistre une souscription pour nettoyage automatique
  void registerSubscription(StreamSubscription subscription, [String? tag]) {
    _subscriptions.add(subscription);
    
    if (tag != null) {
      _resourceCounts[tag] = (_resourceCounts[tag] ?? 0) + 1;
    }
    
    // Vérifier si on dépasse les limites
    if (_subscriptions.length > _maxSubscriptions) {
      debugPrint('⚠️ Trop de subscriptions actives (${_subscriptions.length})');
      _triggerMemoryWarning('Trop de subscriptions');
    }
  }

  /// Enregistre un timer pour nettoyage automatique
  void registerTimer(Timer timer, [String? tag]) {
    _timers.add(timer);
    
    if (tag != null) {
      _resourceCounts[tag] = (_resourceCounts[tag] ?? 0) + 1;
    }
    
    // Vérifier si on dépasse les limites
    if (_timers.length > _maxTimers) {
      debugPrint('⚠️ Trop de timers actifs (${_timers.length})');
      _triggerMemoryWarning('Trop de timers');
    }
  }

  /// Ajoute un objet au pool de réutilisation
  void returnToPool(dynamic object, [String? tag]) {
    if (_objectPool.length < _maxPoolSize) {
      _objectPool.add(object);
      
      if (tag != null) {
        _resourceCounts[tag] = (_resourceCounts[tag] ?? 0) + 1;
      }
    }
  }

  /// Récupère un objet du pool ou crée un nouveau
  T getFromPool<T>(T Function() factory, [String? tag]) {
    if (_objectPool.isNotEmpty) {
      for (int i = 0; i < _objectPool.length; i++) {
        final obj = _objectPool.elementAt(i);
        if (obj is T) {
          _objectPool.remove(obj);
          
          if (tag != null) {
            _resourceCounts[tag] = (_resourceCounts[tag] ?? 0) - 1;
          }
          
          return obj;
        }
      }
    }
    
    // Créer un nouvel objet si rien dans le pool
    return factory();
  }

  /// Initialise la surveillance de la mémoire
  void _initializeMemoryWatcher() {
    // Démarrer un timer pour vérifier la mémoire périodiquement
    _memoryWatchTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkMemoryUsage();
    });
    
    // Écouter les événements système pour les avertissements de mémoire faible
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        const MethodChannel('app.hordmaps/memory').setMethodCallHandler((call) async {
          if (call.method == 'memoryWarning') {
            _handleLowMemoryWarning();
            return true;
          }
          return null;
        });
      } catch (e) {
        debugPrint('❌ Erreur initialisation memory watcher: $e');
      }
    }
  }

  /// Vérifie l'utilisation de la mémoire
  Future<void> _checkMemoryUsage() async {
    try {
      // Vérifier les ressources actives
      _cleanupInactiveResources();
      
      // Vérifier si on est en situation de mémoire faible
      if (_isLowMemory) {
        // Si on était déjà en mémoire faible, faire un nettoyage plus agressif
        _performAggressiveCleanup();
      }
      
      // Vérifier le cache d'images
      _checkImageCache();
      
      // Loguer les statistiques
      _logMemoryStats();
    } catch (e) {
      debugPrint('❌ Erreur vérification mémoire: $e');
    }
  }

  /// Nettoie les ressources inactives
  void _cleanupInactiveResources() {
    int subscriptionsBefore = _subscriptions.length;
    int timersBefore = _timers.length;
    
    // Nettoyer les subscriptions fermées
    _subscriptions.removeWhere((sub) {
      try {
        return sub.isPaused;
      } catch (e) {
        // Si on ne peut pas vérifier, on considère comme à nettoyer
        return true;
      }
    });
    
    // Nettoyer les timers inactifs
    _timers.removeWhere((timer) {
      try {
        return !timer.isActive;
      } catch (e) {
        // Si on ne peut pas vérifier, on considère comme à nettoyer
        return true;
      }
    });
    
    int subscriptionsAfter = _subscriptions.length;
    int timersAfter = _timers.length;
    
    if (subscriptionsBefore != subscriptionsAfter || timersBefore != timersAfter) {
      debugPrint('🧹 Nettoyage ressources: ${subscriptionsBefore - subscriptionsAfter} subscriptions, '
          '${timersBefore - timersAfter} timers');
    }
  }

  /// Effectue un nettoyage agressif en cas de mémoire faible
  void _performAggressiveCleanup() {
    debugPrint('🚨 Nettoyage mémoire agressif en cours...');
    
    // Vider complètement le pool d'objets
    _objectPool.clear();
    
    // Nettoyer le cache d'images
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Forcer le garbage collection
    _forceGarbageCollection();
    
    // Réinitialiser l'état de mémoire faible
    _isLowMemory = false;
    
    debugPrint('✅ Nettoyage mémoire agressif terminé');
  }

  /// Vérifie et optimise le cache d'images
  void _checkImageCache() {
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      
      // Si on est en mémoire faible, réduire drastiquement
      if (_isLowMemory) {
        imageCache.maximumSize = 20;
        imageCache.maximumSizeBytes = _maxImageCacheSize ~/ 4;
      } else {
        // Sinon, utiliser des valeurs raisonnables
        imageCache.maximumSize = 100;
        imageCache.maximumSizeBytes = _maxImageCacheSize;
      }
    } catch (e) {
      debugPrint('❌ Erreur optimisation cache images: $e');
    }
  }

  /// Gère un avertissement de mémoire faible
  void _handleLowMemoryWarning() {
    _isLowMemory = true;
    _memoryWarningCount++;
    _lastMemoryWarning = DateTime.now();
    
    debugPrint('⚠️ AVERTISSEMENT MÉMOIRE FAIBLE (#$_memoryWarningCount)');
    
    // Enregistrer l'événement
    try {
      ErrorLoggingService().warning(
        'MemoryOptimization',
        'Avertissement mémoire faible',
        details: {
          'count': _memoryWarningCount,
          'subscriptions': _subscriptions.length,
          'timers': _timers.length,
          'poolSize': _objectPool.length,
        },
      );
    } catch (_) {}
    
    // Effectuer un nettoyage immédiat
    _performAggressiveCleanup();
  }

  /// Force le garbage collection
  void forceGarbageCollection() {
    _cleanupInactiveResources();
    
    try {
      // Sur Android, on peut suggérer le GC
      if (!kIsWeb && Platform.isAndroid) {
        SystemChannels.platform.invokeMethod('System.gc');
      }
      
      debugPrint('🧹 Garbage collection forcé');
    } catch (e) {
      // Ignorer si pas supporté
      debugPrint('GC non supporté: $e');
    }
  }

  /// Déclenche un avertissement de mémoire faible
  void _triggerMemoryWarning(String reason) {
    if (_lastMemoryWarning != null) {
      final timeSinceLastWarning = DateTime.now().difference(_lastMemoryWarning!);
      
      // Éviter trop d'avertissements rapprochés
      if (timeSinceLastWarning.inMinutes < 5) {
        return;
      }
    }
    
    debugPrint('⚠️ Avertissement mémoire: $reason');
    _handleLowMemoryWarning();
  }

  /// Enregistre les statistiques de mémoire
  void _logMemoryStats() {
    final stats = getStats();
    
    debugPrint('📊 Statistiques mémoire:');
    debugPrint('   - Subscriptions: ${stats['subscriptions']}');
    debugPrint('   - Timers: ${stats['timers']}');
    debugPrint('   - Pool: ${stats['poolSize']}');
    debugPrint('   - Avertissements: ${stats['memoryWarnings']}');
    
    // Loguer les ressources par tag
    if (_resourceCounts.isNotEmpty) {
      debugPrint('   - Ressources par tag:');
      _resourceCounts.forEach((tag, count) {
        if (count > 0) {
          debugPrint('     - $tag: $count');
        }
      });
    }
  }

  /// Obtient les statistiques du service
  Map<String, dynamic> getStats() {
    return {
      'subscriptions': _subscriptions.length,
      'timers': _timers.length,
      'poolSize': _objectPool.length,
      'isLowMemory': _isLowMemory,
      'memoryWarnings': _memoryWarningCount,
      'lastWarning': _lastMemoryWarning?.toIso8601String(),
      'resourceCounts': Map.from(_resourceCounts),
    };
  }

  /// Nettoie toutes les ressources
  void dispose() {
    _memoryWatchTimer?.cancel();
    
    for (final subscription in _subscriptions) {
      try {
        subscription.cancel();
      } catch (e) {
        // Ignorer les erreurs de nettoyage
      }
    }
    _subscriptions.clear();
    
    for (final timer in _timers) {
      try {
        timer.cancel();
      } catch (e) {
        // Ignorer les erreurs de nettoyage
      }
    }
    _timers.clear();
    
    _objectPool.clear();
    _resourceCounts.clear();
    
    debugPrint('🧹 MemoryOptimizationService disposed');
  }
}