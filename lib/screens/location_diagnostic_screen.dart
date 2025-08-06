import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/safe_location_service.dart';

/// Écran de diagnostic pour tester et déboguer la géolocalisation
class LocationDiagnosticScreen extends StatefulWidget {
  const LocationDiagnosticScreen({super.key});

  @override
  State<LocationDiagnosticScreen> createState() =>
      _LocationDiagnosticScreenState();
}

class _LocationDiagnosticScreenState extends State<LocationDiagnosticScreen> {
  final SafeLocationService _locationService = SafeLocationService.instance;
  bool _isServiceEnabled = false;
  PermissionStatus _locationPermission = PermissionStatus.denied;
  Position? _currentPosition;
  String _diagnosticLog = '';
  bool _isRunningDiagnostic = false;

  @override
  void initState() {
    super.initState();
    _runFullDiagnostic();
  }

  /// Effectue un diagnostic complet de la géolocalisation
  Future<void> _runFullDiagnostic() async {
    setState(() {
      _isRunningDiagnostic = true;
      _diagnosticLog = '';
    });

    _addLog('🔍 Démarrage du diagnostic de géolocalisation...');

    try {
      // 1. Vérifier le service de localisation
      _addLog('\n📡 Vérification du service de localisation...');
      _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      _addLog('Service activé: ${_isServiceEnabled ? '✅ OUI' : '❌ NON'}');

      // 2. Vérifier les permissions
      _addLog('\n🔐 Vérification des permissions...');
      _locationPermission = await Permission.location.status;
      _addLog(
        'Permission status: ${_getPermissionStatusText(_locationPermission)}',
      );

      if (_locationPermission.isDenied) {
        _addLog('Demande de permission...');
        _locationPermission = await Permission.location.request();
        _addLog(
          'Nouvelle permission: ${_getPermissionStatusText(_locationPermission)}',
        );
      }

      // 3. Test avec Geolocator natif
      _addLog('\n📍 Test de géolocalisation native...');
      await _testNativeGeolocator();

      // 4. Test avec notre service
      _addLog('\n🔧 Test du SafeLocationService...');
      await _testSafeLocationService();

      // 5. Informations système
      _addLog('\n📱 Informations système...');
      await _getSystemInfo();

      _addLog('\n✅ Diagnostic terminé !');
    } catch (e) {
      _addLog('\n❌ Erreur durant le diagnostic: $e');
    } finally {
      setState(() {
        _isRunningDiagnostic = false;
      });
    }
  }

  /// Test avec l'API Geolocator native
  Future<void> _testNativeGeolocator() async {
    try {
      _addLog('Tentative getCurrentPosition...');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 15));

      _currentPosition = position;
      _addLog('✅ Position obtenue !');
      _addLog('  Lat: ${position.latitude.toStringAsFixed(6)}');
      _addLog('  Lng: ${position.longitude.toStringAsFixed(6)}');
      _addLog('  Précision: ${position.accuracy.toStringAsFixed(1)}m');
      _addLog('  Vitesse: ${position.speed.toStringAsFixed(1)} m/s');
      _addLog('  Timestamp: ${position.timestamp}');
    } catch (e) {
      if (e is TimeoutException) {
        _addLog('⏰ Timeout: $e');
      } else if (e.toString().contains('LocationServiceDisabledException')) {
        _addLog('🚫 Service désactivé: $e');
      } else if (e.toString().contains('PermissionDeniedException')) {
        _addLog('🔒 Permission refusée: $e');
      } else {
        _addLog('❌ Erreur: $e');
      }
    }
  }

  /// Test avec SafeLocationService
  Future<void> _testSafeLocationService() async {
    try {
      _addLog('Initialisation du SafeLocationService...');

      final success = await _locationService.initialize();
      _addLog('Initialisation: ${success ? '✅ Succès' : '❌ Échec'}');

      if (!success) {
        _addLog('Erreur: ${_locationService.lastError}');
        return;
      }

      _addLog('Position du service: ${_locationService.currentPosition}');
      _addLog('Service initialisé: ${_locationService.isInitialized}');
      _addLog('Permissions: ${_locationService.hasPermission}');
      _addLog('Précision: ${_locationService.accuracy.toStringAsFixed(1)}m');
    } catch (e) {
      _addLog('❌ Erreur SafeLocationService: $e');
    }
  }

  /// Obtient les informations système
  Future<void> _getSystemInfo() async {
    try {
      final serviceStatus = await Geolocator.getLocationAccuracy();
      _addLog('Précision système: $serviceStatus');

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        _addLog('Dernière position connue:');
        _addLog(
          '  ${lastKnownPosition.latitude}, ${lastKnownPosition.longitude}',
        );
        _addLog(
          '  Âge: ${DateTime.now().difference(lastKnownPosition.timestamp).inMinutes} min',
        );
      } else {
        _addLog('Aucune dernière position connue');
      }
    } catch (e) {
      _addLog('❌ Erreur info système: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _diagnosticLog += '$message\n';
    });
    print(message); // Aussi dans la console
  }

  String _getPermissionStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '✅ ACCORDÉE';
      case PermissionStatus.denied:
        return '❌ REFUSÉE';
      case PermissionStatus.permanentlyDenied:
        return '🚫 REFUSÉE DÉFINITIVEMENT';
      case PermissionStatus.restricted:
        return '⚠️ RESTREINTE';
      case PermissionStatus.limited:
        return '⚠️ LIMITÉE';
      case PermissionStatus.provisional:
        return '🔶 PROVISOIRE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Géolocalisation'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Statut général
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statut Géolocalisation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _isServiceEnabled ? Icons.gps_fixed : Icons.gps_off,
                      color: _isServiceEnabled ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Service: ${_isServiceEnabled ? 'Activé' : 'Désactivé'}',
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      _locationPermission.isGranted
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: _locationPermission.isGranted
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Permission: ${_getPermissionStatusText(_locationPermission)}',
                    ),
                  ],
                ),
                if (_currentPosition != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Position actuelle:\n'
                    '${_currentPosition!.latitude.toStringAsFixed(6)}, '
                    '${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Boutons d'action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunningDiagnostic ? null : _runFullDiagnostic,
                    icon: _isRunningDiagnostic
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _isRunningDiagnostic ? 'Diagnostic...' : 'Refaire',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Geolocator.openAppSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('Paramètres'),
                  ),
                ),
              ],
            ),
          ),

          // Log du diagnostic
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _diagnosticLog.isEmpty
                      ? 'Aucun diagnostic effectué'
                      : _diagnosticLog,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
