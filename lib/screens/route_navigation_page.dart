import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../features/navigation/providers/navigation_provider_basic.dart';
import '../services/voice_guidance_service.dart';

/// Page d'itinéraire moderne avec navigation turn-by-turn
class RouteNavigationPage extends StatefulWidget {
  final String departure;
  final String destination;
  final String? transportMode;

  const RouteNavigationPage({
    super.key,
    required this.departure,
    required this.destination,
    this.transportMode,
  });

  @override
  State<RouteNavigationPage> createState() => _RouteNavigationPageState();
}

class _RouteNavigationPageState extends State<RouteNavigationPage> {
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Navigation'),
        backgroundColor: Colors.purple[400],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareRoute(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openRouteSettings(),
          ),
        ],
      ),
      body: Consumer<NavigationProvider>(
        builder: (context, navigationProvider, child) {
          return Column(
            children: [
              _buildRouteHeader(context, isDark),
              _buildRouteOptions(context, isDark),
              Expanded(child: _buildRouteSteps(context, isDark)),
              _buildNavigationControls(context, isDark, navigationProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRouteHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.departure,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(left: 6),
            height: 20,
            width: 2,
            color: Colors.grey[400],
          ),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.destination,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.3);
  }

  Widget _buildRouteOptions(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRouteOption(
            icon: Icons.directions_car,
            label: 'Voiture',
            time: '25 min',
            distance: '18.2 km',
            isSelected: true,
            isDark: isDark,
          ),
          _buildRouteOption(
            icon: Icons.directions_walk,
            label: 'Marche',
            time: '3h 42min',
            distance: '18.2 km',
            isSelected: false,
            isDark: isDark,
          ),
          _buildRouteOption(
            icon: Icons.directions_bike,
            label: 'Vélo',
            time: '1h 15min',
            distance: '18.2 km',
            isSelected: false,
            isDark: isDark,
          ),
          _buildRouteOption(
            icon: Icons.directions_transit,
            label: 'Transport',
            time: '45 min',
            distance: '22.1 km',
            isSelected: false,
            isDark: isDark,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildRouteOption({
    required IconData icon,
    required String label,
    required String time,
    required String distance,
    required bool isSelected,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.purple[400]
                : (isDark ? Colors.grey[700] : Colors.grey[200]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey[600],
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildRouteSteps(BuildContext context, bool isDark) {
    final steps = [
      {
        'instruction': 'Dirigez-vous vers le nord sur Rue de la Paix',
        'distance': '500 m',
        'icon': Icons.straight,
      },
      {
        'instruction': 'Tournez à droite sur Avenue des Champs',
        'distance': '1.2 km',
        'icon': Icons.turn_right,
      },
      {
        'instruction': 'Au rond-point, prenez la 2ème sortie',
        'distance': '200 m',
        'icon': Icons.roundabout_right,
      },
      {
        'instruction': 'Continuez tout droit sur Boulevard Central',
        'distance': '3.5 km',
        'icon': Icons.straight,
      },
      {
        'instruction': 'Tournez à gauche sur Rue de la Destination',
        'distance': '300 m',
        'icon': Icons.turn_left,
      },
      {
        'instruction': 'Arrivée à destination',
        'distance': '',
        'icon': Icons.flag,
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instructions de navigation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                final isLast = index == steps.length - 1;

                return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isLast
                                ? Colors.green[100]
                                : Colors.purple[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            step['icon'] as IconData,
                            color: isLast
                                ? Colors.green[600]
                                : Colors.purple[600],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          step['instruction'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: (step['distance'] as String).isNotEmpty
                            ? Text(
                                step['distance'] as String,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                    )
                    .animate(delay: Duration(milliseconds: 300 + index * 100))
                    .fadeIn()
                    .slideX(begin: 0.3);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationControls(
    BuildContext context,
    bool isDark,
    NavigationProvider navigationProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleNavigation(navigationProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNavigating
                        ? Colors.red[400]
                        : Colors.purple[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(_isNavigating ? Icons.stop : Icons.navigation),
                  label: Text(
                    _isNavigating ? 'Arrêter' : 'Commencer',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _toggleVoiceGuidance(),
                  icon: const Icon(Icons.volume_up),
                  color: Colors.purple[600],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _openMapView(),
                  icon: const Icon(Icons.map),
                  color: Colors.purple[600],
                ),
              ),
            ],
          ),
          if (_isNavigating) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Navigation active - Restez vigilant sur la route',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().slideY(begin: 0.3, delay: 400.ms);
  }

  void _shareRoute() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Itinéraire partagé'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openRouteSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Options d\'itinéraire',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.toll),
              title: const Text('Éviter les péages'),
              trailing: Switch(value: false, onChanged: (value) {}),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Éviter les autoroutes'),
              trailing: Switch(value: false, onChanged: (value) {}),
            ),
            ListTile(
              leading: const Icon(Icons.construction),
              title: const Text('Éviter les travaux'),
              trailing: Switch(value: true, onChanged: (value) {}),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleNavigation(NavigationProvider navigationProvider) {
    setState(() {
      _isNavigating = !_isNavigating;
    });

    if (_isNavigating) {
      navigationProvider.startNavigation();
      VoiceGuidanceService().speak(
        'Navigation démarrée vers ${widget.destination}',
      );
    } else {
      navigationProvider.stopNavigation();
      VoiceGuidanceService().speak('Navigation arrêtée');
    }
  }

  void _toggleVoiceGuidance() {
    VoiceGuidanceService().speak('Guidage vocal activé');
  }

  void _openMapView() {
    Navigator.pop(context);
  }
}
