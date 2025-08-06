import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/extensions/color_extensions.dart';

/// Configuration pour l'animation de trajet
class RouteAnimationConfig {
  final Duration duration;
  final Curve curve;
  final double speed; // points par seconde
  final bool loop;
  final bool autoStart;
  final Color trailColor;
  final double trailWidth;
  final Color markerColor;
  final double markerSize;
  final IconData markerIcon;

  const RouteAnimationConfig({
    this.duration = const Duration(seconds: 10),
    this.curve = Curves.linear,
    this.speed = 10.0,
    this.loop = false,
    this.autoStart = true,
    this.trailColor = Colors.blue,
    this.trailWidth = 4.0,
    this.markerColor = Colors.red,
    this.markerSize = 20.0,
    this.markerIcon = Icons.navigation,
  });
}

/// État de l'animation
enum AnimationState { stopped, playing, paused, completed }

/// Point d'animation avec métadonnées
class AnimationPoint {
  final LatLng position;
  final DateTime? timestamp;
  final double? speed;
  final double? bearing;
  final Map<String, dynamic>? metadata;

  const AnimationPoint({
    required this.position,
    this.timestamp,
    this.speed,
    this.bearing,
    this.metadata,
  });
}

/// Service d'animation de trajets
class RouteAnimationService extends ChangeNotifier {
  List<AnimationPoint> _points = [];
  RouteAnimationConfig _config = const RouteAnimationConfig();
  AnimationState _state = AnimationState.stopped;

  Timer? _animationTimer;
  int _currentIndex = 0;
  double _progress = 0.0;
  LatLng? _currentPosition;
  double? _currentBearing;

  // Getters
  List<AnimationPoint> get points => List.unmodifiable(_points);
  RouteAnimationConfig get config => _config;
  AnimationState get state => _state;
  int get currentIndex => _currentIndex;
  double get progress => _progress;
  LatLng? get currentPosition => _currentPosition;
  double? get currentBearing => _currentBearing;
  bool get isPlaying => _state == AnimationState.playing;
  bool get isPaused => _state == AnimationState.paused;
  bool get isCompleted => _state == AnimationState.completed;

  /// Durée totale estimée du trajet
  Duration get estimatedDuration {
    if (_points.isEmpty) return Duration.zero;

    if (_points.first.timestamp != null && _points.last.timestamp != null) {
      return _points.last.timestamp!.difference(_points.first.timestamp!);
    }

    return Duration(
      milliseconds: (_points.length * 1000 / _config.speed).round(),
    );
  }

  /// Distance totale du trajet
  double get totalDistance {
    if (_points.length < 2) return 0.0;

    const Distance distance = Distance();
    double total = 0.0;

    for (int i = 1; i < _points.length; i++) {
      total += distance.as(
        LengthUnit.Meter,
        _points[i - 1].position,
        _points[i].position,
      );
    }

    return total;
  }

  /// Configure l'animation
  void configure(RouteAnimationConfig config) {
    _config = config;
    notifyListeners();
  }

  /// Définit les points du trajet
  void setPoints(List<LatLng> positions) {
    _points = positions.map((pos) => AnimationPoint(position: pos)).toList();

    _reset();

    if (_config.autoStart && _points.isNotEmpty) {
      play();
    }

    notifyListeners();
  }

  /// Définit les points avec métadonnées
  void setAnimationPoints(List<AnimationPoint> points) {
    _points = List.from(points);
    _reset();

    if (_config.autoStart && _points.isNotEmpty) {
      play();
    }

    notifyListeners();
  }

  /// Démarre l'animation
  void play() {
    if (_points.isEmpty) return;

    _state = AnimationState.playing;

    // Calcul de l'intervalle basé sur la vitesse
    final interval = Duration(milliseconds: (1000 / _config.speed).round());

    _animationTimer = Timer.periodic(interval, (timer) {
      _updateAnimation();
    });

    notifyListeners();
  }

  /// Met en pause l'animation
  void pause() {
    if (_state == AnimationState.playing) {
      _animationTimer?.cancel();
      _state = AnimationState.paused;
      notifyListeners();
    }
  }

  /// Reprend l'animation
  void resume() {
    if (_state == AnimationState.paused) {
      play();
    }
  }

  /// Arrête l'animation
  void stop() {
    _animationTimer?.cancel();
    _reset();
    _state = AnimationState.stopped;
    notifyListeners();
  }

  /// Redémarre l'animation
  void restart() {
    stop();
    play();
  }

