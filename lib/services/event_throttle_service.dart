import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Service de gestion optimisée des événements pour éviter les surcharges
class EventThrottleService extends ChangeNotifier {
  static final EventThrottleService _instance =
      EventThrottleService._internal();
  factory EventThrottleService() => _instance;
  EventThrottleService._internal();

  // Timers pour throttling des différents types d'événements
  final Map<String, Timer?> _throttleTimers = {};
  final Map<String, Completer<void>?> _debounceCompleters = {};
  final Map<String, dynamic> _lastValues = {};
  final Map<String, int> _eventCounts = {};
  final Map<String, DateTime> _lastEventTimes = {};

  // Configurations de throttling par type d'événement
  final Map<String, Duration> _throttleDurations = {
    'location_update': const Duration(milliseconds: 500),
    'map_move': const Duration(milliseconds: 100),
    'zoom_change': const Duration(milliseconds: 200),
    'rotation_change': const Duration(milliseconds: 150),
    'marker_update': const Duration(milliseconds: 300),
    'ui_update': const Duration(milliseconds: 16), // 60fps max
    'search_input': const Duration(milliseconds: 300),
    'network_request': const Duration(milliseconds: 1000),
    'animation_frame': const Duration(milliseconds: 16),
    'gesture_event': const Duration(milliseconds: 50),
  };

  // Limites d'événements par seconde
  final Map<String, int> _eventLimits = {
    'location_update': 2, // Max 2 mises à jour de position par seconde
    'map_move': 10, // Max 10 mouvements de carte par seconde
    'zoom_change': 5, // Max 5 changements de zoom par seconde
    'ui_update': 60, // Max 60 FPS
    'network_request': 1, // Max 1 requête réseau par seconde
    'gesture_event': 20, // Max 20 gestes par seconde
  };

  /// Throttle un événement pour éviter trop d'appels
  void throttle(String eventType, VoidCallback callback) {
    if (!_shouldProcessEvent(eventType)) {
      debugPrint('🚫 Événement $eventType throttlé (trop fréquent)');
      return;
    }

    _throttleTimers[eventType]?.cancel();

    final duration =
        _throttleDurations[eventType] ?? const Duration(milliseconds: 100);

    _throttleTimers[eventType] = Timer(duration, () {
      try {
        callback();
        _recordEvent(eventType);
      } catch (e) {
        debugPrint('❌ Erreur dans événement throttlé $eventType: $e');
      }
    });
  }

  /// Debounce un événement pour attendre la fin des appels multiples
  void debounce(String eventType, VoidCallback callback) {
    _debounceCompleters[eventType]?.complete();
    _debounceCompleters[eventType] = Completer<void>();

    final duration =
        _throttleDurations[eventType] ?? const Duration(milliseconds: 300);

    Timer(duration, () {
      if (!_debounceCompleters[eventType]!.isCompleted) {
        try {
          callback();
          _recordEvent(eventType);
          _debounceCompleters[eventType]!.complete();
        } catch (e) {
          debugPrint('❌ Erreur dans événement debouncé $eventType: $e');
          _debounceCompleters[eventType]!.completeError(e);
        }
      }
    });
  }

  /// Throttle avec valeur pour éviter les doublons
  void throttleWithValue<T>(
    String eventType,
    T value,
    void Function(T) callback,
  ) {
    if (_lastValues[eventType] == value) {
      debugPrint('🔄 Valeur identique pour $eventType, ignoré');
      return;
    }

    if (!_shouldProcessEvent(eventType)) {
      debugPrint('🚫 Événement $eventType throttlé (limite atteinte)');
      return;
    }

    _lastValues[eventType] = value;
    throttle(eventType, () => callback(value));
  }

