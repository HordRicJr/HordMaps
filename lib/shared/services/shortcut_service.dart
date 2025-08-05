import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Types de gestes supportés
enum GestureType { tap, doubleTap, longPress, pinch, pan, rotate }

/// Types d'actions
enum ActionType {
  zoomIn,
  zoomOut,
  centerLocation,
  toggleMapStyle,
  search,
  addFavorite,
  openMenu,
  navigation,
  measure,
  share,
}

/// Configuration d'un raccourci
class ShortcutConfig {
  final LogicalKeySet keySet;
  final ActionType action;
  final String description;
  final bool isEnabled;

  const ShortcutConfig({
    required this.keySet,
    required this.action,
    required this.description,
    this.isEnabled = true,
  });
}

/// Configuration d'un geste
class GestureConfig {
  final GestureType type;
  final ActionType action;
  final String description;
  final bool isEnabled;
  final int? tapCount;
  final Duration? duration;

  const GestureConfig({
    required this.type,
    required this.action,
    required this.description,
    this.isEnabled = true,
    this.tapCount,
    this.duration,
  });
}

/// Service de gestion des raccourcis et gestes
class ShortcutService {
  static final Map<ActionType, List<ShortcutConfig>> _shortcuts = {
    ActionType.zoomIn: [
      ShortcutConfig(
        keySet: LogicalKeySet(LogicalKeyboardKey.add),
        action: ActionType.zoomIn,
        description: 'Zoomer (+)',
      ),
      ShortcutConfig(
        keySet: LogicalKeySet(LogicalKeyboardKey.equal),
        action: ActionType.zoomIn,
        description: 'Zoomer (=)',
      ),
    ],
    ActionType.zoomOut: [
      ShortcutConfig(
        keySet: LogicalKeySet(LogicalKeyboardKey.minus),
        action: ActionType.zoomOut,
        description: 'Dézoomer (-)',
      ),
    ],
    ActionType.centerLocation: [
      ShortcutConfig(
        keySet: LogicalKeySet(LogicalKeyboardKey.space),
        action: ActionType.centerLocation,
        description: 'Centrer sur ma position (Espace)',
      ),
    ],
    ActionType.toggleMapStyle: [
      ShortcutConfig(
        keySet: LogicalKeySet(LogicalKeyboardKey.keyM),
        action: ActionType.toggleMapStyle,
        description: 'Changer le style de carte (M)',
      ),
    ],
    ActionType.search: [
      ShortcutConfig(
        keySet: LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyF,
        ),
        action: ActionType.search,
        description: 'Rechercher (Ctrl+F)',
      ),
      ShortcutConfig(
        keySet: LogicalKeySet(LogicalKeyboardKey.keyS),
        action: ActionType.search,
        description: 'Rechercher (S)',
      ),
    ],
    ActionType.addFavorite: [
      ShortcutConfig(
        keySet: LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyD,
        ),
        action: ActionType.addFavorite,
        description: 'Ajouter aux favoris (Ctrl+D)',
      ),
    ],
    ActionType.openMenu: [
      ShortcutConfig(
        keySet: LogicalKeySet(LogicalKeyboardKey.escape),
        action: ActionType.openMenu,
        description: 'Ouvrir le menu (Échap)',
      ),
    ],
    ActionType.navigation: [
      ShortcutConfig(
        keySet: LogicalKeySet(LogicalKeyboardKey.keyN),
        action: ActionType.navigation,
        description: 'Navigation (N)',
      ),
    ],
    ActionType.measure: [
      ShortcutConfig(
        keySet: LogicalKeySet(LogicalKeyboardKey.keyR),
        action: ActionType.measure,
        description: 'Mesurer (R)',
      ),
    ],
    ActionType.share: [
      ShortcutConfig(
        keySet: LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyS,
        ),
        action: ActionType.share,
        description: 'Partager (Ctrl+S)',
      ),
    ],
  };

  static final Map<ActionType, List<GestureConfig>> _gestures = {
    ActionType.zoomIn: [
      GestureConfig(
        type: GestureType.doubleTap,
        action: ActionType.zoomIn,
        description: 'Double-tap pour zoomer',
      ),
      GestureConfig(
        type: GestureType.pinch,
        action: ActionType.zoomIn,
        description: 'Pincer pour zoomer',
      ),
    ],
    ActionType.zoomOut: [
      GestureConfig(
        type: GestureType.pinch,
        action: ActionType.zoomOut,
        description: 'Écarter pour dézoomer',
      ),
    ],
    ActionType.centerLocation: [
      GestureConfig(
        type: GestureType.longPress,
        action: ActionType.centerLocation,
        description: 'Appui long pour centrer',
        duration: Duration(milliseconds: 800),
      ),
    ],
    ActionType.addFavorite: [
      GestureConfig(
        type: GestureType.doubleTap,
        action: ActionType.addFavorite,
        description: 'Double-tap sur marqueur pour favoris',
      ),
    ],
    ActionType.openMenu: [
      GestureConfig(
        type: GestureType.tap,
        action: ActionType.openMenu,
        description: 'Tap sur menu',
        tapCount: 3,
      ),
    ],
  };

  /// Obtient tous les raccourcis pour une action
  static List<ShortcutConfig> getShortcutsForAction(ActionType action) {
    return _shortcuts[action] ?? [];
  }

  /// Obtient tous les gestes pour une action
  static List<GestureConfig> getGesturesForAction(ActionType action) {
    return _gestures[action] ?? [];
  }

  /// Obtient tous les raccourcis
  static Map<ActionType, List<ShortcutConfig>> getAllShortcuts() {
    return Map.unmodifiable(_shortcuts);
  }

  /// Obtient tous les gestes
  static Map<ActionType, List<GestureConfig>> getAllGestures() {
    return Map.unmodifiable(_gestures);
  }

  /// Vérifie si un raccourci est défini pour une combinaison de touches
  static ActionType? getActionForShortcut(LogicalKeySet keySet) {
    for (final entry in _shortcuts.entries) {
      for (final shortcut in entry.value) {
        if (shortcut.isEnabled && shortcut.keySet == keySet) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Active ou désactive un raccourci
  static void toggleShortcut(
    ActionType action,
    LogicalKeySet keySet,
    bool enabled,
  ) {
    final shortcuts = _shortcuts[action];
    if (shortcuts != null) {
      final index = shortcuts.indexWhere((s) => s.keySet == keySet);
      if (index != -1) {
        _shortcuts[action]![index] = ShortcutConfig(
          keySet: shortcuts[index].keySet,
          action: shortcuts[index].action,
          description: shortcuts[index].description,
          isEnabled: enabled,
        );
      }
    }
  }

  /// Active ou désactive un geste
  static void toggleGesture(ActionType action, GestureType type, bool enabled) {
    final gestures = _gestures[action];
    if (gestures != null) {
      final index = gestures.indexWhere((g) => g.type == type);
      if (index != -1) {
        _gestures[action]![index] = GestureConfig(
          type: gestures[index].type,
          action: gestures[index].action,
          description: gestures[index].description,
          isEnabled: enabled,
          tapCount: gestures[index].tapCount,
          duration: gestures[index].duration,
        );
      }
    }
  }

  /// Formate une combinaison de touches pour l'affichage
  static String formatKeySet(LogicalKeySet keySet) {
    final keys = keySet.keys.toList();
    final labels = <String>[];

    for (final key in keys) {
      if (key == LogicalKeyboardKey.control) {
        labels.add('Ctrl');
      } else if (key == LogicalKeyboardKey.alt) {
        labels.add('Alt');
      } else if (key == LogicalKeyboardKey.shift) {
        labels.add('Maj');
      } else if (key == LogicalKeyboardKey.meta) {
        labels.add('Cmd');
      } else if (key == LogicalKeyboardKey.space) {
        labels.add('Espace');
      } else if (key == LogicalKeyboardKey.escape) {
        labels.add('Échap');
      } else if (key == LogicalKeyboardKey.add) {
        labels.add('+');
      } else if (key == LogicalKeyboardKey.minus) {
        labels.add('-');
      } else if (key == LogicalKeyboardKey.equal) {
        labels.add('=');
      } else {
        labels.add(key.keyLabel.toUpperCase());
      }
    }

    return labels.join(' + ');
  }
}

/// Widget pour gérer les raccourcis clavier
class ShortcutHandler extends StatelessWidget {
  final Widget child;
  final Function(ActionType action) onAction;

  const ShortcutHandler({
    super.key,
    required this.child,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final shortcuts = <LogicalKeySet, Intent>{};
    final actions = <Type, Action<Intent>>{};

    // Construction des raccourcis
    for (final entry in ShortcutService.getAllShortcuts().entries) {
      for (final shortcut in entry.value) {
        if (shortcut.isEnabled) {
          final intent = _ActionIntent(shortcut.action);
          shortcuts[shortcut.keySet] = intent;
          actions[_ActionIntent] = _ActionAction(onAction);
        }
      }
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: actions,
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

/// Intent pour les actions
class _ActionIntent extends Intent {
  final ActionType action;
  const _ActionIntent(this.action);
}

/// Action pour exécuter les intents
class _ActionAction extends Action<_ActionIntent> {
  final Function(ActionType action) onAction;
  _ActionAction(this.onAction);

  @override
  Object? invoke(_ActionIntent intent) {
    onAction(intent.action);
    return null;
  }
}

/// Widget pour détecter les gestes
class GestureHandler extends StatefulWidget {
  final Widget child;
  final Function(ActionType action, {Map<String, dynamic>? data}) onAction;

  const GestureHandler({
    super.key,
    required this.child,
    required this.onAction,
  });

  @override
  State<GestureHandler> createState() => _GestureHandlerState();
}

class _GestureHandlerState extends State<GestureHandler> {
  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    _tapCount++;

    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 300), () {
      if (_tapCount == 2) {
        // Double tap
        widget.onAction(ActionType.zoomIn);
      } else if (_tapCount == 3) {
        // Triple tap
        widget.onAction(ActionType.openMenu);
      }
      _tapCount = 0;
    });
  }

  void _handleLongPress() {
    widget.onAction(ActionType.centerLocation);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    // Début du geste de zoom/rotation
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      // Geste de zoom
      if (details.scale > 1.0) {
        widget.onAction(ActionType.zoomIn, data: {'scale': details.scale});
      } else {
        widget.onAction(ActionType.zoomOut, data: {'scale': details.scale});
      }
    }

    if (details.rotation != 0.0) {
      // Geste de rotation
      widget.onAction(
        ActionType.toggleMapStyle,
        data: {'rotation': details.rotation},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      child: widget.child,
    );
  }
}

/// Provider pour la gestion des raccourcis et gestes
class ShortcutProvider extends ChangeNotifier {
  bool _shortcutsEnabled = true;
  bool _gesturesEnabled = true;

  bool get shortcutsEnabled => _shortcutsEnabled;
  bool get gesturesEnabled => _gesturesEnabled;

  /// Active ou désactive les raccourcis
  void setShortcutsEnabled(bool enabled) {
    _shortcutsEnabled = enabled;
    notifyListeners();
  }

  /// Active ou désactive les gestes
  void setGesturesEnabled(bool enabled) {
    _gesturesEnabled = enabled;
    notifyListeners();
  }

  /// Toggle un raccourci spécifique
  void toggleShortcut(ActionType action, LogicalKeySet keySet, bool enabled) {
    ShortcutService.toggleShortcut(action, keySet, enabled);
    notifyListeners();
  }

  /// Toggle un geste spécifique
  void toggleGesture(ActionType action, GestureType type, bool enabled) {
    ShortcutService.toggleGesture(action, type, enabled);
    notifyListeners();
  }

  /// Obtient la description d'une action
  String getActionDescription(ActionType action) {
    switch (action) {
      case ActionType.zoomIn:
        return 'Zoomer sur la carte';
      case ActionType.zoomOut:
        return 'Dézoomer la carte';
      case ActionType.centerLocation:
        return 'Centrer sur ma position';
      case ActionType.toggleMapStyle:
        return 'Changer le style de carte';
      case ActionType.search:
        return 'Ouvrir la recherche';
      case ActionType.addFavorite:
        return 'Ajouter aux favoris';
      case ActionType.openMenu:
        return 'Ouvrir le menu';
      case ActionType.navigation:
        return 'Mode navigation';
      case ActionType.measure:
        return 'Outil de mesure';
      case ActionType.share:
        return 'Partager';
    }
  }
}
