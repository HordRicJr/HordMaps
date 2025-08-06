import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Service de navigation avec transitions fluides
class FluidNavigationService {
  /// Transition de glissement depuis la droite
  static Route<T> slideFromRight<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  /// Transition de glissement depuis la gauche
  static Route<T> slideFromLeft<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  /// Transition de glissement depuis le bas
  static Route<T> slideFromBottom<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  /// Transition de zoom (scale)
  static Route<T> scaleTransition<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        var scaleTween = Tween(
          begin: 0.8,
          end: 1.0,
        ).chain(CurveTween(curve: curve));
        var fadeTween = Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: curve));

        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Transition de rotation
  static Route<T> rotationTransition<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        var rotationTween = Tween(
          begin: 0.1,
          end: 0.0,
        ).chain(CurveTween(curve: curve));
        var scaleTween = Tween(
          begin: 0.8,
          end: 1.0,
        ).chain(CurveTween(curve: curve));

        return RotationTransition(
          turns: animation.drive(rotationTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Transition de fade simple
  static Route<T> fadeTransition<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Navigation fluide avec transition personnalisée
  static Future<T?> navigateTo<T extends Object?>(
    BuildContext context,
    Widget page, {
    NavigationTransition transition = NavigationTransition.slideFromRight,
    bool replace = false,
    bool clearStack = false,
  }) {
    Route<T> route;

    switch (transition) {
      case NavigationTransition.slideFromRight:
        route = slideFromRight<T>(page);
        break;
      case NavigationTransition.slideFromLeft:
        route = slideFromLeft<T>(page);
        break;
      case NavigationTransition.slideFromBottom:
        route = slideFromBottom<T>(page);
        break;
      case NavigationTransition.scale:
        route = scaleTransition<T>(page);
        break;
      case NavigationTransition.rotation:
        route = rotationTransition<T>(page);
        break;
      case NavigationTransition.fade:
        route = fadeTransition<T>(page);
        break;
    }

    if (clearStack) {
      return Navigator.of(context).pushAndRemoveUntil(route, (route) => false);
    } else if (replace) {
      return Navigator.of(context).pushReplacement(route);
    } else {
      return Navigator.of(context).push(route);
    }
  }

  /// Retour en arrière avec animation fluide
  static void goBack(BuildContext context, [result]) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }

  /// Retour jusqu'à la route nommée
  static void popUntil(BuildContext context, String routeName) {
    Navigator.of(context).popUntil(ModalRoute.withName(routeName));
  }
}

/// Types de transitions disponibles
enum NavigationTransition {
  slideFromRight,
  slideFromLeft,
  slideFromBottom,
  scale,
  rotation,
  fade,
}

/// Widget pour les transitions fluides entre les onglets
class FluidTabTransition extends StatefulWidget {
  final List<Widget> children;
  final int currentIndex;
  final Duration duration;

  const FluidTabTransition({
    super.key,
    required this.children,
    required this.currentIndex,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FluidTabTransition> createState() => _FluidTabTransitionState();
}

class _FluidTabTransitionState extends State<FluidTabTransition>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _previousIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(FluidTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            // Page précédente qui sort
            if (_animation.value < 1.0)
              Opacity(
                opacity: 1.0 - _animation.value,
                child: Transform.translate(
                  offset: Offset(-50 * _animation.value, 0),
                  child: widget.children[_previousIndex],
                ),
              ),
            // Page actuelle qui entre
            Opacity(
              opacity: _animation.value,
              child: Transform.translate(
                offset: Offset(50 * (1.0 - _animation.value), 0),
                child: widget.children[widget.currentIndex],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bouton avec animation de rebond
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration duration;
  final double scaleFactor;

  const BouncyButton({
    super.key,
    required this.child,
    this.onPressed,
    this.duration = const Duration(milliseconds: 150),
    this.scaleFactor = 0.95,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scale = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: widget.child);
        },
      ),
    );
  }
}

/// Widget pour les transitions de liste fluides
class FluidListTransition extends StatelessWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration itemDuration;
  final Axis scrollDirection;

  const FluidListTransition({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.itemDuration = const Duration(milliseconds: 300),
    this.scrollDirection = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;

        return child
            .animate(delay: staggerDelay * index)
            .slideY(
              begin: scrollDirection == Axis.vertical ? 1.0 : 0.0,
              end: 0.0,
              duration: itemDuration,
              curve: Curves.easeOutCubic,
            )
            .slideX(
              begin: scrollDirection == Axis.horizontal ? 1.0 : 0.0,
              end: 0.0,
              duration: itemDuration,
              curve: Curves.easeOutCubic,
            )
            .fadeIn(duration: itemDuration, curve: Curves.easeOut);
      }).toList(),
    );
  }
}
