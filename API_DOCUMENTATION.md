# API Documentation - HordMaps Services

## 📡 Services Architecture

### Overview
HordMaps utilise une architecture de services modulaires pour séparer les responsabilités et maintenir un code propre et testable.

```
Services Layer
├── Navigation Services
│   ├── OpenStreetMapRoutingService    # Calcul itinéraires
│   ├── RealTimeNavigationService      # Navigation temps réel
│   └── BackgroundNavigationService    # Services arrière-plan
├── Core Services
│   ├── CacheService                   # Cache intelligent
│   ├── LocationService                # Géolocalisation
│   └── VoiceGuidanceService          # Guidage vocal
└── UI Services
    ├── NavigationNotificationService  # Notifications
    └── NavigationOverlayService      # Overlays système
```

---

## 🗺️ OpenStreetMapRoutingService

Service principal de calcul d'itinéraires avec support multi-API et cache intelligent.

### API Reference

#### `calculateRoute()`
Calcule un itinéraire optimisé entre deux points.

```dart
static Future<RouteResult> calculateRoute({
  required LatLng start,
  required LatLng end,
  String transportMode = 'driving',
}) async
```

**Parameters:**
- `start` *(LatLng)* - Point de départ
- `end` *(LatLng)* - Point d'arrivée  
- `transportMode` *(String)* - Mode de transport (`driving`, `walking`, `cycling`, `motorcycle`, `transit`)

**Returns:**
- `Future<RouteResult>` - Résultat avec points, étapes, distance et durée

**Example:**
```dart
final route = await OpenStreetMapRoutingService.calculateRoute(
  start: LatLng(48.8566, 2.3522),  // Paris
  end: LatLng(45.7640, 4.8357),    // Lyon
  transportMode: 'driving',
);

print('Distance: ${route.totalDistance} km');
print('Durée: ${route.estimatedDuration}');
print('Étapes: ${route.steps.length}');
```

#### `getTrafficData()`
Récupère les données de trafic simulées pour un itinéraire.

```dart
static Future<Map<String, dynamic>> getTrafficData(
  List<LatLng> routePoints,
) async
```

**Parameters:**
- `routePoints` *(List<LatLng>)* - Points de l'itinéraire

**Returns:**
- `Future<Map<String, dynamic>>` - Données trafic avec congestion et incidents

---

## 📍 RealTimeNavigationService

Service de navigation temps réel avec suivi GPS continu et calcul de progression.

### API Reference

#### `startNavigation()`
Démarre la navigation temps réel.

```dart
Future<void> startNavigation({
  required List<LatLng> routePoints,
  required double totalDistance,
  required LatLng destination,
}) async
```

**Parameters:**
- `routePoints` *(List<LatLng>)* - Points de l'itinéraire
- `totalDistance` *(double)* - Distance totale en km
- `destination` *(LatLng)* - Point de destination

#### `stopNavigation()`
Arrête la navigation et nettoie les ressources.

```dart
Future<void> stopNavigation() async
```

### Streams

#### `progressStream`
Stream des mises à jour de progression.

```dart
Stream<NavigationProgress> get progressStream
```

**NavigationProgress Properties:**
```dart
class NavigationProgress {
  final double remainingDistance;      // Distance restante (km)
  final Duration estimatedTimeArrival; // Temps estimé d'arrivée
  final double averageSpeed;           // Vitesse moyenne (km/h)
  final double completionPercentage;   // Pourcentage completion (0-100)
  final bool isArrived;               // Arrivé à destination
  final LatLng currentPosition;       // Position actuelle
}
```

**Example:**
```dart
final service = RealTimeNavigationService.instance;

// Démarrer navigation
await service.startNavigation(
  routePoints: route.points,
  totalDistance: route.totalDistance,
  destination: destination,
);

// Écouter mises à jour
service.progressStream.listen((progress) {
  print('Restant: ${progress.remainingDistance.toStringAsFixed(1)} km');
  print('ETA: ${progress.estimatedTimeArrival}');
  print('Vitesse: ${progress.averageSpeed.toStringAsFixed(0)} km/h');
  print('Progression: ${progress.completionPercentage.toStringAsFixed(1)}%');
});
```

