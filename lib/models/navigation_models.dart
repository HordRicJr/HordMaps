import 'package:latlong2/latlong.dart';

/// Classe représentant un résultat de calcul d'itinéraire
class RouteResult {
  final List<LatLng> points;
  final double totalDistance;
  final Duration estimatedDuration;
  final List<RouteStep> steps;
  final String summary;

  const RouteResult({
    required this.points,
    required this.totalDistance,
    required this.estimatedDuration,
    required this.steps,
    this.summary = '',
  });

  /// Distance totale en kilomètres
  double get distance => totalDistance;

  /// Points de l'itinéraire
  List<LatLng> get routePoints => points;

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final pointsList = json['coordinates'] as List? ?? [];
    final points = pointsList
        .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
        .toList();

    final stepsList = json['steps'] as List? ?? [];
    final steps = stepsList.map((step) => RouteStep.fromJson(step)).toList();

    return RouteResult(
      points: points,
      totalDistance: (json['distance'] ?? 0.0) / 1000.0, // Convertir en km
      estimatedDuration: Duration(seconds: (json['duration'] ?? 0).toInt()),
      steps: steps,
      summary: json['summary'] ?? '',
    );
  }
}

/// Étape de navigation dans un itinéraire
class RouteStep {
  final String instruction;
  final double distance;
  final Duration duration;
  final LatLng location;
  final String type;
  final String modifier;

  const RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.location,
    required this.type,
    this.modifier = '',
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] ?? {};
    final location = maneuver['location'] as List? ?? [0.0, 0.0];

    return RouteStep(
      instruction: json['name'] ?? json['instruction'] ?? 'Continuer',
      distance: (json['distance'] ?? 0.0).toDouble(),
      duration: Duration(seconds: (json['duration'] ?? 0).toInt()),
      location: LatLng(location[1].toDouble(), location[0].toDouble()),
      type: maneuver['type'] ?? 'continue',
      modifier: maneuver['modifier'] ?? '',
    );
  }
}

/// Représente une route de navigation complète
class NavigationRoute {
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double distance;
  final Duration duration;
  final String summary;

  const NavigationRoute({
    required this.points,
    required this.steps,
    required this.distance,
    required this.duration,
    this.summary = '',
  });

  /// Points de l'itinéraire
  List<LatLng> get routePoints => points;

  factory NavigationRoute.fromRouteResult(RouteResult result) {
    return NavigationRoute(
      points: result.points,
      steps: result.steps,
      distance: result.totalDistance,
      duration: result.estimatedDuration,
      summary: result.summary,
    );
  }
}
