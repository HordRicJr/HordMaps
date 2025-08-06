import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/extensions/color_extensions.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.directions_car,
        label: 'En voiture',
        color: Colors.blue,
        onTap: () => _showMessage(context, 'Navigation en voiture'),
      ),
      _QuickAction(
        icon: Icons.directions_walk,
        label: 'À pied',
        color: Colors.green,
        onTap: () => _showMessage(context, 'Navigation à pied'),
      ),
      _QuickAction(
        icon: Icons.directions_bike,
        label: 'À vélo',
        color: Colors.orange,
        onTap: () => _showMessage(context, 'Navigation à vélo'),
      ),
      _QuickAction(
        icon: Icons.local_gas_station,
        label: 'Station',
        color: Colors.red,
        onTap: () => _showMessage(context, 'Recherche station-service'),
      ),
      _QuickAction(
        icon: Icons.restaurant,
        label: 'Restaurant',
        color: Colors.purple,
        onTap: () => _showMessage(context, 'Recherche restaurants'),
      ),
      _QuickAction(
        icon: Icons.local_hospital,
        label: 'Urgences',
        color: Colors.red[700]!,
        onTap: () => _showMessage(context, 'Recherche urgences'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        return actions[index]
            .animate(delay: Duration(milliseconds: index * 100))
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.8, 0.8));
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withCustomOpacity(0.1), color.withCustomOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withCustomOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
