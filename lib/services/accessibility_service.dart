import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

/// Types de handicap supportés
enum AccessibilityType {
  mobility('Mobilité réduite', Icons.accessible),
  visual('Déficience visuelle', Icons.visibility_off),
  hearing('Déficience auditive', Icons.hearing_disabled),
  cognitive('Difficultés cognitives', Icons.psychology);

  const AccessibilityType(this.displayName, this.icon);
  final String displayName;
  final IconData icon;
}

/// Niveaux d'accessibilité
enum AccessibilityLevel {
  none('Non accessible'),
  partial('Partiellement accessible'),
  full('Entièrement accessible'),
  unknown('Inconnu');

  const AccessibilityLevel(this.displayName);
  final String displayName;
}

/// Modèle d'informations d'accessibilité
class AccessibilityInfo {
  final Map<AccessibilityType, AccessibilityLevel> levels;
  final List<String> features;
  final List<String> barriers;
  final Map<String, dynamic> details;

  AccessibilityInfo({
    required this.levels,
    this.features = const [],
    this.barriers = const [],
    this.details = const {},
  });
}

/// Modèle de lieu accessible
class AccessiblePlace {
  final String id;
  final String name;
  final LatLng position;
  final AccessibilityInfo accessibility;
  final double rating;
  final List<String> reviews;

  AccessiblePlace({
    required this.id,
    required this.name,
    required this.position,
    required this.accessibility,
    this.rating = 0.0,
    this.reviews = const [],
  });
}

/// Modèle d'itinéraire accessible
class AccessibleRoute {
  final List<LatLng> points;
  final double totalDistance;
  final Duration estimatedDuration;
  final AccessibilityInfo routeAccessibility;
  final List<String> warnings;
  final List<AccessiblePlace> accessibleStops;

  AccessibleRoute({
    required this.points,
    required this.totalDistance,
    required this.estimatedDuration,
    required this.routeAccessibility,
    this.warnings = const [],
    this.accessibleStops = const [],
  });
}

