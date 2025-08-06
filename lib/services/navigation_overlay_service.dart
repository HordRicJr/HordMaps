import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'real_time_navigation_service.dart';
import '../../shared/extensions/color_extensions.dart';

/// Service pour gérer les overlays de navigation flottants
class NavigationOverlayService {
  static NavigationOverlayService? _instance;
  static NavigationOverlayService get instance =>
      _instance ??= NavigationOverlayService._();

  NavigationOverlayService._();

  static const MethodChannel _channel = MethodChannel('hordmaps/overlay');

  OverlayEntry? _currentOverlay;
  bool _isOverlayVisible = false;
  Timer? _autoHideTimer;
  StreamSubscription<NavigationProgress>? _progressSubscription;

  /// Initialise le service d'overlay
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      debugPrint('Erreur initialisation overlay service: $e');
    }
  }

  /// Affiche l'overlay de navigation dynamique
  Future<void> showNavigationOverlay(
    BuildContext context,
    NavigationProgress progress, {
    Duration autoHideDuration = const Duration(seconds: 10),
  }) async {
    if (_isOverlayVisible) {
      await hideNavigationOverlay();
    }

    if (!context.mounted) return;
    final overlay = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) => DynamicNavigationOverlay(
        progress: progress,
        onClose: hideNavigationOverlay,
        onExpand: () => _expandOverlay(context),
        onMinimize: () => _minimizeOverlay(),
      ),
    );

    overlay.insert(_currentOverlay!);
    _isOverlayVisible = true;

    // Démarre l'écoute des mises à jour de navigation
    _startProgressTracking();

    // Auto-masquage après la durée spécifiée
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(autoHideDuration, () {
      hideNavigationOverlay();
    });
  }

  /// Affiche un overlay persistant pendant la navigation
  Future<void> showPersistentNavigationOverlay(BuildContext context) async {
    if (_isOverlayVisible) return;

    final realTimeService = RealTimeNavigationService.instance;
    if (!realTimeService.isNavigating) return;

    if (!context.mounted) return;
    final overlay = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) => PersistentNavigationOverlay(
        onClose: hideNavigationOverlay,
        onExpand: () => _expandOverlay(context),
      ),
    );

    overlay.insert(_currentOverlay!);
    _isOverlayVisible = true;

    // Démarre l'écoute continue des mises à jour
    _startProgressTracking();
  }

  /// Démarre le suivi des mises à jour de navigation
  void _startProgressTracking() {
    final realTimeService = RealTimeNavigationService.instance;

    _progressSubscription?.cancel();
    _progressSubscription = realTimeService.progressStream.listen((progress) {
      if (_isOverlayVisible && _currentOverlay != null) {
        // Force la reconstruction de l'overlay avec les nouvelles données
        _currentOverlay!.markNeedsBuild();
      }
    });
  }

  /// Masque l'overlay de navigation
  Future<void> hideNavigationOverlay() async {
    try {
      _autoHideTimer?.cancel();
      _autoHideTimer = null;

      await _progressSubscription?.cancel();
      _progressSubscription = null;

      _currentOverlay?.remove();
      _currentOverlay = null;
      _isOverlayVisible = false;
    } catch (e) {
      debugPrint('Erreur masquage overlay: $e');
    }
  }

  /// Agrandit l'overlay
  void _expandOverlay(BuildContext context) {
    // Navigation vers l'écran de navigation complet
    Navigator.of(context).pushNamed('/navigation');
    hideNavigationOverlay();
  }

  /// Minimise l'overlay
  void _minimizeOverlay() {
    // Garde l'overlay mais le rend plus petit
    _currentOverlay?.markNeedsBuild();
  }

  /// Affiche un overlay système natif (Android uniquement)
  Future<void> showSystemOverlay({
    required String title,
    required String content,
    required double progress,
  }) async {
    try {
      await _channel.invokeMethod('showSystemOverlay', {
        'title': title,
        'content': content,
        'progress': progress,
      });
    } catch (e) {
      debugPrint('Erreur affichage overlay système: $e');
    }
  }

  /// Masque l'overlay système
  Future<void> hideSystemOverlay() async {
    try {
      await _channel.invokeMethod('hideSystemOverlay');
    } catch (e) {
      debugPrint('Erreur masquage overlay système: $e');
    }
  }

  /// Vérifie si la permission overlay est accordée
  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod('hasOverlayPermission');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Erreur vérification permission overlay: $e');
      return false;
    }
  }

  /// Demande la permission overlay
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('Erreur demande permission overlay: $e');
    }
  }

  /// Ouvre les paramètres overlay
  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (e) {
      debugPrint('Erreur ouverture paramètres overlay: $e');
    }
  }

  /// Force l'ouverture des paramètres overlay (Android 15)
  Future<void> forceOverlayPermission() async {
    try {
      await _channel.invokeMethod('forceOverlayPermission');
    } catch (e) {
      debugPrint('Erreur force permission overlay: $e');
    }
  }

  /// Getters
  bool get isOverlayVisible => _isOverlayVisible;
}

