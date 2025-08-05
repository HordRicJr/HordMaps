import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoadingIndicator extends StatelessWidget {
  final String message;
  final double? size;

  const LoadingIndicator({
    super.key,
    this.message = 'Chargement...',
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
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
            SizedBox(
                  width: size ?? 32,
                  height: size ?? 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: 1000.ms),

            const SizedBox(height: 16),

            Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                )
                .animate()
                .fadeIn(delay: 200.ms)
                .slideY(begin: 0.3, duration: 300.ms),
          ],
        ),
      ).animate().scale(begin: const Offset(0.8, 0.8)).fadeIn(duration: 300.ms),
    );
  }
}
