import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isSystemMode = true;

  ThemeMode get themeMode => _themeMode;
  bool get isSystemMode => _isSystemMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;

  ThemeProvider() {
    _loadThemeMode();
  }

  /// Charge le mode de thème depuis les préférences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;

      switch (themeIndex) {
        case 0:
          _themeMode = ThemeMode.system;
          _isSystemMode = true;
          break;
        case 1:
          _themeMode = ThemeMode.light;
          _isSystemMode = false;
          break;
        case 2:
          _themeMode = ThemeMode.dark;
          _isSystemMode = false;
          break;
      }

      notifyListeners();
    } catch (e) {
      print('Erreur lors du chargement du thème: $e');
    }
  }

  /// Sauvegarde le mode de thème dans les préférences
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int themeIndex;

      switch (_themeMode) {
        case ThemeMode.system:
          themeIndex = 0;
          break;
        case ThemeMode.light:
          themeIndex = 1;
          break;
        case ThemeMode.dark:
          themeIndex = 2;
          break;
      }

      await prefs.setInt(_themeKey, themeIndex);
    } catch (e) {
      print('Erreur lors de la sauvegarde du thème: $e');
    }
  }

  /// Définit le mode de thème système
  Future<void> setSystemMode() async {
    _themeMode = ThemeMode.system;
    _isSystemMode = true;
    notifyListeners();
    await _saveThemeMode();
  }

  /// Définit le mode clair
  Future<void> setLightMode() async {
    _themeMode = ThemeMode.light;
    _isSystemMode = false;
    notifyListeners();
    await _saveThemeMode();
  }

  /// Définit le mode sombre
  Future<void> setDarkMode() async {
    _themeMode = ThemeMode.dark;
    _isSystemMode = false;
    notifyListeners();
    await _saveThemeMode();
  }

  /// Alterne entre le mode clair et sombre
  Future<void> toggleTheme() async {
    if (_isSystemMode) {
      await setLightMode();
    } else if (_themeMode == ThemeMode.light) {
      await setDarkMode();
    } else {
      await setLightMode();
    }
  }

  /// Retourne l'icône appropriée pour le thème actuel
  IconData get themeIcon {
    switch (_themeMode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  /// Retourne le nom du thème actuel
  String get themeName {
    switch (_themeMode) {
      case ThemeMode.system:
        return 'Automatique (Système)';
      case ThemeMode.light:
        return 'Mode Clair';
      case ThemeMode.dark:
        return 'Mode Sombre';
    }
  }

  /// Affiche un sélecteur de thème
  static Future<void> showThemeSelector(BuildContext context) async {
    final themeProvider = context.read<ThemeProvider>();

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choisir un thème',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            _ThemeOption(
              title: 'Automatique (Système)',
              subtitle: 'Suit les paramètres du système',
              icon: Icons.brightness_auto,
              isSelected: themeProvider._themeMode == ThemeMode.system,
              onTap: () async {
                await themeProvider.setSystemMode();
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              title: 'Mode Clair',
              subtitle: 'Toujours en mode clair',
              icon: Icons.light_mode,
              isSelected: themeProvider._themeMode == ThemeMode.light,
              onTap: () async {
                await themeProvider.setLightMode();
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              title: 'Mode Sombre',
              subtitle: 'Toujours en mode sombre',
              icon: Icons.dark_mode,
              isSelected: themeProvider._themeMode == ThemeMode.dark,
              onTap: () async {
                await themeProvider.setDarkMode();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Widget pour afficher une option de thème
class _ThemeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).primaryColor : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
            : null,
        onTap: onTap,
      ),
    );
  }
}
