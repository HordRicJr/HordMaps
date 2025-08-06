import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/complete_map_controls.dart';

/// Écran de test pour tous les contrôles de carte
class MapControlsTestScreen extends StatelessWidget {
  const MapControlsTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Contrôles Carte'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Fond simulant une carte
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade100,
                  Colors.blue.shade100,
                  Colors.brown.shade100,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.map, size: 64, color: Colors.green),
                        const SizedBox(height: 16),
                        const Text(
                          'Test des Contrôles de Carte',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Testez tous les boutons disponibles',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        Consumer<CompleteMapLayerService>(
                          builder: (context, layerService, child) {
                            final currentLayer = layerService
                                .getCurrentLayerConfig();
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: currentLayer.color.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: currentLayer.color),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        currentLayer.icon,
                                        color: currentLayer.color,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Couche actuelle: ${currentLayer.name}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: currentLayer.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currentLayer.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (layerService.is3DEnabled) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.view_in_ar,
                                          size: 16,
                                          color: Colors.purple,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '3D Activé (${layerService.tilt.round()}°, ${layerService.bearing.round()}°)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.purple,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (layerService.showTraffic) ...[
                                    const SizedBox(height: 4),
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.traffic,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Trafic activé',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (layerService.showTransit) ...[
                                    const SizedBox(height: 4),
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.directions_bus,
                                          size: 16,
                                          color: Colors.indigo,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Transport activé',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.indigo,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Liste des fonctionnalités disponibles
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✅ Fonctionnalités Disponibles:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...[
                          '📍 9 Types de cartes (Standard, Satellite, Relief, etc.)',
                          '🎛️ Contrôles 3D complets (Inclinaison, Rotation)',
                          '🚦 Affichage du trafic en temps réel',
                          '🚌 Overlay des transports en commun',
                          '🚴 Modes vélo et piéton',
                          '🔄 Reset automatique de la vue',
                          '⚡ Animations fluides et responsives',
                        ].map(
                          (text) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contrôles de carte superposés
          const CompleteMapControls(),

          // Instructions en bas
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 Utilisez les boutons à droite pour tester toutes les fonctionnalités de carte',
                style: TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
