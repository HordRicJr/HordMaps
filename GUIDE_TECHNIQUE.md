# HordMaps - Guide Technique Développeur

## 🚀 Démarrage Rapide

### Prérequis
- Flutter 3.19+ 
- Dart 3.3+
- Android Studio / VS Code
- Git

### Installation
```bash
git clone <repository-url>
cd hordmaps
flutter pub get
flutter run
```

## 🏗️ Architecture Technique

### Stack Technologique
- **Framework:** Flutter 3.19
- **Langage:** Dart 3.3
- **État Management:** Provider Pattern
- **Navigation:** flutter_map + OpenStreetMap
- **APIs:** OSRM, OpenRouteService
- **Base de données:** SQLite (via sqflite)
- **Notifications:** flutter_local_notifications

### Structure du Projet
```
lib/
├── core/
│   ├── constants/           # Constantes globales
│   ├── theme/              # Thèmes et styles
│   └── utils/              # Utilitaires généraux
├── features/
│   ├── map/
│   │   ├── providers/      # MapProvider - gestion état carte
│   │   ├── screens/        # MapScreen - interface principale
│   │   └── widgets/        # Composants carte réutilisables
│   ├── navigation/
│   │   ├── providers/      # NavigationProvider - logique navigation
│   │   ├── models/         # RouteResult, RouteStep, NavigationRoute
│   │   └── widgets/        # UI navigation (panel, progress)
│   ├── search/
│   │   ├── providers/      # SearchProvider - recherche lieux
│   │   └── widgets/        # Barre de recherche, résultats
│   ├── favorites/
│   │   ├── providers/      # FavoritesProvider - gestion favoris
│   │   └── screens/        # Interface favoris
│   └── settings/
│       └── screens/        # Paramètres utilisateur
├── services/
│   ├── osm_routing_service.dart      # 🗺️ Calcul itinéraires OSM
│   ├── real_time_navigation_service.dart  # 📍 Navigation temps réel
│   ├── background_navigation_service.dart # 🔔 Service arrière-plan
│   ├── cache_service.dart            # 💾 Cache intelligent
│   ├── voice_guidance_service.dart   # 🔊 Guidage vocal
│   └── navigation_notification_service.dart # 📱 Notifications
├── models/
│   └── navigation_models.dart        # Modèles de données
└── shared/
    ├── widgets/             # Composants UI réutilisables
    └── services/           # Services utilitaires
```

## 🔧 Services Principaux

### `OpenStreetMapRoutingService`
Service central de calcul d'itinéraires avec fallback multi-APIs.

```dart
// Utilisation
final route = await OpenStreetMapRoutingService.calculateRoute(
  start: LatLng(48.8566, 2.3522),  // Paris
  end: LatLng(45.7640, 4.8357),    // Lyon
  transportMode: 'driving',
);
```

**Fonctionnalités:**
- ✅ Calcul itinéraires multi-modaux
- ✅ Cache intelligent (15min)
- ✅ Fallback OSRM → OpenRouteService → Route directe
- ✅ Simulation données trafic
- ✅ Gestion erreurs robuste

### `RealTimeNavigationService`
Service de navigation temps réel avec suivi GPS continu.

```dart
// Démarrage navigation
final service = RealTimeNavigationService.instance;
await service.startNavigation(
  routePoints: route.points,
  totalDistance: route.totalDistance,
  destination: destination,
);

// Écoute des mises à jour
service.progressStream.listen((progress) {
  print('Distance restante: ${progress.remainingDistance} km');
  print('ETA: ${progress.estimatedTimeArrival}');
});
```

**Fonctionnalités:**
- ✅ Suivi GPS haute précision
- ✅ Calcul progression temps réel
- ✅ Stream de données pour UI reactive
- ✅ Détection automatique d'arrivée
- ✅ Recalcul en cas de déviation

### `BackgroundNavigationService`
Service de navigation en arrière-plan avec notifications persistantes.

```dart
// Initialisation
await BackgroundNavigationService.instance.initialize();

// Démarrage navigation arrière-plan
await BackgroundNavigationService.instance.startBackgroundNavigation(
  destination: destination,
  destinationName: "Destination",
  routePoints: route.points,
  totalDistance: route.totalDistance,
);
```

