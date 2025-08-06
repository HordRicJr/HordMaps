import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'central_event_manager.dart';

/// Types d'objets AR
enum ARObjectType {
  poi('Point d\'intérêt', Icons.place),
  direction('Direction', Icons.arrow_forward),
  distance('Distance', Icons.straighten),
  warning('Avertissement', Icons.warning);

  const ARObjectType(this.displayName, this.icon);
  final String displayName;
  final IconData icon;
}

/// Modèle d'objet en réalité augmentée
class ARObject {
  final String id;
  final ARObjectType type;
  final LatLng position;
  final String label;
  final double distance;
  final double bearing;
  final Color color;
  final double size;
  final Map<String, dynamic> metadata;

  ARObject({
    required this.id,
    required this.type,
    required this.position,
    required this.label,
    required this.distance,
    required this.bearing,
    this.color = Colors.blue,
    this.size = 1.0,
    this.metadata = const {},
  });
}

/// Modèle d'instruction AR
class ARInstruction {
  final String id;
  final String text;
  final IconData icon;
  final double distance;
  final LatLng position;
  final DateTime timestamp;
  final bool isActive;

  ARInstruction({
    required this.id,
    required this.text,
    required this.icon,
    required this.distance,
    required this.position,
    required this.timestamp,
    this.isActive = true,
  });
}

/// Service de réalité augmentée pour navigation (version simplifiée)
class ARNavigationService extends ChangeNotifier {
  static final ARNavigationService _instance = ARNavigationService._internal();
  factory ARNavigationService() => _instance;
  ARNavigationService._internal();

  bool _isAREnabled = false;
  bool _isARSupported = true; // Toujours supporté en mode simplifié

  final List<ARObject> _arObjects = [];
  final List<ARInstruction> _arInstructions = [];
  LatLng? _currentPosition;

  StreamSubscription<LatLng>? _positionSubscription;
  Timer? _arUpdateTimer;

  // Gestionnaire central pour éviter les conflits
  final CentralEventManager _eventManager = CentralEventManager();

  // Getters
  bool get isAREnabled => _isAREnabled;
  bool get isARSupported => _isARSupported;
  List<ARObject> get arObjects => List.unmodifiable(_arObjects);
  List<ARInstruction> get arInstructions => List.unmodifiable(_arInstructions);

  /// Initialise le service AR (version simplifiée)
  Future<void> initializeAR() async {
    try {
      // Version simplifiée sans caméra
      _isARSupported = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur initialisation AR: $e');
      _isARSupported = false;
    }
  }

  /// Active/désactive l'AR
  Future<void> toggleAR() async {
    if (!_isARSupported) return;

    if (_isAREnabled) {
      await stopAR();
    } else {
      await startAR();
    }
  }