---

## 🔔 BackgroundNavigationService

Service de navigation en arrière-plan avec notifications persistantes et overlay système.

### API Reference

#### `initialize()`
Initialise le service et configure les notifications.

```dart
Future<void> initialize() async
```

#### `startBackgroundNavigation()`
Démarre la navigation en arrière-plan avec notifications.

```dart
Future<bool> startBackgroundNavigation({
  required LatLng destination,
  required String destinationName,
  required List<LatLng> routePoints,
  required double totalDistance,
}) async
```

**Parameters:**
- `destination` *(LatLng)* - Point de destination
- `destinationName` *(String)* - Nom de la destination
- `routePoints` *(List<LatLng>)* - Points de l'itinéraire
- `totalDistance` *(double)* - Distance totale

**Returns:**
- `Future<bool>` - `true` si démarré avec succès

#### `stopBackgroundNavigation()`
Arrête le service en arrière-plan.

```dart
Future<void> stopBackgroundNavigation() async
```

### Properties

```dart
bool get isServiceRunning          // Service actif
String? get currentDestinationName // Destination actuelle
```

---

## 💾 CacheService

Service de cache générique avec gestion TTL et sérialisation automatique.

### API Reference

#### `saveToCache()`
Sauvegarde des données dans le cache.

```dart
Future<void> saveToCache<T>(String key, T data) async
```

**Parameters:**
- `key` *(String)* - Clé unique de cache
- `data` *(T)* - Données à mettre en cache

#### `getFromCache()`
Récupère des données du cache.

```dart
Future<T?> getFromCache<T>(String key) async
```

**Parameters:**
- `key` *(String)* - Clé de cache

**Returns:**
- `Future<T?>` - Données ou `null` si expirées/inexistantes

#### `clearCache()`
Vide complètement le cache.

```dart
Future<void> clearCache() async
```

**Example:**
```dart
final cache = CacheService.instance;

// Sauvegarder
await cache.saveToCache('user_settings', {
  'theme': 'dark',
  'language': 'fr',
});

// Récupérer
final settings = await cache.getFromCache<Map<String, dynamic>>('user_settings');
if (settings != null) {
  print('Thème: ${settings['theme']}');
}
```

---

## 🔊 VoiceGuidanceService

Service de guidage vocal avec synthèse vocale intelligente.

### API Reference

#### `speak()`
Prononce un texte avec la synthèse vocale.

```dart
Future<void> speak(String text) async
```

#### `announceNavigation()`
Annonce une instruction de navigation.

```dart
Future<void> announceNavigation(String instruction, int distanceInMeters) async
```

**Parameters:**
- `instruction` *(String)* - Instruction de navigation
- `distanceInMeters` *(int)* - Distance en mètres

#### `announceArrival()`
Annonce l'arrivée à destination.

```dart
Future<void> announceArrival() async
```

---

## 🔔 NavigationNotificationService

Service de notifications pour la navigation avec notifications enrichies.

### API Reference

#### `startNavigation()`
Démarre les notifications de navigation.

```dart
Future<void> startNavigation(String destinationName) async
```

#### `updateNavigationInstruction()`
Met à jour l'instruction de navigation.

```dart
Future<void> updateNavigationInstruction(String instruction, int distanceInMeters) async
```

#### `showArrivalNotification()`
Affiche notification d'arrivée.

```dart
Future<void> showArrivalNotification() async
```

#### `stopNavigation()`
Arrête les notifications de navigation.

```dart
Future<void> stopNavigation() async
```

### Static Methods

#### `showInAppNotification()`
Affiche une notification in-app temporaire.

```dart
static void showInAppNotification(
  BuildContext context,
  String message, {
  IconData icon = Icons.info,
  Color backgroundColor = Colors.blue,
  Duration duration = const Duration(seconds: 3),
})
```

---

## 📱 NavigationOverlayService

Service d'overlay système pour affichage par-dessus autres applications.

