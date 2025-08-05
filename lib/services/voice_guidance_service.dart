import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:io' show Platform;

/// Service de synthèse vocale pour la navigation
class VoiceGuidanceService extends ChangeNotifier {
  static final VoiceGuidanceService _instance =
      VoiceGuidanceService._internal();
  factory VoiceGuidanceService() => _instance;
  VoiceGuidanceService._internal();

  late FlutterTts _flutterTts;
  bool _isEnabled = true;
  bool _isPlaying = false;
  double _volume = 0.8;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  String _language = 'fr-FR';
  bool _isInitialized = false;

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  String get language => _language;
  bool get isInitialized => _isInitialized;

  /// Initialise le service TTS
  Future<void> initialize() async {
    try {
      _flutterTts = FlutterTts();

      // Configuration des callbacks
      _flutterTts.setStartHandler(() {
        _isPlaying = true;
        notifyListeners();
      });

      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        notifyListeners();
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('Erreur TTS: $msg');
        _isPlaying = false;
        notifyListeners();
      });

      // Configuration initiale
      await _flutterTts.setLanguage(_language);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);

      // Configuration spécifique à la plateforme
      if (Platform.isAndroid) {
        await _flutterTts.setEngine("com.google.android.tts");
      }

      _isInitialized = true;
      debugPrint('VoiceGuidanceService initialisé avec succès');
    } catch (e) {
      debugPrint('Erreur initialisation VoiceGuidanceService: $e');
      _isInitialized = false;
    }
  }

  /// Active/désactive la synthèse vocale
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled && _isPlaying) {
      stop();
    }
    notifyListeners();
  }

  /// Configure le volume
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_isInitialized) {
      await _flutterTts.setVolume(_volume);
    }
    notifyListeners();
  }

  /// Configure la vitesse de parole
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    if (_isInitialized) {
      await _flutterTts.setSpeechRate(_speechRate);
    }
    notifyListeners();
  }

  /// Configure la hauteur de voix
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    if (_isInitialized) {
      await _flutterTts.setPitch(_pitch);
    }
    notifyListeners();
  }

  /// Configure la langue
  Future<void> setLanguage(String language) async {
    _language = language;
    if (_isInitialized) {
      await _flutterTts.setLanguage(_language);
    }
    notifyListeners();
  }

  /// Prononce un texte
  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty || !_isInitialized) return;

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Erreur lors de la synthèse vocale: $e');
    }
  }

  /// Arrête la lecture en cours
  Future<void> stop() async {
    if (_isInitialized) {
      await _flutterTts.stop();
    }
    _isPlaying = false;
    notifyListeners();
  }

  /// Met en pause la lecture
  Future<void> pause() async {
    if (_isInitialized) {
      await _flutterTts.pause();
    }
    _isPlaying = false;
    notifyListeners();
  }

  /// Annonce une instruction de navigation
  Future<void> announceNavigation(
    String instruction,
    int distanceMeters,
  ) async {
    if (!_isEnabled || !_isInitialized) return;

    String distanceText;
    if (distanceMeters < 50) {
      distanceText = 'Maintenant';
    } else if (distanceMeters < 100) {
      distanceText = 'Dans $distanceMeters mètres';
    } else if (distanceMeters < 1000) {
      final hundreds = (distanceMeters / 100).round() * 100;
      distanceText = 'Dans $hundreds mètres';
    } else {
      final km = (distanceMeters / 1000).toStringAsFixed(1);
      distanceText = 'Dans $km kilomètres';
    }

    final announcement = '$distanceText, $instruction';
    await speak(announcement);
  }

  /// Annonce des informations de trafic
  Future<void> announceTraffic(String trafficInfo) async {
    if (!_isEnabled || !_isInitialized) return;
    await speak('Information trafic: $trafficInfo');
  }

  /// Annonce l'arrivée à destination
  Future<void> announceArrival() async {
    if (!_isEnabled || !_isInitialized) return;
    await speak('Vous êtes arrivé à destination');
  }

  /// Annonce un changement d'itinéraire
  Future<void> announceReroute() async {
    if (!_isEnabled || !_isInitialized) return;
    await speak('Calcul d\'un nouvel itinéraire en cours');
  }

  /// Annonce une alerte de vitesse
  Future<void> announceSpeedAlert(int speedLimit) async {
    if (!_isEnabled || !_isInitialized) return;
    await speak(
      'Attention, limitation de vitesse à $speedLimit kilomètres par heure',
    );
  }

  /// Annonce un embouteillage
  Future<void> announceTrafficJam(int delayMinutes) async {
    if (!_isEnabled || !_isInitialized) return;
    if (delayMinutes > 0) {
      await speak(
        'Embouteillage détecté, retard estimé de $delayMinutes minutes',
      );
    }
  }

  /// Teste la synthèse vocale
  Future<void> test() async {
    await speak('Test de la synthèse vocale. HordMaps est prêt à vous guider.');
  }

  /// Obtient les langues disponibles
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) return [];
    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages);
    } catch (e) {
      debugPrint('Erreur lors de la récupération des langues: $e');
      return [];
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
