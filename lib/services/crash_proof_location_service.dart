import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de géolocalisation ultra-robuste qui ne crash jamais
/// Gère toutes les erreurs possibles et fournit des fallbacks
class CrashProofLocationService extends ChangeNotifier {
  static final CrashProofLocationService _instance =
      CrashProofLocationService._internal();
  factory CrashProofLocationService() => _instance;
  CrashProofLocationService._internal();

  // États possibles
  bool _isInitialized = false;
  bool _isPermissionGranted = false;
  bool _isServiceEnabled = false;
  Position? _lastKnownPosition;
  String? _lastError;

  // Position par défaut (Paris) si aucune géolocalisation
  static final Position _defaultPosition = Position(
    latitude: 48.8566,
    longitude: 2.3522,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPermissionGranted => _isPermissionGranted;
  bool get isServiceEnabled => _isServiceEnabled;
  Position? get lastKnownPosition => _lastKnownPosition;
  String? get lastError => _lastError;
  bool get isLocationAvailable => _isPermissionGranted && _isServiceEnabled;

  /// Initialise le service de manière ultra-sécurisée
  Future<bool> initialize() async {
    try {
      debugPrint('🗺️ Initialisation CrashProofLocationService...');

      // Étape 1: Vérifier les permissions
      await _checkPermissions();

      // Étape 2: Vérifier les services
      await _checkLocationService();

      // Étape 3: Charger la dernière position sauvegardée
      await _loadLastSavedPosition();

      _isInitialized = true;
      _lastError = null;

      debugPrint('✅ CrashProofLocationService initialisé');
      debugPrint('   - Permissions: $_isPermissionGranted');
      debugPrint('   - Service GPS: $_isServiceEnabled');
      debugPrint('   - Position disponible: ${_lastKnownPosition != null}');

      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Erreur initialisation: $e';
      debugPrint('❌ Erreur initialisation location: $e');
      _isInitialized =
          true; // On considère comme initialisé même en cas d'erreur
      notifyListeners();
      return false;
    }
  }

  /// Vérification ultra-sécurisée des permissions
  Future<void> _checkPermissions() async {
    try {
      // Méthode 1: permission_handler
      final status = await Permission.location.status;
      _isPermissionGranted = status.isGranted;

      if (!_isPermissionGranted) {
        debugPrint(
          '📍 Permission géolocalisation non accordée, tentative de demande...',
        );
        final requestResult = await Permission.location.request();
        _isPermissionGranted = requestResult.isGranted;
      }

      // Méthode 2: geolocator en backup
      if (!_isPermissionGranted) {
        try {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          _isPermissionGranted =
              permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever;
        } catch (e) {
          debugPrint('Backup permission check failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Erreur vérification permissions: $e');
      _isPermissionGranted = false;
    }
  }

  /// Vérification ultra-sécurisée du service de localisation
  Future<void> _checkLocationService() async {
    try {
      _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Erreur vérification service GPS: $e');
      _isServiceEnabled = false;
    }
  }

  /// Charge la dernière position sauvegardée
  Future<void> _loadLastSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positionJson = prefs.getString('last_known_position');

      if (positionJson != null) {
        final positionData = Map<String, dynamic>.from(
          Map.from(Uri.splitQueryString(positionJson)),
        );

        _lastKnownPosition = Position(
          latitude: double.parse(positionData['lat'] ?? '48.8566'),
          longitude: double.parse(positionData['lng'] ?? '2.3522'),
          timestamp:
              DateTime.tryParse(positionData['time'] ?? '') ?? DateTime.now(),
          accuracy: double.parse(positionData['acc'] ?? '0'),
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        debugPrint(
          '📍 Position précédente chargée: ${_lastKnownPosition!.latitude}, ${_lastKnownPosition!.longitude}',
        );
      }
    } catch (e) {
      debugPrint('Erreur chargement position: $e');
      _lastKnownPosition = null;
    }
  }

  /// Sauvegarde une position
  Future<void> _savePosition(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positionString =
          'lat=${position.latitude}&lng=${position.longitude}&time=${position.timestamp.toIso8601String()}&acc=${position.accuracy}';
      await prefs.setString('last_known_position', positionString);
    } catch (e) {
      debugPrint('Erreur sauvegarde position: $e');
    }
  }

  /// Obtient la position actuelle de manière ultra-sécurisée
  Future<Position> getCurrentPosition() async {
    try {
      // Si pas initialisé, initialiser d'abord
      if (!_isInitialized) {
        await initialize();
      }

      // Si pas de permissions ou service, retourner position par défaut ou dernière connue
      if (!isLocationAvailable) {
        debugPrint(
          '⚠️ Géolocalisation non disponible, utilisation position par défaut',
        );
        return _lastKnownPosition ?? _defaultPosition;
      }

      // Tentative de géolocalisation avec timeout strict
      final position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10), // Timeout strict de 10 secondes
            ),
          ).timeout(
            const Duration(seconds: 15), // Double timeout pour être sûr
            onTimeout: () {
              debugPrint(
                '⏱️ Timeout géolocalisation, utilisation position par défaut',
              );
              throw TimeoutException('Géolocalisation timeout');
            },
          );

