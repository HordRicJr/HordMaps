import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'emergency_location_disable_service.dart';
import 'event_throttle_service.dart';

/// Service de géolocalisation robuste avec gestion d'erreurs complète
class SafeLocationService extends ChangeNotifier {
  static SafeLocationService? _instance;
  static SafeLocationService get instance =>
      _instance ??= SafeLocationService._();
  SafeLocationService._();

  StreamSubscription<Position>? _positionSubscription;
  final StreamController<LatLng> _positionController =
      StreamController<LatLng>.broadcast();

  LatLng? _currentPosition;
  LatLng? _lastKnownPosition;
  double _currentSpeed = 0.0;
  double _accuracy = 0.0;
  bool _isLocationEnabled = false;
  bool _hasPermission = false;
  bool _isInitialized = false;
  String _lastError = '';

  // Getters
  LatLng? get currentPosition => _currentPosition;
  LatLng? get lastKnownPosition => _lastKnownPosition ?? _currentPosition;
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;
  bool get isLocationEnabled => _isLocationEnabled;
  double get currentSpeed => _currentSpeed;
  double get accuracy => _accuracy;
  String get lastError => _lastError;
  Stream<LatLng> get positionStream => _positionController.stream;

  /// Initialise le service de géolocalisation avec gestion d'erreurs robuste
  Future<bool> initialize() async {
    debugPrint('🔍 Initialisation du service de géolocalisation...');

    try {
      // NOUVEAU: Vérifier si la géolocalisation est désactivée en mode d'urgence
      final isDisabled =
          await EmergencyLocationDisableService.isGeolocationDisabled();
      if (isDisabled) {
        debugPrint('🚨 Géolocalisation désactivée en mode d\'urgence');
        _lastError = 'Mode d\'urgence activé - géolocalisation désactivée';

        // Utiliser la position par défaut
        final defaultPos = EmergencyLocationDisableService.getDefaultPosition();
        _currentPosition = LatLng(
          defaultPos['latitude']!,
          defaultPos['longitude']!,
        );
        _lastKnownPosition = _currentPosition;
        _isInitialized = true;
        debugPrint('✅ Mode d\'urgence : position par défaut utilisée');
        return true;
      }

      // 1. Vérifier les permissions étape par étape
      _hasPermission = await _checkAndRequestPermissions();
      if (!_hasPermission) {
        _lastError = 'Permissions de localisation refusées';
        debugPrint('❌ $_lastError');
        return false;
      }

      // 2. Vérifier si le service de localisation est activé
      _isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_isLocationEnabled) {
        _lastError = 'Service de localisation désactivé';
        debugPrint('❌ $_lastError');
        return false;
      }

      // 3. Tester l'obtention de position avec timeout
      Position? position = await _getCurrentPositionSafely();
      if (position != null) {
        _updatePosition(position);
        _isInitialized = true;
        debugPrint('✅ Service de géolocalisation initialisé avec succès');
        return true;
      } else {
        _lastError = 'Impossible d\'obtenir la position actuelle';
        debugPrint('❌ $_lastError');
        return false;
      }
    } catch (e) {
      _lastError = 'Erreur d\'initialisation: $e';
      debugPrint('❌ $_lastError');

      // NOUVEAU: En cas d'erreur, basculer automatiquement en mode d'urgence
      debugPrint('🚨 Basculement automatique en mode d\'urgence');
      await EmergencyLocationDisableService.disableGeolocation();

      final defaultPos = EmergencyLocationDisableService.getDefaultPosition();
      _currentPosition = LatLng(
        defaultPos['latitude']!,
        defaultPos['longitude']!,
      );
      _lastKnownPosition = _currentPosition;
      _isInitialized = true;
      return true;
    }
  }

  /// Vérifie et demande les permissions nécessaires
  Future<bool> _checkAndRequestPermissions() async {
    try {
      // Utiliser permission_handler pour une gestion plus robuste
      PermissionStatus locationStatus = await Permission.location.status;

      if (locationStatus.isDenied) {
        debugPrint('🔐 Demande de permission de localisation...');
        locationStatus = await Permission.location.request();
      }

      if (locationStatus.isPermanentlyDenied) {
        debugPrint('❌ Permission de localisation refusée définitivement');
        // Optionnel : ouvrir les paramètres
        await openAppSettings();
        return false;
      }

      bool granted = locationStatus.isGranted;
      debugPrint(
        '🔐 Permission de localisation: ${granted ? 'accordée' : 'refusée'}',
      );
      return granted;
    } catch (e) {
      debugPrint('❌ Erreur vérification permissions: $e');
      return false;
    }
  }

  /// Obtient la position actuelle de manière sécurisée
  Future<Position?> _getCurrentPositionSafely() async {
    try {
      debugPrint('📍 Tentative d\'obtention de la position...');

      // Configuration sécurisée avec timeout
      const LocationSettings locationSettings = LocationSettings(
        accuracy:
            LocationAccuracy.medium, // Équilibre entre précision et rapidité
        timeLimit: Duration(seconds: 15), // Timeout réduit
      );

      Position position =
          await Geolocator.getCurrentPosition(
            locationSettings: locationSettings,
          ).timeout(
            const Duration(seconds: 20), // Timeout supplémentaire
            onTimeout: () {
              throw TimeoutException(
                'Timeout lors de l\'obtention de la position',
                const Duration(seconds: 20),
              );
            },
          );

      debugPrint(
        '✅ Position obtenue: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } on TimeoutException catch (e) {
      debugPrint('⏰ Timeout géolocalisation: $e');
      return null;
    } on LocationServiceDisabledException catch (e) {
      debugPrint('🚫 Service de localisation désactivé: $e');
      return null;
    } on PermissionDeniedException catch (e) {
      debugPrint('🔒 Permission refusée: $e');
      return null;
    } catch (e) {
      debugPrint('❌ Erreur géolocalisation: $e');
      return null;
    }
  }

  /// Met à jour la position actuelle
  void _updatePosition(Position position) {
    final newPosition = LatLng(position.latitude, position.longitude);
    _currentPosition = newPosition;
    _lastKnownPosition = newPosition;
    _currentSpeed = position.speed * 3.6; // Conversion m/s vers km/h
    _accuracy = position.accuracy;

    // NOUVEAU: Throttle les mises à jour pour éviter les surcharges
    EventThrottleService().throttle('stream_update', () {
      if (!_positionController.isClosed) {
        _positionController.add(newPosition);
      }
    });

    EventThrottleService().throttle('ui_update', () {
      notifyListeners();
    });

    debugPrint(
      '📍 Position mise à jour: ${position.latitude}, ${position.longitude}',
    );
  }

  /// Démarre le suivi de position avec gestion d'erreurs
  Future<void> startLocationTracking() async {
    if (!_isInitialized) {
      debugPrint('❌ Service non initialisé, impossible de démarrer le suivi');
      return;
    }

    try {
      // Configuration optimisée pour éviter les erreurs
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10, // Mise à jour tous les 10 mètres
        timeLimit: Duration(seconds: 30), // Timeout pour chaque mise à jour
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              // NOUVEAU: Throttle les mises à jour de position pour éviter les surcharges
              EventThrottleService().throttle('location_update', () {
                _updatePosition(position);
              });
            },
            onError: (error) {
              debugPrint('❌ Erreur suivi position: $error');
              _lastError = 'Erreur suivi: $error';

              // Throttle les notifications d'erreur aussi
              EventThrottleService().throttle('location_error', () {
                notifyListeners();
              });
            },
          );

      debugPrint('✅ Suivi de position démarré avec throttling');
    } catch (e) {
      debugPrint('❌ Erreur démarrage suivi: $e');
      _lastError = 'Erreur démarrage suivi: $e';
    }
  }

  /// Arrête le suivi de position
  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    debugPrint('🛑 Suivi de position arrêté');
  }

  /// Obtient la position actuelle (méthode publique)
  Future<Position?> getCurrentPosition() async {
    if (!_isInitialized) {
      debugPrint('❌ Service non initialisé');
      return null;
    }
    return await _getCurrentPositionSafely();
  }

  /// Force la réinitialisation du service
  Future<bool> reinitialize() async {
    debugPrint('🔄 Réinitialisation du service de géolocalisation...');

    // Nettoyer l'état actuel
    stopLocationTracking();
    _isInitialized = false;
    _hasPermission = false;
    _isLocationEnabled = false;
    _lastError = '';

    // Réinitialiser
    return await initialize();
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    stopLocationTracking();
    _positionController.close();
    super.dispose();
  }
}

/// Exception personnalisée pour les erreurs de géolocalisation
class LocationException implements Exception {
  final String message;
  final String? code;

  const LocationException(this.message, [this.code]);

  @override
  String toString() =>
      'LocationException: $message${code != null ? ' (Code: $code)' : ''}';
}
