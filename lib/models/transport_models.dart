import 'package:flutter/material.dart';

/// Modèle pour les modes de transport
class TransportMode {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final double speedKmh;
  final bool isAvailable;

  const TransportMode({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.speedKmh,
    this.isAvailable = true,
  });

  static const List<TransportMode> allModes = [
    TransportMode(
      id: 'car',
      name: 'Voiture',
      description: 'Trajet en voiture',
      icon: Icons.directions_car,
      color: Color(0xFF2196F3),
      speedKmh: 50.0,
    ),
    TransportMode(
      id: 'motorcycle',
      name: 'Moto/Scooter',
      description: 'Trajet en moto ou scooter',
      icon: Icons.motorcycle,
      color: Color(0xFFFF9800),
      speedKmh: 45.0,
    ),
    TransportMode(
      id: 'bicycle',
      name: 'Vélo',
      description: 'Trajet à vélo',
      icon: Icons.directions_bike,
      color: Color(0xFF4CAF50),
      speedKmh: 20.0,
    ),
    TransportMode(
      id: 'walking',
      name: 'Marche',
      description: 'Trajet à pied',
      icon: Icons.directions_walk,
      color: Color(0xFF9C27B0),
      speedKmh: 5.0,
    ),
    TransportMode(
      id: 'public_transport',
      name: 'Transport Public',
      description: 'Bus, métro, tramway',
      icon: Icons.directions_bus,
      color: Color(0xFFF44336),
      speedKmh: 25.0,
    ),
  ];

  static TransportMode? getById(String id) {
    try {
      return allModes.firstWhere((mode) => mode.id == id);
    } catch (e) {
      return null;
    }
  }

  // Getters statiques pour les modes de transport couramment utilisés
  static TransportMode get car =>
      allModes.firstWhere((mode) => mode.id == 'car');
  static TransportMode get motorcycle =>
      allModes.firstWhere((mode) => mode.id == 'motorcycle');
  static TransportMode get bicycle =>
      allModes.firstWhere((mode) => mode.id == 'bicycle');
  static TransportMode get walking =>
      allModes.firstWhere((mode) => mode.id == 'walking');
  static TransportMode get publicTransport =>
      allModes.firstWhere((mode) => mode.id == 'public_transport');
}

/// Modèle pour les options de route
class RouteOptions {
  final TransportMode transportMode;
  final bool avoidTolls;
  final bool avoidHighways;
  final bool avoidFerries;
  final bool shortestRoute;
  final bool fastestRoute;

  const RouteOptions({
    required this.transportMode,
    this.avoidTolls = false,
    this.avoidHighways = false,
    this.avoidFerries = false,
    this.shortestRoute = false,
    this.fastestRoute = true,
  });

  RouteOptions copyWith({
    TransportMode? transportMode,
    bool? avoidTolls,
    bool? avoidHighways,
    bool? avoidFerries,
    bool? shortestRoute,
    bool? fastestRoute,
  }) {
    return RouteOptions(
      transportMode: transportMode ?? this.transportMode,
      avoidTolls: avoidTolls ?? this.avoidTolls,
      avoidHighways: avoidHighways ?? this.avoidHighways,
      avoidFerries: avoidFerries ?? this.avoidFerries,
      shortestRoute: shortestRoute ?? this.shortestRoute,
      fastestRoute: fastestRoute ?? this.fastestRoute,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transportMode': transportMode.id,
      'avoidTolls': avoidTolls,
      'avoidHighways': avoidHighways,
      'avoidFerries': avoidFerries,
      'shortestRoute': shortestRoute,
      'fastestRoute': fastestRoute,
    };
  }

  factory RouteOptions.fromJson(Map<String, dynamic> json) {
    return RouteOptions(
      transportMode:
          TransportMode.getById(json['transportMode']) ??
          TransportMode.allModes.first,
      avoidTolls: json['avoidTolls'] ?? false,
      avoidHighways: json['avoidHighways'] ?? false,
      avoidFerries: json['avoidFerries'] ?? false,
      shortestRoute: json['shortestRoute'] ?? false,
      fastestRoute: json['fastestRoute'] ?? true,
    );
  }
}
