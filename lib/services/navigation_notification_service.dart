import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../../shared/extensions/color_extensions.dart';

/// Service de notifications pour la navigation
class NavigationNotificationService extends ChangeNotifier {
  static final NavigationNotificationService _instance =
      NavigationNotificationService._internal();
  factory NavigationNotificationService() => _instance;
  NavigationNotificationService._internal();

  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  bool _isInitialized = false;
  bool _isNavigating = false;
  String? _currentRoute;
  int _nextTurnDistance = 0;
  String _nextInstruction = '';

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isNavigating => _isNavigating;
  String? get currentRoute => _currentRoute;
  int get nextTurnDistance => _nextTurnDistance;
  String get nextInstruction => _nextInstruction;

  /// Initialise le service de notifications
  Future<void> initialize() async {
    try {
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Configuration Android
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configuration iOS
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestSoundPermission: true,
            requestBadgePermission: true,
            requestAlertPermission: true,
          );

      // Configuration Windows (si disponible)
      const LinuxInitializationSettings initializationSettingsLinux =
          LinuxInitializationSettings(defaultActionName: 'Ouvrir HordMaps');

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
            linux: initializationSettingsLinux,
          );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Demande de permissions pour Android 13+
      if (Platform.isAndroid) {
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('NavigationNotificationService initialisé avec succès');
    } catch (e) {
      debugPrint('Erreur initialisation NavigationNotificationService: $e');
      _isInitialized = false;
    }
  }

  /// Gestionnaire de tap sur notification
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    debugPrint('Notification tappée: ${notificationResponse.payload}');
    // Ici on peut naviguer vers l'écran de navigation
  }

  /// Démarre la navigation avec notifications
  Future<void> startNavigation(String routeName) async {
    if (!_isInitialized) return;

    _isNavigating = true;
    _currentRoute = routeName;
    notifyListeners();

    await _showNavigationStartNotification(routeName);
  }

  /// Arrête la navigation
  Future<void> stopNavigation() async {
    if (!_isInitialized) return;

    _isNavigating = false;
    _currentRoute = null;
    _nextTurnDistance = 0;
    _nextInstruction = '';
    notifyListeners();

    await _flutterLocalNotificationsPlugin.cancel(1); // ID navigation
  }

  /// Met à jour l'instruction de navigation
  Future<void> updateNavigationInstruction(
    String instruction,
    int distanceMeters,
  ) async {
    if (!_isInitialized || !_isNavigating) return;

    _nextInstruction = instruction;
    _nextTurnDistance = distanceMeters;
    notifyListeners();

    await _showNavigationUpdateNotification(instruction, distanceMeters);
  }

  /// Affiche la notification de début de navigation
  Future<void> _showNavigationStartNotification(String routeName) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'navigation_channel',
          'Navigation',
          channelDescription: 'Notifications de navigation en cours',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      1, // ID unique pour la navigation
      'Navigation en cours',
      'Itinéraire vers $routeName',
      platformChannelSpecifics,
      payload: 'navigation_active',
    );
  }

  /// Met à jour la notification avec la prochaine instruction
  Future<void> _showNavigationUpdateNotification(
    String instruction,
    int distanceMeters,
  ) async {
    String distanceText;
    if (distanceMeters < 100) {
      distanceText = '${distanceMeters}m';
    } else if (distanceMeters < 1000) {
      distanceText = '${(distanceMeters / 100).round() * 100}m';
    } else {
      distanceText = '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'navigation_channel',
          'Navigation',
          channelDescription: 'Notifications de navigation en cours',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          playSound: false, // Pas de son pour les mises à jour
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      1, // Même ID pour remplacer la notification
      'Dans $distanceText',
      instruction,
      platformChannelSpecifics,
      payload: 'navigation_instruction',
    );
  }

  /// Affiche une notification d'embouteillage
  Future<void> showTrafficAlert(String message) async {
    if (!_isInitialized) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'traffic_channel',
          'Alertes Trafic',
          channelDescription: 'Alertes de trafic et embouteillages',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      2, // ID pour les alertes trafic
      'Alerte Trafic',
      message,
      platformChannelSpecifics,
      payload: 'traffic_alert',
    );
  }

  /// Affiche une notification d'arrivée
  Future<void> showArrivalNotification() async {
    if (!_isInitialized) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'arrival_channel',
          'Arrivée',
          channelDescription: 'Notification d\'arrivée à destination',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      3, // ID pour l'arrivée
      'Destination atteinte',
      'Vous êtes arrivé à destination !',
      platformChannelSpecifics,
      payload: 'arrival',
    );

    // Arrête la navigation après l'arrivée
    await stopNavigation();
  }

  /// Affiche une notification personnalisée
  Future<void> showCustomNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    if (!_isInitialized) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'general_channel',
          'Général',
          channelDescription: 'Notifications générales de l\'application',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // ID unique
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Annule toutes les notifications
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) return;
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Affiche un popup de confirmation avant de quitter l'application
  static Future<bool> showExitConfirmation(BuildContext context) async {
    final instance = NavigationNotificationService();
    if (!instance._isNavigating) return true;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                const Text('Navigation en cours'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vous êtes actuellement en navigation vers:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withCustomOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withCustomOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          instance._currentRoute ?? 'Destination inconnue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Si vous quittez maintenant, la navigation sera interrompue. Voulez-vous vraiment quitter ?',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.navigation, size: 18),
                    const SizedBox(width: 4),
                    const Text('Continuer'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await instance.stopNavigation();
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.exit_to_app, size: 18),
                    const SizedBox(width: 4),
                    const Text('Quitter'),
                  ],
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Affiche une notification dans l'app
  static void showInAppNotification(
    BuildContext context, {
    required String title,
    required String message,
    IconData? icon,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(message, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF4CAF50),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    cancelAllNotifications();
    super.dispose();
  }
}
