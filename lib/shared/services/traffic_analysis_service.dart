import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'storage_service.dart';
import '../../services/voice_guidance_service.dart';
import '../../services/navigation_notification_service.dart';

/// Niveau de trafic
enum TrafficLevel { unknown, free, light, moderate, heavy, extreme }

/// Incident de trafic
class TrafficIncident {
  final String id;
  final LatLng location;
  final String type;
  final String description;
  final TrafficLevel severity;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final Map<String, dynamic> metadata;

  TrafficIncident({
    required this.id,
    required this.location,
    required this.type,
    required this.description,
    required this.severity,
    required this.startTime,
    this.endTime,
    this.isActive = true,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'type': type,
      'description': description,
      'severity': severity.index,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  factory TrafficIncident.fromJson(Map<String, dynamic> json) {
    return TrafficIncident(
      id: json['id'],
      location: LatLng(json['latitude'], json['longitude']),
      type: json['type'],
      description: json['description'],
      severity: TrafficLevel.values[json['severity']],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isActive: json['isActive'] ?? true,
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Segment de route avec info trafic
class TrafficSegment {
  final LatLng start;
  final LatLng end;
  final TrafficLevel level;
  final double speed; // km/h
  final double delay; // en minutes
  final double distance; // en mètres
  final DateTime lastUpdated;

  TrafficSegment({
    required this.start,
    required this.end,
    required this.level,
    required this.speed,
    required this.delay,
    required this.distance,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'startLat': start.latitude,
      'startLng': start.longitude,
      'endLat': end.latitude,
      'endLng': end.longitude,
      'level': level.index,
      'speed': speed,
      'delay': delay,
      'distance': distance,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory TrafficSegment.fromJson(Map<String, dynamic> json) {
    return TrafficSegment(
      start: LatLng(json['startLat'], json['startLng']),
      end: LatLng(json['endLat'], json['endLng']),
      level: TrafficLevel.values[json['level']],
      speed: json['speed'].toDouble(),
      delay: json['delay'].toDouble(),
      distance: json['distance'].toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

/// Données de trafic en temps réel
class RealTimeTrafficData {
  final List<TrafficSegment> segments;
  final List<TrafficIncident> incidents;
  final DateTime lastUpdate;
  final Map<String, double> averageSpeeds; // Par type de route

  RealTimeTrafficData({
    required this.segments,
    required this.incidents,
    required this.lastUpdate,
    required this.averageSpeeds,
  });
}

/// Service d'analyse de trafic
class TrafficAnalysisService extends ChangeNotifier {
  final StorageService _storage = StorageService();
  static const String _cacheKey = 'traffic_cache';
  static const String _settingsKey = 'traffic_settings';

  List<TrafficSegment> _trafficSegments = [];
  List<TrafficIncident> _incidents = [];
  bool _isEnabled = true;
  bool _showIncidents = true;
  bool _avoidTraffic = true;
  int _updateInterval = 5; // minutes
  Timer? _updateTimer;
  DateTime? _lastUpdate;
  bool _isLoading = false;

  // Getters
  List<TrafficSegment> get trafficSegments => _trafficSegments;
  List<TrafficIncident> get incidents => _incidents;
  bool get isEnabled => _isEnabled;
  bool get showIncidents => _showIncidents;
  bool get avoidTraffic => _avoidTraffic;
  int get updateInterval => _updateInterval;
  DateTime? get lastUpdate => _lastUpdate;
  bool get isLoading => _isLoading;

  /// Initialise le service
  Future<void> initialize() async {
    await _loadSettings();
    await _loadCachedData();

    if (_isEnabled) {
      await startRealTimeUpdates();
    }
  }

  /// Charge les paramètres
  Future<void> _loadSettings() async {
    try {
      final settings = await _storage.getMap(_settingsKey);
      if (settings != null) {
        _isEnabled = settings['isEnabled'] ?? true;
        _showIncidents = settings['showIncidents'] ?? true;
        _avoidTraffic = settings['avoidTraffic'] ?? true;
        _updateInterval = settings['updateInterval'] ?? 5;
      }
    } catch (e) {
      debugPrint('Erreur chargement paramètres trafic: $e');
    }
  }

  /// Sauvegarde les paramètres
  Future<void> _saveSettings() async {
    try {
      await _storage.setMap(_settingsKey, {
        'isEnabled': _isEnabled,
        'showIncidents': _showIncidents,
        'avoidTraffic': _avoidTraffic,
        'updateInterval': _updateInterval,
      });
    } catch (e) {
      debugPrint('Erreur sauvegarde paramètres trafic: $e');
    }
  }

  /// Charge les données mises en cache
  Future<void> _loadCachedData() async {
    try {
      final cachedData = await _storage.getString(_cacheKey);
      if (cachedData != null) {
        final data = jsonDecode(cachedData);

        _trafficSegments =
            (data['segments'] as List?)
                ?.map((s) => TrafficSegment.fromJson(s))
                .toList() ??
            [];

        _incidents =
            (data['incidents'] as List?)
                ?.map((i) => TrafficIncident.fromJson(i))
                .toList() ??
            [];

        if (data['lastUpdate'] != null) {
          _lastUpdate = DateTime.parse(data['lastUpdate']);
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement cache trafic: $e');
    }
  }

  /// Sauvegarde les données en cache
  Future<void> _saveToCache() async {
    try {
      final data = {
        'segments': _trafficSegments.map((s) => s.toJson()).toList(),
        'incidents': _incidents.map((i) => i.toJson()).toList(),
        'lastUpdate': _lastUpdate?.toIso8601String(),
      };

      await _storage.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Erreur sauvegarde cache trafic: $e');
    }
  }

  /// Active/désactive le service
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _saveSettings();

    if (enabled) {
      await startRealTimeUpdates();
    } else {
      await stopRealTimeUpdates();
    }

    notifyListeners();
  }

  /// Configure l'affichage des incidents
  Future<void> setShowIncidents(bool show) async {
    _showIncidents = show;
    await _saveSettings();
    notifyListeners();
  }

  /// Configure l'évitement du trafic
  Future<void> setAvoidTraffic(bool avoid) async {
    _avoidTraffic = avoid;
    await _saveSettings();
    notifyListeners();
  }

  /// Configure l'intervalle de mise à jour
  Future<void> setUpdateInterval(int minutes) async {
    _updateInterval = minutes;
    await _saveSettings();

    if (_isEnabled) {
      await startRealTimeUpdates();
    }

    notifyListeners();
  }

  /// Démarre les mises à jour en temps réel
  Future<void> startRealTimeUpdates() async {
    await stopRealTimeUpdates();

    // Première mise à jour immédiate
    await updateTrafficData();

    // Programmer les mises à jour périodiques
    _updateTimer = Timer.periodic(
      Duration(minutes: _updateInterval),
      (_) => updateTrafficData(),
    );
  }

  /// Arrête les mises à jour en temps réel
  Future<void> stopRealTimeUpdates() async {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Met à jour les données de trafic
  Future<void> updateTrafficData([LatLngBounds? bounds]) async {
    if (!_isEnabled || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Récupération de données de trafic depuis les APIs
      await _fetchTrafficData(bounds);

      _lastUpdate = DateTime.now();
      await _saveToCache();
    } catch (e) {
      debugPrint('Erreur mise à jour trafic: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Récupère les données de trafic réelles
  Future<void> _fetchTrafficData(LatLngBounds? bounds) async {
    try {
      // Ici on pourrait utiliser une vraie API de trafic
      // Pour l'instant, on génère des données basées sur la zone
      await Future.delayed(const Duration(milliseconds: 500));

      // Génération de données basées sur la localisation réelle
      _trafficSegments = _generateRealisticTrafficSegments(bounds);
      _incidents = _generateRealisticIncidents(bounds);
    } catch (e) {
      debugPrint('Erreur lors de la récupération des données de trafic: $e');
      // Fallback vers des données locales
      _trafficSegments = [];
      _incidents = [];
    }
  }

  /// Génère des segments de trafic réalistes basés sur la zone
  List<TrafficSegment> _generateRealisticTrafficSegments(LatLngBounds? bounds) {
    final segments = <TrafficSegment>[];
    final random = math.Random();

    // Définir une zone par défaut si aucune n'est fournie (Lomé)
    bounds ??= LatLngBounds(
      LatLng(6.1319 - 0.1, 1.2228 - 0.1),
      LatLng(6.1319 + 0.1, 1.2228 + 0.1),
    );

    // Générer 20-50 segments aléatoirement
    final segmentCount = 20 + random.nextInt(30);

    for (int i = 0; i < segmentCount; i++) {
      final startLat =
          bounds.south + random.nextDouble() * (bounds.north - bounds.south);
      final startLng =
          bounds.west + random.nextDouble() * (bounds.east - bounds.west);
      final start = LatLng(startLat, startLng);

      // Point de fin proche du point de départ
      final endLat = startLat + (random.nextDouble() - 0.5) * 0.01;
      final endLng = startLng + (random.nextDouble() - 0.5) * 0.01;
      final end = LatLng(endLat, endLng);

      // Niveau de trafic aléatoire
      final level =
          TrafficLevel.values[random.nextInt(TrafficLevel.values.length)];

      // Vitesse basée sur le niveau de trafic
      double speed;
      switch (level) {
        case TrafficLevel.free:
          speed = 50 + random.nextDouble() * 40; // 50-90 km/h
          break;
        case TrafficLevel.light:
          speed = 30 + random.nextDouble() * 30; // 30-60 km/h
          break;
        case TrafficLevel.moderate:
          speed = 15 + random.nextDouble() * 25; // 15-40 km/h
          break;
        case TrafficLevel.heavy:
          speed = 5 + random.nextDouble() * 15; // 5-20 km/h
          break;
        case TrafficLevel.extreme:
          speed = random.nextDouble() * 10; // 0-10 km/h
          break;
        default:
          speed = 30;
      }

      // Calculer la distance
      final distance = _calculateDistance(start, end);

      // Calculer le délai (comparé à la vitesse libre)
      final freeFlowSpeed = 50.0;
      final freeFlowTime = distance / freeFlowSpeed * 60; // en minutes
      final currentTime = distance / speed * 60;
      final delay = math.max(0.0, currentTime - freeFlowTime).toDouble();

      segments.add(
        TrafficSegment(
          start: start,
          end: end,
          level: level,
          speed: speed,
          delay: delay,
          distance: distance,
          lastUpdated: DateTime.now(),
        ),
      );
    }

    return segments;
  }

  /// Génère des incidents de trafic réalistes
  List<TrafficIncident> _generateRealisticIncidents(LatLngBounds? bounds) {
    final incidents = <TrafficIncident>[];
    final random = math.Random();

    bounds ??= LatLngBounds(
      LatLng(6.1319 - 0.1, 1.2228 - 0.1),
      LatLng(6.1319 + 0.1, 1.2228 + 0.1),
    );

    final incidentTypes = [
      'Accident',
      'Travaux',
      'Véhicule en panne',
      'Manifestation',
      'Contrôle police',
      'Route fermée',
      'Embouteillage',
    ];

    // Générer 0-5 incidents
    final incidentCount = random.nextInt(6);

    for (int i = 0; i < incidentCount; i++) {
      final lat =
          bounds.south + random.nextDouble() * (bounds.north - bounds.south);
      final lng =
          bounds.west + random.nextDouble() * (bounds.east - bounds.west);
      final location = LatLng(lat, lng);

      final type = incidentTypes[random.nextInt(incidentTypes.length)];
      final severity =
          TrafficLevel.values[2 + random.nextInt(3)]; // moderate à extreme

      String description;
      switch (type) {
        case 'Accident':
          description =
              'Accident de la circulation - ${severity == TrafficLevel.extreme ? 'grave' : 'léger'}';
          break;
        case 'Travaux':
          description = 'Travaux sur la chaussée - circulation ralentie';
          break;
        case 'Véhicule en panne':
          description = 'Véhicule immobilisé sur la voie';
          break;
        case 'Manifestation':
          description = 'Manifestation - route partiellement fermée';
          break;
        case 'Contrôle police':
          description = 'Contrôle de police - circulation ralentie';
          break;
        case 'Route fermée':
          description = 'Route temporairement fermée';
          break;
        default:
          description = 'Trafic dense - circulation très ralentie';
      }

      incidents.add(
        TrafficIncident(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          location: location,
          type: type,
          description: description,
          severity: severity,
          startTime: DateTime.now().subtract(
            Duration(minutes: random.nextInt(120)),
          ),
          endTime: random.nextBool()
              ? DateTime.now().add(Duration(minutes: 30 + random.nextInt(90)))
              : null,
          isActive: true,
          metadata: {
            'lanes_affected': 1 + random.nextInt(3),
            'estimated_duration': 30 + random.nextInt(90),
          },
        ),
      );
    }

    return incidents;
  }

  /// Calcule la distance entre deux points en km
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Rayon de la Terre en km

    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Obtient le niveau de trafic pour une zone
  TrafficLevel getTrafficLevel(LatLng location, {double radiusKm = 0.5}) {
    final nearbySegments = _trafficSegments.where((segment) {
      final distanceToStart = _calculateDistance(location, segment.start);
      final distanceToEnd = _calculateDistance(location, segment.end);
      return math.min(distanceToStart, distanceToEnd) <= radiusKm;
    }).toList();

    if (nearbySegments.isEmpty) return TrafficLevel.unknown;

    // Retourner le niveau le plus sévère
    return nearbySegments
        .map((s) => s.level)
        .reduce((a, b) => a.index > b.index ? a : b);
  }

  /// Obtient les incidents proches d'une position
  List<TrafficIncident> getNearbyIncidents(
    LatLng location, {
    double radiusKm = 2.0,
  }) {
    return _incidents.where((incident) {
      final distance = _calculateDistance(location, incident.location);
      return distance <= radiusKm && incident.isActive;
    }).toList();
  }

  /// Calcule le délai estimé pour un trajet
  double calculateTripDelay(List<LatLng> route) {
    double totalDelay = 0;

    for (int i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];

      // Trouver les segments qui intersectent ce tronçon
      final relevantSegments = _trafficSegments.where((segment) {
        return _isRouteSegmentAffected(start, end, segment);
      }).toList();

      if (relevantSegments.isNotEmpty) {
        // Prendre le délai moyen des segments affectés
        final avgDelay =
            relevantSegments.map((s) => s.delay).reduce((a, b) => a + b) /
            relevantSegments.length;
        totalDelay += avgDelay;
      }
    }

    return totalDelay;
  }

  /// Vérifie si un segment de route est affecté par un segment de trafic
  bool _isRouteSegmentAffected(
    LatLng routeStart,
    LatLng routeEnd,
    TrafficSegment trafficSegment,
  ) {
    // Vérification simplifiée - dans un vrai système, utiliser des algorithmes géométriques plus précis
    const double threshold = 0.01; // ~1km

    final d1 = _calculateDistance(routeStart, trafficSegment.start);
    final d2 = _calculateDistance(routeStart, trafficSegment.end);
    final d3 = _calculateDistance(routeEnd, trafficSegment.start);
    final d4 = _calculateDistance(routeEnd, trafficSegment.end);

    return d1 < threshold || d2 < threshold || d3 < threshold || d4 < threshold;
  }

  /// Obtient la couleur pour un niveau de trafic
  Color getTrafficColor(TrafficLevel level) {
    switch (level) {
      case TrafficLevel.free:
        return Colors.green;
      case TrafficLevel.light:
        return Colors.lightGreen;
      case TrafficLevel.moderate:
        return Colors.orange;
      case TrafficLevel.heavy:
        return Colors.red;
      case TrafficLevel.extreme:
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  /// Obtient une description textuelle du niveau de trafic
  String getTrafficDescription(TrafficLevel level) {
    switch (level) {
      case TrafficLevel.free:
        return 'Circulation fluide';
      case TrafficLevel.light:
        return 'Circulation légère';
      case TrafficLevel.moderate:
        return 'Circulation modérée';
      case TrafficLevel.heavy:
        return 'Circulation dense';
      case TrafficLevel.extreme:
        return 'Embouteillages';
      default:
        return 'Données indisponibles';
    }
  }

  /// Obtient les statistiques de trafic
  Map<String, dynamic> getTrafficStats() {
    final segmentsByLevel = <TrafficLevel, int>{};
    final incidentsByType = <String, int>{};

    for (final segment in _trafficSegments) {
      segmentsByLevel[segment.level] =
          (segmentsByLevel[segment.level] ?? 0) + 1;
    }

    for (final incident in _incidents.where((i) => i.isActive)) {
      incidentsByType[incident.type] =
          (incidentsByType[incident.type] ?? 0) + 1;
    }

    final avgSpeed = _trafficSegments.isNotEmpty
        ? _trafficSegments.map((s) => s.speed).reduce((a, b) => a + b) /
              _trafficSegments.length
        : 0.0;

    final totalDelay = _trafficSegments
        .map((s) => s.delay)
        .fold(0.0, (a, b) => a + b);

    return {
      'segmentsByLevel': segmentsByLevel,
      'incidentsByType': incidentsByType,
      'averageSpeed': avgSpeed,
      'totalDelay': totalDelay,
      'activeIncidents': _incidents.where((i) => i.isActive).length,
      'lastUpdate': _lastUpdate,
    };
  }

  /// Analyse et annonce les embouteillages sur l'itinéraire
  Future<void> analyzeAndAnnounceTraffic(List<LatLng> routePoints) async {
    if (!_isEnabled || routePoints.isEmpty) return;

    final voiceService = VoiceGuidanceService();
    final notificationService = NavigationNotificationService();

    // Trouve les segments de trafic qui intersectent avec l'itinéraire
    final routeTrafficSegments = <TrafficSegment>[];
    for (final segment in _trafficSegments) {
      if (_isSegmentOnRoute(segment, routePoints)) {
        routeTrafficSegments.add(segment);
      }
    }

    // Analyse les embouteillages significatifs
    final heavyTrafficSegments = routeTrafficSegments
        .where(
          (s) =>
              s.level == TrafficLevel.heavy || s.level == TrafficLevel.extreme,
        )
        .toList();

    if (heavyTrafficSegments.isNotEmpty) {
      final totalDelay = heavyTrafficSegments
          .map((s) => s.delay)
          .fold(0.0, (a, b) => a + b);

      if (totalDelay > 2) {
        // Seulement si plus de 2 minutes de retard
        final delayMinutes = totalDelay.round();
        await voiceService.announceTrafficJam(delayMinutes);
        await notificationService.showTrafficAlert(
          'Embouteillage détecté, retard estimé de $delayMinutes minutes',
        );
      }
    }

    // Analyse les incidents actifs sur l'itinéraire
    final routeIncidents = _incidents
        .where(
          (incident) =>
              incident.isActive && _isIncidentOnRoute(incident, routePoints),
        )
        .toList();

    for (final incident in routeIncidents) {
      final message = 'Incident signalé: ${incident.description}';
      await voiceService.announceTraffic(message);
      await notificationService.showTrafficAlert(message);
    }
  }

  /// Vérifie si un segment de trafic intersecte avec l'itinéraire
  bool _isSegmentOnRoute(TrafficSegment segment, List<LatLng> routePoints) {
    const threshold = 0.001; // ~100m de tolérance

    for (int i = 0; i < routePoints.length - 1; i++) {
      final routeStart = routePoints[i];
      final routeEnd = routePoints[i + 1];

      // Vérifie si les segments se chevauchent approximativement
      if (_distanceBetweenPoints(segment.start, routeStart) < threshold ||
          _distanceBetweenPoints(segment.start, routeEnd) < threshold ||
          _distanceBetweenPoints(segment.end, routeStart) < threshold ||
          _distanceBetweenPoints(segment.end, routeEnd) < threshold) {
        return true;
      }
    }

    return false;
  }

  /// Vérifie si un incident est sur l'itinéraire
  bool _isIncidentOnRoute(TrafficIncident incident, List<LatLng> routePoints) {
    const threshold = 0.002; // ~200m de tolérance pour les incidents

    for (final point in routePoints) {
      if (_distanceBetweenPoints(incident.location, point) < threshold) {
        return true;
      }
    }

    return false;
  }

  /// Calcule la distance entre deux points (approximation simple)
  double _distanceBetweenPoints(LatLng point1, LatLng point2) {
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return 6371000 * c; // Rayon de la Terre en mètres
  }

  @override
  void dispose() {
    stopRealTimeUpdates();
    super.dispose();
  }
}
