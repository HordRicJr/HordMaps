import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'real_time_navigation_service.dart';

/// Service de navigation en arrière-plan avec notification persistante
class BackgroundNavigationService {
  static BackgroundNavigationService? _instance;
  static BackgroundNavigationService get instance =>
      _instance ??= BackgroundNavigationService._();

  BackgroundNavigationService._();

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  static const String _channelId = 'hordmaps_navigation_channel';
  static const String _channelName = 'Navigation HordMaps';
  static const int _notificationId = 1001;

  bool _isServiceRunning = false;
  Timer? _updateTimer;
  StreamSubscription<NavigationProgress>? _progressSubscription;
  String? _currentDestinationName;

  /// Initialise le service de navigation en arrière-plan
  Future<void> initialize() async {
    await _initializeNotifications();
  }

  /// Initialise les notifications
  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Créer le canal de notification pour Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _createNotificationChannel();
    }
  }

  /// Créer le canal de notification Android
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Notifications pour la navigation active dans HordMaps',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  /// Démarre la navigation en arrière-plan
  Future<bool> startBackgroundNavigation({
    required LatLng destination,
    required String destinationName,
    required List<LatLng> routePoints,
    required double totalDistance,
  }) async {
    try {
      // Vérifier les permissions
      final hasPermissions = await _checkPermissions();
      if (!hasPermissions) {
        debugPrint('Permissions manquantes pour la navigation en arrière-plan');
        return false;
      }

      _isServiceRunning = true;
      _currentDestinationName = destinationName;

      // Démarrer le suivi des mises à jour de navigation
      _startProgressTracking();

      // Afficher la notification initiale
      await _showNavigationNotification(
        title: 'Navigation vers $destinationName',
        body:
            'Distance: ${totalDistance.toStringAsFixed(1)} km - Préparation...',
        progress: 0,
      );

      debugPrint('Service de navigation en arrière-plan démarré');
      return true;
    } catch (e) {
      debugPrint('Erreur démarrage service arrière-plan: $e');
      return false;
    }
  }

  /// Arrête la navigation en arrière-plan
  Future<void> stopBackgroundNavigation() async {
    try {
      _isServiceRunning = false;
      _currentDestinationName = null;

      // Arrêter le timer de mise à jour
      _updateTimer?.cancel();
      _updateTimer = null;

      // Arrêter l'écoute des mises à jour
      await _progressSubscription?.cancel();
      _progressSubscription = null;

      // Supprimer la notification
      await _notificationsPlugin.cancel(_notificationId);

      debugPrint('Service de navigation en arrière-plan arrêté');
    } catch (e) {
      debugPrint('Erreur arrêt service arrière-plan: $e');
    }
  }

  /// Démarre le suivi des mises à jour de navigation
  void _startProgressTracking() {
    final realTimeService = RealTimeNavigationService.instance;

    _progressSubscription = realTimeService.progressStream.listen((progress) {
      if (_isServiceRunning && _currentDestinationName != null) {
        _updateNavigationNotification(progress, _currentDestinationName!);
      }
    });

    // Timer de sauvegarde pour les mises à jour périodiques
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!_isServiceRunning) {
        timer.cancel();
        return;
      }

      // Mettre à jour la notification même sans nouvelles données
      if (_currentDestinationName != null) {
        _refreshNotification(_currentDestinationName!);
      }
    });
  }

  /// Met à jour la notification de navigation
  Future<void> _updateNavigationNotification(
    NavigationProgress progress,
    String destinationName,
  ) async {
    if (!_isServiceRunning) return;

    final eta = _formatDuration(progress.estimatedTimeArrival);
    final distance = progress.remainingDistance.toStringAsFixed(1);
    final speed = progress.averageSpeed.toStringAsFixed(0);

    String body;
    if (progress.isArrived) {
      body = 'Arrivé à destination !';
    } else {
      body = '$distance km restants • ETA: $eta • $speed km/h';
    }

    await _showNavigationNotification(
      title: 'Navigation vers $destinationName',
      body: body,
      progress: progress.completionPercentage.round(),
    );
  }

  /// Rafraîchit la notification
  Future<void> _refreshNotification(String destinationName) async {
    final realTimeService = RealTimeNavigationService.instance;

    if (realTimeService.isNavigating) {
      final eta = _formatDuration(realTimeService.estimatedTimeArrival);
      final distance = realTimeService.remainingDistance.toStringAsFixed(1);
      final speed = realTimeService.averageSpeed.toStringAsFixed(0);

      await _showNavigationNotification(
        title: 'Navigation vers $destinationName',
        body: '$distance km restants • ETA: $eta • $speed km/h',
        progress: realTimeService.completionPercentage.round(),
      );
    }
  }

  /// Affiche la notification de navigation
  Future<void> _showNavigationNotification({
    required String title,
    required String body,
    required int progress,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription:
            'Notifications pour la navigation active dans HordMaps',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        showProgress: true,
        maxProgress: 100,
        playSound: false,
        enableVibration: false,
        icon: '@drawable/ic_navigation',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        actions: const [
          AndroidNotificationAction(
            'stop_navigation',
            'Arrêter',
            cancelNotification: false,
            showsUserInterface: false,
            icon: DrawableResourceAndroidBitmap('@drawable/ic_stop'),
          ),
          AndroidNotificationAction(
            'open_app',
            'Ouvrir HordMaps',
            cancelNotification: false,
            showsUserInterface: true,
            icon: DrawableResourceAndroidBitmap('@drawable/ic_open'),
          ),
        ],
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'HordMaps Navigation',
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
        subtitle: 'Navigation en cours',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails.copyWith(progress: progress),
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        _notificationId,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Erreur affichage notification: $e');
    }
  }

  /// Vérifie les permissions nécessaires
  Future<bool> _checkPermissions() async {
    try {
      // Permission de notification
      final notificationStatus = await Permission.notification.request();
      if (!notificationStatus.isGranted) {
        debugPrint('Permission de notification refusée');
        return false;
      }

      // Permission de localisation
      final locationStatus = await Permission.locationWhenInUse.request();
      if (!locationStatus.isGranted) {
        debugPrint('Permission de localisation refusée');
        return false;
      }

      // Permission de superposition système (Android uniquement)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final systemAlertWindowStatus = await Permission.systemAlertWindow
            .request();
        if (!systemAlertWindowStatus.isGranted) {
          debugPrint('Permission de superposition refusée');
          // Continuons même si la permission overlay est refusée
        }
      }

      return true;
    } catch (e) {
      debugPrint('Erreur vérification permissions: $e');
      return false;
    }
  }

  /// Callback tap sur notification
  void _onNotificationTapped(NotificationResponse response) {
    final actionId = response.actionId;

    switch (actionId) {
      case 'stop_navigation':
        stopBackgroundNavigation();
        break;
      case 'open_app':
        _openApp();
        break;
      default:
        _openApp();
        break;
    }
  }

  /// Ouvre l'application
  void _openApp() {
    // Logique pour ouvrir l'application et naviguer vers la page de navigation
    debugPrint('Ouverture de HordMaps depuis la notification');

    // Utiliser platform channel pour ouvrir l'app
    try {
      const platform = MethodChannel('hordmaps.navigation/app_launcher');
      platform.invokeMethod('openApp');
    } catch (e) {
      debugPrint('Erreur ouverture app: $e');
    }
  }

  /// Formate la durée
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '< 1m';
    }
  }

  /// Affiche un toast de navigation (overlay simple)
  static void showNavigationOverlay(
    BuildContext context,
    NavigationProgress progress,
  ) {
    if (!progress.isArrived) {
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => NavigationOverlayWidget(
          progress: progress,
          onClose: () => overlayEntry.remove(),
        ),
      );

      overlay.insert(overlayEntry);

      // Auto-suppression après 8 secondes
      Timer(const Duration(seconds: 8), () {
        try {
          overlayEntry.remove();
        } catch (e) {
          // Overlay déjà supprimé
        }
      });
    }
  }

  /// Getters
  bool get isServiceRunning => _isServiceRunning;
  String? get currentDestinationName => _currentDestinationName;
}

/// Widget overlay flottant pour la navigation
class NavigationOverlayWidget extends StatelessWidget {
  final NavigationProgress progress;
  final VoidCallback onClose;

  const NavigationOverlayWidget({
    super.key,
    required this.progress,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.navigation, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${progress.remainingDistance.toStringAsFixed(1)} km restants',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'ETA: ${_formatDuration(progress.estimatedTimeArrival)} • ${progress.averageSpeed.toStringAsFixed(0)} km/h',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '< 1m';
    }
  }
}

/// Extension pour les détails de notification Android
extension AndroidNotificationDetailsExtension on AndroidNotificationDetails {
  AndroidNotificationDetails copyWith({int? progress}) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      ongoing: ongoing,
      autoCancel: autoCancel,
      showProgress: showProgress,
      maxProgress: maxProgress,
      progress: progress ?? this.progress,
      playSound: playSound,
      enableVibration: enableVibration,
      icon: icon,
      largeIcon: largeIcon,
      actions: actions,
      styleInformation: styleInformation,
    );
  }
}
