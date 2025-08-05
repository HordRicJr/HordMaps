import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedFAB extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isExtended;
  final String? label;

  const AnimatedFAB({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.isExtended = false,
    this.label,
  });

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
    widget.onPressed();
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        widget.backgroundColor ??
                        Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(
                      widget.isExtended ? 24 : 28,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (widget.backgroundColor ??
                                    Theme.of(context).primaryColor)
                                .withOpacity(0.3),
                        blurRadius: _isPressed ? 8 : 12,
                        offset: Offset(0, _isPressed ? 2 : 4),
                      ),
                    ],
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isExtended ? 20 : 16,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          color: widget.foregroundColor ?? Colors.white,
                          size: 24,
                        ),
                        if (widget.isExtended && widget.label != null) ...[
                          const SizedBox(width: 12),
                          Text(
                                widget.label!,
                                style: TextStyle(
                                  color: widget.foregroundColor ?? Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 200.ms)
                              .slideX(begin: 0.3, duration: 200.ms),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        )
        .animate()
        .scale(
          begin: const Offset(0, 0),
          duration: 300.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 200.ms);
  }
}
