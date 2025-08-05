import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import 'dart:async';

/// Types de transport en commun
enum TransportType {
  bus('Bus', Icons.directions_bus, Color(0xFF2196F3)),
  metro('Métro', Icons.subway, Color(0xFF9C27B0)),
  train('Train', Icons.train, Color(0xFF4CAF50)),
  tram('Tramway', Icons.tram, Color(0xFFFF9800)),
  ferry('Ferry', Icons.directions_boat, Color(0xFF00BCD4));

  const TransportType(this.displayName, this.icon, this.color);
  final String displayName;
  final IconData icon;
  final Color color;
}

/// Statut du transport
enum TransportStatus {
  onTime('À l\'heure'),
  delayed('Retardé'),
  cancelled('Annulé'),
  early('En avance');

  const TransportStatus(this.displayName);
  final String displayName;
}

/// Modèle d'arrêt de transport
class TransportStop {
  final String id;
  final String name;
  final LatLng position;
  final Set<TransportType> types;
  final List<String> lines;
  final Map<String, dynamic> accessibility;
  final bool hasRealTimeInfo;

  TransportStop({
    required this.id,
    required this.name,
    required this.position,
    required this.types,
    required this.lines,
    this.accessibility = const {},
    this.hasRealTimeInfo = false,
  });
}

/// Modèle de ligne de transport
class TransportLine {
  final String id;
  final String name;
  final TransportType type;
  final Color color;
  final List<TransportStop> stops;
  final String operator;
  final Map<String, String> schedule;

  TransportLine({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.stops,
    required this.operator,
    this.schedule = const {},
  });
}

/// Modèle de passage de véhicule
class VehiclePassage {
  final String lineId;
  final String destination;
  final DateTime scheduledTime;
  final DateTime? realTime;
  final TransportStatus status;
  final String vehicleId;
  final int occupancyLevel; // 0-100%

  VehiclePassage({
    required this.lineId,
    required this.destination,
    required this.scheduledTime,
    this.realTime,
    required this.status,
    required this.vehicleId,
    required this.occupancyLevel,
  });

  Duration get timeUntilArrival {
    final targetTime = realTime ?? scheduledTime;
    return targetTime.difference(DateTime.now());
  }

  String get formattedTimeUntilArrival {
    final duration = timeUntilArrival;
    if (duration.isNegative) return 'Passé';
    if (duration.inMinutes == 0) return 'Maintenant';
    if (duration.inMinutes < 60) return '${duration.inMinutes} min';
    return '${duration.inHours}h ${duration.inMinutes % 60}min';
  }
}

/// Modèle de segment de voyage
class TransportSegment {
  final TransportLine line;
  final TransportStop from;
  final TransportStop to;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final int stopsCount;
  final double walkingDistance;

  TransportSegment({
    required this.line,
    required this.from,
    required this.to,
    required this.departureTime,
    required this.arrivalTime,
    required this.stopsCount,
    this.walkingDistance = 0.0,
  });

  Duration get duration => arrivalTime.difference(departureTime);
}

/// Modèle d'itinéraire en transport en commun
class PublicTransportRoute {
  final List<TransportSegment> segments;
  final Duration totalDuration;
  final double totalWalkingDistance;
  final double totalPrice;
  final int transfers;
  final DateTime departureTime;
  final DateTime arrivalTime;

  PublicTransportRoute({
    required this.segments,
    required this.totalDuration,
    required this.totalWalkingDistance,
    required this.totalPrice,
    required this.transfers,
    required this.departureTime,
    required this.arrivalTime,
  });
}

/// Service de transport en commun dynamique
class PublicTransportService extends ChangeNotifier {
  static final PublicTransportService _instance =
      PublicTransportService._internal();
  factory PublicTransportService() => _instance;
  PublicTransportService._internal();

  final Dio _dio = Dio();
  final Map<String, TransportLine> _lines = {};
  final Map<String, TransportStop> _stops = {};
  final Map<String, List<VehiclePassage>> _realTimeData = {};
  bool _isEnabled = false;
  Timer? _realTimeUpdateTimer;

  // Getters
  bool get isEnabled => _isEnabled;
  Map<String, TransportLine> get lines => Map.unmodifiable(_lines);
  Map<String, TransportStop> get stops => Map.unmodifiable(_stops);

