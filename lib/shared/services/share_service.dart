import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/extensions/color_extensions.dart';

class ShareService {
  static const String _appName = 'HordMaps';

  /// Partage une localisation
  static Future<void> shareLocation({
    required LatLng position,
    String? locationName,
    String? description,
    BuildContext? context,
  }) async {
    final String name = locationName ?? 'Localisation partagée';
    final String desc = description ?? '';

    // URLs pour différentes plateformes
    final String googleMapsUrl =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    final String openStreetMapUrl =
        'https://www.openstreetmap.org/?mlat=${position.latitude}&mlon=${position.longitude}&zoom=15';

    final String shareText =
        '''
🗺️ $name
${desc.isNotEmpty ? '$desc\n' : ''}
📍 Coordonnées: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}

🔗 Voir sur Google Maps: $googleMapsUrl

🌍 Voir sur OpenStreetMap: $openStreetMapUrl

📱 Partagé via $_appName - Navigation GPS Togo
''';

    try {
      await Share.share(shareText, subject: 'Localisation partagée - $name');
    } catch (e) {
      debugPrint('Erreur partage localisation: $e');
      if (context != null && context.mounted) {
        _showError(context, 'Erreur lors du partage de la localisation');
      }
    }
  }

  /// Partage un POI (Point d'Intérêt)
  static Future<void> sharePOI({
    required String name,
    required LatLng position,
    String? address,
    String? phone,
    String? website,
    String? description,
    BuildContext? context,
  }) async {
    final String shareText =
        '''
📍 $name

${description?.isNotEmpty == true ? '$description\n\n' : ''}Adresse: ${address ?? 'Non spécifiée'}
${phone?.isNotEmpty == true ? 'Téléphone: $phone\n' : ''}${website?.isNotEmpty == true ? 'Site web: $website\n' : ''}
Position: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}

🗺️ Voir sur Google Maps: https://maps.google.com/?q=${position.latitude},${position.longitude}

📱 Découvert via $_appName - Navigation GPS Togo
''';

    try {
      await Share.share(shareText, subject: 'POI partagé - $name');
    } catch (e) {
      debugPrint('Erreur partage POI: $e');
      if (context != null && context.mounted) {
        _showError(context, 'Erreur lors du partage du POI');
      }
    }
  }

  /// Partage un itinéraire
  static Future<void> shareRoute({
    required LatLng start,
    required LatLng end,
    String? startName,
    String? endName,
    double? distance,
    double? duration,
    BuildContext? context,
  }) async {
    final String startLocation = startName ?? 'Point de départ';
    final String endLocation = endName ?? 'Destination';

    String routeInfo = '';
    if (distance != null) {
      routeInfo += '📏 Distance: ${distance.toStringAsFixed(1)} km\n';
    }
    if (duration != null) {
      final int hours = (duration / 60).floor();
      final int minutes = (duration % 60).round();
      routeInfo +=
          '⏱️ Durée estimée: ${hours > 0 ? '${hours}h ' : ''}${minutes}min\n';
    }

    final String googleMapsUrl =
        'https://maps.google.com/dir/${start.latitude},${start.longitude}/${end.latitude},${end.longitude}';

    final String shareText =
        '''
🗺️ Itinéraire $_appName

📍 Départ: $startLocation
🎯 Arrivée: $endLocation

$routeInfo
🔗 Voir l'itinéraire: $googleMapsUrl

📱 Calculé avec $_appName - Navigation GPS Togo
''';

    try {
      await Share.share(
        shareText,
        subject: 'Itinéraire partagé - $startLocation → $endLocation',
      );
    } catch (e) {
      debugPrint('Erreur partage itinéraire: $e');
      if (context != null && context.mounted) {
        _showError(context, 'Erreur lors du partage de l\'itinéraire');
      }
    }
  }

  /// Génère un QR code pour une localisation
  static Widget generateLocationQR({
    required LatLng position,
    String? locationName,
    double size = 200,
  }) {
    final String qrData =
        'geo:${position.latitude},${position.longitude}?q=${position.latitude},${position.longitude}(${locationName ?? 'Localisation'})';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withCustomOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: size,
            gapless: false,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          const SizedBox(height: 8),
          Text(
            'Scannez pour ouvrir dans votre app de cartes',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Copie du texte dans le presse-papiers
  static Future<void> copyToClipboard({
    required String text,
    required BuildContext context,
    String? successMessage,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage ?? 'Copié dans le presse-papiers'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur copie presse-papiers: $e');
      if (context.mounted) {
        _showError(context, 'Erreur lors de la copie');
      }
    }
  }

  /// Ouvre une URL externe
  static Future<void> openUrl(String url, {BuildContext? context}) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Impossible d\'ouvrir l\'URL: $url';
      }
    } catch (e) {
      debugPrint('Erreur ouverture URL: $e');
      if (context != null && context.mounted) {
        _showError(context, 'Impossible d\'ouvrir le lien');
      }
    }
  }

  /// Partage l'application
  static Future<void> shareApp({BuildContext? context}) async {
    const String shareText =
        '''
🗺️ Découvrez $_appName !

Une application de navigation complète avec:
📍 Navigation GPS précise
🗺️ Cartes hors ligne
🔍 Recherche de lieux
⭐ Gestion des favoris
🚗 Navigation temps réel

Téléchargez $_appName maintenant !

#Navigation #GPS #Togo #HordMaps
''';

    try {
      await Share.share(shareText, subject: 'Découvrez $_appName');
    } catch (e) {
      debugPrint('Erreur partage app: $e');
      if (context != null && context.mounted) {
        _showError(context, 'Erreur lors du partage de l\'application');
      }
    }
  }

  /// Affiche une boîte de dialogue de partage avancée
  static Future<void> showShareDialog({
    required BuildContext context,
    required LatLng position,
    String? locationName,
    String? description,
  }) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Partager la localisation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(locationName ?? 'Localisation'),
              const SizedBox(height: 16),
              generateLocationQR(
                position: position,
                locationName: locationName,
                size: 150,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.share,
                    label: 'Partager',
                    onTap: () {
                      Navigator.of(context).pop();
                      shareLocation(
                        position: position,
                        locationName: locationName,
                        description: description,
                        context: context,
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.copy,
                    label: 'Copier',
                    onTap: () {
                      Navigator.of(context).pop();
                      copyToClipboard(
                        text: '${position.latitude}, ${position.longitude}',
                        context: context,
                        successMessage: 'Coordonnées copiées',
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.map,
                    label: 'Google Maps',
                    onTap: () {
                      Navigator.of(context).pop();
                      openUrl(
                        'https://maps.google.com/?q=${position.latitude},${position.longitude}',
                        context: context,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Widget bouton d'action pour la boîte de dialogue
  static Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Affiche un message d'erreur
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
