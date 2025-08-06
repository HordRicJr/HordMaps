import 'package:flutter/material.dart';

/// Extension pour remplacer la méthode withOpacity deprecated
extension ColorOpacityExtension on Color {
  /// Remplace withOpacity avec la nouvelle syntaxe withValues
  Color withCustomOpacity(double opacity) {
    assert(
      opacity >= 0.0 && opacity <= 1.0,
      'Opacity must be between 0.0 and 1.0',
    );
    return withValues(alpha: opacity);
  }
}