      // Succès: sauvegarder et retourner
      _lastKnownPosition = position;
      _lastError = null;
      await _savePosition(position);

      debugPrint(
        '✅ Position obtenue: ${position.latitude}, ${position.longitude}',
      );
      notifyListeners();
      return position;
    } catch (e) {
      _lastError = 'Erreur getCurrentPosition: $e';
      debugPrint('❌ Erreur géolocalisation: $e');

      // En cas d'erreur, retourner la dernière position connue ou position par défaut
      final fallbackPosition = _lastKnownPosition ?? _defaultPosition;
      debugPrint(
        '🔄 Utilisation position de secours: ${fallbackPosition.latitude}, ${fallbackPosition.longitude}',
      );

      notifyListeners();
      return fallbackPosition;
    }
  }

  /// Obtient la position de manière synchrone (pour usage immédiat)
  Position getCurrentPositionSync() {
    if (_lastKnownPosition != null) {
      return _lastKnownPosition!;
    }

    debugPrint(
      '📍 Aucune position connue, utilisation position par défaut (Paris)',
    );
    return _defaultPosition;
  }

  /// Démarre le suivi de position ultra-sécurisé
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  Future<void> startLocationTracking() async {
    try {
      if (!isLocationAvailable) {
        debugPrint('⚠️ Suivi de position non disponible');
        return;
      }

      _positionSubscription?.cancel();

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 10, // Mise à jour tous les 10 mètres
            ),
          ).listen(
            (position) {
              _lastKnownPosition = position;
              _savePosition(position);
              _positionController.add(position);
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Erreur stream position: $error');
              _lastError = 'Erreur suivi: $error';

              // En cas d'erreur, envoyer la dernière position connue
              if (_lastKnownPosition != null) {
                _positionController.add(_lastKnownPosition!);
              }
            },
          );

      debugPrint('🎯 Suivi de position démarré');
    } catch (e) {
      debugPrint('Erreur démarrage suivi: $e');
      _lastError = 'Erreur startTracking: $e';
    }
  }

  /// Arrête le suivi de position
  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    debugPrint('🛑 Suivi de position arrêté');
  }

  /// Force un refresh des permissions et services
  Future<void> refreshStatus() async {
    await _checkPermissions();
    await _checkLocationService();
    notifyListeners();
  }

  /// Ouvre les paramètres de l'application pour activer les permissions
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Erreur ouverture paramètres: $e');
    }
  }

  /// Obtient un rapport de diagnostic complet
  Map<String, dynamic> getDiagnostic() {
    return {
      'isInitialized': _isInitialized,
      'isPermissionGranted': _isPermissionGranted,
      'isServiceEnabled': _isServiceEnabled,
      'isLocationAvailable': isLocationAvailable,
      'hasLastKnownPosition': _lastKnownPosition != null,
      'lastError': _lastError,
      'lastKnownPosition': _lastKnownPosition != null
          ? '${_lastKnownPosition!.latitude}, ${_lastKnownPosition!.longitude}'
          : null,
    };
  }

  @override
  void dispose() {
    stopLocationTracking();
    _positionController.close();
    super.dispose();
  }
}

/// Exception de timeout personnalisée
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