  /// Exécute un callback sur le prochain frame pour éviter les blocages UI
  void scheduleNextFrame(String eventType, VoidCallback callback) {
    if (!_shouldProcessEvent('animation_frame')) {
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      try {
        callback();
        _recordEvent(eventType);
      } catch (e) {
        debugPrint('❌ Erreur dans frame callback $eventType: $e');
      }
    });
  }

  /// Traite un événement avec limitation de fréquence
  bool _shouldProcessEvent(String eventType) {
    final now = DateTime.now();
    final lastTime = _lastEventTimes[eventType];
    final limit = _eventLimits[eventType] ?? 10;

    // Réinitialiser le compteur chaque seconde
    if (lastTime == null || now.difference(lastTime).inSeconds >= 1) {
      _eventCounts[eventType] = 0;
      _lastEventTimes[eventType] = now;
    }

    final currentCount = _eventCounts[eventType] ?? 0;
    if (currentCount >= limit) {
      return false; // Limite atteinte
    }

    return true;
  }

  /// Enregistre qu'un événement a été traité
  void _recordEvent(String eventType) {
    _eventCounts[eventType] = (_eventCounts[eventType] ?? 0) + 1;
    _lastEventTimes[eventType] = DateTime.now();
  }

  /// Obtient les statistiques des événements
  Map<String, int> getEventStats() {
    return Map.from(_eventCounts);
  }

  /// Réinitialise les statistiques
  void resetStats() {
    _eventCounts.clear();
    _lastEventTimes.clear();
    debugPrint('📊 Statistiques d\'événements réinitialisées');
  }

  /// Nettoie tous les timers
  @override
  void dispose() {
    for (final timer in _throttleTimers.values) {
      timer?.cancel();
    }
    _throttleTimers.clear();
    _debounceCompleters.clear();
    _lastValues.clear();
    _eventCounts.clear();
    _lastEventTimes.clear();
    super.dispose();
  }
}

/// Service de gestion de la mémoire pour éviter les fuites
class MemoryOptimizationService {
  static final MemoryOptimizationService _instance =
      MemoryOptimizationService._internal();
  factory MemoryOptimizationService() => _instance;
  MemoryOptimizationService._internal();

  final Set<StreamSubscription> _subscriptions = <StreamSubscription>{};
  final Set<Timer> _timers = <Timer>{};
  final Queue<dynamic> _objectPool = Queue<dynamic>();
  final int _maxPoolSize = 100;

  /// Enregistre une souscription pour nettoyage automatique
  void registerSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Enregistre un timer pour nettoyage automatique
  void registerTimer(Timer timer) {
    _timers.add(timer);
  }

  /// Ajoute un objet au pool de réutilisation
  void returnToPool(dynamic object) {
    if (_objectPool.length < _maxPoolSize) {
      _objectPool.add(object);
    }
  }

  /// Récupère un objet du pool ou crée un nouveau
  T getFromPool<T>(T Function() factory) {
    if (_objectPool.isNotEmpty) {
      final obj = _objectPool.removeFirst();
      if (obj is T) {
        return obj;
      }
    }
    return factory();
  }

  /// Force le garbage collection (avec prudence)
  void forceGarbageCollection() {
    // Nettoyer les subscriptions fermées
    _subscriptions.removeWhere((sub) => sub.isPaused);

    // Nettoyer les timers inactifs
    _timers.removeWhere((timer) => !timer.isActive);

    debugPrint(
      '🧹 Nettoyage mémoire effectué - ${_subscriptions.length} subscriptions, ${_timers.length} timers actifs',
    );
  }

  /// Nettoie toutes les ressources
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    _objectPool.clear();
    debugPrint('🧹 MemoryOptimizationService disposed');
  }
}

/// Extensions pour simplifier l'utilisation
extension ThrottleExtensions on VoidCallback {
  void throttled(String eventType) {
    EventThrottleService().throttle(eventType, this);
  }

  void debounced(String eventType) {
    EventThrottleService().debounce(eventType, this);
  }

  void nextFrame(String eventType) {
    EventThrottleService().scheduleNextFrame(eventType, this);
  }
}

extension ValueThrottleExtensions<T> on void Function(T) {
  void throttledWithValue(String eventType, T value) {
    EventThrottleService().throttleWithValue(eventType, value, this);
  }
}