  /// Démarre l'AR
  Future<void> startAR() async {
    if (!_isARSupported) return;

    try {
      _isAREnabled = true;

      // Démarrer le timer de mise à jour via le gestionnaire central
      _arUpdateTimer = _eventManager.registerPeriodicTimer(
        'ar_navigation_update',
        const Duration(milliseconds: 100),
        (_) => _updateARObjects(),
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Erreur démarrage AR: $e');
      _isAREnabled = false;
    }
  }

  /// Arrête l'AR
  Future<void> stopAR() async {
    _isAREnabled = false;
    _eventManager.cancelTimer('ar_navigation_update');
    _arUpdateTimer = null;
    notifyListeners();
  }

  /// Met à jour la position actuelle
  void updatePosition(LatLng position) {
    _currentPosition = position;
    if (_isAREnabled) {
      _updateARObjects();
    }
  }

  /// Met à jour l'orientation
  void updateHeading(double heading) {
    // Version simplifiée
    notifyListeners();
  }

  /// Met à jour l'inclinaison de la caméra (version simplifiée)
  void updateCameraTilt(double tilt) {
    // Version simplifiée sans caméra
    if (_isAREnabled) {
      notifyListeners();
    }
  }

  /// Met à jour les objets AR
  void _updateARObjects() {
    if (_currentPosition == null) return;

    // Nettoyer les objets trop lointains
    _arObjects.removeWhere((obj) => obj.distance > 2000);

    // Recalculer les positions relatives
    for (final obj in _arObjects) {
      // Mettre à jour les positions 3D basées sur
      // la position actuelle, l'orientation, etc.
      debugPrint('Mise à jour objet AR: ${obj.id} à ${obj.distance}m');
    }

    notifyListeners();
  }

  /// Ajoute un objet AR
  void addARObject(ARObject object) {
    _arObjects.add(object);
    notifyListeners();
  }

  /// Supprime un objet AR
  void removeARObject(String id) {
    _arObjects.removeWhere((obj) => obj.id == id);
    notifyListeners();
  }

  /// Ajoute une instruction AR
  void addARInstruction(ARInstruction instruction) {
    _arInstructions.add(instruction);
    notifyListeners();
  }

  /// Supprime une instruction AR
  void removeARInstruction(String id) {
    _arInstructions.removeWhere((inst) => inst.id == id);
    notifyListeners();
  }

  /// Crée des objets AR pour une route
  void createRouteARObjects(List<LatLng> routePoints) {
    if (_currentPosition == null) return;

    _arObjects.clear();

    for (int i = 0; i < routePoints.length; i++) {
      final point = routePoints[i];
      final distance = const Distance().as(
        LengthUnit.Meter,
        _currentPosition!,
        point,
      );
      final bearing = const Distance().bearing(_currentPosition!, point);

      if (distance < 1000) {
        // Seulement les points proches
        final arObject = ARObject(
          id: 'route_$i',
          type: ARObjectType.direction,
          position: point,
          label: 'Point ${i + 1}',
          distance: distance,
          bearing: bearing,
          color: Colors.blue,
        );

        _arObjects.add(arObject);
      }
    }

    notifyListeners();
  }

  /// Crée des objets AR pour des POI
  void createPOIARObjects(List<Map<String, dynamic>> pois) {
    if (_currentPosition == null) return;

    for (final poi in pois) {
      final position = LatLng(poi['lat'], poi['lon']);
      final distance = const Distance().as(
        LengthUnit.Meter,
        _currentPosition!,
        position,
      );
      final bearing = const Distance().bearing(_currentPosition!, position);

      if (distance < 500) {
        // Seulement les POI proches
        final arObject = ARObject(
          id: 'poi_${poi['id']}',
          type: ARObjectType.poi,
          position: position,
          label: poi['name'] ?? 'POI',
          distance: distance,
          bearing: bearing,
          color: Colors.red,
          metadata: poi,
        );

        _arObjects.add(arObject);
      }
    }

    notifyListeners();
  }

  /// Calibre la boussole AR
  Future<void> calibrateCompass() async {
    // Simulation de calibration
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('Boussole AR calibrée');
    notifyListeners();
  }

  /// Ajuste la sensibilité des capteurs
  void adjustSensorSensitivity(double sensitivity) {
    // Pour la version simplifiée, on log juste
    debugPrint('Sensibilité capteurs AR: $sensitivity');
  }

  /// Configure les filtres AR
  void configureARFilters({
    bool showPOIs = true,
    bool showDirections = true,
    bool showDistances = true,
    bool showWarnings = true,
    double maxDistance = 1000,
  }) {
    // Filtrer les objets selon les paramètres
    _arObjects.removeWhere((obj) {
      if (obj.distance > maxDistance) return true;

      switch (obj.type) {
        case ARObjectType.poi:
          return !showPOIs;
        case ARObjectType.direction:
          return !showDirections;
        case ARObjectType.distance:
          return !showDistances;
        case ARObjectType.warning:
          return !showWarnings;
      }
    });

    notifyListeners();
  }

  /// Active/désactive le mode nuit AR
  void toggleNightMode() {
    // Pour la version simplifiée, on simule
    debugPrint('Mode nuit AR basculé');
    notifyListeners();
  }

  /// Sauvegarde une session AR
  Future<void> saveARSession(String sessionName) async {
    try {
      // Simulation de sauvegarde
      final sessionData = {
        'name': sessionName,
        'timestamp': DateTime.now().toIso8601String(),
        'objects': _arObjects.length,
        'instructions': _arInstructions.length,
        'duration': 'simulé',
      };

      debugPrint('Session AR sauvegardée: $sessionData');
    } catch (e) {
      debugPrint('Erreur sauvegarde session AR: $e');
    }
  }

  /// Charge une session AR
  Future<void> loadARSession(String sessionId) async {
    try {
      // Simulation de chargement
      debugPrint('Session AR chargée: $sessionId');

      // Pour la démo, on ajoute quelques objets
      _addDemoARObjects();

      notifyListeners();
    } catch (e) {
      debugPrint('Erreur chargement session AR: $e');
    }
  }

  /// Ajoute des objets AR de démonstration
  void _addDemoARObjects() {
    if (_currentPosition == null) return;

    final demoObjects = [
      ARObject(
        id: 'demo_1',
        type: ARObjectType.poi,
        position: LatLng(
          _currentPosition!.latitude + 0.001,
          _currentPosition!.longitude + 0.001,
        ),
        label: 'Restaurant Demo',
        distance: 150,
        bearing: 45,
        color: Colors.orange,
      ),
      ARObject(
        id: 'demo_2',
        type: ARObjectType.direction,
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude + 0.002,
        ),
        label: 'Direction Demo',
        distance: 200,
        bearing: 90,
        color: Colors.green,
      ),
    ];

    _arObjects.addAll(demoObjects);
  }

  /// Active les instructions vocales AR
  void enableVoiceInstructions(bool enabled) {
    debugPrint(
      'Instructions vocales AR: ${enabled ? 'activées' : 'désactivées'}',
    );
  }

  /// Configure la précision de localisation AR
  void setLocationAccuracy(String accuracy) {
    debugPrint('Précision localisation AR: $accuracy');
  }

  /// Partage la position AR actuelle
  Future<void> shareARPosition() async {
    if (_currentPosition == null) return;

    // Pour la démo, on simule juste
    notifyListeners();
  }

  /// Capture un screenshot AR (version simplifiée)
  Future<String?> captureARScreenshot() async {
    // Version simplifiée sans caméra
    debugPrint('Screenshot AR simulé');
    return 'ar_screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  /// Démarre l'enregistrement AR (version simplifiée)
  Future<void> startARRecording() async {
    // Version simplifiée sans caméra
    debugPrint('Enregistrement AR démarré (simulé)');
  }

  /// Arrête l'enregistrement AR (version simplifiée)
  Future<String?> stopARRecording() async {
    // Version simplifiée sans caméra
    debugPrint('Enregistrement AR arrêté (simulé)');
    return 'ar_recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
  }

  @override
  void dispose() {
    _arUpdateTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
