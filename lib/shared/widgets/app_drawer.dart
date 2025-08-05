import 'package:flutter/material.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/offline/offline_map_screen.dart';
import '../../features/traffic/traffic_stats_screen.dart';
import 'app_actions.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context),
          _buildMenuItem(
            context,
            Icons.map,
            'Carte',
            'Affichage principal',
            () => Navigator.pop(context),
            isActive: true,
          ),

          const Divider(),

          _buildMenuItem(
            context,
            Icons.search,
            'Recherche',
            'Trouver un lieu',
            () {
              Navigator.pop(context);
              AppActions.openSearch(context);
            },
          ),

          _buildMenuItem(
            context,
            Icons.navigation,
            'Navigation',
            'Calculer un itinéraire',
            () {
              Navigator.pop(context);
              AppActions.openNavigation(context);
            },
          ),

          _buildMenuItem(
            context,
            Icons.favorite,
            'Favoris',
            'Lieux sauvegardés',
            () {
              Navigator.pop(context);
              AppActions.openFavorites(context);
            },
          ),

          const Divider(),

          _buildMenuItem(
            context,
            Icons.straighten,
            'Mesurer',
            'Distance et surface',
            () {
              Navigator.pop(context);
              AppActions.toggleMeasurement(context);
            },
          ),

          _buildMenuItem(
            context,
            Icons.share,
            'Partager',
            'Position ou itinéraire',
            () {
              Navigator.pop(context);
              AppActions.openShare(context);
            },
          ),

          _buildMenuItem(context, Icons.explore, 'Boussole', 'Orientation', () {
            Navigator.pop(context);
            AppActions.toggleCompass(context);
          }),

          const Divider(),

          _buildMenuItem(
            context,
            Icons.layers,
            'Styles de carte',
            'Personnaliser l\'affichage',
            () {
              Navigator.pop(context);
              AppActions.openMapStyles(context);
            },
          ),

          _buildMenuItem(
            context,
            Icons.my_location,
            'Ma position',
            'Centrer sur ma position',
            () {
              Navigator.pop(context);
              AppActions.centerLocation(context);
            },
          ),

          const Divider(),

          _buildMenuItem(
            context,
            Icons.offline_pin,
            'Cartes hors ligne',
            'Télécharger pour usage offline',
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OfflineMapScreen(),
                ),
              );
            },
          ),

          _buildMenuItem(
            context,
            Icons.traffic,
            'Analyse du trafic',
            'Conditions de circulation',
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrafficStatsScreen(),
                ),
              );
            },
          ),

          const Divider(),

          _buildMenuItem(
            context,
            Icons.settings,
            'Paramètres',
            'Configuration',
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),

          _buildMenuItem(
            context,
            Icons.help_outline,
            'Aide',
            'Guide et raccourcis',
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
            },
          ),

          const SizedBox(height: 16),

          // Informations basiques
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'HordMaps v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Navigation basée sur OpenStreetMap',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.map, size: 48, color: Colors.white),
          const SizedBox(height: 8),
          const Text(
            'HordMaps',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Navigation intelligente',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          const Text(
            'Application de navigation',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isActive = false,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isActive
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Theme.of(context).primaryColor : null,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : null,
            color: isActive ? Theme.of(context).primaryColor : null,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
