import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Service pour gérer la boussole et l'orientation
class CompassService extends ChangeNotifier {
  static final CompassService _instance = CompassService._internal();
  factory CompassService() => _instance;
  CompassService._internal();

  double _heading = 0.0;
  bool _isEnabled = false;
  StreamSubscription<double>? _headingSubscription;
  Timer? _simulationTimer;

  /// Orientation actuelle en degrés (0-360)
  double get heading => _heading;

  /// Si la boussole est activée
  bool get isEnabled => _isEnabled;

  /// Démarre la boussole
  void startCompass() {
    if (_isEnabled) return;

    _isEnabled = true;

    // Simulation de la boussole pour le développement
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      // Simulation d'un mouvement de boussole aléatoire
      final random = Random();
      final variation =
          (random.nextDouble() - 0.5) * 10; // Variation de ±5 degrés
      _heading = (_heading + variation) % 360;
      if (_heading < 0) _heading += 360;

      notifyListeners();
    });

    notifyListeners();
  }

  /// Arrête la boussole
  void stopCompass() {
    if (!_isEnabled) return;

    _isEnabled = false;
    _headingSubscription?.cancel();
    _headingSubscription = null;
    _simulationTimer?.cancel();
    _simulationTimer = null;

    notifyListeners();
  }

  /// Remet la boussole à zéro (nord)
  void resetCompass() {
    _heading = 0.0;
    notifyListeners();
  }

  /// Convertit les degrés en direction cardinale
  String getCardinalDirection() {
    if (_heading >= 337.5 || _heading < 22.5) return 'N';
    if (_heading >= 22.5 && _heading < 67.5) return 'NE';
    if (_heading >= 67.5 && _heading < 112.5) return 'E';
    if (_heading >= 112.5 && _heading < 157.5) return 'SE';
    if (_heading >= 157.5 && _heading < 202.5) return 'S';
    if (_heading >= 202.5 && _heading < 247.5) return 'SW';
    if (_heading >= 247.5 && _heading < 292.5) return 'W';
    if (_heading >= 292.5 && _heading < 337.5) return 'NW';
    return 'N';
  }

  /// Calcule l'angle entre deux points géographiques
  double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;

    final y = sin(dLon) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  /// Calibre la boussole (simulation)
  Future<void> calibrateCompass() async {
    // Simulation d'un processus de calibration
    await Future.delayed(const Duration(seconds: 2));
    _heading = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    stopCompass();
    super.dispose();
  }
}
