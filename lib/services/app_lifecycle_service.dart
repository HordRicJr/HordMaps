import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Service pour gérer l'état de l'application et les popups de sortie
class AppLifecycleService extends ChangeNotifier with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  AppLifecycleState _currentState = AppLifecycleState.resumed;
  bool _isNavigating = false;
  DateTime? _pausedTime;
  final List<VoidCallback> _onBackgroundCallbacks = [];
  final List<VoidCallback> _onResumeCallbacks = [];

  // Getters
  AppLifecycleState get currentState => _currentState;
  bool get isNavigating => _isNavigating;
  DateTime? get pausedTime => _pausedTime;

  /// Initialise le service
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    debugPrint('AppLifecycleService initialisé');
  }

  /// Définit si l'utilisateur est en navigation
  void setNavigating(bool navigating) {
    _isNavigating = navigating;
    notifyListeners();
  }

  /// Ajoute un callback pour quand l'app passe en arrière-plan
  void addBackgroundCallback(VoidCallback callback) {
    _onBackgroundCallbacks.add(callback);
  }

  /// Ajoute un callback pour quand l'app reprend
  void addResumeCallback(VoidCallback callback) {
    _onResumeCallbacks.add(callback);
  }

  /// Supprime un callback
  void removeBackgroundCallback(VoidCallback callback) {
    _onBackgroundCallbacks.remove(callback);
  }

  void removeResumeCallback(VoidCallback callback) {
    _onResumeCallbacks.remove(callback);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final previousState = _currentState;
    _currentState = state;

    switch (state) {
      case AppLifecycleState.paused:
        _pausedTime = DateTime.now();
        _onAppPaused();
        break;
      case AppLifecycleState.resumed:
        if (previousState == AppLifecycleState.paused) {
          _onAppResumed();
        }
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
        // L'app est inactive mais toujours visible (ex: popup système)
        break;
      case AppLifecycleState.hidden:
        // L'app est cachée
        break;
    }

    notifyListeners();
  }

  /// Appelé quand l'app passe en arrière-plan
  void _onAppPaused() {
    debugPrint('Application mise en arrière-plan');

    // Exécute tous les callbacks d'arrière-plan
    for (final callback in _onBackgroundCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Erreur dans callback background: $e');
      }
    }
  }

  /// Appelé quand l'app reprend
  void _onAppResumed() {
    debugPrint('Application reprise');

    // Calcule le temps passé en arrière-plan
    if (_pausedTime != null) {
      final backgroundDuration = DateTime.now().difference(_pausedTime!);
      debugPrint(
        'Temps en arrière-plan: ${backgroundDuration.inMinutes} minutes',
      );
    }

    _pausedTime = null;

    // Exécute tous les callbacks de reprise
    for (final callback in _onResumeCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Erreur dans callback resume: $e');
      }
    }
  }

  /// Appelé quand l'app est fermée
  void _onAppDetached() {
    debugPrint('Application fermée');
  }

  /// Affiche un popup de confirmation avant de quitter
  static Future<bool> showExitConfirmation(BuildContext context) async {
    final appService = AppLifecycleService();

    // Si l'utilisateur n'est pas en navigation, quitter directement
    if (!appService.isNavigating) {
      return true;
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Navigation en cours'),
              ],
            ),
            content: const Text(
              'Vous êtes actuellement en navigation. Voulez-vous vraiment quitter l\'application ?\n\n'
              'La navigation sera interrompue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Continuer la navigation'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Quitter'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Gère le bouton retour Android
  static Future<bool> handleBackButton(BuildContext context) async {
    final shouldExit = await showExitConfirmation(context);
    if (shouldExit) {
      SystemNavigator.pop();
    }
    return shouldExit;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onBackgroundCallbacks.clear();
    _onResumeCallbacks.clear();
    super.dispose();
  }
}

/// Widget wrapper pour gérer le bouton retour
class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;

  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> {
  @override
  void initState() {
    super.initState();
    AppLifecycleService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await AppLifecycleService.handleBackButton(context);
        }
      },
      child: widget.child,
    );
  }
}
