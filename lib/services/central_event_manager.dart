import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Gestionnaire central pour tous les événements de l'application
/// Assure la cohérence et évite les conflits entre services
class CentralEventManager extends ChangeNotifier {
  static final CentralEventManager _instance = CentralEventManager._internal();
  factory CentralEventManager() => _instance;
  CentralEventManager._internal();

  // Registre de tous les timers actifs pour éviter les conflits
  final Map<String, Timer> _activeTimers = {};
  final Map<String, StreamSubscription> _activeSubscriptions = {};

  // Queue d'événements prioritaires
  final Queue<_PriorityEvent> _eventQueue = Queue<_PriorityEvent>();
  bool _isProcessingEvents = false;

  // Limites globales pour éviter les surcharges
  static const int _maxConcurrentTimers = 15;
  static const int _maxConcurrentSubscriptions = 20;
  static const int _maxEventQueueSize = 100;

  /// Enregistre un timer de manière sécurisée
  Timer? registerTimer(
    String key,
    Duration duration,
    VoidCallback callback, {
    int priority = 5,
  }) {
    // Vérifier les limites
    if (_activeTimers.length >= _maxConcurrentTimers) {
      debugPrint('⚠️ Limite de timers atteinte ($key ignoré)');
      return null;
    }

    // Annuler le timer existant s'il y en a un
    _activeTimers[key]?.cancel();

    // Créer le nouveau timer avec wrapper de sécurité
    _activeTimers[key] = Timer(duration, () {
      try {
        callback();
      } catch (e) {
        debugPrint('❌ Erreur dans timer $key: $e');
      } finally {
        _activeTimers.remove(key);
      }
    });

    debugPrint('⏱️ Timer enregistré: $key (${_activeTimers.length} actifs)');
    return _activeTimers[key];
  }

  /// Enregistre un timer périodique de manière sécurisée
  Timer? registerPeriodicTimer(
    String key,
    Duration duration,
    void Function(Timer) callback, {
    int priority = 5,
  }) {
    // Vérifier les limites
    if (_activeTimers.length >= _maxConcurrentTimers) {
      debugPrint('⚠️ Limite de timers atteinte ($key ignoré)');
      return null;
    }

    // Annuler le timer existant
    _activeTimers[key]?.cancel();

    // Créer le timer périodique avec wrapper de sécurité
    _activeTimers[key] = Timer.periodic(duration, (timer) {
      try {
        callback(timer);
      } catch (e) {
        debugPrint('❌ Erreur dans timer périodique $key: $e');
        timer.cancel();
        _activeTimers.remove(key);
      }
    });

    debugPrint(
      '🔄 Timer périodique enregistré: $key (${_activeTimers.length} actifs)',
    );
    return _activeTimers[key];
  }

