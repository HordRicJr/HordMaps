import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/real_time_navigation_service.dart';
import '../../navigation/providers/navigation_provider.dart';

/// Widget pour afficher la progression de navigation en temps réel
class NavigationProgressWidget extends StatefulWidget {
  const NavigationProgressWidget({super.key});

  @override
  State<NavigationProgressWidget> createState() =>
      _NavigationProgressWidgetState();
}

class _NavigationProgressWidgetState extends State<NavigationProgressWidget> {
  late final RealTimeNavigationService _navigationService;
  NavigationProgress? _currentProgress;

  @override
  void initState() {
    super.initState();
    _navigationService = RealTimeNavigationService.instance;
    _listenToProgress();
  }

  void _listenToProgress() {
    _navigationService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentProgress == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressHeader(),
          _buildProgressIndicator(),
          _buildProgressStats(),
          _buildNavigationControls(),
        ],
      ),
    ).animate().slideY(begin: 1, duration: 300.ms).fadeIn();
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.navigation,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Navigation en cours',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                if (_currentProgress!.isArrived)
                  Text(
                    'Arrivée à destination !',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          _buildProgressBadge(),
        ],
      ),
    );
  }

  Widget _buildProgressBadge() {
    final percentage = _currentProgress!.completionPercentage;
    final color = _getProgressColor(percentage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '${percentage.toStringAsFixed(0)}%',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final percentage = _currentProgress!.completionPercentage / 100;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progression',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                '${_currentProgress!.completionPercentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(_currentProgress!.completionPercentage),
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStats() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.straighten,
              label: 'Distance restante',
              value:
                  '${_currentProgress!.remainingDistance.toStringAsFixed(1)} km',
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              icon: Icons.access_time,
              label: 'Temps estimé',
              value: _formatDuration(_currentProgress!.estimatedTimeArrival),
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              icon: Icons.speed,
              label: 'Vitesse moy.',
              value:
                  '${_currentProgress!.averageSpeed.toStringAsFixed(0)} km/h',
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _pauseNavigation(),
              icon: const Icon(Icons.pause, size: 18),
              label: const Text('Pause'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _stopNavigation(),
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Arrêter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _showNavigationOptions(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Icon(Icons.more_vert, size: 18),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage < 25) return Colors.red;
    if (percentage < 50) return Colors.orange;
    if (percentage < 75) return Colors.blue;
    return Colors.green;
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '< 1m';
    }
  }

  void _pauseNavigation() {
    final navProvider = context.read<NavigationProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mettre en pause la navigation'),
        content: const Text(
          'Voulez-vous mettre en pause ou arrêter la navigation ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (navProvider.isNavigating) {
                // La pause n'est pas implémentée, on utilise stop à la place
                _stopNavigation();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Navigation arrêtée'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Arrêter'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _stopNavigation();
            },
            child: const Text('Arrêter'),
          ),
        ],
      ),
    );
  }

  void _stopNavigation() {
    context.read<NavigationProvider>().stopNavigation();
    _navigationService.stopNavigation();
  }

  void _showNavigationOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Options de navigation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Instructions vocales'),
              trailing: Switch(value: true, onChanged: (value) {}),
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              trailing: Switch(value: true, onChanged: (value) {}),
            ),
            ListTile(
              leading: const Icon(Icons.route),
              title: const Text('Recalculer itinéraire'),
              onTap: () {
                Navigator.pop(context);
                _recalculateRoute();
              },
            ),
            ListTile(
              leading: const Icon(Icons.save),
              title: const Text('Sauvegarder l\'état'),
              onTap: () {
                Navigator.pop(context);
                _navigationService.saveNavigationState();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('État de navigation sauvegardé'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _recalculateRoute() {
    final navProvider = context.read<NavigationProvider>();
    if (navProvider.startPoint != null && navProvider.endPoint != null) {
      navProvider.calculateRoute(
        navProvider.startPoint!,
        navProvider.endPoint!,
        transportMode: navProvider.routeProfile,
      );
    }
  }
}
