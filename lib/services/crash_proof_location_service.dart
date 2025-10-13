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
  /// Implémente une stratégie de récupération progressive avec plusieurs niveaux de fallback
  Future<Position> getCurrentPosition() async {
    int recoveryLevel = 0;
    
    try {
      // Si pas initialisé, initialiser d'abord
      if (!_isInitialized) {
        try {
          await initialize();
        } catch (initError) {
          debugPrint('⚠️ Échec initialisation location: $initError');
          recoveryLevel = 1;
          // Continuer même si l'initialisation échoue
        }
      }

      // Si pas de permissions ou service, retourner position par défaut ou dernière connue
      if (!isLocationAvailable) {
        debugPrint(
          '⚠️ Géolocalisation non disponible, utilisation position par défaut',
        );
        recoveryLevel = 2;
        return _lastKnownPosition ?? _defaultPosition;
      }

      // Tentative de géolocalisation avec timeout strict et gestion d'erreur progressive
      Position? position;
      
      try {
        // Premier essai: précision moyenne avec timeout court
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10), // Timeout strict de 10 secondes
          ),
        ).timeout(
          const Duration(seconds: 15), // Double timeout pour être sûr
          onTimeout: () {
            debugPrint('⏱️ Timeout géolocalisation niveau 1');
            throw TimeoutException('Géolocalisation timeout niveau 1');
          },
        );
      } catch (e) {
        debugPrint('⚠️ Premier essai géolocalisation échoué: $e');
        recoveryLevel = 3;
        
        // Deuxième essai: précision basse avec timeout plus long
        try {
          debugPrint('🔄 Tentative de récupération avec précision réduite');
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 15),
            ),
          ).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('⏱️ Timeout géolocalisation niveau 2');
              throw TimeoutException('Géolocalisation timeout niveau 2');
            },
          );
        } catch (e2) {
          debugPrint('⚠️ Deuxième essai géolocalisation échoué: $e2');
          recoveryLevel = 4;
          
          // Troisième essai: dernière position connue du système
          try {
            debugPrint('🔄 Tentative de récupération avec dernière position système');
            position = await Geolocator.getLastKnownPosition();
            
            if (position == null) {
              throw Exception('Aucune dernière position système disponible');
            }
          } catch (e3) {
            debugPrint('⚠️ Troisième essai géolocalisation échoué: $e3');
            recoveryLevel = 5;
            // Continuer vers le fallback
          }
        }
      }

      // Si on a obtenu une position
      if (position != null) {
        // Vérifier que la position est valide (coordonnées non NaN)
        if (position.latitude.isNaN || position.longitude.isNaN) {
          debugPrint('⚠️ Position obtenue avec coordonnées invalides (NaN)');
          throw Exception('Coordonnées invalides (NaN)');
        }
        
        // Vérifier que les coordonnées sont dans des limites raisonnables
        if (position.latitude.abs() > 90 || position.longitude.abs() > 180) {
          debugPrint('⚠️ Position obtenue avec coordonnées hors limites');
          throw Exception('Coordonnées hors limites');
        }
        
        // Succès: sauvegarder et retourner
        _lastKnownPosition = position;
        _lastError = null;
        
        try {
          await _savePosition(position);
        } catch (saveError) {
          // Continuer même si la sauvegarde échoue
          debugPrint('⚠️ Erreur sauvegarde position: $saveError');
        }

        debugPrint(
          '✅ Position obtenue (niveau $recoveryLevel): ${position.latitude}, ${position.longitude}',
        );
        notifyListeners();
        return position;
      }
      
      // Si on arrive ici, aucune position n'a été obtenue
      throw Exception('Impossible d\'obtenir une position valide');
      
    } catch (e) {
      _lastError = 'Erreur getCurrentPosition: $e';
      debugPrint('❌ Erreur géolocalisation (niveau $recoveryLevel): $e');
      
      // Enregistrer l'erreur dans le service de récupération
      try {
        AutoRecoveryService().reportError('LocationService', e);
      } catch (_) {}

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
  /// Implémente une gestion robuste des erreurs et des interruptions
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Timer? _locationWatchdogTimer;
  DateTime? _lastLocationUpdate;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;
  static const Duration _locationTimeout = Duration(minutes: 2);

  Stream<Position> get positionStream => _positionController.stream;

  Future<void> startLocationTracking() async {
    try {
      // Vérifier si le service est déjà initialisé
      if (!_isInitialized) {
        try {
          await initialize();
        } catch (e) {
          debugPrint('⚠️ Échec initialisation pour tracking: $e');
          // Continuer même si l'initialisation échoue
        }
      }
      
      // Vérifier les permissions et services
      if (!isLocationAvailable) {
        debugPrint('⚠️ Suivi de position non disponible - permissions ou service manquants');
        
        // Tenter de récupérer les permissions
        try {
          await _checkPermissions();
          await _checkLocationService();
        } catch (e) {
          debugPrint('⚠️ Échec récupération permissions: $e');
        }
        
        // Si toujours pas disponible, envoyer des positions simulées
        if (!isLocationAvailable) {
          _startFallbackLocationSimulation();
          return;
        }
      }

      // Nettoyer les ressources existantes
      await _cleanupLocationResources();

      // Démarrer le stream avec gestion d'erreur
      try {
        _positionSubscription =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                distanceFilter: 10, // Mise à jour tous les 10 mètres
              ),
            ).listen(
              (position) {
                // Vérifier que la position est valide
                if (!_isValidPosition(position)) {
                  debugPrint('⚠️ Position invalide reçue, ignorée');
                  return;
                }
                
                _lastLocationUpdate = DateTime.now();
                _consecutiveErrors = 0;
                _lastKnownPosition = position;
                
                // Sauvegarder en arrière-plan pour ne pas bloquer
                _savePosition(position).catchError((e) {
                  debugPrint('⚠️ Erreur sauvegarde position tracking: $e');
                });
                
                // Envoyer la position au stream
                if (!_positionController.isClosed) {
                  _positionController.add(position);
                }
                
                notifyListeners();
              },
              onError: (error) {
                _handleLocationStreamError(error);
              },
              onDone: () {
                debugPrint('🛑 Stream de position terminé');
                _restartLocationTracking();
              },
              cancelOnError: false, // Ne pas annuler sur erreur
            );

        // Démarrer le watchdog pour surveiller les timeouts
        _startLocationWatchdog();
        
        debugPrint('🎯 Suivi de position démarré');
      } catch (e) {
        debugPrint('❌ Erreur démarrage stream position: $e');
        _lastError = 'Erreur startTracking: $e';
        _startFallbackLocationSimulation();
      }
    } catch (e) {
      debugPrint('❌ Erreur démarrage suivi: $e');
      _lastError = 'Erreur startTracking: $e';
      
      // Enregistrer l'erreur dans le service de récupération
      try {
        AutoRecoveryService().reportError('LocationTracking', e);
      } catch (_) {}
      
      _startFallbackLocationSimulation();
    }
  }
  
  /// Vérifie si une position est valide
  bool _isValidPosition(Position position) {
    return !position.latitude.isNaN && 
           !position.longitude.isNaN &&
           position.latitude.abs() <= 90 && 
           position.longitude.abs() <= 180;
  }
  
  /// Gère les erreurs du stream de position
  void _handleLocationStreamError(dynamic error) {
    _consecutiveErrors++;
    debugPrint('⚠️ Erreur stream position ($error) - erreur $_consecutiveErrors/$_maxConsecutiveErrors');
    _lastError = 'Erreur suivi: $error';

    // En cas d'erreur, envoyer la dernière position connue
    if (_lastKnownPosition != null && !_positionController.isClosed) {
      _positionController.add(_lastKnownPosition!);
    }
    
    // Si trop d'erreurs consécutives, redémarrer le tracking
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      debugPrint('🔄 Trop d\'erreurs consécutives, redémarrage du tracking');
      _restartLocationTracking();
    }
  }
  
  /// Démarre un timer watchdog pour surveiller les timeouts de localisation
  void _startLocationWatchdog() {
    _locationWatchdogTimer?.cancel();
    _lastLocationUpdate = DateTime.now();
    
    _locationWatchdogTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_lastLocationUpdate == null) {
        _lastLocationUpdate = DateTime.now();
        return;
      }
      
      final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
      if (timeSinceLastUpdate > _locationTimeout) {
        debugPrint('⏱️ Timeout détecté dans le suivi de position (${timeSinceLastUpdate.inMinutes}min)');
        _restartLocationTracking();
      }
    });
  }
  
  /// Redémarre le tracking de position après une erreur
  Future<void> _restartLocationTracking() async {
    await _cleanupLocationResources();
    
    // Attendre un peu avant de redémarrer
    await Future.delayed(const Duration(seconds: 2));
    
    debugPrint('🔄 Redémarrage du suivi de position');
    startLocationTracking();
  }
  
  /// Nettoie les ressources de localisation
  Future<void> _cleanupLocationResources() async {
    _locationWatchdogTimer?.cancel();
    _locationWatchdogTimer = null;
    
    if (_positionSubscription != null) {
      await _positionSubscription!.cancel();
      _positionSubscription = null;
    }
  }
  
  /// Démarre une simulation de position en cas d'échec complet
  void _startFallbackLocationSimulation() {
    debugPrint('⚠️ Démarrage de la simulation de position (fallback)');
    
    _locationWatchdogTimer?.cancel();
    _positionSubscription?.cancel();
    
    // Créer une position de base (dernière connue ou par défaut)
    final basePosition = _lastKnownPosition ?? _defaultPosition;
    
    // Simuler des mises à jour de position toutes les 5 secondes
    _locationWatchdogTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Créer une petite variation aléatoire pour simuler un mouvement
      final random = DateTime.now().millisecondsSinceEpoch % 1000 / 10000;
      final simulatedPosition = Position(
        latitude: basePosition.latitude + (random - 0.05),
        longitude: basePosition.longitude + (random - 0.05),
        timestamp: DateTime.now(),
        accuracy: 50.0,
        altitude: basePosition.altitude,
        altitudeAccuracy: basePosition.altitudeAccuracy,
        heading: basePosition.heading,
        headingAccuracy: basePosition.headingAccuracy,
        speed: 1.0,
        speedAccuracy: 1.0,
      );
      
      // Envoyer la position simulée
      if (!_positionController.isClosed) {
        _positionController.add(simulatedPosition);
      }
    });
  }

  /// Arrête le suivi de position et nettoie toutes les ressources
  Future<void> stopLocationTracking() async {
    try {
      await _cleanupLocationResources();
      
      // Sauvegarder la dernière position connue avant d'arrêter
      if (_lastKnownPosition != null) {
        try {
          await _savePosition(_lastKnownPosition!);
        } catch (e) {
          debugPrint('⚠️ Erreur sauvegarde dernière position: $e');
        }
      }
      
      debugPrint('🛑 Suivi de position arrêté et ressources nettoyées');
    } catch (e) {
      debugPrint('⚠️ Erreur arrêt suivi position: $e');
      
      // Forcer l'arrêt en cas d'erreur
      _locationWatchdogTimer?.cancel();
      _locationWatchdogTimer = null;
      _positionSubscription?.cancel();
      _positionSubscription = null;
    }
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
    try {
      // Arrêter le tracking
      _locationWatchdogTimer?.cancel();
      _positionSubscription?.cancel();
      
      // Fermer le controller de manière sécurisée
      if (!_positionController.isClosed) {
        _positionController.close();
      }
      
      debugPrint('✅ CrashProofLocationService dispose complet');
    } catch (e) {
      debugPrint('⚠️ Erreur dispose CrashProofLocationService: $e');
    } finally {
      super.dispose();
    }
  }
}

/// Exception de timeout personnalisée
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