  /// Va à un point spécifique (0.0 = début, 1.0 = fin)
  void seekTo(double progress) {
    if (_points.isEmpty) return;

    progress = progress.clamp(0.0, 1.0);
    _progress = progress;

    final totalPoints = _points.length - 1;
    final exactIndex = progress * totalPoints;
    _currentIndex = exactIndex.floor();

    if (_currentIndex >= _points.length - 1) {
      _currentIndex = _points.length - 1;
      _currentPosition = _points.last.position;
      _currentBearing = _points.last.bearing;
    } else {
      final nextIndex = _currentIndex + 1;
      final segmentProgress = exactIndex - _currentIndex;

      _currentPosition = _interpolatePosition(
        _points[_currentIndex].position,
        _points[nextIndex].position,
        segmentProgress,
      );

      _currentBearing = _calculateBearing(
        _points[_currentIndex].position,
        _points[nextIndex].position,
      );
    }

    notifyListeners();
  }

  /// Met à jour l'animation
  void _updateAnimation() {
    if (_points.isEmpty || _currentIndex >= _points.length - 1) {
      _completeAnimation();
      return;
    }

    _currentIndex++;
    _progress = _currentIndex / (_points.length - 1);
    _currentPosition = _points[_currentIndex].position;

    // Calcul du bearing si possible
    if (_currentIndex > 0) {
      _currentBearing = _calculateBearing(
        _points[_currentIndex - 1].position,
        _points[_currentIndex].position,
      );
    }

    notifyListeners();

    // Vérification de fin
    if (_currentIndex >= _points.length - 1) {
      _completeAnimation();
    }
  }

  /// Termine l'animation
  void _completeAnimation() {
    _animationTimer?.cancel();
    _state = AnimationState.completed;
    _progress = 1.0;

    if (_config.loop) {
      Timer(const Duration(milliseconds: 500), () {
        restart();
      });
    }

    notifyListeners();
  }

  /// Remet à zéro les valeurs
  void _reset() {
    _currentIndex = 0;
    _progress = 0.0;
    _currentPosition = _points.isNotEmpty ? _points.first.position : null;
    _currentBearing = null;
  }

  /// Interpole entre deux positions
  LatLng _interpolatePosition(LatLng start, LatLng end, double progress) {
    final lat = start.latitude + (end.latitude - start.latitude) * progress;
    final lng = start.longitude + (end.longitude - start.longitude) * progress;
    return LatLng(lat, lng);
  }

  /// Calcule le bearing entre deux points
  double _calculateBearing(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance.bearing(start, end);
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  /// Obtient les statistiques de l'animation
  Map<String, dynamic> getStats() {
    return {
      'totalPoints': _points.length,
      'currentIndex': _currentIndex,
      'progress': _progress,
      'state': _state.name,
      'totalDistance': totalDistance,
      'estimatedDuration': estimatedDuration.inSeconds,
      'currentPosition': _currentPosition != null
          ? {
              'latitude': _currentPosition!.latitude,
              'longitude': _currentPosition!.longitude,
            }
          : null,
      'currentBearing': _currentBearing,
    };
  }
}

/// Widget d'animation de trajet
class RouteAnimationWidget extends StatefulWidget {
  final RouteAnimationService service;
  final Widget Function(
    BuildContext context,
    LatLng? position,
    double? bearing,
  )?
  builder;

  const RouteAnimationWidget({super.key, required this.service, this.builder});

  @override
  State<RouteAnimationWidget> createState() => _RouteAnimationWidgetState();
}

class _RouteAnimationWidgetState extends State<RouteAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    widget.service.addListener(_onAnimationUpdate);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onAnimationUpdate);
    _rotationController.dispose();
    super.dispose();
  }

  void _onAnimationUpdate() {
    if (widget.service.currentBearing != null) {
      _rotationController.animateTo(widget.service.currentBearing! / 360.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, child) {
        if (widget.builder != null) {
          return widget.builder!(
            context,
            widget.service.currentPosition,
            widget.service.currentBearing,
          );
        }

        if (widget.service.currentPosition == null) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationController.value * 2 * math.pi,
              child: Container(
                width: widget.service.config.markerSize,
                height: widget.service.config.markerSize,
                decoration: BoxDecoration(
                  color: widget.service.config.markerColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withCustomOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.service.config.markerIcon,
                  color: Colors.white,
                  size: widget.service.config.markerSize * 0.6,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Contrôleur d'animation avec interface utilisateur
class RouteAnimationController extends StatelessWidget {
  final RouteAnimationService service;

  const RouteAnimationController({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withCustomOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barre de progression
              LinearProgressIndicator(
                value: service.progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),

              const SizedBox(height: 16),

              // Contrôles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: service.stop,
                    icon: const Icon(Icons.stop),
                    tooltip: 'Arrêter',
                  ),
                  IconButton(
                    onPressed: service.isPlaying
                        ? service.pause
                        : service.resume,
                    icon: Icon(
                      service.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    tooltip: service.isPlaying ? 'Pause' : 'Lecture',
                  ),
                  IconButton(
                    onPressed: service.restart,
                    icon: const Icon(Icons.replay),
                    tooltip: 'Redémarrer',
                  ),
                ],
              ),

              // Informations
              Text(
                '${service.currentIndex + 1} / ${service.points.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
