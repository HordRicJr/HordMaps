import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/navigation_models.dart';

class NavigationPanel extends StatelessWidget {
  final RouteStep? currentStep;
  final double totalDistance;
  final double totalDuration;
  final VoidCallback onStopNavigation;
  final VoidCallback onNextStep;
  final VoidCallback onPreviousStep;

  const NavigationPanel({
    super.key,
    required this.currentStep,
    required this.totalDistance,
    required this.totalDuration,
    required this.onStopNavigation,
    required this.onNextStep,
    required this.onPreviousStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée de glissement
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Informations de l'étape actuelle
              if (currentStep != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instruction principale
                      Text(
                        currentStep!.instruction,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                      ),

                      const SizedBox(height: 16),

                      // Informations sur la distance et le temps
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              context: context,
                              icon: Icons.straighten,
                              title: 'Distance',
                              value: _formatDistance(totalDistance),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              context: context,
                              icon: Icons.access_time,
                              title: 'Temps',
                              value: _formatDuration(totalDuration),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Contrôles de navigation
                      Row(
                        children: [
                          // Bouton étape précédente
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onPreviousStep,
                              icon: const Icon(Icons.skip_previous),
                              label: const Text('Précédent'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Bouton arrêter navigation
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onStopNavigation,
                              icon: const Icon(Icons.stop),
                              label: const Text('Arrêter'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Bouton étape suivante
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onNextStep,
                              icon: const Icon(Icons.skip_next),
                              label: const Text('Suivant'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        )
        .animate()
        .slideY(begin: 1, duration: 500.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 300.ms);
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()} m';
    } else {
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }

  String _formatDuration(double durationInSeconds) {
    final hours = (durationInSeconds / 3600).floor();
    final minutes = ((durationInSeconds % 3600) / 60).floor();

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }
}