/// Widget overlay dynamique de navigation
class DynamicNavigationOverlay extends StatefulWidget {
  final NavigationProgress progress;
  final VoidCallback onClose;
  final VoidCallback onExpand;
  final VoidCallback onMinimize;

  const DynamicNavigationOverlay({
    super.key,
    required this.progress,
    required this.onClose,
    required this.onExpand,
    required this.onMinimize,
  });

  @override
  State<DynamicNavigationOverlay> createState() =>
      _DynamicNavigationOverlayState();
}

class _DynamicNavigationOverlayState extends State<DynamicNavigationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          shadowColor: Colors.black.withCustomOpacity(0.3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isMinimized ? 60 : 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withCustomOpacity(0.9),
                  Colors.black.withCustomOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.withCustomOpacity(0.6),
                width: 2,
              ),
            ),
            child: _isMinimized
                ? _buildMinimizedContent()
                : _buildFullContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildFullContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // En-tête avec icône et boutons de contrôle
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withCustomOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Navigation en cours',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isMinimized = true;
                  });
                  widget.onMinimize();
                },
                icon: const Icon(
                  Icons.minimize,
                  color: Colors.white70,
                  size: 20,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
              ),
              IconButton(
                onPressed: widget.onExpand,
                icon: const Icon(
                  Icons.open_in_full,
                  color: Colors.white70,
                  size: 20,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Informations de navigation
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value:
                      '${widget.progress.remainingDistance.toStringAsFixed(1)} km',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.access_time,
                  label: 'ETA',
                  value: _formatDuration(widget.progress.estimatedTimeArrival),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.speed,
                  label: 'Vitesse',
                  value:
                      '${widget.progress.averageSpeed.toStringAsFixed(0)} km/h',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimizedContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.progress.remainingDistance.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'ETA: ${_formatDuration(widget.progress.estimatedTimeArrival)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isMinimized = false;
              });
            },
            icon: const Icon(
              Icons.expand_less,
              color: Colors.white70,
              size: 20,
            ),
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withCustomOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
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
}

/// Widget overlay persistant pour la navigation
class PersistentNavigationOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onExpand;

  const PersistentNavigationOverlay({
    super.key,
    required this.onClose,
    required this.onExpand,
  });

  @override
  State<PersistentNavigationOverlay> createState() =>
      _PersistentNavigationOverlayState();
}

class _PersistentNavigationOverlayState
    extends State<PersistentNavigationOverlay> {
  late StreamSubscription<NavigationProgress> _progressSubscription;
  NavigationProgress? _currentProgress;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final realTimeService = RealTimeNavigationService.instance;
    _progressSubscription = realTimeService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentProgress == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 100,
      right: 16,
      child: GestureDetector(
        onTap: widget.onExpand,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black.withCustomOpacity(0.8),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.blue, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withCustomOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.navigation, color: Colors.blue, size: 24),
              const SizedBox(height: 4),
              Text(
                _currentProgress!.remainingDistance.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'km',
                style: const TextStyle(color: Colors.white70, fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
