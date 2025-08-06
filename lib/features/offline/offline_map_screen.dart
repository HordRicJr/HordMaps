import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../shared/services/offline_service.dart';
import '../../../shared/extensions/color_extensions.dart';

/// Classe pour représenter le progrès de téléchargement
class DownloadProgress {
  final String regionId;
  final int downloadedTiles;
  final int totalTiles;
  final double sizeDownloaded;
  final double totalSize;
  final bool isCompleted;
  final String? error;
  final Duration? estimatedTimeRemaining;

  DownloadProgress({
    required this.regionId,
    required this.downloadedTiles,
    required this.totalTiles,
    required this.sizeDownloaded,
    required this.totalSize,
    this.isCompleted = false,
    this.error,
    this.estimatedTimeRemaining,
  });

  double get progress => totalTiles > 0 ? downloadedTiles / totalTiles : 0.0;

  String get progressText => '$downloadedTiles/$totalTiles tuiles';

  String get sizeText =>
      '${sizeDownloaded.toStringAsFixed(1)}/${totalSize.toStringAsFixed(1)} MB';

  double get downloadedSize => sizeDownloaded;

  bool get hasError => error != null;

  String? get errorMessage => error;
}

/// Écran de gestion des cartes hors ligne
class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _cacheStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCacheStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCacheStats() async {
    // Simuler les stats du cache
    if (mounted) {
      setState(() {
        _cacheStats = {
          'totalSize': '125 MB',
          'totalTiles': 15420,
          'regions': 3,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartes hors ligne'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Régions'),
            Tab(icon: Icon(Icons.download), text: 'Téléchargements'),
            Tab(icon: Icon(Icons.settings), text: 'Paramètres'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showAddRegionDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter une région',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegionsTab(),
          _buildDownloadsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  /// Onglet des régions
  Widget _buildRegionsTab() {
    return Consumer<OfflineService>(
      builder: (context, offlineService, child) {
        if (offlineService.regions.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offlineService.regions.length,
          itemBuilder: (context, index) {
            final region = offlineService.regions[index];
            return _buildRegionCard(region)
                .animate()
                .fadeIn(delay: Duration(milliseconds: index * 100))
                .slideX(begin: 0.3);
          },
        );
      },
    );
  }

  /// Carte d'une région
  Widget _buildRegionCard(OfflineRegion region) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: region.isDownloaded
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
              child: Icon(
                region.isDownloaded ? Icons.offline_pin : Icons.cloud_download,
                color: Colors.white,
              ),
            ),
            title: Text(
              region.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Créée le ${_formatDate(region.createdAt)}'),
                Text('Zoom: ${region.minZoom}-${region.maxZoom}'),
                Consumer<OfflineService>(
                  builder: (context, offlineService, child) {
                    final estimatedTiles = offlineService.estimateTiles(
                      region.bounds,
                      region.minZoom,
                      region.maxZoom,
                    );
                    final estimatedSize = offlineService.estimateSize(
                      region.bounds,
                      region.minZoom,
                      region.maxZoom,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$estimatedTiles tuiles'),
                        Text('${estimatedSize.toStringAsFixed(1)} MB'),
                      ],
                    );
                  },
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                if (!region.isDownloaded)
                  PopupMenuItem(
                    onTap: () => _downloadRegion(region.id),
                    child: const Row(
                      children: [
                        Icon(Icons.download),
                        SizedBox(width: 8),
                        Text('Télécharger'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  onTap: () => _showRegionDetails(region),
                  child: const Row(
                    children: [
                      Icon(Icons.info),
                      SizedBox(width: 8),
                      Text('Détails'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  onTap: () => _deleteRegion(region),
                  child: const Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (region.isDownloaded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withCustomOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Disponible hors ligne',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Onglet des téléchargements
  Widget _buildDownloadsTab() {
    return Consumer<OfflineService>(
      builder: (context, offlineService, child) {
        final downloadableRegions = offlineService.regions
            .where((region) => !region.isDownloaded)
            .toList();

        if (downloadableRegions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_done, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Toutes les régions sont téléchargées',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Ajoutez de nouvelles régions pour les télécharger',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: downloadableRegions.length,
          itemBuilder: (context, index) {
            final region = downloadableRegions[index];
            return _buildDownloadCard(region);
          },
        );
      },
    );
  }

  /// Carte de téléchargement
  Widget _buildDownloadCard(OfflineRegion region) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Consumer<OfflineService>(
                        builder: (context, offlineService, child) {
                          final estimatedTiles = offlineService.estimateTiles(
                            region.bounds,
                            region.minZoom,
                            region.maxZoom,
                          );
                          final estimatedSize = offlineService.estimateSize(
                            region.bounds,
                            region.minZoom,
                            region.maxZoom,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$estimatedTiles tuiles estimées'),
                              Text(
                                '${estimatedSize.toStringAsFixed(1)} MB estimés',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _downloadRegion(region.id),
                  icon: const Icon(Icons.download),
                  label: const Text('Télécharger'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Onglet des paramètres
  Widget _buildSettingsTab() {
    return Consumer<OfflineService>(
      builder: (context, offlineService, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Statistiques du cache
            if (_cacheStats != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistiques du cache',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatRow(
                        'Régions totales',
                        '${_cacheStats!['totalRegions']}',
                      ),
                      _buildStatRow(
                        'Régions téléchargées',
                        '${_cacheStats!['downloadedRegions']}',
                      ),
                      _buildStatRow(
                        'Taille du cache',
                        '${_cacheStats!['cacheSizeMB'].toStringAsFixed(1)} MB',
                      ),
                      _buildStatRow(
                        'Limite de cache',
                        '${_cacheStats!['maxCacheSizeMB'].toStringAsFixed(0)} MB',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _cacheStats!['cacheUsagePercent'] / 100,
                        backgroundColor: Colors.grey[300],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Utilisation: ${_cacheStats!['cacheUsagePercent'].toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Mode hors ligne
            Card(
              child: SwitchListTile(
                title: const Text('Mode hors ligne'),
                subtitle: const Text(
                  'Utiliser uniquement les cartes téléchargées',
                ),
                value: offlineService.isOfflineMode,
                onChanged: offlineService.setOfflineMode,
                secondary: const Icon(Icons.offline_bolt),
              ),
            ),

            // Téléchargement automatique
            Card(
              child: SwitchListTile(
                title: const Text('Téléchargement automatique'),
                subtitle: const Text(
                  'Télécharger automatiquement les zones visitées',
                ),
                value: offlineService.autoDownload,
                onChanged: offlineService.setAutoDownload,
                secondary: const Icon(Icons.auto_awesome),
              ),
            ),

            // Taille maximale du cache
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Taille maximale du cache'),
                subtitle: Text(
                  '${offlineService.maxCacheSize.toStringAsFixed(0)} MB',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showCacheSizeDialog,
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('Actualiser les statistiques'),
                    onTap: _loadCacheStats,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep, color: Colors.red),
                    title: const Text(
                      'Vider le cache',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: _showClearCacheDialog,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Ligne de statistique
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// État vide
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Aucune région hors ligne',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez des régions pour les utiliser sans connexion',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddRegionDialog,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une région'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8));
  }

  /// Dialogue d'ajout de région
  void _showAddRegionDialog() {
    final nameController = TextEditingController();
    final northController = TextEditingController();
    final southController = TextEditingController();
    final eastController = TextEditingController();
    final westController = TextEditingController();
    int minZoom = 1;
    int maxZoom = 18;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter une région'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la région',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: northController,
                        decoration: const InputDecoration(
                          labelText: 'Nord (lat)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: southController,
                        decoration: const InputDecoration(
                          labelText: 'Sud (lat)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: eastController,
                        decoration: const InputDecoration(
                          labelText: 'Est (lng)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: westController,
                        decoration: const InputDecoration(
                          labelText: 'Ouest (lng)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Zoom minimum: $minZoom'),
                Slider(
                  value: minZoom.toDouble(),
                  min: 1,
                  max: 18,
                  divisions: 17,
                  onChanged: (value) {
                    setState(() {
                      minZoom = value.toInt();
                      if (minZoom > maxZoom) maxZoom = minZoom;
                    });
                  },
                ),
                Text('Zoom maximum: $maxZoom'),
                Slider(
                  value: maxZoom.toDouble(),
                  min: 1,
                  max: 18,
                  divisions: 17,
                  onChanged: (value) {
                    setState(() {
                      maxZoom = value.toInt();
                      if (maxZoom < minZoom) minZoom = maxZoom;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    northController.text.isNotEmpty &&
                    southController.text.isNotEmpty &&
                    eastController.text.isNotEmpty &&
                    westController.text.isNotEmpty) {
                  _addRegion(
                    nameController.text,
                    double.parse(northController.text),
                    double.parse(southController.text),
                    double.parse(eastController.text),
                    double.parse(westController.text),
                    minZoom,
                    maxZoom,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  /// Ajouter une région
  Future<void> _addRegion(
    String name,
    double north,
    double south,
    double east,
    double west,
    int minZoom,
    int maxZoom,
  ) async {
    final offlineService = context.read<OfflineService>();

    final bounds = LatLngBounds(LatLng(south, west), LatLng(north, east));

    final region = OfflineRegion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    await offlineService.addRegion(region);
    await _loadCacheStats();
  }

  /// Télécharger une région
  Future<void> _downloadRegion(String regionId) async {
    final offlineService = context.read<OfflineService>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(
        regionId: regionId,
        offlineService: offlineService,
        onComplete: () {
          Navigator.pop(context);
          _loadCacheStats();
        },
      ),
    );
  }

  /// Supprimer une région
  Future<void> _deleteRegion(OfflineRegion region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la région'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${region.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final offlineService = context.read<OfflineService>();
      await offlineService.removeRegion(region.id);
      await _loadCacheStats();
    }
  }

  /// Afficher les détails d'une région
  void _showRegionDetails(OfflineRegion region) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(region.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Nord', region.bounds.north.toStringAsFixed(6)),
            _buildDetailRow('Sud', region.bounds.south.toStringAsFixed(6)),
            _buildDetailRow('Est', region.bounds.east.toStringAsFixed(6)),
            _buildDetailRow('Ouest', region.bounds.west.toStringAsFixed(6)),
            _buildDetailRow('Zoom min', region.minZoom.toString()),
            _buildDetailRow('Zoom max', region.maxZoom.toString()),
            Consumer<OfflineService>(
              builder: (context, offlineService, child) {
                final estimatedTiles = offlineService.estimateTiles(
                  region.bounds,
                  region.minZoom,
                  region.maxZoom,
                );
                final estimatedSize = offlineService.estimateSize(
                  region.bounds,
                  region.minZoom,
                  region.maxZoom,
                );
                return Column(
                  children: [
                    _buildDetailRow('Tuiles', estimatedTiles.toString()),
                    _buildDetailRow(
                      'Taille',
                      '${estimatedSize.toStringAsFixed(1)} MB',
                    ),
                  ],
                );
              },
            ),
            _buildDetailRow('Créée le', _formatDate(region.createdAt)),
            _buildDetailRow(
              'Statut',
              region.isDownloaded ? 'Téléchargée' : 'Non téléchargée',
            ),
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

  /// Ligne de détail
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Dialogue de taille de cache
  void _showCacheSizeDialog() {
    final offlineService = context.read<OfflineService>();
    double newSize = offlineService.maxCacheSize;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Taille maximale du cache'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Taille actuelle: ${newSize.toStringAsFixed(0)} MB'),
              const SizedBox(height: 16),
              Slider(
                value: newSize,
                min: 100,
                max: 5000,
                divisions: 49,
                label: '${newSize.toStringAsFixed(0)} MB',
                onChanged: (value) {
                  setState(() {
                    newSize = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                offlineService.setMaxCacheSize(newSize);
                Navigator.pop(context);
                _loadCacheStats();
              },
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialogue de vidage du cache
  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le cache'),
        content: const Text(
          'Cette action supprimera toutes les cartes téléchargées. '
          'Vous devrez les télécharger à nouveau pour les utiliser hors ligne.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final offlineService = context.read<OfflineService>();
              await offlineService.clearCache();
              if (mounted) {
                navigator.pop();
                await _loadCacheStats();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Cache vidé')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }

  /// Formate une date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Dialogue de progrès de téléchargement
class _DownloadProgressDialog extends StatefulWidget {
  final String regionId;
  final OfflineService offlineService;
  final VoidCallback onComplete;

  const _DownloadProgressDialog({
    required this.regionId,
    required this.offlineService,
    required this.onComplete,
  });

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  DownloadProgress? _progress;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
    });

    await widget.offlineService.downloadRegion(widget.regionId);

    // Simulate download completion
    if (mounted) {
      setState(() {
        _progress = DownloadProgress(
          regionId: widget.regionId,
          downloadedTiles: 100,
          totalTiles: 100,
          sizeDownloaded: 2.0,
          totalSize: 2.0,
          isCompleted: true,
          error: null,
          estimatedTimeRemaining: null,
        );
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          widget.onComplete();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Téléchargement en cours'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_progress != null) ...[
            LinearProgressIndicator(
              value: _progress!.progress,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text('${(_progress!.progress * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Text(
              '${_progress!.downloadedTiles} / ${_progress!.totalTiles} tuiles',
            ),
            Text('${_progress!.downloadedSize.toStringAsFixed(1)} MB'),
            if (_progress!.estimatedTimeRemaining != null)
              Text(
                'Temps restant: ${_formatDuration(_progress!.estimatedTimeRemaining!)}',
              ),
            if (_progress!.hasError)
              Text(
                'Erreur: ${_progress!.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            if (_progress!.isCompleted && !_progress!.hasError)
              const Row(
                children: [
                  Icon(Icons.check, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Téléchargement terminé !',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Préparation du téléchargement...'),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading || (_progress?.hasError ?? false))
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
