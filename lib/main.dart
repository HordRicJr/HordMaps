import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
import 'shared/services/poi_service.dart';
import 'shared/services/offline_service.dart';
import 'shared/services/storage_service.dart';
import 'screens/user_setup_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'views/route_search_view.dart';
import 'views/navigation_view.dart';

void main() async {
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

  // Initialisation des services
  await UserService.instance.initialize();
  await CacheService.initialize();

  // Initialiser le storage service
  await StorageService.initialize();

  // Initialiser l'AppController MVC
  await AppController.instance.initializeApp();

  // Initialiser les autres contrôleurs MVC
  await search.SearchController.instance.initialize();
  await FavoritesController.instance.initialize();

  runApp(const HordMapsApp());
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
