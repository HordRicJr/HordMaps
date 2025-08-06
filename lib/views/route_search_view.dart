import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../controllers/route_controller.dart';
import '../models/transport_models.dart';
import '../../shared/extensions/color_extensions.dart';

/// Vue MVC pour la recherche et configuration d'itinéraires
class RouteSearchView extends StatefulWidget {
  const RouteSearchView({super.key});

  @override
  State<RouteSearchView> createState() => _RouteSearchViewState();
}

class _RouteSearchViewState extends State<RouteSearchView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  bool _showOptions = false;
  RouteController? _routeController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _tabController = TabController(length: 2, vsync: this);

    // Initialisation différée
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _routeController = RouteController.instance;
        _routeController?.restoreState();
        _updateControllersFromState();
      }
    });
  }

  void _updateControllersFromState() {
    if (_routeController != null) {
      _startController.text = _routeController!.startAddress;
      _endController.text = _routeController!.endAddress;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            _buildSearchForm(context, isDark),
            if (_showOptions) _buildOptionsPanel(context, isDark),
            _buildTransportModeSelector(context, isDark),
            Expanded(child: _buildResultsArea(context, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recherche d\'itinéraire',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showOptions = !_showOptions;
              });
              if (_showOptions) {
                _animationController.forward();
              } else {
                _animationController.reverse();
              }
            },
            icon: AnimatedRotation(
              turns: _showOptions ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchForm(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLocationField(
            controller: _startController,
            hintText: 'Point de départ',
            icon: Icons.my_location,
            color: Colors.green,
            onTap: () => _selectLocation(true),
          ),
          const Divider(height: 1),
          _buildLocationField(
            controller: _endController,
            hintText: 'Destination',
            icon: Icons.location_on,
            color: Colors.red,
            onTap: () => _selectLocation(false),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _calculateRoute,
                    icon: const Icon(Icons.directions),
                    label: const Text('Calculer l\'itinéraire'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _swapLocations,
                  icon: const Icon(Icons.swap_vert),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withCustomOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    controller.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear, size: 20),
                )
              : null,
        ),
        onTap: onTap,
        onChanged: (value) => setState(() {}),
      ),
      trailing: IconButton(onPressed: onTap, icon: const Icon(Icons.search)),
    );
  }

  Widget _buildOptionsPanel(BuildContext context, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showOptions ? 200 : 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withCustomOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Consumer<RouteController>(
          builder: (context, controller, child) {
            final options = controller.currentOptions;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Options d\'itinéraire',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 8,
                      children: [
                        _buildOptionTile(
                          'Éviter les péages',
                          options.avoidTolls,
                          (value) => _updateOption(avoidTolls: value),
                        ),
                        _buildOptionTile(
                          'Éviter les autoroutes',
                          options.avoidHighways,
                          (value) => _updateOption(avoidHighways: value),
                        ),
                        _buildOptionTile(
                          'Éviter les ferries',
                          options.avoidFerries,
                          (value) => _updateOption(avoidFerries: value),
                        ),
                        _buildOptionTile(
                          'Route la plus courte',
                          options.shortestRoute,
                          (value) => _updateOption(shortestRoute: value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ).animate().slideY(begin: -1, end: 0).fadeIn();
  }

  Widget _buildOptionTile(String title, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF4CAF50),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _buildTransportModeSelector(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 100,
      child: Consumer<RouteController>(
        builder: (context, controller, child) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: TransportMode.allModes.length,
            itemBuilder: (context, index) {
              final mode = TransportMode.allModes[index];
              final isSelected =
                  controller.currentOptions.transportMode.id == mode.id;

              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                child: Material(
                  color: isSelected
                      ? mode.color
                      : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  elevation: 2,
                  child: InkWell(
                    onTap: () => controller.setTransportMode(mode),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            mode.icon,
                            color: isSelected ? Colors.white : mode.color,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mode.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().scale(delay: Duration(milliseconds: index * 50));
            },
          );
        },
      ),
    );
  }

  Widget _buildResultsArea(BuildContext context, bool isDark) {
    return Consumer<RouteController>(
      builder: (context, controller, child) {
        if (controller.isCalculating) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Calcul de l\'itinéraire en cours...'),
              ],
            ),
          );
        }

        if (controller.lastError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.withCustomOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Erreur',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  controller.lastError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _calculateRoute,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        if (controller.currentRoute != null) {
          return _buildRouteDetails(controller.currentRoute!, isDark);
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions,
                size: 64,
                color: Colors.grey.withCustomOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Recherchez un itinéraire',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Entrez un point de départ et une destination',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteDetails(dynamic route, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails de l\'itinéraire',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Ici vous pouvez ajouter les détails de la route
            // selon la structure de votre modèle RouteResult
            Text('Itinéraire calculé avec succès'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startNavigation,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Commencer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0).fadeIn();
  }

  void _selectLocation(bool isStart) async {
    // TODO: Implémenter la sélection de lieu
    // Peut utiliser SearchProvider pour chercher des lieux
  }

  void _calculateRoute() async {
    if (_routeController == null) return;

    // TODO: Convertir les adresses en coordonnées
    // puis appeler _routeController.calculateRoute()
  }

  void _swapLocations() {
    final temp = _startController.text;
    _startController.text = _endController.text;
    _endController.text = temp;

    _routeController?.reverseRoute();
  }

  void _updateOption({
    bool? avoidTolls,
    bool? avoidHighways,
    bool? avoidFerries,
    bool? shortestRoute,
  }) {
    if (_routeController == null) return;

    final newOptions = _routeController!.currentOptions.copyWith(
      avoidTolls: avoidTolls,
      avoidHighways: avoidHighways,
      avoidFerries: avoidFerries,
      shortestRoute: shortestRoute,
    );

    _routeController!.updateRouteOptions(newOptions);
  }

  void _startNavigation() {
    // TODO: Implémenter le démarrage de la navigation
    Navigator.of(context).pushNamed('/navigation');
  }
}