### API Reference

#### `initialize()`
Initialise le service d'overlay.

```dart
Future<void> initialize() async
```

#### `showNavigationOverlay()`
Affiche l'overlay de navigation.

```dart
Future<void> showNavigationOverlay(
  BuildContext context,
  NavigationProgress progress, {
  Duration autoHideDuration = const Duration(seconds: 5),
}) async
```

#### `showSystemOverlay()`
Affiche l'overlay système natif (Android).

```dart
Future<void> showSystemOverlay({
  required String title,
  required String content,
  required double progress,
}) async
```

#### `hideOverlay()`
Masque l'overlay actuel.

```dart
Future<void> hideOverlay() async
```

---

## 📊 Models

### RouteResult
Résultat d'un calcul d'itinéraire.

```dart
class RouteResult {
  final List<LatLng> points;           // Points de l'itinéraire
  final double totalDistance;         // Distance totale (km)
  final Duration estimatedDuration;    // Durée estimée
  final List<RouteStep> steps;        // Étapes de navigation
  final String summary;               // Résumé de l'itinéraire
  
  // Getters
  double get distance => totalDistance;
  List<LatLng> get routePoints => points;
}
```

### RouteStep
Étape de navigation dans un itinéraire.

```dart
class RouteStep {
  final String instruction;           // Instruction de navigation
  final double distance;              // Distance de l'étape (km)
  final Duration duration;            // Durée de l'étape
  final LatLng location;              // Position de l'étape
  final String type;                  // Type d'instruction
  final String modifier;             // Modificateur (optionnel)
}
```

### NavigationRoute
Route de navigation complète avec méthodes utilitaires.

```dart
class NavigationRoute {
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double distance;
  final Duration duration;
  final String summary;
  
  // Factory
  factory NavigationRoute.fromRouteResult(RouteResult result);
  
  // Getters
  List<LatLng> get routePoints => points;
}
```

---

## 🔧 Configuration

### Transport Profiles
Profils de transport disponibles pour le calcul d'itinéraires.

```dart
static const Map<String, Map<String, dynamic>> transportProfiles = {
  'driving': {
    'osrm': 'driving',
    'ors': 'driving-car',
    'speed': 60.0,           // km/h
    'color': Color(0xFF2196F3),
  },
  'walking': {
    'osrm': 'foot',
    'ors': 'foot-walking',
    'speed': 5.0,
    'color': Color(0xFF4CAF50),
  },
  'cycling': {
    'osrm': 'bicycle',
    'ors': 'cycling-regular',
    'speed': 20.0,
    'color': Color(0xFFFF9800),
  },
  'motorcycle': {
    'osrm': 'driving',
    'ors': 'driving-car',
    'speed': 70.0,
    'color': Color(0xFF9C27B0),
  },
  'transit': {
    'ors': 'driving-car',
    'speed': 40.0,
    'color': Color(0xFFF44336),
  },
};
```

### Cache Configuration
Configuration du cache avec TTL par défaut.

```dart
static const Duration _cacheValidDuration = Duration(minutes: 15);
static const String _routeCacheKey = 'cached_routes';
```

---

## 🚨 Error Handling

### Service Exceptions
Toutes les méthodes de service gèrent les erreurs de manière robuste avec logs détaillés.

```dart
try {
  final route = await OpenStreetMapRoutingService.calculateRoute(start, end);
  // Utiliser route
} catch (e) {
  debugPrint('Erreur calcul itinéraire: $e');
  // Fallback ou message utilisateur
}
```

### Fallback Strategy
Stratégie de fallback automatique pour la robustesse :

1. **OSRM API** (primaire)
2. **OpenRouteService API** (secondaire)  
3. **Route directe** (fallback final)

---

## 📞 Support API

**Documentation technique :** assounrodrigue5@gmail.com  
**Issues GitHub :** Créer une issue avec logs détaillés  
**Version API :** 1.0.0  
**Dernière mise à jour :** Août 2025

---

*Documentation API maintenue par l'équipe HordMaps*
