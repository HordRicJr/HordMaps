import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service d'urgence pour désactiver complètement la géolocalisation
class EmergencyLocationDisableService {
  static const String _disabledKey = 'geolocation_emergency_disabled';
  static bool _isDisabled = false;

  /// Désactive complètement la géolocalisation
  static Future<void> disableGeolocation() async {
    _isDisabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disabledKey, true);
  }

  /// Réactive la géolocalisation
  static Future<void> enableGeolocation() async {
    _isDisabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disabledKey, false);
  }

  /// Vérifie si la géolocalisation est désactivée
  static Future<bool> isGeolocationDisabled() async {
    if (_isDisabled) return true;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_disabledKey) ?? false;
  }

  /// Position par défaut (Paris) quand la géolocalisation est désactivée
  static const double defaultLatitude = 48.8566;
  static const double defaultLongitude = 2.3522;

  /// Retourne une position par défaut
  static Map<String, double> getDefaultPosition() {
    return {'latitude': defaultLatitude, 'longitude': defaultLongitude};
  }
}

/// Service de fallback sans géolocalisation
class FallbackLocationService extends ChangeNotifier {
  double _latitude = EmergencyLocationDisableService.defaultLatitude;
  double _longitude = EmergencyLocationDisableService.defaultLongitude;
  bool _isLocationSet = false;

  double get latitude => _latitude;
  double get longitude => _longitude;
  bool get isLocationSet => _isLocationSet;

  /// Définit une position manuellement
  void setManualPosition(double lat, double lng) {
    _latitude = lat;
    _longitude = lng;
    _isLocationSet = true;
    notifyListeners();
  }

  /// Définit une position par nom de ville
  void setCityPosition(String cityName) {
    switch (cityName.toLowerCase()) {
      case 'paris':
        setManualPosition(48.8566, 2.3522);
        break;
      case 'lyon':
        setManualPosition(45.7640, 4.8357);
        break;
      case 'marseille':
        setManualPosition(43.2965, 5.3698);
        break;
      case 'toulouse':
        setManualPosition(43.6047, 1.4442);
        break;
      case 'nice':
        setManualPosition(43.7102, 7.2620);
        break;
      case 'nantes':
        setManualPosition(47.2184, -1.5536);
        break;
      case 'strasbourg':
        setManualPosition(48.5734, 7.7521);
        break;
      case 'montpellier':
        setManualPosition(43.6119, 3.8772);
        break;
      case 'bordeaux':
        setManualPosition(44.8378, -0.5792);
        break;
      case 'lille':
        setManualPosition(50.6292, 3.0573);
        break;
      default:
        // Position par défaut : Paris
        setManualPosition(48.8566, 2.3522);
    }
  }

  /// Réinitialise à la position par défaut
  void resetToDefault() {
    setManualPosition(
      EmergencyLocationDisableService.defaultLatitude,
      EmergencyLocationDisableService.defaultLongitude,
    );
  }
}
