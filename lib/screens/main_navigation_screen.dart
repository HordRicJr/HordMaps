import 'package:flutter/material.dart';
import '../../shared/extensions/color_extensions.dart';

import 'modern_home_page.dart';
import 'route_search_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../services/navigation_notification_service.dart';
import '../shared/services/fluid_navigation_service.dart';

/// Écran principal avec navigation entre les onglets
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop =
            await NavigationNotificationService.showExitConfirmation(context);

        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: FluidTabTransition(
          currentIndex: _selectedIndex,
          children: const [
            // Accueil
            ModernHomePage(),
            // Itinéraire
            RouteSearchScreen(),
            // Favoris
            FavoritesScreen(),
            // Profil
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withCustomOpacity(0.3)
                    : Colors.grey.withCustomOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: const Color(0xFF4CAF50),
            unselectedItemColor: isDark
                ? const Color(0xFF9E9E9E)
                : const Color(0xFF757575),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Accueil',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.directions_rounded),
                label: 'Itinéraire',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_rounded),
                label: 'Favoris',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
        appBar: _selectedIndex == 3 ? _buildProfileAppBar() : null,
      ),
    );
  }

  AppBar _buildProfileAppBar() {
    return AppBar(
      title: const Text('Profil'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            FluidNavigationService.navigateTo(
              context,
              const SettingsScreen(),
              transition: NavigationTransition.slideFromRight,
            );
          },
        ),
      ],
    );
  }
}

/// Onglet d'accueil modifié pour être intégré dans la navigation
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _departController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _departController.dispose();
    _arrivalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernHomePage();
  }
}