/// Service d'accessibilité avancée
class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance =
      AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  bool _isEnabled = false;
  Set<AccessibilityType> _userAccessibilityNeeds = {};
  bool _highContrastMode = false;
  bool _largeTextMode = false;
  bool _audioDescriptionsEnabled = false;
  bool _vibrationFeedbackEnabled = true;
  double _speechRate = 1.0;

  final Map<String, AccessiblePlace> _accessiblePlaces = {};
  final List<String> _accessibilityAnnouncements = [];

  // Getters
  bool get isEnabled => _isEnabled;
  Set<AccessibilityType> get userAccessibilityNeeds =>
      Set.unmodifiable(_userAccessibilityNeeds);
  bool get highContrastMode => _highContrastMode;
  bool get largeTextMode => _largeTextMode;
  bool get audioDescriptionsEnabled => _audioDescriptionsEnabled;
  bool get vibrationFeedbackEnabled => _vibrationFeedbackEnabled;
  double get speechRate => _speechRate;
  Map<String, AccessiblePlace> get accessiblePlaces =>
      Map.unmodifiable(_accessiblePlaces);

  /// Active/désactive le service d'accessibilité
  void toggleAccessibility() {
    _isEnabled = !_isEnabled;
    if (_isEnabled) {
      _loadAccessibilityData();
    }
    notifyListeners();
  }

  /// Configure les besoins d'accessibilité de l'utilisateur
  void setUserAccessibilityNeeds(Set<AccessibilityType> needs) {
    _userAccessibilityNeeds = needs;
    if (_isEnabled) {
      _updateAccessibilitySettings();
    }
    notifyListeners();
  }

  /// Active/désactive le mode haut contraste
  void toggleHighContrast() {
    _highContrastMode = !_highContrastMode;
    notifyListeners();
  }

  /// Active/désactive le mode texte large
  void toggleLargeText() {
    _largeTextMode = !_largeTextMode;
    notifyListeners();
  }

  /// Active/désactive les descriptions audio
  void toggleAudioDescriptions() {
    _audioDescriptionsEnabled = !_audioDescriptionsEnabled;
    notifyListeners();
  }

  /// Active/désactive le feedback vibratoire
  void toggleVibrationFeedback() {
    _vibrationFeedbackEnabled = !_vibrationFeedbackEnabled;
    notifyListeners();
  }

  /// Configure la vitesse de parole
  void setSpeechRate(double rate) {
    _speechRate = rate.clamp(0.5, 2.0);
    notifyListeners();
  }

  /// Charge les données d'accessibilité
  void _loadAccessibilityData() {
    _accessiblePlaces.clear();
    _generateAccessiblePlaces();
    notifyListeners();
  }

  /// Met à jour les paramètres d'accessibilité
  void _updateAccessibilitySettings() {
    // Ici on adapterait l'interface selon les besoins
    if (_userAccessibilityNeeds.contains(AccessibilityType.visual)) {
      _audioDescriptionsEnabled = true;
      _highContrastMode = true;
    }

    if (_userAccessibilityNeeds.contains(AccessibilityType.hearing)) {
      _vibrationFeedbackEnabled = true;
    }

    if (_userAccessibilityNeeds.contains(AccessibilityType.cognitive)) {
      _largeTextMode = true;
      _speechRate = 0.8; // Parole plus lente
    }
  }

  /// Génère des lieux accessibles simulés
  void _generateAccessiblePlaces() {
    final parisCenter = const LatLng(48.8566, 2.3522);

    final places = [
      {
        'name': 'Musée du Louvre',
        'features': [
          'Rampe d\'accès',
          'Ascenseurs',
          'Toilettes PMR',
          'Audioguide',
        ],
        'barriers': [],
        'levels': {
          AccessibilityType.mobility: AccessibilityLevel.full,
          AccessibilityType.visual: AccessibilityLevel.full,
          AccessibilityType.hearing: AccessibilityLevel.partial,
          AccessibilityType.cognitive: AccessibilityLevel.partial,
        },
      },
      {
        'name': 'Tour Eiffel',
        'features': ['Ascenseurs adaptés', 'Toilettes PMR'],
        'barriers': ['Escaliers nombreux', 'Foule importante'],
        'levels': {
          AccessibilityType.mobility: AccessibilityLevel.partial,
          AccessibilityType.visual: AccessibilityLevel.partial,
          AccessibilityType.hearing: AccessibilityLevel.full,
          AccessibilityType.cognitive: AccessibilityLevel.partial,
        },
      },
      {
        'name': 'Centre Pompidou',
        'features': ['Accès complet PMR', 'Visite tactile', 'LSF disponible'],
        'barriers': [],
        'levels': {
          AccessibilityType.mobility: AccessibilityLevel.full,
          AccessibilityType.visual: AccessibilityLevel.full,
          AccessibilityType.hearing: AccessibilityLevel.full,
          AccessibilityType.cognitive: AccessibilityLevel.full,
        },
      },
      {
        'name': 'Gare du Nord',
        'features': ['Ascenseurs', 'Aide à la mobilité', 'Annonces sonores'],
        'barriers': ['Affluence aux heures de pointe'],
        'levels': {
          AccessibilityType.mobility: AccessibilityLevel.full,
          AccessibilityType.visual: AccessibilityLevel.full,
          AccessibilityType.hearing: AccessibilityLevel.partial,
          AccessibilityType.cognitive: AccessibilityLevel.partial,
        },
      },
      {
        'name': 'Hôpital Pitié-Salpêtrière',
        'features': [
          'Accès PMR complet',
          'Signalétique braille',
          'Personnel formé',
        ],
        'barriers': [],
        'levels': {
          AccessibilityType.mobility: AccessibilityLevel.full,
          AccessibilityType.visual: AccessibilityLevel.full,
          AccessibilityType.hearing: AccessibilityLevel.full,
          AccessibilityType.cognitive: AccessibilityLevel.full,
        },
      },
    ];

    for (int i = 0; i < places.length; i++) {
      final place = places[i];

      // Position simulée autour de Paris
      final lat = parisCenter.latitude + (i - 2) * 0.02;
      final lng = parisCenter.longitude + (i - 2) * 0.02;

      _accessiblePlaces['place_$i'] = AccessiblePlace(
        id: 'place_$i',
        name: place['name'] as String,
        position: LatLng(lat, lng),
        accessibility: AccessibilityInfo(
          levels: place['levels'] as Map<AccessibilityType, AccessibilityLevel>,
          features: List<String>.from(place['features'] as List),
          barriers: List<String>.from(place['barriers'] as List),
          details: {
            'last_updated': DateTime.now().toIso8601String(),
            'verified': true,
          },
        ),
        rating: 4.0 + (i * 0.2),
        reviews: [
          'Très bien adapté aux personnes à mobilité réduite',
          'Personnel accueillant et formé',
          'Signalétique claire',
        ],
      );
    }
  }

  /// Recherche de lieux accessibles
  List<AccessiblePlace> findAccessiblePlaces(
    LatLng position, {
    double radiusKm = 5.0,
    Set<AccessibilityType>? filterTypes,
    AccessibilityLevel minLevel = AccessibilityLevel.partial,
  }) {
    const distance = Distance();

    return _accessiblePlaces.values.where((place) {
      // Filtre par distance
      final placeDistance = distance.as(
        LengthUnit.Kilometer,
        position,
        place.position,
      );
      if (placeDistance > radiusKm) return false;

      // Filtre par type d'accessibilité
      if (filterTypes != null && filterTypes.isNotEmpty) {
        for (final type in filterTypes) {
          final level =
              place.accessibility.levels[type] ?? AccessibilityLevel.none;
          if (level.index < minLevel.index) return false;
        }
      }

      return true;
    }).toList()..sort((a, b) {
      final distA = distance.as(LengthUnit.Kilometer, position, a.position);
      final distB = distance.as(LengthUnit.Kilometer, position, b.position);
      return distA.compareTo(distB);
    });
  }

  /// Calcule un itinéraire accessible
  Future<AccessibleRoute?> calculateAccessibleRoute(
    LatLng from,
    LatLng to, {
    Set<AccessibilityType>? accessibilityNeeds,
    bool avoidStairs = false,
    bool preferRamps = false,
    bool requireElevators = false,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulation

    final needs = accessibilityNeeds ?? _userAccessibilityNeeds;
    final warnings = <String>[];

    // Générer un itinéraire adapté
    final points = _generateAccessibleRoutePoints(from, to, needs);

    // Calculer la distance et la durée
    const distance = Distance();
    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += distance.as(
        LengthUnit.Kilometer,
        points[i],
        points[i + 1],
      );
    }

    // Ajuster la durée selon les besoins d'accessibilité
    var estimatedDuration = Duration(minutes: (totalDistance * 15).round());
    if (needs.contains(AccessibilityType.mobility)) {
      estimatedDuration = Duration(
        seconds: (estimatedDuration.inSeconds * 1.5).round(),
      );
      warnings.add(
        'Itinéraire adapté aux personnes à mobilité réduite (+50% de temps)',
      );
    }

    // Identifier les arrêts accessibles sur le trajet
    final accessibleStops = _findAccessibleStopsOnRoute(points, needs);

    // Évaluer l'accessibilité générale de l'itinéraire
    final routeAccessibility = _evaluateRouteAccessibility(points, needs);

    // Ajouter des avertissements selon les besoins
    if (needs.contains(AccessibilityType.visual)) {
      warnings.add('Navigation vocale activée pour déficience visuelle');
    }
    if (needs.contains(AccessibilityType.hearing)) {
      warnings.add('Feedback vibratoire activé');
    }

    return AccessibleRoute(
      points: points,
      totalDistance: totalDistance,
      estimatedDuration: estimatedDuration,
      routeAccessibility: routeAccessibility,
      warnings: warnings,
      accessibleStops: accessibleStops,
    );
  }

  /// Génère les points d'un itinéraire accessible
  List<LatLng> _generateAccessibleRoutePoints(
    LatLng from,
    LatLng to,
    Set<AccessibilityType> needs,
  ) {
    final points = <LatLng>[from];

    // Ajouter des points intermédiaires évitant les obstacles
    if (needs.contains(AccessibilityType.mobility)) {
      // Éviter les escaliers, privilégier les rampes
      final midLat = (from.latitude + to.latitude) / 2;
      final midLng = (from.longitude + to.longitude) / 2;

      // Ajouter un détour pour éviter les escaliers
      points.add(LatLng(midLat + 0.001, midLng));
    }

    points.add(to);
    return points;
  }

  /// Trouve les arrêts accessibles sur un itinéraire
  List<AccessiblePlace> _findAccessibleStopsOnRoute(
    List<LatLng> routePoints,
    Set<AccessibilityType> needs,
  ) {
    final stops = <AccessiblePlace>[];

    for (final point in routePoints) {
      final nearbyPlaces = findAccessiblePlaces(
        point,
        radiusKm: 0.5,
        filterTypes: needs,
        minLevel: AccessibilityLevel.partial,
      );

      if (nearbyPlaces.isNotEmpty) {
        stops.add(nearbyPlaces.first);
      }
    }

    return stops;
  }

  /// Évalue l'accessibilité d'un itinéraire
  AccessibilityInfo _evaluateRouteAccessibility(
    List<LatLng> routePoints,
    Set<AccessibilityType> needs,
  ) {
    final levels = <AccessibilityType, AccessibilityLevel>{};
    final features = <String>[];
    final barriers = <String>[];

    for (final need in needs) {
      switch (need) {
        case AccessibilityType.mobility:
          levels[need] = AccessibilityLevel.full;
          features.add('Itinéraire sans escaliers');
          break;
        case AccessibilityType.visual:
          levels[need] = AccessibilityLevel.full;
          features.add('Navigation vocale disponible');
          break;
        case AccessibilityType.hearing:
          levels[need] = AccessibilityLevel.full;
          features.add('Feedback visuel et vibratoire');
          break;
        case AccessibilityType.cognitive:
          levels[need] = AccessibilityLevel.partial;
          features.add('Instructions simplifiées');
          barriers.add('Itinéraire complexe avec correspondances');
          break;
      }
    }

    return AccessibilityInfo(
      levels: levels,
      features: features,
      barriers: barriers,
      details: {
        'route_type': 'accessible',
        'evaluation_date': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Annonce vocale d'accessibilité
  Future<void> announceAccessibilityInfo(String message) async {
    if (!_audioDescriptionsEnabled) return;

    _accessibilityAnnouncements.add(message);

    // Ici on utiliserait un service TTS avec la vitesse configurée
    await HapticFeedback.lightImpact();

    notifyListeners();
  }

  /// Feedback vibratoire
  Future<void> accessibilityVibration({int duration = 100}) async {
    if (!_vibrationFeedbackEnabled) return;

    await HapticFeedback.mediumImpact();
  }

  /// Obtient le thème adapté à l'accessibilité
  ThemeData getAccessibleTheme(ThemeData baseTheme) {
    var theme = baseTheme;

    if (_highContrastMode) {
      theme = theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.white,
          onSecondary: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      );
    }

    if (_largeTextMode) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
          bodyMedium: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
          titleLarge: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
        ),
      );
    }

    return theme;
  }

  /// Valide l'accessibilité d'un lieu
  void validatePlaceAccessibility(
    String placeId,
    AccessibilityInfo newInfo,
    String userComment,
  ) {
    if (_accessiblePlaces.containsKey(placeId)) {
      // Mettre à jour les informations d'accessibilité
      // Dans une vraie app, on enverrait ça à un serveur
      debugPrint('Accessibilité mise à jour pour $placeId: $userComment');
    }
    notifyListeners();
  }

  /// Signale un problème d'accessibilité
  void reportAccessibilityIssue(
    LatLng location,
    AccessibilityType type,
    String description,
  ) {
    // Dans une vraie app, on enverrait ça à un service de signalement
    debugPrint(
      'Problème d\'accessibilité signalé: $type à $location - $description',
    );

    _accessibilityAnnouncements.add(
      'Problème d\'accessibilité signalé. Merci pour votre contribution.',
    );

    notifyListeners();
  }

  /// Obtient les statistiques d'accessibilité
  Map<String, dynamic> getAccessibilityStats() {
    final totalPlaces = _accessiblePlaces.length;
    final fullyAccessible = _accessiblePlaces.values
        .where(
          (place) => place.accessibility.levels.values.every(
            (level) => level == AccessibilityLevel.full,
          ),
        )
        .length;

    return {
      'total_places': totalPlaces,
      'fully_accessible': fullyAccessible,
      'accessibility_coverage': fullyAccessible / totalPlaces,
      'user_needs': _userAccessibilityNeeds
          .map((need) => need.displayName)
          .toList(),
      'features_enabled': {
        'high_contrast': _highContrastMode,
        'large_text': _largeTextMode,
        'audio_descriptions': _audioDescriptionsEnabled,
        'vibration_feedback': _vibrationFeedbackEnabled,
      },
    };
  }
}
