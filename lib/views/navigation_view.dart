import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../controllers/route_controller.dart';
import '../../shared/extensions/color_extensions.dart';
import '../../features/navigation/providers/provider_navigation.dart';
import '../../services/voice_guidance_service.dart';

/// Vue MVC pour la navigation en temps réel
class NavigationView extends StatefulWidget {
  const NavigationView({super.key});

  @override
  State<NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<NavigationView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;

  RouteController? _routeController;
  VoiceGuidanceService? _voiceService;

  bool _isMapExpanded = false;
  final bool _showSpeedInfo = true;
  final bool _showManeuvers = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialisation différée des services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  void _initializeServices() {
    if (mounted) {
      _routeController = RouteController.instance;
      _voiceService = VoiceGuidanceService();

      // Démarrer la navigation si une route est disponible
      if (_routeController?.currentRoute != null) {
        _startNavigation();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            _buildNavigationHeader(context, isDark),
            Expanded(
              flex: _isMapExpanded ? 8 : 5,
              child: _buildMapArea(context, isDark),
            ),
            if (!_isMapExpanded) ...[
              Expanded(flex: 3, child: _buildNavigationInfo(context, isDark)),
            ],
            _buildNavigationControls(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Consumer<NavigationProvider>(
        builder: (context, navProvider, child) {
          return Row(
            children: [
              IconButton(
                onPressed: () => _showExitDialog(context),
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDestinationText(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (navProvider.isNavigating) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatRemainingTime(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.straighten,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatRemainingDistance(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isMapExpanded = !_isMapExpanded;
                  });
                  if (_isMapExpanded) {
                    _slideController.forward();
                  } else {
                    _slideController.reverse();
                  }
                },
                icon: AnimatedRotation(
                  turns: _isMapExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.expand_less),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapArea(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Zone de la carte (à remplacer par votre widget de carte)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.withCustomOpacity(0.1),
                    Colors.green.withCustomOpacity(0.1),
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Carte de navigation',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // Indicateur de position utilisateur
            Positioned(
              bottom: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.2),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF4CAF50,
                            ).withCustomOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Boutons de contrôle de la carte
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                children: [
                  _buildMapControlButton(
                    icon: Icons.zoom_in,
                    onPressed: () => _zoomIn(),
                  ),
                  const SizedBox(height: 8),
                  _buildMapControlButton(
                    icon: Icons.zoom_out,
                    onPressed: () => _zoomOut(),
                  ),
                  const SizedBox(height: 8),
                  _buildMapControlButton(
                    icon: Icons.my_location,
                    onPressed: () => _centerOnUser(),
                  ),
                ],
              ),
            ),

            // Informations de vitesse
            if (_showSpeedInfo)
              Positioned(top: 16, left: 16, child: _buildSpeedInfo(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withCustomOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(onPressed: onPressed, icon: Icon(icon), iconSize: 20),
    );
  }

  Widget _buildSpeedInfo(bool isDark) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withCustomOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '${navProvider.currentSpeed.toInt()}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'km/h',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationInfo(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Consumer<NavigationProvider>(
        builder: (context, navProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_showManeuvers) ...[
                  _buildNextManeuver(navProvider, isDark),
                  const SizedBox(height: 16),
                ],
                _buildRouteProgress(navProvider, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNextManeuver(NavigationProvider navProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.turn_right, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dans 200 m',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tournez à droite sur Avenue des Champs-Élysées',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideX(begin: -1, end: 0).fadeIn();
  }

  Widget _buildRouteProgress(NavigationProvider navProvider, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progression',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: 0.0, // Simplifié
          backgroundColor: Colors.grey.withCustomOpacity(0.2),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temps restant',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  _formatRemainingTime(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Distance restante',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  _formatRemainingDistance(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationControls(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _pauseNavigation,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showExitDialog(context),
              icon: const Icon(Icons.stop),
              label: const Text('Arrêter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _toggleVoiceGuidance,
            icon: Icon(
              _voiceService?.isEnabled == true
                  ? Icons.volume_up
                  : Icons.volume_off,
            ),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getDestinationText() {
    return _routeController?.endAddress ?? 'Destination';
  }

  String _formatRemainingTime() {
    // TODO: Récupérer le temps restant réel depuis NavigationProvider
    return '15 min';
  }

  String _formatRemainingDistance() {
    // TODO: Récupérer la distance restante réelle depuis NavigationProvider
    return '3.2 km';
  }

  void _startNavigation() {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    navProvider.startNavigation();

    // Configurer l'écran pour rester allumé
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _pauseNavigation() {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    // NavigationProvider n'a pas de pause, on arrête
    navProvider.stopNavigation();
  }

  void _toggleVoiceGuidance() {
    // VoiceGuidanceService n'a pas de toggle simple
    setState(() {});
  }

  void _zoomIn() {
    // TODO: Implémenter le zoom avant sur la carte
  }

  void _zoomOut() {
    // TODO: Implémenter le zoom arrière sur la carte
  }

  void _centerOnUser() {
    // TODO: Centrer la carte sur la position de l'utilisateur
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arrêter la navigation'),
        content: const Text('Voulez-vous vraiment arrêter la navigation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exitNavigation();
            },
            child: const Text('Arrêter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _exitNavigation() {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    navProvider.stopNavigation();

    // Restaurer l'interface système
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    Navigator.of(context).pop();
  }
}
