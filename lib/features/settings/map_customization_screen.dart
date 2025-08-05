import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/services/map_customization_service.dart';

class MapCustomizationScreen extends StatefulWidget {
  const MapCustomizationScreen({super.key});

  @override
  State<MapCustomizationScreen> createState() => _MapCustomizationScreenState();
}

class _MapCustomizationScreenState extends State<MapCustomizationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Personnalisation'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Style'),
            Tab(icon: Icon(Icons.palette), text: 'Couleurs'),
            Tab(icon: Icon(Icons.settings), text: 'Options'),
            Tab(icon: Icon(Icons.animation), text: 'Animation'),
          ],
        ),
      ),
      body: Consumer<MapCustomizationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildStyleTab(provider),
              _buildColorsTab(provider),
              _buildOptionsTab(provider),
              _buildAnimationTab(provider),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showResetDialog(context),
        icon: const Icon(Icons.refresh),
        label: const Text('Réinitialiser'),
      ),
    );
  }

  Widget _buildStyleTab(MapCustomizationProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Style de carte',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...MapStyle.values.map(
          (style) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<MapStyle>(
              title: Text(style.name),
              subtitle: Text(_getStyleDescription(style)),
              value: style,
              groupValue: provider.configuration.style,
              onChanged: (value) {
                if (value != null) {
                  provider.updateMapStyle(value);
                }
              },
              secondary: Icon(_getStyleIcon(style)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Type de marqueur',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...MarkerType.values.map(
          (type) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<MarkerType>(
              title: Text(type.name),
              value: type,
              groupValue: provider.configuration.markerType,
              onChanged: (value) {
                if (value != null) {
                  provider.updateMarkerType(value);
                }
              },
              secondary: Icon(type.icon),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Taille des marqueurs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Petite'),
                    Text('${provider.configuration.markerSize.round()}px'),
                    const Text('Grande'),
                  ],
                ),
                Slider(
                  value: provider.configuration.markerSize,
                  min: 20,
                  max: 80,
                  divisions: 12,
                  onChanged: (value) {
                    provider.updateMarkerSize(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorsTab(MapCustomizationProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Couleurs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Couleur principale'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      [
                            Colors.blue,
                            Colors.green,
                            Colors.red,
                            Colors.purple,
                            Colors.orange,
                            Colors.teal,
                            Colors.indigo,
                            Colors.pink,
                          ]
                          .map(
                            (color) => GestureDetector(
                              onTap: () {
                                provider.updateColors(primaryColor: color);
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border:
                                      provider.configuration.primaryColor ==
                                          color
                                      ? Border.all(
                                          color: Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Couleur d\'accent'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      [
                            Colors.orange,
                            Colors.amber,
                            Colors.yellow,
                            Colors.lime,
                            Colors.cyan,
                            Colors.deepOrange,
                            Colors.pinkAccent,
                            Colors.purpleAccent,
                          ]
                          .map(
                            (color) => GestureDetector(
                              onTap: () {
                                provider.updateColors(accentColor: color);
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border:
                                      provider.configuration.accentColor ==
                                          color
                                      ? Border.all(
                                          color: Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsTab(MapCustomizationProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Options d\'affichage',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Afficher le trafic'),
                subtitle: const Text(
                  'Indicateurs de circulation en temps réel',
                ),
                value: provider.configuration.showTraffic,
                onChanged: (value) {
                  provider.updateDisplayOptions(showTraffic: value);
                },
                secondary: const Icon(Icons.traffic),
              ),
              SwitchListTile(
                title: const Text('Afficher les transports'),
                subtitle: const Text('Stations et lignes de transport public'),
                value: provider.configuration.showTransit,
                onChanged: (value) {
                  provider.updateDisplayOptions(showTransit: value);
                },
                secondary: const Icon(Icons.train),
              ),
              SwitchListTile(
                title: const Text('Mode 3D'),
                subtitle: const Text('Affichage en relief des bâtiments'),
                value: provider.configuration.show3D,
                onChanged: (value) {
                  provider.updateDisplayOptions(show3D: value);
                },
                secondary: const Icon(Icons.view_in_ar),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimationTab(MapCustomizationProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Paramètres d\'animation',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Vitesse d\'animation'),
                    Text(
                      '${(provider.configuration.animationSpeed * 100).round()}%',
                    ),
                  ],
                ),
                Slider(
                  value: provider.configuration.animationSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  onChanged: (value) {
                    provider.updateAnimationSettings(animationSpeed: value);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Rotation activée'),
                subtitle: const Text('Permettre la rotation de la carte'),
                value: provider.configuration.enableRotation,
                onChanged: (value) {
                  provider.updateAnimationSettings(enableRotation: value);
                },
                secondary: const Icon(Icons.rotate_right),
              ),
              SwitchListTile(
                title: const Text('Inclinaison activée'),
                subtitle: const Text('Permettre l\'inclinaison de la carte'),
                value: provider.configuration.enableTilt,
                onChanged: (value) {
                  provider.updateAnimationSettings(enableTilt: value);
                },
                secondary: const Icon(Icons.threed_rotation),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStyleDescription(MapStyle style) {
    switch (style) {
      case MapStyle.standard:
        return 'Carte classique avec détails complets';
      case MapStyle.dark:
        return 'Thème sombre pour la nuit';
      case MapStyle.satellite:
        return 'Images satellite haute résolution';
      case MapStyle.terrain:
        return 'Relief et topographie détaillés';
      case MapStyle.cycling:
        return 'Optimisé pour les cyclistes';
    }
  }

  IconData _getStyleIcon(MapStyle style) {
    switch (style) {
      case MapStyle.standard:
        return Icons.map;
      case MapStyle.dark:
        return Icons.nights_stay;
      case MapStyle.satellite:
        return Icons.satellite_alt;
      case MapStyle.terrain:
        return Icons.terrain;
      case MapStyle.cycling:
        return Icons.pedal_bike;
    }
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser'),
        content: const Text(
          'Voulez-vous remettre tous les paramètres par défaut ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              context.read<MapCustomizationProvider>().resetToDefault();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paramètres réinitialisés')),
              );
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }
}
