import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'core/config/environment_config.dart';
import 'features/favorites/providers/favorites_provider.dart';
import 'features/map/providers/map_provider.dart';
import 'features/search/providers/search_provider.dart';
import 'features/navigation/providers/providers.dart';
import 'features/theme/theme_provider.dart';
import 'controllers/app_controller.dart';
import 'controllers/route_controller.dart';
import 'controllers/search_controller.dart' as search;
import 'controllers/favorites_controller.dart';
import 'services/user_service.dart';
import 'services/cache_service.dart';
import 'services/crash_proof_location_service.dart';
import 'services/auto_recovery_service.dart';
import 'services/error_logging_service.dart';
import 'shared/services/poi_service.dart';
import 'shared/services/offline_service.dart';
import 'shared/services/storage_service.dart';
import 'widgets/complete_map_controls.dart';
import 'screens/user_setup_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'views/route_search_view.dart';
import 'views/navigation_view.dart';

void main() async {
  // Capture des erreurs avant même l'initialisation de Flutter
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Configuration du système
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Initialisation des animations
    Animate.restartOnHotReload = true;

    // Initialiser les services de gestion d'erreurs en premier
    try {
      // Initialiser le service de logging d'erreurs
      await ErrorLoggingService().initialize();
      debugPrint('✅ Service de logging d\'erreurs initialisé');
      
      // Initialiser le service de récupération automatique
      AutoRecoveryService().startRecovery();
      debugPrint('✅ Service de récupération automatique démarré');
    } catch (e) {
      debugPrint('⚠️ Erreur initialisation services d\'erreur: $e');
      // Continuer même si ces services échouent
    }

    // Initialisation des services de base avec gestion d'erreur robuste
    try {
      // Initialiser la configuration d'environnement en premier
      await EnvironmentConfig.initialize();
      debugPrint('✅ Configuration d\'environnement initialisée');
      
      // Initialiser les services de base avec retry en cas d'échec
      await _initializeServiceWithRetry(
        'UserService', 
        () => UserService.instance.initialize(),
      );
      
      await _initializeServiceWithRetry(
        'CacheService', 
        () => CacheService.initialize(),
      );
      
      await _initializeServiceWithRetry(
        'StorageService', 
        () => StorageService.initialize(),
      );

      // Initialiser le service de géolocalisation sécurisé
      await _initializeServiceWithRetry(
        'CrashProofLocationService',
        () => CrashProofLocationService().initialize(),
      );

      debugPrint('✅ Services de base initialisés');
    } catch (e) {
      // Enregistrer l'erreur mais continuer
      ErrorLoggingService().error('main', 'Erreur initialisation services de base', details: e);
      debugPrint('⚠️ Erreur initialisation services: $e');
      // L'app continue même si certains services échouent
    }

    // Initialiser les contrôleurs MVC avec gestion d'erreur
    try {
      // Initialiser l'AppController MVC
      await _initializeServiceWithRetry(
        'AppController',
        () => AppController.instance.initializeApp(),
      );

      // Initialiser les autres contrôleurs MVC
      await _initializeServiceWithRetry(
        'SearchController',
        () => search.SearchController.instance.initialize(),
      );
      
      await _initializeServiceWithRetry(
        'FavoritesController',
        () => FavoritesController.instance.initialize(),
      );
    } catch (e) {
      // Enregistrer l'erreur mais continuer
      ErrorLoggingService().error('main', 'Erreur initialisation contrôleurs', details: e);
      debugPrint('⚠️ Erreur initialisation contrôleurs: $e');
    }

    // Configurer le widget d'erreur personnalisé
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Enregistrer l'erreur
      ErrorLoggingService().critical(
        'ErrorWidget', 
        'Erreur de rendu widget: ${details.exception}',
        details: details.exception,
        stackTrace: details.stack,
      );
      
      // Retourner un widget d'erreur personnalisé
      return Material(
        color: Colors.red.shade100,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 8),
                Text(
                  'Une erreur est survenue',
                  style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'L\'application tente de récupérer...',
                  style: TextStyle(color: Colors.red.shade900),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Tenter de reconstruire le widget
                    (details.context as Element?)?.markNeedsBuild();
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    };

    runApp(const HordMapsApp());
  }, (error, stack) {
    // Capture des erreurs non gérées au niveau de la zone
    debugPrint('🚨 ERREUR NON GÉRÉE: $error');
    debugPrint('Stack trace: $stack');
    
    // Enregistrer dans le service de logging si disponible
    try {
      ErrorLoggingService().critical(
        'ZoneError', 
        'Erreur non gérée: $error',
        details: error,
        stackTrace: stack,
      );
    } catch (_) {}
    
    // Enregistrer dans le service de récupération si disponible
    try {
      AutoRecoveryService().reportError('ZoneError', error);
    } catch (_) {}
  });
}

/// Initialise un service avec retry en cas d'échec
Future<void> _initializeServiceWithRetry(
  String serviceName,
  Future<void> Function() initFunction, {
  int maxRetries = 3,
}) async {
  int retryCount = 0;
  
  while (retryCount < maxRetries) {
    try {
      await initFunction();
      debugPrint('✅ $serviceName initialisé avec succès');
      return;
    } catch (e) {
      retryCount++;
      final errorMsg = 'Échec initialisation $serviceName (tentative $retryCount/$maxRetries): $e';
      debugPrint('⚠️ $errorMsg');
      
      // Enregistrer l'erreur
      try {
        ErrorLoggingService().warning('ServiceInit', errorMsg, details: e);
      } catch (_) {}
      
      if (retryCount < maxRetries) {
        // Attendre avant de réessayer avec backoff exponentiel
        final waitTime = Duration(milliseconds: 500 * (1 << retryCount));
        debugPrint('⏱️ Nouvelle tentative dans ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      } else {
        // Échec après toutes les tentatives
        throw Exception('Échec initialisation $serviceName après $maxRetries tentatives: $e');
      }
    }
  }
}

class HordMapsApp extends StatelessWidget {
  const HordMapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Contrôleurs MVC
        ChangeNotifierProvider(create: (_) => AppController.instance),
        ChangeNotifierProvider(create: (_) => RouteController.instance),
        ChangeNotifierProvider(create: (_) => search.SearchController.instance),
        ChangeNotifierProvider(create: (_) => FavoritesController.instance),

        // Providers existants
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => CacheService.instance),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => CrashProofLocationService()),
        ChangeNotifierProvider(create: (_) => CompleteMapLayerService()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = NavigationProvider();
            // Initialisation différée après le build complet
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Connecter NavigationProvider à AppController
              AppController.instance.setNavigationProvider(provider);

              provider.initialize().catchError((e) {
                debugPrint('Erreur initialisation NavigationProvider: $e');
              });
            });
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => POIService()),
        ChangeNotifierProvider(create: (_) => OfflineService(StorageService())),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => MaterialApp(
          title: 'HordMaps',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: themeProvider.themeMode,

          // Routes pour l'architecture MVC
          routes: {
            '/route-search': (context) => const RouteSearchView(),
            '/navigation': (context) => const NavigationView(),
          },

          home: FutureBuilder<bool>(
            future: _checkUserProfile(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final hasProfile = snapshot.data ?? false;
              return hasProfile
                  ? const MainNavigationScreen()
                  : const UserSetupScreen();
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _checkUserProfile() async {
    return await UserService.instance.hasUserProfile();
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      primaryColor: const Color(0xFF4CAF50),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF4CAF50),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
