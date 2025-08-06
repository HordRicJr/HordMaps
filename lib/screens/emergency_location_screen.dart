import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/emergency_location_disable_service.dart';

/// Écran d'urgence pour la sélection de position manuelle
class EmergencyLocationScreen extends StatefulWidget {
  const EmergencyLocationScreen({super.key});

  @override
  State<EmergencyLocationScreen> createState() =>
      _EmergencyLocationScreenState();
}

class _EmergencyLocationScreenState extends State<EmergencyLocationScreen> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  String _selectedCity = 'Paris';

  final List<String> _cities = [
    'Paris',
    'Lyon',
    'Marseille',
    'Toulouse',
    'Nice',
    'Nantes',
    'Strasbourg',
    'Montpellier',
    'Bordeaux',
    'Lille',
  ];

  @override
  void initState() {
    super.initState();
    _latController.text = EmergencyLocationDisableService.defaultLatitude
        .toString();
    _lngController.text = EmergencyLocationDisableService.defaultLongitude
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 Position d\'Urgence'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message d'urgence
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    '🛑 MODE D\'URGENCE ACTIVÉ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La géolocalisation a été désactivée pour éviter les crashes. Sélectionnez une position manuellement.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sélection par ville
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏙️ Sélection par ville',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCity,
                      decoration: const InputDecoration(
                        labelText: 'Choisir une ville',
                        border: OutlineInputBorder(),
                      ),
                      items: _cities
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCity = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _setCityPosition(),
                        icon: const Icon(Icons.location_city),
                        label: const Text('Utiliser cette ville'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sélection manuelle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📍 Position manuelle',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _latController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                        hintText: '48.8566',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lngController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                        hintText: '2.3522',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _setManualPosition(),
                        icon: const Icon(Icons.my_location),
                        label: const Text('Définir position manuelle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Actions d'urgence
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _disableGeolocationPermanently(),
                    icon: const Icon(Icons.block),
                    label: const Text('DÉSACTIVER GÉOLOCALISATION'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _enableGeolocationBack(),
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Réactiver géolocalisation (DANGER)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setCityPosition() {
    final fallbackService = Provider.of<FallbackLocationService>(
      context,
      listen: false,
    );
    fallbackService.setCityPosition(_selectedCity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Position définie sur $_selectedCity'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _setManualPosition() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat != null && lng != null) {
      final fallbackService = Provider.of<FallbackLocationService>(
        context,
        listen: false,
      );
      fallbackService.setManualPosition(lat, lng);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position manuelle définie'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordonnées invalides'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disableGeolocationPermanently() async {
    await EmergencyLocationDisableService.disableGeolocation();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Géolocalisation désactivée définitivement'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _enableGeolocationBack() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ ATTENTION'),
        content: const Text(
          'Réactiver la géolocalisation peut causer des crashes. Êtes-vous sûr?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              await EmergencyLocationDisableService.enableGeolocation();
              if (mounted) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Géolocalisation réactivée'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Réactiver'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ℹ️ Mode d\'urgence'),
        content: const Text(
          'Ce mode désactive complètement la géolocalisation pour éviter les crashes.\n\n'
          '• Sélectionnez une ville française\n'
          '• Ou définissez des coordonnées manuellement\n'
          '• L\'application fonctionnera sans GPS\n\n'
          'Vous pouvez réactiver la géolocalisation plus tard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }
}
