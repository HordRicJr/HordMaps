import 'package:flutter/material.dart';
import 'dart:math' as math;

class CompassUtils {
  /// Convertit un angle en radians
  static double degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Convertit des radians en degrés
  static double radiansToDegrees(double radians) {
    return radians * (180 / math.pi);
  }

  /// Normalise un angle entre 0 et 360 degrés
  static double normalizeAngle(double angle) {
    while (angle < 0) angle += 360;
    while (angle >= 360) angle -= 360;
    return angle;
  }

  /// Convertit un angle en direction cardinale
  static String angleToCardinal(double angle) {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSO',
      'SO',
      'OSO',
      'O',
      'ONO',
      'NO',
      'NNO',
    ];

    angle = normalizeAngle(angle);
    final index = ((angle + 11.25) / 22.5).round() % 16;
    return directions[index];
  }
}

/// Widget boussole simple
class CompassWidget extends StatefulWidget {
  final double rotation;
  final double size;

  const CompassWidget({super.key, required this.rotation, this.size = 120});

  @override
  State<CompassWidget> createState() => _CompassWidgetState();
}

class _CompassWidgetState extends State<CompassWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _lastRotation = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CompassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotation != widget.rotation) {
      _updateRotation();
    }
  }

  void _updateRotation() {
    _animation = Tween<double>(begin: _lastRotation, end: widget.rotation)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _lastRotation = widget.rotation;
    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: CompassUtils.degreesToRadians(_animation.value),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cercle principal
                Container(
                  width: widget.size - 16,
                  height: widget.size - 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                ),

                // Aiguille Nord (rouge)
                Positioned(
                  top: 8,
                  child: Container(
                    width: 3,
                    height: widget.size / 3,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Aiguille Sud (blanc)
                Positioned(
                  bottom: 8,
                  child: Container(
                    width: 3,
                    height: widget.size / 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.grey, width: 1),
                    ),
                  ),
                ),

                // Centre
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),

                // Marques cardinales
                ...List.generate(4, (index) {
                  final angle = index * 90.0;
                  final isNorth = index == 0;
                  return Transform.rotate(
                    angle: CompassUtils.degreesToRadians(angle),
                    child: Positioned(
                      top: 4,
                      child: Text(
                        ['N', 'E', 'S', 'O'][index],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isNorth ? Colors.red : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Provider pour la gestion de la boussole
class CompassProvider extends ChangeNotifier {
  double _heading = 0.0;
  bool _isEnabled = false;

  double get heading => _heading;
  bool get isEnabled => _isEnabled;
  String get cardinalDirection => CompassUtils.angleToCardinal(_heading);

  void updateHeading(double heading) {
    _heading = CompassUtils.normalizeAngle(heading);
    notifyListeners();
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }
}
