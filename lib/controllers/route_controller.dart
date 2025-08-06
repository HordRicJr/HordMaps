import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

import '../models/transport_models.dart';
import '../models/navigation_models.dart';
import '../services/osm_routing_service.dart';
import '../services/cache_service.dart';

/// Controller MVC pour la gestion des routes et navigation
class RouteController extends ChangeNotifier {
  static RouteController? _instance;
  static RouteController get instance => _instance ??= RouteController._();
  RouteController._();

  // État privé
  RouteOptions _currentOptions = RouteOptions(
    transportMode: TransportMode.allModes.first,
  );
  RouteResult? _currentRoute;
  bool _isCalculating = false;
  String? _lastError;
  LatLng? _startPoint;
  LatLng? _endPoint;
  String _startAddress = '';
  String _endAddress = '';

  // Services
  final CacheService _cacheService = CacheService.instance;

  // Getters publics
  RouteOptions get currentOptions => _currentOptions;
  RouteResult? get currentRoute => _currentRoute;
  bool get isCalculating => _isCalculating;
  String? get lastError => _lastError;
  LatLng? get startPoint => _startPoint;
  LatLng? get endPoint => _endPoint;
  String get startAddress => _startAddress;
  String get endAddress => _endAddress;
  bool get hasValidRoute =>
      _currentRoute != null && _startPoint != null && _endPoint != null;

  /// Met à jour les options de route
  Future<void> updateRouteOptions(RouteOptions newOptions) async {
    if (_currentOptions.transportMode.id != newOptions.transportMode.id ||
        _currentOptions.avoidTolls != newOptions.avoidTolls ||
        _currentOptions.avoidHighways != newOptions.avoidHighways) {
      _currentOptions = newOptions;
      notifyListeners();

      // Recalculer automatiquement si on a des points
      if (_startPoint != null && _endPoint != null) {
        await calculateRoute(_startPoint!, _endPoint!);
      }
    }
  }

  /// Met à jour le mode de transport
  Future<void> setTransportMode(TransportMode mode) async {
    await updateRouteOptions(_currentOptions.copyWith(transportMode: mode));
  }

  /// Met à jour les points de départ et d'arrivée
  Future<void> setRoutePoints({
    LatLng? start,
    LatLng? end,
    String? startAddr,
    String? endAddr,
  }) async {
    bool shouldRecalculate = false;

    if (start != null && start != _startPoint) {
      _startPoint = start;
      _startAddress = startAddr ?? '';
      shouldRecalculate = true;
    }

    if (end != null && end != _endPoint) {
      _endPoint = end;
      _endAddress = endAddr ?? '';
      shouldRecalculate = true;
    }

    notifyListeners();

    if (shouldRecalculate && _startPoint != null && _endPoint != null) {
      await calculateRoute(_startPoint!, _endPoint!);
    }
  }

  /// Calcule une route entre deux points
  Future<bool> calculateRoute(
    LatLng start,
    LatLng end, {
    String? startAddr,
    String? endAddr,
  }) async {
    try {
      _isCalculating = true;
      _lastError = null;
      notifyListeners();

      // Mettre à jour les points
      _startPoint = start;
      _endPoint = end;
      _startAddress = startAddr ?? _startAddress;
      _endAddress = endAddr ?? _endAddress;

      // Vérifier le cache d'abord
      final cacheKey =
          '${start.latitude},${start.longitude}-${end.latitude},${end.longitude}-${_currentOptions.transportMode.id}';
      final cachedRoute = await _cacheService.getRoute(cacheKey);

      if (cachedRoute != null) {
        _currentRoute = cachedRoute;
        _isCalculating = false;
        notifyListeners();
        return true;
      }

      // Calculer nouvelle route
      final result =
          await OpenStreetMapRoutingService.calculateRoute(
            start: start,
            end: end,
            transportMode: _currentOptions.transportMode.id,
            avoidTolls: _currentOptions.avoidTolls,
            avoidHighways: _currentOptions.avoidHighways,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Timeout lors du calcul de la route',
                const Duration(seconds: 30),
              );
            },
          );

      // Le résultat est toujours RouteResult
      _currentRoute = result;

      // Sauvegarder en cache
      await _cacheService.saveRoute(cacheKey, result);

      _isCalculating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Erreur: ${e.toString()}';
      _currentRoute = null;
      debugPrint('Erreur calcul route: $e');
    } finally {
      _isCalculating = false;
      notifyListeners();
    }

    return false;
  }

  /// Efface la route actuelle
  void clearRoute() {
    _currentRoute = null;
    _startPoint = null;
    _endPoint = null;
    _startAddress = '';
    _endAddress = '';
    _lastError = null;
    notifyListeners();
  }

  /// Inverse les points de départ et d'arrivée
  Future<void> reverseRoute() async {
    if (_startPoint != null && _endPoint != null) {
      final tempPoint = _startPoint;
      final tempAddr = _startAddress;

      await setRoutePoints(
        start: _endPoint,
        end: tempPoint,
        startAddr: _endAddress,
        endAddr: tempAddr,
      );
    }
  }

  /// Obtient les routes alternatives
  Future<List<RouteResult>> getAlternativeRoutes() async {
    if (_startPoint == null || _endPoint == null) return [];

    try {
      final alternatives = <RouteResult>[];

      // Calculer avec différentes options
      for (final mode in TransportMode.allModes.where((m) => m.isAvailable)) {
        if (mode.id != _currentOptions.transportMode.id) {
          final result = await OpenStreetMapRoutingService.calculateRoute(
            start: _startPoint!,
            end: _endPoint!,
            transportMode: mode.id,
          );

          alternatives.add(result);
        }
      }

      return alternatives;
    } catch (e) {
      debugPrint('Erreur alternatives: $e');
      return [];
    }
  }

  /// Mappe les modes de transport vers les profils OSM
  /// Sauvegarde l'état actuel
  Future<void> saveState() async {
    try {
      final state = {
        'options': _currentOptions.toJson(),
        'startPoint': _startPoint != null
            ? {'lat': _startPoint!.latitude, 'lng': _startPoint!.longitude}
            : null,
        'endPoint': _endPoint != null
            ? {'lat': _endPoint!.latitude, 'lng': _endPoint!.longitude}
            : null,
        'startAddress': _startAddress,
        'endAddress': _endAddress,
      };

      await _cacheService.saveData('route_controller_state', state);
    } catch (e) {
      debugPrint('Erreur sauvegarde état: $e');
    }
  }

  /// Restaure l'état sauvegardé
  Future<void> restoreState() async {
    try {
      final state = await _cacheService.getData('route_controller_state');
      if (state != null) {
        _currentOptions = RouteOptions.fromJson(state['options'] ?? {});

        if (state['startPoint'] != null) {
          _startPoint = LatLng(
            state['startPoint']['lat'],
            state['startPoint']['lng'],
          );
          _startAddress = state['startAddress'] ?? '';
        }

        if (state['endPoint'] != null) {
          _endPoint = LatLng(
            state['endPoint']['lat'],
            state['endPoint']['lng'],
          );
          _endAddress = state['endAddress'] ?? '';
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur restauration état: $e');
    }
  }

  @override
  void dispose() {
    saveState();
    super.dispose();
  }
}
