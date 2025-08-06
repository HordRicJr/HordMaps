import 'package:flutter/foundation.dart';
import 'event_throttle_service.dart';

/// Mixin pour intégrer automatiquement le throttling dans les services
mixin ThrottledNotificationMixin on ChangeNotifier {
  /// Service de throttling partagé
  final EventThrottleService _throttleService = EventThrottleService();

  /// Notifie avec throttling selon le contexte
  void notifyWithThrottling(String eventType) {
    _throttleService.throttle(eventType, () => notifyListeners());
  }

  /// Notifications spécialisées par type d'événement
  void notifyLocationChange() => notifyWithThrottling('location_update');
  void notifyUIUpdate() => notifyWithThrottling('ui_update');
  void notifyMapChange() => notifyWithThrottling('map_move');
  void notifySearchChange() => notifyWithThrottling('search_result');
  void notifyNavigationChange() => notifyWithThrottling('navigation_update');
  void notifyDataChange() => notifyWithThrottling('data_update');
  void notifyStreamChange() => notifyWithThrottling('stream_update');
  void notifyGestureChange() => notifyWithThrottling('gesture_event');
  void notifyUserActionChange() => notifyWithThrottling('user_action');
  void notifyNetworkChange() => notifyWithThrottling('network_request');
}

/// Helper pour throttler les setState dans les StatefulWidget
class StatefulWidgetThrottleHelper {
  static final EventThrottleService _service = EventThrottleService();

  /// Throttle setState pour éviter les reconstructions excessives
  static void throttledSetState(
    void Function() setState, {
    String eventType = 'ui_update',
  }) {
    _service.throttle(eventType, setState);
  }

  /// Helpers spécialisés
  static void throttledMapSetState(void Function() setState) {
    throttledSetState(setState, eventType: 'map_move');
  }

  static void throttledSearchSetState(void Function() setState) {
    throttledSetState(setState, eventType: 'search_result');
  }

  static void throttledNavigationSetState(void Function() setState) {
    throttledSetState(setState, eventType: 'navigation_update');
  }

  static void throttledGestureSetState(void Function() setState) {
    throttledSetState(setState, eventType: 'gesture_event');
  }
}

/// Configuration globale pour l'intégration du throttling
class EventThrottleConfig {
  /// Active le throttling global pour tous les ChangeNotifier
  static bool globalThrottlingEnabled = true;

  /// Délais par défaut pour différents types d'événements (en ms)
  static const Map<String, int> defaultDelays = {
    'location_update': 500, // GPS updates
    'map_move': 100, // Map movement
    'ui_update': 16, // 60 FPS UI updates
    'search_result': 300, // Search results
    'navigation_update': 200, // Navigation updates
    'data_update': 250, // Data loading
    'stream_update': 150, // Stream events
    'gesture_event': 50, // User gestures
    'user_action': 100, // User actions
    'network_request': 1000, // Network requests
  };

  /// Retourne le délai configuré pour un type d'événement
  static int getDelay(String eventType) {
    return defaultDelays[eventType] ?? 100;
  }

  /// Met à jour la configuration des délais
  static void updateDelay(String eventType, int delayMs) {
    // Note: Cette méthode pourrait être étendue pour persister les configurations
    debugPrint('Configuration throttling: $eventType = ${delayMs}ms');
  }
}

/// Decorator pattern pour wrapper automatiquement les méthodes avec throttling
class ThrottledMethodWrapper {
  final EventThrottleService _throttleService = EventThrottleService();

  /// Wrapper générique pour throttler n'importe quelle méthode
  void throttledCall(String eventType, void Function() method) {
    _throttleService.throttle(eventType, method);
  }

  /// Wrappers spécialisés
  void throttledLocationUpdate(void Function() method) {
    throttledCall('location_update', method);
  }

  void throttledMapUpdate(void Function() method) {
    throttledCall('map_move', method);
  }

  void throttledSearchUpdate(void Function() method) {
    throttledCall('search_result', method);
  }

  void throttledNavigationUpdate(void Function() method) {
    throttledCall('navigation_update', method);
  }

  void throttledUIUpdate(void Function() method) {
    throttledCall('ui_update', method);
  }
}

/// Service de surveillance pour détecter les surcharges d'événements
class EventOverloadDetector {
  static final Map<String, List<DateTime>> _eventHistory = {};
  static const int _windowSizeMs = 1000; // Fenêtre d'1 seconde
  static const int _warningThreshold = 50; // Plus de 50 événements/seconde

  /// Enregistre un événement et vérifie les surcharges
  static void recordEvent(String eventType) {
    final now = DateTime.now();
    _eventHistory[eventType] ??= [];

    // Nettoyer l'historique (garder seulement la dernière seconde)
    _eventHistory[eventType]!.removeWhere(
      (time) => now.difference(time).inMilliseconds > _windowSizeMs,
    );

    // Ajouter l'événement actuel
    _eventHistory[eventType]!.add(now);

    // Vérifier la surcharge
    if (_eventHistory[eventType]!.length > _warningThreshold) {
      debugPrint(
        '⚠️ SURCHARGE DÉTECTÉE: $eventType (${_eventHistory[eventType]!.length} événements/seconde)',
      );

      // Recommander l'augmentation du throttling
      final currentDelay = EventThrottleConfig.getDelay(eventType);
      final recommendedDelay = (currentDelay * 1.5).round();
      debugPrint(
        '💡 Recommandation: Augmenter le délai de throttling de ${currentDelay}ms à ${recommendedDelay}ms',
      );
    }
  }

  /// Obtient les statistiques d'événements pour le diagnostic
  static Map<String, int> getEventStats() {
    final stats = <String, int>{};
    _eventHistory.forEach((eventType, events) {
      stats[eventType] = events.length;
    });
    return stats;
  }

  /// Remet à zéro les statistiques
  static void resetStats() {
    _eventHistory.clear();
  }
}