**Fonctionnalités:**
- ✅ Foreground Service Android
- ✅ Notifications enrichies avec actions
- ✅ Gestion permissions automatique
- ✅ Overlay système natif
- ✅ Optimisation batterie

### `CacheService`
Service de cache générique avec gestion TTL.

```dart
// Utilisation
final cache = CacheService.instance;

// Sauvegarder
await cache.saveToCache('route_key', routeData);

// Récupérer
final cachedRoute = await cache.getFromCache('route_key');
```

**Fonctionnalités:**
- ✅ Cache générique avec types
- ✅ Expiration automatique (TTL)
- ✅ Sérialisation JSON automatique
- ✅ Nettoyage périodique
- ✅ Singleton pattern

## 📱 Gestion d'État

### Provider Pattern
L'application utilise le pattern Provider pour la gestion d'état centralisée.

```dart
// Configuration dans main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => MapProvider()),
    ChangeNotifierProvider(create: (_) => NavigationProvider()),
    ChangeNotifierProvider(create: (_) => SearchProvider()),
    ChangeNotifierProvider(create: (_) => FavoritesProvider()),
  ],
  child: MyApp(),
)

// Utilisation dans les widgets
Consumer<NavigationProvider>(
  builder: (context, navProvider, child) {
    return Text('Distance: ${navProvider.currentRoute?.totalDistance}');
  },
)
```

### États de Navigation
```dart
class NavigationProvider extends ChangeNotifier {
  RouteResult? _currentRoute;           // Route calculée
  bool _isCalculatingRoute = false;     // État calcul
  bool _isNavigating = false;           // Navigation active
  int _currentStepIndex = 0;           // Étape actuelle
  String _routeProfile = 'driving';    // Mode transport
  Map<String, dynamic>? _trafficData;  // Données trafic
  
  // Getters reactifs
  RouteResult? get currentRoute => _currentRoute;
  bool get isNavigating => _isNavigating;
  RouteStep? get currentStep => /* logique étape actuelle */;
}
```

## 🗺️ Intégration Cartographique

### Configuration Flutter Map
```dart
FlutterMap(
  mapController: mapProvider.mapController,
  options: MapOptions(
    initialCenter: mapProvider.mapCenter,
    initialZoom: mapProvider.mapZoom,
    onPositionChanged: (position, hasGesture) {
      // Mise à jour état carte
    },
  ),
  children: [
    // Couche tuiles OSM
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.hordmaps.app',
    ),
    
    // Couche itinéraires
    PolylineLayer(
      polylines: mapProvider.routePolylines,
    ),
    
    // Couche marqueurs
    MarkerLayer(
      markers: mapProvider.markers,
    ),
  ],
)
```

### Création Polylines Dynamiques
```dart
Polyline createRoutePolyline(RouteResult route, String transportMode) {
  return Polyline(
    points: route.points,
    strokeWidth: 6.0,
    color: _getColorForTransportMode(transportMode),
    patterns: transportMode == 'walking' ? [PatternItem.dash(10)] : [],
  );
}
```

## 🔔 Système de Notifications

### Configuration Android
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

<service
    android:name=".NavigationForegroundService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="location" />
```

### Notifications Enrichies
```dart
const androidDetails = AndroidNotificationDetails(
  'hordmaps_navigation_channel',
  'Navigation HordMaps',
  importance: Importance.high,
  ongoing: true,
  showProgress: true,
  actions: [
    AndroidNotificationAction('stop_navigation', 'Arrêter'),
    AndroidNotificationAction('open_app', 'Ouvrir HordMaps'),
  ],
  styleInformation: BigTextStyleInformation(
    'Distance restante: 15.2 km • ETA: 18min • 65 km/h',
    contentTitle: 'Navigation vers Destination',
  ),
);
```

## 📡 Intégration APIs

### Configuration OSRM
```dart
static const String _osrmUrl = 'https://router.project-osrm.org/route/v1';

Future<RouteResult> _callOSRMAPI(LatLng start, LatLng end, String profile) async {
  final url = '$_osrmUrl/$profile/${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
  
  final response = await _dio.get(url, queryParameters: {
    'overview': 'full',
    'geometries': 'geojson',
    'steps': 'true',
  });
  
  return _parseOSRMResponse(response.data, profile);
}
```

### Configuration OpenRouteService
```dart
static const String _orsUrl = 'https://api.openrouteservice.org/v2/directions';

