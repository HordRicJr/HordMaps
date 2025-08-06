import 'dart:async';
import 'package:flutter/foundation.dart';

/// Circuit breaker pattern pour protéger l'application des cascades d'erreurs réseau
/// Implémente un mécanisme de protection automatique contre les services défaillants
class ApiCircuitBreaker {
  static const int maxFailures = 3;
  static const Duration resetTimeout = Duration(minutes: 1);
  static const Duration halfOpenTimeout = Duration(seconds: 30);

  static bool _isOpen = false;
  static bool _isHalfOpen = false;
  static int _failureCount = 0;
  static DateTime? _lastFailureTime;
  static Timer? _resetTimer;

  /// État du circuit breaker
  static CircuitBreakerState get state {
    if (_isOpen) return CircuitBreakerState.open;
    if (_isHalfOpen) return CircuitBreakerState.halfOpen;
    return CircuitBreakerState.closed;
  }

  /// Exécute une opération avec protection circuit breaker
  static Future<T> execute<T>(
    String operationName,
    Future<T> Function() operation, {
    T? fallbackValue,
    Duration? customTimeout,
  }) async {
    // Vérifier si le circuit est ouvert
    if (_isCircuitOpen()) {
      debugPrint('🚫 Circuit breaker ouvert pour $operationName');
      if (fallbackValue != null) {
        return fallbackValue;
      }
      throw CircuitBreakerException(
        'Circuit breaker ouvert - service temporairement indisponible',
      );
    }

    // Tenter l'opération avec timeout
    try {
      final result = await operation().timeout(
        customTimeout ?? Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Timeout pour $operationName'),
      );

      _onSuccess();
      return result;
    } catch (e) {
      debugPrint('❌ Erreur circuit breaker pour $operationName: $e');
      _onFailure();

      if (fallbackValue != null) {
        return fallbackValue;
      }
      rethrow;
    }
  }

  /// Vérifie si le circuit est ouvert
  static bool _isCircuitOpen() {
    if (!_isOpen) return false;

    final now = DateTime.now();
    final timeSinceLastFailure = _lastFailureTime != null
        ? now.difference(_lastFailureTime!)
        : Duration.zero;

    // Passer en état half-open après le timeout
    if (timeSinceLastFailure >= resetTimeout) {
      _isHalfOpen = true;
      _isOpen = false;
      debugPrint('🔄 Circuit breaker passe en état half-open');

      // Timer pour revenir en état fermé
      _resetTimer?.cancel();
      _resetTimer = Timer(halfOpenTimeout, () {
        if (_failureCount == 0) {
          _closeCircuit();
        }
      });

      return false;
    }

    return true;
  }

  /// Gère le succès d'une opération
  static void _onSuccess() {
    if (_isHalfOpen) {
      _closeCircuit();
      debugPrint('✅ Circuit breaker fermé après succès');
    }
    _failureCount = 0;
  }

  /// Gère l'échec d'une opération
  static void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= maxFailures) {
      _openCircuit();
      debugPrint('🔴 Circuit breaker ouvert après $_failureCount échecs');
    }
  }

  /// Ouvre le circuit
  static void _openCircuit() {
    _isOpen = true;
    _isHalfOpen = false;

    // Timer pour essayer de fermer le circuit
    _resetTimer?.cancel();
    _resetTimer = Timer(resetTimeout, () {
      _isOpen = false;
      _isHalfOpen = true;
      debugPrint('🔄 Circuit breaker tente de se fermer');
    });
  }

  /// Ferme le circuit
  static void _closeCircuit() {
    _isOpen = false;
    _isHalfOpen = false;
    _failureCount = 0;
    _lastFailureTime = null;
    _resetTimer?.cancel();
  }

  /// Force la fermeture du circuit (pour tests ou reset manuel)
  static void reset() {
    _closeCircuit();
    debugPrint('🔄 Circuit breaker reset manuellement');
  }

  /// Statistiques du circuit breaker
  static CircuitBreakerStats getStats() {
    return CircuitBreakerStats(
      state: state,
      failureCount: _failureCount,
      lastFailureTime: _lastFailureTime,
      isOpen: _isOpen,
      isHalfOpen: _isHalfOpen,
    );
  }

  /// Nettoie les ressources
  static void dispose() {
    _resetTimer?.cancel();
    _resetTimer = null;
  }
}

/// États possibles du circuit breaker
enum CircuitBreakerState {
  closed, // Circuit fermé - opérations normales
  open, // Circuit ouvert - toutes les opérations échouent
  halfOpen, // Circuit semi-ouvert - test d'une opération
}

/// Exception levée quand le circuit breaker est ouvert
class CircuitBreakerException implements Exception {
  final String message;
  CircuitBreakerException(this.message);

  @override
  String toString() => 'CircuitBreakerException: $message';
}

/// Exception de timeout personnalisée
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

/// Statistiques du circuit breaker
class CircuitBreakerStats {
  final CircuitBreakerState state;
  final int failureCount;
  final DateTime? lastFailureTime;
  final bool isOpen;
  final bool isHalfOpen;

  CircuitBreakerStats({
    required this.state,
    required this.failureCount,
    required this.lastFailureTime,
    required this.isOpen,
    required this.isHalfOpen,
  });

  @override
  String toString() {
    return 'CircuitBreakerStats(state: $state, failures: $failureCount, open: $isOpen, halfOpen: $isHalfOpen)';
  }
}
