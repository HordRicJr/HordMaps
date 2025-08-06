import 'package:flutter/material.dart';
import '../../shared/services/shortcut_service.dart';
import '../../../shared/extensions/color_extensions.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.keyboard), text: 'Raccourcis'),
            Tab(icon: Icon(Icons.touch_app), text: 'Gestes'),
            Tab(icon: Icon(Icons.help_outline), text: 'Guide'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildShortcutsTab(), _buildGesturesTab(), _buildGuideTab()],
      ),
    );
  }

  Widget _buildShortcutsTab() {
    final shortcuts = ShortcutService.getAllShortcuts();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Raccourcis clavier',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Utilisez ces raccourcis pour naviguer plus rapidement',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 24),
        ...shortcuts.entries.map((entry) {
          final action = entry.key;
          final actionShortcuts = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getActionIcon(action),
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getActionTitle(action),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...actionShortcuts.map(
                    (shortcut) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).chipTheme.backgroundColor ??
                                  Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ShortcutService.formatKeySet(shortcut.keySet),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              shortcut.description,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          if (!shortcut.isEnabled)
                            Icon(
                              Icons.block,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGesturesTab() {
    final gestures = ShortcutService.getAllGestures();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Gestes tactiles',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Gestes disponibles pour contrôler la carte',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 24),
        ...gestures.entries.map((entry) {
          final action = entry.key;
          final actionGestures = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getActionIcon(action),
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getActionTitle(action),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...actionGestures.map(
                    (gesture) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            _getGestureIcon(gesture.type),
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              gesture.description,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          if (!gesture.isEnabled)
                            Icon(
                              Icons.block,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGuideTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Guide d\'utilisation',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        _buildGuideSection('Navigation de base', Icons.map, [
          'Glissez pour déplacer la carte',
          'Pincez pour zoomer/dézoomer',
          'Double-tap pour zoomer rapidement',
          'Appui long pour ajouter un marqueur',
        ]),

        _buildGuideSection('Recherche', Icons.search, [
          'Tapez une adresse dans la barre de recherche',
          'Sélectionnez un résultat dans la liste',
          'Les recherches récentes sont sauvegardées',
          'Utilisez "Ctrl+F" ou "S" pour ouvrir la recherche',
        ]),

        _buildGuideSection('Navigation', Icons.navigation, [
          'Appuyez sur "Itinéraire" pour calculer un chemin',
          'Choisissez votre mode de transport',
          'Suivez les instructions vocales',
          'Appuyez sur "N" pour démarrer la navigation',
        ]),

        _buildGuideSection('Favoris', Icons.favorite, [
          'Appui long sur un lieu pour l\'ajouter aux favoris',
          'Accédez à vos favoris via le menu principal',
          'Organisez vos favoris par catégories',
          'Partagez vos lieux favoris avec vos contacts',
        ]),

        _buildGuideSection('Mesures', Icons.straighten, [
          'Activez l\'outil de mesure (touche "R")',
          'Touchez les points pour mesurer la distance',
          'Double-tap pour terminer la mesure',
          'Les résultats s\'affichent en temps réel',
        ]),

        _buildGuideSection('Partage', Icons.share, [
          'Partagez votre position actuelle',
          'Générez un QR code pour un lieu',
          'Envoyez un lien vers un itinéraire',
          'Exportez vos favoris',
        ]),

        _buildGuideSection('Personnalisation', Icons.palette, [
          'Changez le style de carte (touche "M")',
          'Modifiez les couleurs et marqueurs',
          'Ajustez les paramètres d\'animation',
          'Configurez vos préférences',
        ]),

        const SizedBox(height: 32),
        Card(
          color: Theme.of(context).primaryColor.withCustomOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: Theme.of(context).primaryColor,
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Astuce',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Maintenez enfoncé n\'importe quel bouton pour voir '
                  'une description de sa fonction.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideSection(String title, IconData icon, List<String> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 8, right: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon(ActionType action) {
    switch (action) {
      case ActionType.zoomIn:
      case ActionType.zoomOut:
        return Icons.zoom_in;
      case ActionType.centerLocation:
        return Icons.my_location;
      case ActionType.toggleMapStyle:
        return Icons.layers;
      case ActionType.search:
        return Icons.search;
      case ActionType.addFavorite:
        return Icons.favorite;
      case ActionType.openMenu:
        return Icons.menu;
      case ActionType.navigation:
        return Icons.navigation;
      case ActionType.measure:
        return Icons.straighten;
      case ActionType.share:
        return Icons.share;
    }
  }

  String _getActionTitle(ActionType action) {
    switch (action) {
      case ActionType.zoomIn:
        return 'Zoomer';
      case ActionType.zoomOut:
        return 'Dézoomer';
      case ActionType.centerLocation:
        return 'Centrer la position';
      case ActionType.toggleMapStyle:
        return 'Changer le style';
      case ActionType.search:
        return 'Rechercher';
      case ActionType.addFavorite:
        return 'Ajouter aux favoris';
      case ActionType.openMenu:
        return 'Ouvrir le menu';
      case ActionType.navigation:
        return 'Navigation';
      case ActionType.measure:
        return 'Mesurer';
      case ActionType.share:
        return 'Partager';
    }
  }

  IconData _getGestureIcon(GestureType gesture) {
    switch (gesture) {
      case GestureType.tap:
        return Icons.touch_app;
      case GestureType.doubleTap:
        return Icons.double_arrow;
      case GestureType.longPress:
        return Icons.timer;
      case GestureType.pinch:
        return Icons.pinch;
      case GestureType.pan:
        return Icons.pan_tool;
      case GestureType.rotate:
        return Icons.rotate_right;
    }
  }
}