Future<RouteResult> _callOpenRouteServiceAPI(LatLng start, LatLng end, String profile) async {
  final response = await _dio.post(
    '$_orsUrl/$profile/geojson',
    data: {
      'coordinates': [[start.longitude, start.latitude], [end.longitude, end.latitude]],
      'format': 'geojson',
      'instructions': true,
    },
    options: Options(headers: {'Authorization': 'Bearer YOUR_ORS_API_KEY'}),
  );
  
  return _parseORSResponse(response.data, profile);
}
```

## 🧪 Tests et Débogage

### Tests Unitaires
```dart
// test/services/osm_routing_service_test.dart
void main() {
  group('OpenStreetMapRoutingService', () {
    test('calcule route basique', () async {
      final start = LatLng(48.8566, 2.3522);
      final end = LatLng(45.7640, 4.8357);
      
      final route = await OpenStreetMapRoutingService.calculateRoute(
        start: start,
        end: end,
        transportMode: 'driving',
      );
      
      expect(route.points, isNotEmpty);
      expect(route.totalDistance, greaterThan(0));
    });
  });
}
```

### Logging et Debug
```dart
// Configuration logs
import 'package:flutter/foundation.dart';

void debugLog(String message) {
  if (kDebugMode) {
    debugPrint('[HordMaps] $message');
  }
}

// Usage dans services
debugLog('Route calculée: ${route.totalDistance}km en ${route.estimatedDuration}');
```

## 🚀 Build et Déploiement

### Configuration Build Android
```bash
# Debug
flutter build apk --debug

# Release
flutter build apk --release --obfuscate --split-debug-info=debug-symbols/

# Bundle AAB pour Play Store
flutter build appbundle --release --obfuscate --split-debug-info=debug-symbols/
```

### Configuration Build iOS
```bash
# Debug
flutter build ios --debug

# Release
flutter build ios --release --obfuscate --split-debug-info=debug-symbols/

# Archive pour App Store
flutter build ipa --release --obfuscate --split-debug-info=debug-symbols/
```

## 🔒 Sécurité

### Obfuscation du Code
```yaml
# pubspec.yaml - configuration build
flutter:
  uses-material-design: true
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

### Gestion des Clés API
```dart
// lib/core/constants/api_keys.dart
class ApiKeys {
  static const String openRouteServiceKey = String.fromEnvironment('ORS_API_KEY');
  static const String mapboxKey = String.fromEnvironment('MAPBOX_KEY');
}
```

```bash
# Build avec variables d'environnement
flutter build apk --release --dart-define=ORS_API_KEY=your_key_here
```

## 📊 Performance et Optimisation

### Optimisations Principales
- **Lazy loading** des tuiles cartes
- **Cache intelligent** avec TTL
- **Debouncing** des recherches
- **Pooling GPS** optimisé
- **Compression** des données route

### Monitoring Performance
```dart
// Mesure performance calcul route
final stopwatch = Stopwatch()..start();
final route = await OpenStreetMapRoutingService.calculateRoute(start, end);
stopwatch.stop();

debugLog('Route calculée en ${stopwatch.elapsedMilliseconds}ms');
```

## 🐛 Débogage Courant

### Problèmes GPS
```dart
// Vérification permissions
final locationPermission = await Permission.location.request();
if (!locationPermission.isGranted) {
  debugLog('Permission de localisation refusée');
}

// Test précision GPS
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);
debugLog('Précision GPS: ${position.accuracy}m');
```

### Problèmes Navigation
```dart
// Debug état navigation
debugLog('Navigation active: ${navProvider.isNavigating}');
debugLog('Route actuelle: ${navProvider.currentRoute?.summary}');
debugLog('Étape: ${navProvider.currentStepIndex}/${navProvider.currentRoute?.steps.length}');
```

## 📞 Support Développeur

**Contact technique :** assounrodrigue5@gmail.com  
**Documentation API :** Voir fichiers dart avec documentation inline  
**Issues GitHub :** Créer une issue avec logs détaillés  

---

*Guide mis à jour pour la version 1.0.0 - Août 2025*