  /// Active/désactive le service de transport public
  void toggleService() {
    _isEnabled = !_isEnabled;
    if (_isEnabled) {
      _startRealTimeUpdates();
      _loadTransportData();
    } else {
      _stopRealTimeUpdates();
    }
    notifyListeners();
  }

  /// Démarre les mises à jour en temps réel
  void _startRealTimeUpdates() {
    _realTimeUpdateTimer?.cancel();
    _realTimeUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateRealTimeData(),
    );
  }

  /// Arrête les mises à jour en temps réel
  void _stopRealTimeUpdates() {
    _realTimeUpdateTimer?.cancel();
  }

  /// Charge les données de transport public
  void _loadTransportData() {
    _lines.clear();
    _stops.clear();

    // Essayer de charger des données réelles via API
    _loadRealTransportData().catchError((e) {
      debugPrint(
        'Erreur chargement données réelles: $e, utilisation données locales',
      );
      // Fallback vers données locales basiques
      _generateLocalTransportData();
    });

    notifyListeners();
  }

  /// Charge des données réelles de transport public via API OpenStreetMap
  Future<void> _loadRealTransportData() async {
    try {
      // Position par défaut (Lomé, Togo) - devrait être configurée selon l'utilisateur
      const position = LatLng(6.1319, 1.2228);
      const radiusKm = 5.0;

      final lines = await _fetchRealTransportLines(position, radiusKm);

      if (lines.isNotEmpty) {
        _lines.clear();
        _stops.clear();

        for (final line in lines) {
          _lines[line.id] = line;
          for (final stop in line.stops) {
            _stops[stop.id] = stop;
          }
        }

        debugPrint('Chargé ${lines.length} lignes de transport réelles');
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Erreur API transport: $e');
    }

    // Fallback vers données locales
    _generateLocalTransportData();
  }

  /// Génère des données de transport locales basiques
  void _generateLocalTransportData() {
    _generateSimulatedStops();
    _generateSimulatedLines();
  }

  /// Récupère les lignes de transport depuis l'API Overpass
  Future<List<TransportLine>> _fetchRealTransportLines(
    LatLng position,
    double radiusKm,
  ) async {
    final radiusMeters = (radiusKm * 1000).toInt();

    final query =
        '''
    [out:json][timeout:25];
    (
      node["public_transport"="stop_position"](around:$radiusMeters,${position.latitude},${position.longitude});
      node["highway"="bus_stop"](around:$radiusMeters,${position.latitude},${position.longitude});
      node["railway"="station"](around:$radiusMeters,${position.latitude},${position.longitude});
      node["railway"="tram_stop"](around:$radiusMeters,${position.latitude},${position.longitude});
    );
    out body;
    ''';

    try {
      final response = await _dio.post(
        'https://overpass-api.de/api/interpreter',
        data: query,
        options: Options(
          headers: {'Content-Type': 'text/plain'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        return _parseOverpassData(response.data);
      }
    } catch (e) {
      debugPrint('Erreur requête Overpass: $e');
    }

    return [];
  }

  /// Parse les données de l'API Overpass
  List<TransportLine> _parseOverpassData(Map<String, dynamic> data) {
    final lines = <TransportLine>[];
    final elements = data['elements'] as List<dynamic>? ?? [];

    final stopsData = <String, TransportStop>{};

    for (final element in elements) {
      if (element['type'] == 'node' && element['tags'] != null) {
        final tags = element['tags'] as Map<String, dynamic>;
        final lat = element['lat'] as double;
        final lon = element['lon'] as double;

        final stop = TransportStop(
          id: element['id'].toString(),
          name: tags['name'] ?? 'Arrêt ${element['id']}',
          position: LatLng(lat, lon),
          types: {_determineTransportType(tags)},
          lines: _extractLines(tags),
          accessibility: _extractAccessibility(tags),
          hasRealTimeInfo: true,
        );

        stopsData[stop.id] = stop;
      }
    }

    // Grouper par lignes
    final linesMap = <String, List<TransportStop>>{};

    for (final stop in stopsData.values) {
      for (final lineId in stop.lines) {
        linesMap.putIfAbsent(lineId, () => []).add(stop);
      }
    }

    // Créer les objets TransportLine
    for (final entry in linesMap.entries) {
      if (entry.value.length >= 2) {
        final firstStop = entry.value.first;
        final firstStopType = firstStop.types.first;
        lines.add(
          TransportLine(
            id: entry.key,
            name: _generateLineName(entry.key, firstStopType),
            type: firstStopType,
            color: firstStopType.color,
            stops: entry.value,
            operator: 'Données OSM',
            schedule: _generateSchedule(firstStopType),
          ),
        );
      }
    }

    return lines;
  }

  /// Extrait les lignes depuis les tags OSM
  List<String> _extractLines(Map<String, dynamic> tags) {
    final lines = <String>[];

    if (tags['route_ref'] != null) {
      lines.addAll(tags['route_ref'].toString().split(';'));
    }
    if (tags['ref'] != null) {
      lines.add(tags['ref'].toString());
    }
    if (tags['line'] != null) {
      lines.add(tags['line'].toString());
    }

    if (lines.isEmpty) {
      lines.add('line_${tags['name']?.toString().hashCode.abs() ?? 'unknown'}');
    }

    return lines.where((line) => line.trim().isNotEmpty).toList();
  }

  /// Détermine le type de transport
  TransportType _determineTransportType(Map<String, dynamic> tags) {
    if (tags['railway'] == 'station' || tags['railway'] == 'subway_entrance') {
      return TransportType.metro;
    }
    if (tags['railway'] == 'tram_stop') {
      return TransportType.tram;
    }
    return TransportType.bus;
  }

  /// Extrait les données d'accessibilité depuis les tags OSM
  Map<String, dynamic> _extractAccessibility(Map<String, dynamic> tags) {
    final accessibility = <String, dynamic>{};

    if (tags['wheelchair'] == 'yes') accessibility['wheelchair'] = true;
    if (tags['tactile_paving'] == 'yes') accessibility['tactile_paving'] = true;
    if (tags['shelter'] == 'yes') accessibility['shelter'] = true;
    if (tags['bench'] == 'yes') accessibility['bench'] = true;
    if (tags['departures_board'] == 'yes')
      accessibility['departures_board'] = true;

    return accessibility;
  }

  /// Génère un nom de ligne
  String _generateLineName(String id, TransportType type) {
    switch (type) {
      case TransportType.metro:
        return 'M$id';
      case TransportType.tram:
        return 'T$id';
      case TransportType.bus:
        return 'Bus $id';
      case TransportType.train:
        return 'Train $id';
      case TransportType.ferry:
        return 'Ferry $id';
    }
  }

  /// Génère des horaires réalistes
  Map<String, String> _generateSchedule(TransportType type) {
    switch (type) {
      case TransportType.metro:
        return {'first': '05:30', 'last': '01:15', 'freq': '2-5min'};
      case TransportType.tram:
        return {'first': '05:45', 'last': '01:00', 'freq': '5-8min'};
      case TransportType.bus:
        return {'first': '06:00', 'last': '00:30', 'freq': '10-20min'};
      case TransportType.train:
        return {'first': '05:00', 'last': '01:30', 'freq': '15-30min'};
      case TransportType.ferry:
        return {'first': '06:30', 'last': '22:00', 'freq': '30-60min'};
    }
  }

  /// Génère des arrêts de transport simulés
  void _generateSimulatedStops() {
    final lomeCenter = const LatLng(6.1319, 1.2228); // Lomé, Togo
    final random = math.Random(42); // Seed fixe pour consistance

    final stopNames = [
      'Châtelet-Les Halles',
      'Gare du Nord',
      'République',
      'Bastille',
      'Nation',
      'Montparnasse',
      'Opéra',
      'Louvre',
      'Invalides',
      'Trocadéro',
      'Champs-Élysées',
      'Arc de Triomphe',
      'La Défense',
      'Vincennes',
      'Belleville',
      'Ménilmontant',
      'Oberkampf',
      'Temple',
      'Marais',
      'Saint-Germain',
      'Quartier Latin',
      'Panthéon',
      'Sorbonne',
      'Odéon',
    ];

    for (int i = 0; i < stopNames.length; i++) {
      final name = stopNames[i];

      // Position aléatoire autour de Lomé
      final lat = lomeCenter.latitude + (random.nextDouble() - 0.5) * 0.1;
      final lng = lomeCenter.longitude + (random.nextDouble() - 0.5) * 0.1;

      // Types de transport disponibles
      final types = <TransportType>{};
      if (random.nextBool()) types.add(TransportType.metro);
      if (random.nextBool()) types.add(TransportType.bus);
      if (random.nextDouble() < 0.3) types.add(TransportType.tram);
      if (random.nextDouble() < 0.1) types.add(TransportType.train);

      // Lignes disponibles
      final lines = <String>[];
      for (final type in types) {
        final lineCount = 1 + random.nextInt(3);
        for (int j = 0; j < lineCount; j++) {
          switch (type) {
            case TransportType.metro:
              lines.add('M${1 + random.nextInt(14)}');
              break;
            case TransportType.bus:
              lines.add('${20 + random.nextInt(80)}');
              break;
            case TransportType.tram:
              lines.add('T${1 + random.nextInt(8)}');
              break;
            case TransportType.train:
              lines.add('RER ${String.fromCharCode(65 + random.nextInt(5))}');
              break;
            default:
              break;
          }
        }
      }

      _stops['stop_$i'] = TransportStop(
        id: 'stop_$i',
        name: name,
        position: LatLng(lat, lng),
        types: types,
        lines: lines,
        accessibility: {
          'wheelchair': random.nextBool(),
          'elevator': random.nextBool(),
          'visual_aid': random.nextBool(),
        },
        hasRealTimeInfo: random.nextDouble() < 0.8,
      );
    }
  }

  /// Génère des lignes de transport simulées
  void _generateSimulatedLines() {
    final random = math.Random(42);

    // Lignes de métro
    for (int i = 1; i <= 14; i++) {
      final metroStops = _stops.values
          .where((stop) => stop.lines.contains('M$i'))
          .toList();

      if (metroStops.length >= 2) {
        _lines['metro_$i'] = TransportLine(
          id: 'metro_$i',
          name: 'Ligne $i',
          type: TransportType.metro,
          color: Color.fromRGBO(
            random.nextInt(256),
            random.nextInt(256),
            random.nextInt(256),
            1.0,
          ),
          stops: metroStops,
          operator: 'RATP',
          schedule: {
            'first_departure': '05:30',
            'last_departure': '01:15',
            'frequency': '2-7 min',
          },
        );
      }
    }

    // Lignes de bus
    for (int i = 20; i < 100; i += 5) {
      final busStops = _stops.values
          .where((stop) => stop.lines.contains('$i'))
          .toList();

      if (busStops.length >= 2) {
        _lines['bus_$i'] = TransportLine(
          id: 'bus_$i',
          name: 'Bus $i',
          type: TransportType.bus,
          color: TransportType.bus.color,
          stops: busStops,
          operator: 'RATP',
          schedule: {
            'first_departure': '06:00',
            'last_departure': '00:30',
            'frequency': '10-15 min',
          },
        );
      }
    }

    // Lignes de tramway
    for (int i = 1; i <= 8; i++) {
      final tramStops = _stops.values
          .where((stop) => stop.lines.contains('T$i'))
          .toList();

      if (tramStops.length >= 2) {
        _lines['tram_$i'] = TransportLine(
          id: 'tram_$i',
          name: 'Tramway T$i',
          type: TransportType.tram,
          color: TransportType.tram.color,
          stops: tramStops,
          operator: 'RATP',
          schedule: {
            'first_departure': '05:45',
            'last_departure': '01:00',
            'frequency': '5-8 min',
          },
        );
      }
    }
  }

  /// Met à jour les données temps réel
  void _updateRealTimeData() {
    if (!_isEnabled) return;

    final random = math.Random();
    _realTimeData.clear();

    for (final stop in _stops.values) {
      final passages = <VehiclePassage>[];

      for (final lineId in stop.lines) {
        // Générer 2-4 passages par ligne
        final passageCount = 2 + random.nextInt(3);

        for (int i = 0; i < passageCount; i++) {
          final scheduledTime = DateTime.now().add(
            Duration(minutes: 2 + i * 5 + random.nextInt(8)),
          );

          // Simuler des retards/avances
          DateTime? realTime;
          TransportStatus status = TransportStatus.onTime;

          if (random.nextDouble() < 0.2) {
            // 20% de chance de retard
            realTime = scheduledTime.add(
              Duration(minutes: 1 + random.nextInt(5)),
            );
            status = TransportStatus.delayed;
          } else if (random.nextDouble() < 0.05) {
            // 5% de chance d'avance
            realTime = scheduledTime.subtract(
              Duration(minutes: 1 + random.nextInt(3)),
            );
            status = TransportStatus.early;
          } else if (random.nextDouble() < 0.02) {
            // 2% de chance d'annulation
            status = TransportStatus.cancelled;
          }

          passages.add(
            VehiclePassage(
              lineId: lineId,
              destination: _generateDestination(lineId, random),
              scheduledTime: scheduledTime,
              realTime: realTime,
              status: status,
              vehicleId: '${lineId}_${1000 + random.nextInt(9000)}',
              occupancyLevel: random.nextInt(101),
            ),
          );
        }
      }

      _realTimeData[stop.id] = passages;
    }

    notifyListeners();
  }

  /// Génère une destination simulée
  String _generateDestination(String lineId, math.Random random) {
    final destinations = {
      'metro': [
        'Château de Vincennes',
        'Pont de Levallois',
        'Créteil',
        'Porte de Clignancourt',
      ],
      'bus': ['Gare de l\'Est', 'Place de la Bastille', 'Châtelet', 'Opéra'],
      'tram': [
        'Pont du Garigliano',
        'Porte de Versailles',
        'Bobigny',
        'Noisy-le-Sec',
      ],
      'rer': [
        'Marne-la-Vallée',
        'Saint-Germain-en-Laye',
        'Roissy CDG',
        'Melun',
      ],
    };

    if (lineId.startsWith('M')) {
      return destinations['metro']![random.nextInt(
        destinations['metro']!.length,
      )];
    } else if (lineId.startsWith('T')) {
      return destinations['tram']![random.nextInt(
        destinations['tram']!.length,
      )];
    } else if (lineId.startsWith('RER')) {
      return destinations['rer']![random.nextInt(destinations['rer']!.length)];
    } else {
      return destinations['bus']![random.nextInt(destinations['bus']!.length)];
    }
  }

  /// Recherche d'arrêts à proximité
  List<TransportStop> findNearbyStops(
    LatLng position, {
    double radiusKm = 1.0,
  }) {
    const distance = Distance();

    return _stops.values.where((stop) {
      final stopDistance = distance.as(
        LengthUnit.Kilometer,
        position,
        stop.position,
      );
      return stopDistance <= radiusKm;
    }).toList()..sort((a, b) {
      final distA = distance.as(LengthUnit.Kilometer, position, a.position);
      final distB = distance.as(LengthUnit.Kilometer, position, b.position);
      return distA.compareTo(distB);
    });
  }

  /// Obtient les prochains passages pour un arrêt
  List<VehiclePassage> getNextPassages(String stopId, {int limit = 10}) {
    if (!_realTimeData.containsKey(stopId)) return [];

    final passages =
        _realTimeData[stopId]!
            .where((passage) => passage.status != TransportStatus.cancelled)
            .where((passage) => passage.timeUntilArrival.inMinutes >= 0)
            .toList()
          ..sort((a, b) => a.timeUntilArrival.compareTo(b.timeUntilArrival));

    return passages.take(limit).toList();
  }

  /// Calcule un itinéraire en transport en commun
  Future<List<PublicTransportRoute>> calculatePublicTransportRoute(
    LatLng from,
    LatLng to, {
    DateTime? departureTime,
    bool wheelchairAccessible = false,
  }) async {
    if (!_isEnabled) return [];

    await Future.delayed(const Duration(seconds: 2)); // Simulation API

    final routes = <PublicTransportRoute>[];
    final departure = departureTime ?? DateTime.now();

    // Trouver les arrêts de départ et d'arrivée
    final startStops = findNearbyStops(from, radiusKm: 0.5);
    final endStops = findNearbyStops(to, radiusKm: 0.5);

    if (startStops.isEmpty || endStops.isEmpty) return [];

    // Générer quelques routes simulées
    for (int i = 0; i < 3; i++) {
      final route = _generateSimulatedRoute(
        startStops.first,
        endStops.first,
        departure.add(Duration(minutes: i * 10)),
        wheelchairAccessible,
      );
      if (route != null) {
        routes.add(route);
      }
    }

    return routes;
  }

  /// Génère une route simulée
  PublicTransportRoute? _generateSimulatedRoute(
    TransportStop start,
    TransportStop end,
    DateTime departureTime,
    bool wheelchairAccessible,
  ) {
    final random = math.Random();
    final segments = <TransportSegment>[];

    // Ligne commune entre départ et arrivée
    final commonLines = start.lines.toSet().intersection(end.lines.toSet());

    if (commonLines.isNotEmpty) {
      // Route directe
      final lineId = commonLines.first;
      final line = _lines[lineId];
      if (line != null) {
        final segment = TransportSegment(
          line: line,
          from: start,
          to: end,
          departureTime: departureTime,
          arrivalTime: departureTime.add(
            Duration(minutes: 15 + random.nextInt(20)),
          ),
          stopsCount: 3 + random.nextInt(8),
        );
        segments.add(segment);
      }
    } else {
      // Route avec correspondance
      final intermediateStop = _stops.values
          .where((stop) => stop.id != start.id && stop.id != end.id)
          .toList()[random.nextInt(_stops.length ~/ 2)];

      // Premier segment
      if (start.lines.isNotEmpty) {
        final line1 = _lines[start.lines.first];
        if (line1 != null) {
          final arrivalTime1 = departureTime.add(
            Duration(minutes: 8 + random.nextInt(12)),
          );
          segments.add(
            TransportSegment(
              line: line1,
              from: start,
              to: intermediateStop,
              departureTime: departureTime,
              arrivalTime: arrivalTime1,
              stopsCount: 2 + random.nextInt(5),
            ),
          );

          // Temps de correspondance
          final departureTime2 = arrivalTime1.add(
            Duration(minutes: 3 + random.nextInt(5)),
          );

          // Deuxième segment
          if (intermediateStop.lines.isNotEmpty) {
            final line2 = _lines[intermediateStop.lines.first];
            if (line2 != null) {
              segments.add(
                TransportSegment(
                  line: line2,
                  from: intermediateStop,
                  to: end,
                  departureTime: departureTime2,
                  arrivalTime: departureTime2.add(
                    Duration(minutes: 10 + random.nextInt(15)),
                  ),
                  stopsCount: 3 + random.nextInt(6),
                ),
              );
            }
          }
        }
      }
    }

    if (segments.isEmpty) return null;

    final totalDuration = segments.last.arrivalTime.difference(
      segments.first.departureTime,
    );
    final walkingDistance = random.nextDouble() * 500 + 200; // 200-700m
    final price =
        1.90 + (segments.length > 1 ? 0.0 : 0.0); // Prix Navigo simulé

    return PublicTransportRoute(
      segments: segments,
      totalDuration: totalDuration,
      totalWalkingDistance: walkingDistance,
      totalPrice: price,
      transfers: segments.length - 1,
      departureTime: segments.first.departureTime,
      arrivalTime: segments.last.arrivalTime,
    );
  }

  /// Recherche de lignes par nom
  List<TransportLine> searchLines(String query) {
    return _lines.values
        .where((line) => line.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Obtient les informations de trafic
  Map<String, String> getTrafficInfo() {
    final random = math.Random();
    final incidents = <String, String>{};

    final incidentTypes = [
      'Incident voyageur',
      'Problème technique',
      'Travaux',
      'Affluence exceptionnelle',
      'Grève partielle',
    ];

    for (final line in _lines.values) {
      if (random.nextDouble() < 0.1) {
        // 10% de chance d'incident
        incidents[line.id] =
            incidentTypes[random.nextInt(incidentTypes.length)];
      }
    }

    return incidents;
  }

  @override
  void dispose() {
    _realTimeUpdateTimer?.cancel();
    _dio.close();
    super.dispose();
  }
}
