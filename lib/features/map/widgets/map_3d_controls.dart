import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/map_3d_service.dart';

/// Widget de contrôles 3D pour la carte
class Map3DControls extends StatelessWidget {
  const Map3DControls({super.key});

  @override
  Widget build(BuildContext context) {
    final map3DService = Map3DService.instance;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton toggle 3D
          _buildToggle3DButton(context, map3DService),

          if (map3DService.is3DEnabled) ...[
            const SizedBox(height: 12),

            // Contrôle d'inclinaison
            _buildTiltControl(context, map3DService),

            const SizedBox(height: 8),

            // Contrôle de rotation
            _buildBearingControl(context, map3DService),

            const SizedBox(height: 8),

            // Contrôle hauteur des bâtiments
            _buildBuildingHeightControl(context, map3DService),
          ],
        ],
      ),
    );
  }

  Widget _buildToggle3DButton(BuildContext context, Map3DService service) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          service.toggle3DMode();
          // Trigger rebuild via setState ou Provider
          (context as Element).markNeedsBuild();
        },
        icon: Icon(
          service.is3DEnabled ? Icons.threed_rotation : Icons.map,
          size: 18,
        ),
        label: Text(
          service.is3DEnabled ? 'Mode 2D' : 'Mode 3D',
          style: const TextStyle(fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: service.is3DEnabled
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          foregroundColor: service.is3DEnabled
              ? Colors.white
              : Theme.of(context).textTheme.bodyLarge?.color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildTiltControl(BuildContext context, Map3DService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Inclinaison',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '${service.tiltAngle.toInt()}°',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: service.tiltAngle,
            min: 0,
            max: 60,
            divisions: 12,
            onChanged: (value) {
              service.setTilt(value);
              (context as Element).markNeedsBuild();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBearingControl(BuildContext context, Map3DService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Rotation',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '${service.bearing.toInt()}°',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: service.bearing,
            min: 0,
            max: 360,
            divisions: 36,
            onChanged: (value) {
              service.setBearing(value);
              (context as Element).markNeedsBuild();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingHeightControl(
    BuildContext context,
    Map3DService service,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hauteur bâtiments',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '${service.buildingHeight.toInt()}px',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: service.buildingHeight,
            min: 5,
            max: 50,
            divisions: 9,
            onChanged: (value) {
              service.setBuildingHeight(value);
              (context as Element).markNeedsBuild();
            },
          ),
        ),
      ],
    );
  }
}

/// Widget d'affichage du profil d'élévation
class ElevationProfileWidget extends StatelessWidget {
  final List<double> elevationProfile;
  final double currentPosition;

  const ElevationProfileWidget({
    super.key,
    required this.elevationProfile,
    this.currentPosition = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (elevationProfile.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 120,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.terrain,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 6),
              const Text(
                'Profil d\'élévation',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${_getMinElevation().toInt()}m - ${_getMaxElevation().toInt()}m',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: ElevationProfilePainter(
                elevationProfile: elevationProfile,
                currentPosition: currentPosition,
                primaryColor: Theme.of(context).primaryColor,
              ),
              size: const Size(double.infinity, double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  double _getMinElevation() {
    return elevationProfile.reduce((a, b) => a < b ? a : b);
  }

  double _getMaxElevation() {
    return elevationProfile.reduce((a, b) => a > b ? a : b);
  }
}

/// Painter personnalisé pour le profil d'élévation
class ElevationProfilePainter extends CustomPainter {
  final List<double> elevationProfile;
  final double currentPosition;
  final Color primaryColor;

  ElevationProfilePainter({
    required this.elevationProfile,
    required this.currentPosition,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (elevationProfile.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final currentPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    final linePath = Path();

    final minElevation = elevationProfile.reduce((a, b) => a < b ? a : b);
    final maxElevation = elevationProfile.reduce((a, b) => a > b ? a : b);
    final elevationRange = maxElevation - minElevation;

    if (elevationRange == 0) return;

    // Démarrer le chemin de remplissage
    path.moveTo(0, size.height);

    // Démarrer le chemin de ligne
    final firstY =
        size.height -
        ((elevationProfile[0] - minElevation) / elevationRange) * size.height;
    linePath.moveTo(0, firstY);
    path.lineTo(0, firstY);

    // Dessiner les points
    for (int i = 1; i < elevationProfile.length; i++) {
      final x = (i / (elevationProfile.length - 1)) * size.width;
      final y =
          size.height -
          ((elevationProfile[i] - minElevation) / elevationRange) * size.height;

      linePath.lineTo(x, y);
      path.lineTo(x, y);
    }

    // Fermer le chemin de remplissage
    path.lineTo(size.width, size.height);
    path.close();

    // Dessiner le remplissage
    canvas.drawPath(path, paint);

    // Dessiner la ligne
    canvas.drawPath(linePath, linePaint);

    // Dessiner la position actuelle
    if (currentPosition >= 0 && currentPosition <= 1) {
      final currentX = currentPosition * size.width;
      final currentIndex = (currentPosition * (elevationProfile.length - 1))
          .round();
      if (currentIndex < elevationProfile.length) {
        final currentY =
            size.height -
            ((elevationProfile[currentIndex] - minElevation) / elevationRange) *
                size.height;
        canvas.drawLine(
          Offset(currentX, 0),
          Offset(currentX, size.height),
          currentPaint,
        );

        // Point actuel
        canvas.drawCircle(
          Offset(currentX, currentY),
          4,
          Paint()..color = Colors.red,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ElevationProfilePainter oldDelegate) {
    return oldDelegate.elevationProfile != elevationProfile ||
        oldDelegate.currentPosition != currentPosition;
  }
}
