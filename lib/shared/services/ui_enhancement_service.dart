import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../shared/extensions/color_extensions.dart';

/// Service d'améliorations de l'interface utilisateur
class UIEnhancementService {
  static const Duration _defaultAnimationDuration = Duration(milliseconds: 300);
  static const Curve _defaultAnimationCurve = Curves.easeInOutCubic;

  /// Animation d'entrée fluide pour les widgets
  static Widget slideInFromBottom(
    Widget child, {
    Duration? delay,
    Duration? duration,
  }) {
    return child
        .animate(delay: delay ?? Duration.zero)
        .slideY(
          begin: 1.0,
          end: 0.0,
          duration: duration ?? _defaultAnimationDuration,
          curve: _defaultAnimationCurve,
        )
        .fadeIn(
          duration: duration ?? _defaultAnimationDuration,
          curve: _defaultAnimationCurve,
        );
  }

  /// Animation d'entrée fluide depuis la gauche
  static Widget slideInFromLeft(
    Widget child, {
    Duration? delay,
    Duration? duration,
  }) {
    return child
        .animate(delay: delay ?? Duration.zero)
        .slideX(
          begin: -1.0,
          end: 0.0,
          duration: duration ?? _defaultAnimationDuration,
          curve: _defaultAnimationCurve,
        )
        .fadeIn(
          duration: duration ?? _defaultAnimationDuration,
          curve: _defaultAnimationCurve,
        );
  }

  /// Animation d'entrée fluide depuis la droite
  static Widget slideInFromRight(
    Widget child, {
    Duration? delay,
    Duration? duration,
  }) {
    return child
        .animate(delay: delay ?? Duration.zero)
        .slideX(
          begin: 1.0,
          end: 0.0,
          duration: duration ?? _defaultAnimationDuration,
          curve: _defaultAnimationCurve,
        )
        .fadeIn(
          duration: duration ?? _defaultAnimationDuration,
          curve: _defaultAnimationCurve,
        );
  }

  /// Animation de mise à l'échelle fluide
  static Widget scaleIn(
    Widget child, {
    Duration? delay,
    Duration? duration,
    double beginScale = 0.8,
  }) {
    return child
        .animate(delay: delay ?? Duration.zero)
        .scale(
          begin: Offset(beginScale, beginScale),
          end: const Offset(1.0, 1.0),
          duration: duration ?? _defaultAnimationDuration,
          curve: _defaultAnimationCurve,
        )
        .fadeIn(
          duration: duration ?? _defaultAnimationDuration,
          curve: _defaultAnimationCurve,
        );
  }

