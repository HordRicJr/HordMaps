import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings/map_customization_screen.dart';
import '../help/help_screen.dart';
import '../theme/theme_provider.dart';
import '../../shared/services/map_customization_service.dart';
import '../../features/notifications/notification_provider.dart';
import '../../services/user_service.dart';
import '../../../shared/extensions/color_extensions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _offlineModeEnabled = false;
  bool _hapticFeedbackEnabled = true;
  bool _animationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoDownloadEnabled = false;
  String _language = 'Français';
  String _units = 'Métrique';
  String _mapStyle = 'Standard';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Charger les paramètres depuis le stockage local
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _locationEnabled = prefs.getBool('location_enabled') ?? true;
        _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
        _autoDownloadEnabled = prefs.getBool('auto_download_enabled') ?? false;
        _mapStyle = prefs.getString('map_style') ?? 'Standard';
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des paramètres: $e');
    }
  }

  Future<void> _saveSettings() async {
    // Sauvegarder les paramètres dans le stockage local
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('location_enabled', _locationEnabled);
      await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
      await prefs.setBool('auto_download_enabled', _autoDownloadEnabled);
      await prefs.setString('map_style', _mapStyle);
      await prefs.setString('language', _language);
      await prefs.setString('units', _units);
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde des paramètres: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres'), elevation: 0),
      body: ListView(
        children: [
          _buildSection('Affichage', Icons.display_settings, [
            _buildThemeSelector(),
            _buildSwitchTile(
              'Animations',
              'Animations fluides de l\'interface',
              Icons.animation,
              _animationsEnabled,
              (value) {
                setState(() {
                  _animationsEnabled = value;
                });
                _saveSettings();
              },
            ),
            _buildNavigationTile(
              'Personnaliser la carte',
              'Styles, couleurs et marqueurs',
              Icons.palette,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MapCustomizationScreen(),
                  ),
                );
              },
            ),
          ]),

          _buildSection('Localisation', Icons.location_on, [
            _buildSwitchTile(
              'Services de localisation',
              'Autoriser l\'accès à votre position',
              Icons.my_location,
              _locationEnabled,
              (value) {
                setState(() {
                  _locationEnabled = value;
                });
                _saveSettings();
              },
            ),
            _buildDropdownTile(
              'Unités',
              'Système de mesure',
              Icons.straighten,
              _units,
              ['Métrique', 'Impérial'],
              (value) {
                setState(() {
                  _units = value;
                });
                _saveSettings();
              },
            ),
          ]),

          _buildSection('Notifications', Icons.notifications, [
            _buildSwitchTile(
              'Notifications',
              'Alertes et informations',
              Icons.notifications_outlined,
              _notificationsEnabled,
              (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _saveSettings();
              },
            ),
            _buildSwitchTile(
              'Retour haptique',
              'Vibrations lors des interactions',
              Icons.vibration,
              _hapticFeedbackEnabled,
              (value) {
                setState(() {
                  _hapticFeedbackEnabled = value;
                });
                _saveSettings();
              },
            ),
          ]),

          _buildSection('Données', Icons.storage, [
            _buildSwitchTile(
              'Mode hors ligne',
              'Utiliser les cartes en cache',
              Icons.offline_bolt,
              _offlineModeEnabled,
              (value) {
                setState(() {
                  _offlineModeEnabled = value;
                });
                _saveSettings();
              },
            ),
            _buildNavigationTile(
              'Gérer le cache',
              'Vider les données temporaires',
              Icons.cleaning_services,
              () => _showClearCacheDialog(),
            ),
            _buildNavigationTile(
              'Exporter les données',
              'Sauvegarder favoris et historique',
              Icons.download,
              () => _exportData(),
            ),
            _buildNavigationTile(
              'Importer les données',
              'Restaurer favoris et historique',
              Icons.upload,
              () => _importData(),
            ),
          ]),

          _buildSection('Général', Icons.settings, [
            _buildDropdownTile(
              'Langue',
              'Langue de l\'interface',
              Icons.language,
              _language,
              ['Français', 'English', 'Español', 'Deutsch'],
              (value) {
                setState(() {
                  _language = value;
                });
                _saveSettings();
              },
            ),
            _buildNavigationTile(
              'Aide et raccourcis',
              'Guide d\'utilisation',
              Icons.help_outline,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              },
            ),
          ]),

          _buildSection('À propos', Icons.info, [
            _buildNavigationTile(
              'Version de l\'application',
              'HordMaps v1.0.0',
              Icons.phone_android,
              () => _showVersionInfo(),
            ),
            _buildNavigationTile(
              'Licences',
              'Licences des composants',
              Icons.description,
              () => _showLicenses(),
            ),
            _buildNavigationTile(
              'Politique de confidentialité',
              'Protection de vos données',
              Icons.privacy_tip,
              () => _showPrivacyPolicy(),
            ),
          ]),

          const SizedBox(height: 32),

          // Bouton de réinitialisation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _showResetDialog(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réinitialiser tous les paramètres'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      secondary: Icon(icon),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildNavigationTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(icon),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    IconData icon,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(icon),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
        items: options.map((option) {
          return DropdownMenuItem<String>(value: option, child: Text(option));
        }).toList(),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le cache'),
        content: const Text(
          'Cette action supprimera toutes les données temporaires '
          'et les cartes hors ligne. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final notificationProvider = context.read<NotificationProvider>();

              if (mounted) {
                navigator.pop();
              }
              await _clearCache();
              if (mounted) {
                notificationProvider.showSuccess(
                  'Cache vidé',
                  'Les données temporaires ont été supprimées',
                );
              }
            },
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    // Nettoyage du cache implémenté
    try {
      final prefs = await SharedPreferences.getInstance();
      // Nettoyer le cache des cartes offline
      await prefs.remove('offline_maps_cache');
      // Nettoyer d'autres données de cache selon les besoins
      await prefs.remove('recent_searches');
      await prefs.remove('cached_weather_data');
      // Simulation d'un nettoyage qui prend du temps
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Erreur lors du nettoyage du cache: $e');
    }
  }

  Future<void> _exportData() async {
    try {
      final userService = UserService.instance;
      final userData = await userService.getUserProfile();
      final userStats = await userService.getUserStats();

      // Créer le contenu d'export
      final favorites = await _getFavorites();
      final history = await _getHistory();

      final exportData = {
        'version': '1.0.0',
        'timestamp': DateTime.now().toIso8601String(),
        'profile': userData,
        'stats': userStats,
        'favorites': favorites,
        'history': history,
      };

      // Partager les données
      await SharePlus.instance.share(
        ShareParams(
          text: 'Mes données HordMaps:\n${exportData.toString()}',
          subject: 'Export HordMaps',
        ),
      );
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Données HordMaps exportées le ${DateTime.now().toLocal()}\n'
              'Profil: ${userData['name'] ?? 'Utilisateur'}\n'
              'Email: ${userData['email'] ?? 'Non défini'}\n'
              'Données complètes en JSON disponibles.',
          subject: 'Export HordMaps - ${userData['name'] ?? 'Utilisateur'}',
        ),
      );

      if (mounted) {
        context.read<NotificationProvider>().showSuccess(
          'Export réussi',
          'Vos données ont été préparées pour le partage',
        );
      }
    } catch (e) {
      if (mounted) {
        context.read<NotificationProvider>().showError(
          'Erreur d\'export',
          'Impossible d\'exporter les données: $e',
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getFavorites() async {
    // Récupérer les favoris depuis le stockage local
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList('favorites') ?? [];
      return favoritesJson
          .map(
            (f) => {
              'location': f,
              'timestamp': DateTime.now().toIso8601String(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des favoris: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getHistory() async {
    // Récupérer l'historique depuis le stockage local
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('search_history') ?? [];
      return historyJson
          .map(
            (h) => {'search': h, 'timestamp': DateTime.now().toIso8601String()},
          )
          .toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération de l\'historique: $e');
      return [];
    }
  }

  Future<void> _importData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer des données'),
        content: const Text(
          'Cette fonctionnalité permet d\'importer des données précédemment exportées.\n\n'
          'Prochainement disponible: sélection de fichiers et restauration automatique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                context.read<NotificationProvider>().showInfo(
                  'Fonctionnalité en cours',
                  'Import de données bientôt disponible',
                );
              }
            },
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _showVersionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HordMaps'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            Text('Build: 100'),
            Text('Flutter: 3.8.1'),
            SizedBox(height: 16),
            Text('Application de navigation basée sur OpenStreetMap'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'HordMaps',
      applicationVersion: '1.0.0',
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Politique de confidentialité'),
        content: const SingleChildScrollView(
          child: Text(
            'Cette application respecte votre vie privée.\n\n'
            '• Aucune donnée personnelle n\'est collectée sans votre autorisation\n'
            '• Les données de localisation sont utilisées uniquement pour les fonctionnalités de navigation\n'
            '• Vos favoris et historique sont stockés localement sur votre appareil\n'
            '• Aucune donnée n\'est partagée avec des tiers\n\n'
            'Pour plus d\'informations, consultez notre politique complète sur notre site web.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser'),
        content: const Text(
          'Cette action remettra tous les paramètres à leurs valeurs par défaut. '
          'Vos favoris et historique seront conservés. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final notificationProvider = context.read<NotificationProvider>();

              if (mounted) {
                navigator.pop();
              }
              await _resetSettings();
              if (mounted) {
                notificationProvider.showSuccess(
                  'Paramètres réinitialisés',
                  'Tous les paramètres ont été remis par défaut',
                );
              }
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSettings() async {
    setState(() {
      _notificationsEnabled = true;
      _locationEnabled = true;
      _offlineModeEnabled = false;
      _hapticFeedbackEnabled = true;
      _animationsEnabled = true;
      _language = 'Français';
      _units = 'Métrique';
    });

    // Réinitialiser aussi la personnalisation de la carte
    final customizationProvider = context.read<MapCustomizationProvider>();
    await customizationProvider.resetToDefault();

    await _saveSettings();
  }

  /// Construit le sélecteur de thème
  Widget _buildThemeSelector() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withCustomOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            themeProvider.themeIcon,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
        ),
        title: const Text('Thème de l\'application'),
        subtitle: Text(themeProvider.themeName),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).primaryColor,
        ),
        onTap: () => ThemeProvider.showThemeSelector(context),
      ),
    );
  }
}
