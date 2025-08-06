import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'route_navigation_page.dart';
import '../../shared/extensions/color_extensions.dart';

class RouteSearchScreen extends StatefulWidget {
  final String? initialDeparture;
  final String? initialDestination;

  const RouteSearchScreen({
    super.key,
    this.initialDeparture,
    this.initialDestination,
  });

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  String _selectedTransportMode = 'car';
  bool _isLoading = false;
  Position? _currentPosition;
  LatLng? _selectedDeparture;
  LatLng? _selectedDestination;
  List<Map<String, dynamic>> _departureSuggestions = [];
  List<Map<String, dynamic>> _destinationSuggestions = [];

  @override
  void initState() {
    super.initState();
    _departureController.text = widget.initialDeparture ?? '';
    _destinationController.text = widget.initialDestination ?? '';
    _getCurrentPosition();
    _generateSuggestions();
  }

  Future<void> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition();
      setState(() {});
    } catch (e) {
      debugPrint('Erreur géolocalisation: $e');
    }
  }

  void _generateSuggestions() {
    // Suggestions basées sur la position actuelle ou des lieux communs
    final commonPlaces = [
      {
        'name': 'Ma position actuelle',
        'description': 'Utiliser votre position actuelle',
        'icon': Icons.my_location,
        'position': _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
        'isCurrentLocation': true,
      },
      {
        'name': 'Centre-ville',
        'description': 'Centre de la ville',
        'icon': Icons.location_city,
        'position': const LatLng(48.8566, 2.3522), // Paris par défaut
      },
      {
        'name': 'Aéroport',
        'description': 'Aéroport principal',
        'icon': Icons.flight,
        'position': const LatLng(49.0097, 2.5479), // CDG
      },
      {
        'name': 'Gare centrale',
        'description': 'Gare principale',
        'icon': Icons.train,
        'position': const LatLng(48.8449, 2.3738), // Gare du Nord
      },
      {
        'name': 'Hôpital principal',
        'description': 'Centre hospitalier',
        'icon': Icons.local_hospital,
        'position': const LatLng(48.8534, 2.3488),
      },
    ];

    _departureSuggestions = commonPlaces;
    _destinationSuggestions = commonPlaces;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Recherche d\'itinéraire',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Fields
            _buildSearchSection(isDark).animate().fadeIn().slideY(),

            const SizedBox(height: 24),

            // Transport Mode Selection
            _buildTransportModeSection(
              isDark,
            ).animate().fadeIn(delay: 200.ms).slideY(),

            const SizedBox(height: 24),

            // Quick Options
            _buildQuickOptionsSection(
              isDark,
            ).animate().fadeIn(delay: 400.ms).slideY(),

            const SizedBox(height: 32),

            // Search Button
            _buildSearchButton(isDark).animate().fadeIn(delay: 600.ms).scale(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Departure Field
          _buildSearchField(
            controller: _departureController,
            label: 'Départ',
            icon: Icons.my_location,
            hint: 'Votre position actuelle',
            onSuffixTap: () => _setCurrentLocation(_departureController),
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // Swap Button
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withCustomOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _swapLocations,
                icon: const Icon(Icons.swap_vert, color: Color(0xFF4CAF50)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Destination Field
          _buildSearchField(
            controller: _destinationController,
            label: 'Destination',
            icon: Icons.location_on,
            hint: 'Où voulez-vous aller ?',
            onSuffixTap: () => _selectFromMap(_destinationController),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required VoidCallback onSuffixTap,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onTap: () => _showLocationPicker(controller, label),
          readOnly: true,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onSuffixTap,
                  icon: Icon(
                    label == 'Départ' ? Icons.gps_fixed : Icons.map,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                IconButton(
                  onPressed: () => _showLocationPicker(controller, label),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF8F8F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransportModeSection(bool isDark) {
    final transportModes = [
      {'id': 'car', 'label': 'Voiture', 'icon': Icons.directions_car},
      {'id': 'walk', 'label': 'À pied', 'icon': Icons.directions_walk},
      {'id': 'bike', 'label': 'Vélo', 'icon': Icons.directions_bike},
      {'id': 'transit', 'label': 'Transport', 'icon': Icons.directions_transit},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mode de transport',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: transportModes.map((mode) {
              final isSelected = _selectedTransportMode == mode['id'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                    () => _selectedTransportMode = mode['id'] as String,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4CAF50)
                          : (isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFF0F0F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          mode['icon'] as IconData,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mode['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOptionsSection(bool isDark) {
    final quickOptions = [
      {'label': 'Éviter les péages', 'value': false},
      {'label': 'Route la plus rapide', 'value': true},
      {'label': 'Éviter les autoroutes', 'value': false},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Options de route',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...quickOptions
              .map(
                (option) => CheckboxListTile(
                  title: Text(
                    option['label'] as String,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  value: option['value'] as bool,
                  onChanged: (value) {
                    // Implement option toggle
                  },
                  activeColor: const Color(0xFF4CAF50),
                  contentPadding: EdgeInsets.zero,
                ),
              )
              ,
        ],
      ),
    );
  }

  Widget _buildSearchButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _searchRoute,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Rechercher l\'itinéraire',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  void _setCurrentLocation(TextEditingController controller) {
    if (_currentPosition != null) {
      controller.text = 'Ma position actuelle';
      if (controller == _departureController) {
        _selectedDeparture = LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      } else {
        _selectedDestination = LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position actuelle définie'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position non disponible'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLocationPicker(TextEditingController controller, String label) {
    final suggestions = label == 'Départ'
        ? _departureSuggestions
        : _destinationSuggestions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    label == 'Départ' ? Icons.my_location : Icons.location_on,
                    color: const Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Choisir $label',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Suggestions
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withCustomOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          suggestion['icon'],
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                      title: Text(
                        suggestion['name'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(suggestion['description']),
                      trailing: suggestion['isCurrentLocation'] == true
                          ? Icon(Icons.gps_fixed, color: Colors.blue[600])
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        controller.text = suggestion['name'];
                        if (controller == _departureController) {
                          _selectedDeparture = suggestion['position'];
                        } else {
                          _selectedDestination = suggestion['position'];
                        }
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${suggestion['name']} sélectionné'),
                            backgroundColor: const Color(0xFF4CAF50),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Custom location button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _selectCustomLocation(controller);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.map),
                  label: const Text('Choisir sur la carte'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectCustomLocation(TextEditingController controller) {
    // Dialog pour saisir une adresse personnalisée
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        return AlertDialog(
          title: Text('Adresse personnalisée'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Entrez une adresse',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  controller.text = textController.text;
                  // Ici vous pourriez géocoder l'adresse pour obtenir les coordonnées
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Adresse "${textController.text}" définie'),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

  void _selectFromMap(TextEditingController controller) {
    // Ouvrir un sélecteur de carte
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sélection sur carte'),
        content: const Text(
          'Cette fonctionnalité permettra de sélectionner une position directement sur la carte. '
          'Pour l\'instant, utilisez les suggestions ou entrez une adresse personnalisée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _selectCustomLocation(controller);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Saisir adresse'),
          ),
        ],
      ),
    );
  }

  void _swapLocations() {
    // Échanger les textes
    final tempText = _departureController.text;
    _departureController.text = _destinationController.text;
    _destinationController.text = tempText;

    // Échanger les positions
    final tempPosition = _selectedDeparture;
    _selectedDeparture = _selectedDestination;
    _selectedDestination = tempPosition;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Départ et destination échangés'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _searchRoute() {
    if (_departureController.text.isEmpty ||
        _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir les champs départ et destination'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simuler une recherche
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isLoading = false);

        // Créer un message de confirmation avec les coordonnées si disponibles
        String departureInfo = _departureController.text;
        String destinationInfo = _destinationController.text;

        if (_selectedDeparture != null) {
          departureInfo +=
              ' (${_selectedDeparture!.latitude.toStringAsFixed(4)}, ${_selectedDeparture!.longitude.toStringAsFixed(4)})';
        }

        if (_selectedDestination != null) {
          destinationInfo +=
              ' (${_selectedDestination!.latitude.toStringAsFixed(4)}, ${_selectedDestination!.longitude.toStringAsFixed(4)})';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Itinéraire calculé de $departureInfo vers $destinationInfo',
            ),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RouteNavigationPage(
              departure: _departureController.text,
              destination: _destinationController.text,
              transportMode: _selectedTransportMode,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _departureController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}