  /// Animation de pulsation pour attirer l'attention
  static Widget pulse(Widget child, {Duration? duration, bool repeat = true}) {
    return child
        .animate(
          onPlay: (controller) =>
              repeat ? controller.repeat(reverse: true) : null,
        )
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.05, 1.05),
          duration: duration ?? const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
  }

  /// Container avec ombre moderne
  static Widget modernContainer({
    required Widget child,
    required bool isDark,
    EdgeInsets? padding,
    EdgeInsets? margin,
    BorderRadius? borderRadius,
    Color? backgroundColor,
    double elevation = 4,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDark
                ? Colors.grey[800] ?? const Color(0xFF424242)
                : Colors.white),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withCustomOpacity(0.1),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation / 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  /// Bouton avec design moderne et animations
  static Widget modernButton({
    required String text,
    required VoidCallback onPressed,
    required bool isDark,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    bool isSecondary = false,
    EdgeInsets? padding,
    double borderRadius = 12,
  }) {
    final defaultBackgroundColor = isSecondary
        ? (isDark
              ? Colors.grey[700] ?? const Color(0xFF424242)
              : Colors.grey[200] ?? const Color(0xFFEEEEEE))
        : const Color(0xFF4CAF50);

    final defaultTextColor = isSecondary
        ? (isDark ? Colors.white : Colors.black87)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: AnimatedContainer(
          duration: _defaultAnimationDuration,
          padding:
              padding ??
              const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: backgroundColor ?? defaultBackgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: isSecondary
                ? null
                : [
                    BoxShadow(
                      color: (backgroundColor ?? defaultBackgroundColor)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor ?? defaultTextColor, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: textColor ?? defaultTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// TextField avec design moderne
  static Widget modernTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    IconData? prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixPressed,
    VoidCallback? onTap,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    Color? prefixIconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[800] ?? const Color(0xFF424242)
            : Colors.grey[50] ?? const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        onTap: onTap,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark
                ? Colors.grey[400] ?? const Color(0xFFBDBDBD)
                : Colors.grey[500] ?? const Color(0xFF9E9E9E),
            fontSize: 16,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  color:
                      prefixIconColor ??
                      (isDark
                          ? Colors.grey[400] ?? const Color(0xFFBDBDBD)
                          : Colors.grey[600] ?? const Color(0xFF757575)),
                  size: 20,
                )
              : null,
          suffixIcon: suffixIcon != null
              ? IconButton(
                  icon: Icon(
                    suffixIcon,
                    color: isDark
                        ? Colors.grey[400] ?? const Color(0xFFBDBDBD)
                        : Colors.grey[600] ?? const Color(0xFF757575),
                    size: 20,
                  ),
                  onPressed: onSuffixPressed,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  /// Card avec effet de hover et animations
  static Widget modernCard({
    required Widget child,
    required bool isDark,
    VoidCallback? onTap,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double borderRadius = 12,
    double elevation = 2,
  }) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[800] ?? const Color(0xFF424242)
                  : Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.grey).withCustomOpacity(0.1),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Indicateur de chargement moderne
  static Widget modernLoadingIndicator({
    required bool isDark,
    String? message,
    double size = 40,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            strokeWidth: 3,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: isDark
                  ? Colors.grey[400] ?? const Color(0xFFBDBDBD)
                  : Colors.grey[600] ?? const Color(0xFF757575),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Badge avec compteur
  static Widget modernBadge({
    required Widget child,
    required int count,
    required bool isDark,
    Color? badgeColor,
    Color? textColor,
  }) {
    if (count <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor ?? Colors.red,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.white,
                width: 2,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// Shimmer pour les états de chargement
  static Widget shimmerPlaceholder({
    required double width,
    required double height,
    required bool isDark,
    BorderRadius? borderRadius,
  }) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[700] ?? const Color(0xFF424242)
                : Colors.grey[300] ?? const Color(0xFFE0E0E0),
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .shimmer(
          duration: const Duration(milliseconds: 1200),
          color: isDark
              ? Colors.grey[600] ?? const Color(0xFF757575)
              : Colors.grey[100] ?? const Color(0xFFF5F5F5),
        );
  }

  /// Snackbar moderne
  static void showModernSnackBar({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = const Color(0xFF4CAF50);
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case SnackBarType.error:
        backgroundColor = const Color(0xFFE53E3E);
        textColor = Colors.white;
        icon = Icons.error;
        break;
      case SnackBarType.warning:
        backgroundColor = const Color(0xFFFF9800);
        textColor = Colors.white;
        icon = Icons.warning;
        break;
      case SnackBarType.info:
        backgroundColor = const Color(0xFF2196F3);
        textColor = Colors.white;
        icon = Icons.info;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: textColor,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }
}

enum SnackBarType { success, error, warning, info }

/// Extensions pour les animations
extension WidgetAnimationExtensions on Widget {
  Widget fadeInUp({Duration? delay}) {
    return UIEnhancementService.slideInFromBottom(this, delay: delay);
  }

  Widget fadeInLeft({Duration? delay}) {
    return UIEnhancementService.slideInFromLeft(this, delay: delay);
  }

  Widget fadeInRight({Duration? delay}) {
    return UIEnhancementService.slideInFromRight(this, delay: delay);
  }

  Widget scaleUp({Duration? delay, double beginScale = 0.8}) {
    return UIEnhancementService.scaleIn(
      this,
      delay: delay,
      beginScale: beginScale,
    );
  }

  Widget pulseAnimation({Duration? duration, bool repeat = true}) {
    return UIEnhancementService.pulse(this, duration: duration, repeat: repeat);
  }
}