  /// Enregistre une subscription de manière sécurisée
  StreamSubscription<T>? registerSubscription<T>(
    String key,
    Stream<T> stream,
    void Function(T) onData, {
    Function? onError,
    VoidCallback? onDone,
    int priority = 5,
  }) {
    // Vérifier les limites
    if (_activeSubscriptions.length >= _maxConcurrentSubscriptions) {
      debugPrint('⚠️ Limite de subscriptions atteinte ($key ignoré)');
      return null;
    }

    // Annuler la subscription existante
    _activeSubscriptions[key]?.cancel();

    // Créer la nouvelle subscription avec wrapper de sécurité
    _activeSubscriptions[key] = stream.listen(
      (data) {
        try {
          onData(data);
        } catch (e) {
          debugPrint('❌ Erreur dans subscription $key: $e');
        }
      },
      onError: (error) {
        debugPrint('❌ Erreur stream $key: $error');
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            debugPrint('❌ Erreur handler $key: $e');
          }
        }
      },
      onDone: () {
        _activeSubscriptions.remove(key);
        debugPrint('✅ Subscription $key terminée');
        if (onDone != null) {
          try {
            onDone();
          } catch (e) {
            debugPrint('❌ Erreur onDone $key: $e');
          }
        }
      },
    );

    debugPrint(
      '📡 Subscription enregistrée: $key (${_activeSubscriptions.length} actives)',
    );
    return _activeSubscriptions[key] as StreamSubscription<T>?;
  }

  /// Ajoute un événement à la queue avec priorité
  void queueEvent(String eventType, VoidCallback callback, {int priority = 5}) {
    if (_eventQueue.length >= _maxEventQueueSize) {
      debugPrint('⚠️ Queue d\'événements pleine, suppression du plus ancien');
      _eventQueue.removeFirst();
    }

    _eventQueue.add(_PriorityEvent(eventType, callback, priority));

    // Démarrer le traitement si pas déjà en cours
    if (!_isProcessingEvents) {
      _processEventQueue();
    }
  }

  /// Traite la queue d'événements par ordre de priorité
  Future<void> _processEventQueue() async {
    if (_isProcessingEvents) return;

    _isProcessingEvents = true;

    while (_eventQueue.isNotEmpty) {
      // Trier par priorité (plus haut = plus prioritaire)
      final sortedEvents = _eventQueue.toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));

      _eventQueue.clear();
      _eventQueue.addAll(sortedEvents);

      final event = _eventQueue.removeFirst();

      try {
        event.callback();

        // Petite pause pour éviter de bloquer l'UI
        await Future.delayed(const Duration(microseconds: 100));
      } catch (e) {
        debugPrint('❌ Erreur dans événement ${event.type}: $e');
      }
    }

    _isProcessingEvents = false;
  }

  /// Annule un timer spécifique
  bool cancelTimer(String key) {
    final timer = _activeTimers[key];
    if (timer != null) {
      timer.cancel();
      _activeTimers.remove(key);
      debugPrint('🛑 Timer $key annulé');
      return true;
    }
    return false;
  }

  /// Annule une subscription spécifique
  bool cancelSubscription(String key) {
    final subscription = _activeSubscriptions[key];
    if (subscription != null) {
      subscription.cancel();
      _activeSubscriptions.remove(key);
      debugPrint('🛑 Subscription $key annulée');
      return true;
    }
    return false;
  }

  /// Annule tous les timers d'un type spécifique
  void cancelTimersByPrefix(String prefix) {
    final keysToRemove = _activeTimers.keys
        .where((key) => key.startsWith(prefix))
        .toList();

    for (final key in keysToRemove) {
      cancelTimer(key);
    }

    if (keysToRemove.isNotEmpty) {
      debugPrint('🛑 ${keysToRemove.length} timers $prefix* annulés');
    }
  }

  /// Annule toutes les subscriptions d'un type spécifique
  void cancelSubscriptionsByPrefix(String prefix) {
    final keysToRemove = _activeSubscriptions.keys
        .where((key) => key.startsWith(prefix))
        .toList();

    for (final key in keysToRemove) {
      cancelSubscription(key);
    }

    if (keysToRemove.isNotEmpty) {
      debugPrint('🛑 ${keysToRemove.length} subscriptions $prefix* annulées');
    }
  }

  /// Obtient les statistiques d'utilisation
  Map<String, dynamic> getStats() {
    return {
      'activeTimers': _activeTimers.length,
      'activeSubscriptions': _activeSubscriptions.length,
      'queuedEvents': _eventQueue.length,
      'timerKeys': _activeTimers.keys.toList(),
      'subscriptionKeys': _activeSubscriptions.keys.toList(),
      'maxTimers': _maxConcurrentTimers,
      'maxSubscriptions': _maxConcurrentSubscriptions,
    };
  }

  /// Nettoie tous les timers et subscriptions inactifs
  void cleanup() {
    final timersBefore = _activeTimers.length;
    final subscriptionsBefore = _activeSubscriptions.length;

    // Nettoyer les timers inactifs
    _activeTimers.removeWhere((key, timer) {
      if (!timer.isActive) {
        debugPrint('🧹 Timer inactif supprimé: $key');
        return true;
      }
      return false;
    });

    // Les subscriptions se nettoient automatiquement via onDone

    // Vider la queue d'événements si elle est trop ancienne
    _eventQueue.clear();

    final timersAfter = _activeTimers.length;
    final subscriptionsAfter = _activeSubscriptions.length;

    debugPrint(
      '🧹 Nettoyage effectué: ${timersBefore - timersAfter} timers, '
      '${subscriptionsBefore - subscriptionsAfter} subscriptions supprimés',
    );
  }

  /// Arrête tout et nettoie complètement
  void shutdown() {
    debugPrint('🛑 Arrêt du gestionnaire central d\'événements...');

    // Annuler tous les timers
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();

    // Annuler toutes les subscriptions
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();

    // Vider la queue
    _eventQueue.clear();
    _isProcessingEvents = false;

    debugPrint('✅ Gestionnaire central arrêté proprement');
  }

  /// Vérifie la santé du système
  bool isHealthy() {
    final stats = getStats();
    return stats['activeTimers'] < _maxConcurrentTimers &&
        stats['activeSubscriptions'] < _maxConcurrentSubscriptions &&
        stats['queuedEvents'] < _maxEventQueueSize;
  }

  /// Log des informations de debug
  void logStatus() {
    final stats = getStats();
    debugPrint('📊 État du gestionnaire central:');
    debugPrint(
      '   - Timers actifs: ${stats['activeTimers']}/$_maxConcurrentTimers',
    );
    debugPrint(
      '   - Subscriptions actives: ${stats['activeSubscriptions']}/$_maxConcurrentSubscriptions',
    );
    debugPrint(
      '   - Événements en queue: ${stats['queuedEvents']}/$_maxEventQueueSize',
    );
    debugPrint('   - Santé: ${isHealthy() ? '✅ OK' : '⚠️ PROBLÈME'}');
  }
}

/// Classe interne pour les événements prioritaires
class _PriorityEvent {
  final String type;
  final VoidCallback callback;
  final int priority;
  final DateTime createdAt;

  _PriorityEvent(this.type, this.callback, this.priority)
    : createdAt = DateTime.now();
}

/// Extension pour faciliter l'utilisation dans les services
extension ServiceEventManagerExtension on ChangeNotifier {
  /// Helper pour enregistrer un timer via le gestionnaire central
  Timer? registerManagedTimer(
    String key,
    Duration duration,
    VoidCallback callback,
  ) {
    return CentralEventManager().registerTimer(key, duration, callback);
  }

  /// Helper pour enregistrer un timer périodique via le gestionnaire central
  Timer? registerManagedPeriodicTimer(
    String key,
    Duration duration,
    void Function(Timer) callback,
  ) {
    return CentralEventManager().registerPeriodicTimer(key, duration, callback);
  }

  /// Helper pour enregistrer une subscription via le gestionnaire central
  StreamSubscription<T>? registerManagedSubscription<T>(
    String key,
    Stream<T> stream,
    void Function(T) onData,
  ) {
    return CentralEventManager().registerSubscription(key, stream, onData);
  }

  /// Helper pour nettoyer les ressources d'un service
  void cleanupServiceResources(String servicePrefix) {
    final manager = CentralEventManager();
    manager.cancelTimersByPrefix(servicePrefix);
    manager.cancelSubscriptionsByPrefix(servicePrefix);
  }
}
