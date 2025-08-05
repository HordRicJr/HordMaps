import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton Zoom In
            _buildControlButton(
              context: context,
              icon: Icons.add,
              onPressed: onZoomIn,
              isTop: true,
            ),

            // Séparateur
            Container(
              width: 48,
              height: 1,
              color: Colors.grey.withOpacity(0.3),
            ),

            // Bouton Zoom Out
            _buildControlButton(
              context: context,
              icon: Icons.remove,
              onPressed: onZoomOut,
              isTop: false,
            ),
          ],
        )
        .animate()
        .slideX(begin: 1, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn(delay: 200.ms);
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isTop,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.vertical(
        top: isTop ? const Radius.circular(12) : Radius.zero,
        bottom: isTop ? Radius.zero : const Radius.circular(12),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(12) : Radius.zero,
          bottom: isTop ? Radius.zero : const Radius.circular(12),
        ),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        ),
      ),
    );
  }
}
