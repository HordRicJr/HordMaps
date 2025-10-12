import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import '../../core/config/environment_config.dart';

// Classes simplifiées pour le cache offline
class LatLngBounds {
  final LatLng northEast;
  final LatLng southWest;

  LatLngBounds(this.southWest, this.northEast);

  double get north => northEast.latitude;
  double get south => southWest.latitude;
  double get east => northEast.longitude;
  double get west => southWest.longitude;

  bool contains(LatLng point) {
    return point.latitude >= south &&
        point.latitude <= north &&
        point.longitude >= west &&
        point.longitude <= east;
  }
}

/// Tuile de carte
class MapTile {
  final int x;
  final int y;
  final int z;
  final String url;
  final String? filePath;
  final DateTime? downloadedAt;

  MapTile({
    required this.x,
    required this.y,
    required this.z,
    required this.url,
    this.filePath,
    this.downloadedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'z': z,
      'url': url,
      'filePath': filePath,
      'downloadedAt': downloadedAt?.toIso8601String(),
    };
  }

  factory MapTile.fromJson(Map<String, dynamic> json) {
    return MapTile(
      x: json['x'],
      y: json['y'],
      z: json['z'],
      url: json['url'],
      filePath: json['filePath'],
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.parse(json['downloadedAt'])
          : null,
    );
  }

  String get tileKey => '${z}_${x}_$y';
}

/// Région de carte hors ligne
class OfflineRegion {
  final String id;
  final String name;
  final LatLngBounds bounds;
  final int minZoom;
  final int maxZoom;
  final DateTime createdAt;
  final double progress;
  final bool isDownloaded;
  final int tileCount;
  final double sizeOnDisk;

  OfflineRegion({
    required this.id,
    required this.name,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    DateTime? createdAt,
    this.progress = 0.0,
    this.isDownloaded = false,
    this.tileCount = 0,
    this.sizeOnDisk = 0.0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bounds': {
        'northEast': {
          'lat': bounds.northEast.latitude,
          'lng': bounds.northEast.longitude,
        },
        'southWest': {
          'lat': bounds.southWest.latitude,
          'lng': bounds.southWest.longitude,
        },
      },
      'minZoom': minZoom,
      'maxZoom': maxZoom,
      'createdAt': createdAt.toIso8601String(),
      'progress': progress,
      'isDownloaded': isDownloaded,
      'tileCount': tileCount,
      'sizeOnDisk': sizeOnDisk,
    };
  }

  factory OfflineRegion.fromJson(Map<String, dynamic> json) {
    final boundsData = json['bounds'];
    return OfflineRegion(
      id: json['id'],
      name: json['name'],
      bounds: LatLngBounds(
        LatLng(boundsData['southWest']['lat'], boundsData['southWest']['lng']),
        LatLng(boundsData['northEast']['lat'], boundsData['northEast']['lng']),
      ),
      minZoom: json['minZoom'],
      maxZoom: json['maxZoom'],
      createdAt: DateTime.parse(json['createdAt']),
      progress: json['progress']?.toDouble() ?? 0.0,
      isDownloaded: json['isDownloaded'] ?? false,
      tileCount: json['tileCount'] ?? 0,
      sizeOnDisk: json['sizeOnDisk']?.toDouble() ?? 0.0,
    );
  }
}

/// Service de gestion du mode hors ligne
class OfflineService extends ChangeNotifier {
  final StorageService _storage;

  static const String _settingsKey = 'offline_settings';
  static const String _regionsKey = 'offline_regions';
  static const String _tilesKey = 'offline_tiles';

  bool _isOfflineMode = false;
  bool _autoDownload = false;
  double _maxCacheSize = 500.0; // MB
  String? _cacheDirectory;
  List<OfflineRegion> _regions = [];
  Map<String, MapTile> _cachedTiles = {};

  OfflineService(this._storage);

  // Getters
  bool get isOfflineMode => _isOfflineMode;
  bool get autoDownload => _autoDownload;
  double get maxCacheSize => _maxCacheSize;
  List<OfflineRegion> get regions => List.unmodifiable(_regions);
  String? get cacheDirectory => _cacheDirectory;

  /// Initialise le service offline
  Future<void> initialize() async {
    await _initializeCacheDirectory();
    await _loadSettings();
    await _loadRegions();
    await _loadCachedTiles();
  }

  /// Initialise le répertoire de cache
  Future<void> _initializeCacheDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = '${appDir.path}/hordmaps_cache';
      final cacheDir = Directory(_cacheDirectory!);

      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Erreur initialisation cache directory: $e');
    }
  }

  /// Charge les paramètres depuis le stockage
  Future<void> _loadSettings() async {
    try {
      final settings = await _storage.getMap(_settingsKey);
      if (settings != null) {
        _isOfflineMode = settings['isOfflineMode'] ?? false;
        _autoDownload = settings['autoDownload'] ?? false;
        _maxCacheSize = settings['maxCacheSize']?.toDouble() ?? 500.0;
      }
    } catch (e) {
      debugPrint('Erreur chargement paramètres offline: $e');
    }
  }

  /// Sauvegarde les paramètres
  Future<void> _saveSettings() async {
    try {
      await _storage.setMap(_settingsKey, {
        'isOfflineMode': _isOfflineMode,
        'autoDownload': _autoDownload,
        'maxCacheSize': _maxCacheSize,
      });
    } catch (e) {
      debugPrint('Erreur sauvegarde paramètres offline: $e');
    }
  }

  /// Charge les régions depuis le stockage
  Future<void> _loadRegions() async {
    try {
      final regionsString = await _storage.getString(_regionsKey);
      if (regionsString != null) {
        final regionsData = jsonDecode(regionsString) as List;
        _regions = regionsData
            .map((data) => OfflineRegion.fromJson(data))
            .toList();
      }
    } catch (e) {
      debugPrint('Erreur chargement régions offline: $e');
    }
  }

  /// Sauvegarde les régions
  Future<void> _saveRegions() async {
    try {
      final regionsData = _regions.map((region) => region.toJson()).toList();
      await _storage.setString(_regionsKey, jsonEncode(regionsData));
    } catch (e) {
      debugPrint('Erreur sauvegarde régions offline: $e');
    }
  }

  /// Active/désactive le mode hors ligne
  Future<void> setOfflineMode(bool enabled) async {
    _isOfflineMode = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Active/désactive le téléchargement automatique
  Future<void> setAutoDownload(bool enabled) async {
    _autoDownload = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Définit la taille maximale du cache
  Future<void> setMaxCacheSize(double sizeMB) async {
    _maxCacheSize = sizeMB;
    await _saveSettings();
    notifyListeners();
  }

  /// Ajoute une région pour le téléchargement hors ligne
  Future<void> addRegion(OfflineRegion region) async {
    _regions.add(region);
    await _saveRegions();
    notifyListeners();
  }

  /// Supprime une région
  Future<void> removeRegion(String regionId) async {
    _regions.removeWhere((region) => region.id == regionId);

    // Supprimer les fichiers de cache de la région
    try {
      final regionDir = Directory('$_cacheDirectory/$regionId');
      if (await regionDir.exists()) {
        await regionDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Erreur suppression fichiers région: $e');
    }

    await _saveRegions();
    notifyListeners();
  }

  /// Démarre le téléchargement d'une région
  Future<void> downloadRegion(String regionId) async {
    try {
      final region = _regions.firstWhere((r) => r.id == regionId);

      // Créer le répertoire de la région
      final regionDir = Directory('$_cacheDirectory/$regionId');
      if (!await regionDir.exists()) {
        await regionDir.create(recursive: true);
      }

      // Calculer le nombre total de tuiles
      int totalTiles = 0;
      for (int zoom = region.minZoom; zoom <= region.maxZoom; zoom++) {
        final bounds = _getBoundingTileNumbers(region.bounds, zoom);
        totalTiles +=
            (bounds['maxX']! - bounds['minX']! + 1) *
            (bounds['maxY']! - bounds['minY']! + 1);
      }

      int downloadedTiles = 0;

      // Télécharger les tuiles
      for (int zoom = region.minZoom; zoom <= region.maxZoom; zoom++) {
        final bounds = _getBoundingTileNumbers(region.bounds, zoom);

        for (int x = bounds['minX']!; x <= bounds['maxX']!; x++) {
          for (int y = bounds['minY']!; y <= bounds['maxY']!; y++) {
            await _downloadTile(x, y, zoom, regionId);
            downloadedTiles++;

            // Mettre à jour le progrès
            final progress = downloadedTiles / totalTiles;
            await _updateRegionProgress(regionId, progress);

            // Notifier les listeners périodiquement
            if (downloadedTiles % 10 == 0) {
              notifyListeners();
            }
          }
        }
      }

      // Marquer comme téléchargé
      await _updateRegionProgress(regionId, 1.0, isDownloaded: true);
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur téléchargement région: $e');
    }
  }

  /// Met à jour le progrès d'une région
  Future<void> _updateRegionProgress(
    String regionId,
    double progress, {
    bool? isDownloaded,
  }) async {
    try {
      final index = _regions.indexWhere((r) => r.id == regionId);
      if (index != -1) {
        _regions[index] = OfflineRegion(
          id: _regions[index].id,
          name: _regions[index].name,
          bounds: _regions[index].bounds,
          minZoom: _regions[index].minZoom,
          maxZoom: _regions[index].maxZoom,
          createdAt: _regions[index].createdAt,
          progress: progress,
          isDownloaded: isDownloaded ?? _regions[index].isDownloaded,
          tileCount: _regions[index].tileCount,
          sizeOnDisk: _regions[index].sizeOnDisk,
        );
        await _saveRegions();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur mise à jour progrès région: $e');
    }
  }

  /// Télécharge une tuile
  Future<void> _downloadTile(int x, int y, int zoom, String regionId) async {
    try {
      final url = AzureTileUrls.standard.replaceAll('{z}', zoom.toString()).replaceAll('{x}', x.toString()).replaceAll('{y}', y.toString());
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final tilePath = '$_cacheDirectory/$regionId/${zoom}_${x}_$y.png';
        final tileFile = File(tilePath);
        await tileFile.writeAsBytes(response.bodyBytes);

        // Stocker les métadonnées de la tuile
        final tile = MapTile(
          x: x,
          y: y,
          z: zoom,
          url: url,
          filePath: tilePath,
          downloadedAt: DateTime.now(),
        );
        _cachedTiles[tile.tileKey] = tile;
      }
    } catch (e) {
      debugPrint('Erreur téléchargement tuile $x,$y,$zoom: $e');
    }
  }

  /// Calcule les numéros de tuiles pour une région et un niveau de zoom
  Map<String, int> _getBoundingTileNumbers(LatLngBounds bounds, int zoom) {
    final minX = _lon2tile(bounds.west, zoom);
    final maxX = _lon2tile(bounds.east, zoom);
    final minY = _lat2tile(bounds.north, zoom);
    final maxY = _lat2tile(bounds.south, zoom);

    return {
      'minX': math.min(minX, maxX),
      'maxX': math.max(minX, maxX),
      'minY': math.min(minY, maxY),
      'maxY': math.max(minY, maxY),
    };
  }

  /// Convertit longitude en numéro de tuile
  int _lon2tile(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  /// Convertit latitude en numéro de tuile
  int _lat2tile(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    return ((1.0 -
                math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi) /
            2.0 *
            (1 << zoom))
        .floor();
  }

  /// Calcule la taille du cache en MB
  Future<double> getCacheSize() async {
    try {
      if (_cacheDirectory == null) return 0.0;

      final cacheDir = Directory(_cacheDirectory!);
      if (!await cacheDir.exists()) return 0.0;

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }

      return totalSize / (1024 * 1024); // Convertir en MB
    } catch (e) {
      debugPrint('Erreur calcul taille cache: $e');
      return 0.0;
    }
  }

  /// Nettoie le cache si nécessaire
  Future<void> cleanupCache() async {
    try {
      if (_cacheDirectory == null) return;

      final cacheDir = Directory(_cacheDirectory!);
      if (!await cacheDir.exists()) return;

      final currentSize = await getCacheSize();
      if (currentSize <= _maxCacheSize) return;

      // Mettre à jour les tailles des régions
      for (int i = 0; i < _regions.length; i++) {
        final region = _regions[i];
        _regions[i] = OfflineRegion(
          id: region.id,
          name: region.name,
          bounds: region.bounds,
          minZoom: region.minZoom,
          maxZoom: region.maxZoom,
          createdAt: region.createdAt,
          progress: region.progress,
          isDownloaded: region.isDownloaded,
          tileCount: region.tileCount,
          sizeOnDisk: await _getRegionSize(region.id),
        );
      }

      await _saveRegions();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur nettoyage cache: $e');
    }
  }

  /// Vérifie si une position est disponible hors ligne
  bool isPositionAvailableOffline(LatLng position) {
    return _regions.any(
      (region) => region.isDownloaded && region.bounds.contains(position),
    );
  }

  /// Obtient la tuile en cache
  String? getCachedTilePath(int x, int y, int zoom) {
    final tileKey = '${zoom}_${x}_$y';
    return _cachedTiles[tileKey]?.filePath;
  }

  /// Charge les tuiles en cache depuis le stockage
  Future<void> _loadCachedTiles() async {
    try {
      final tilesString = await _storage.getString(_tilesKey);
      if (tilesString != null) {
        final tilesData = jsonDecode(tilesString) as Map<String, dynamic>;
        _cachedTiles = tilesData.map(
          (key, value) => MapEntry(key, MapTile.fromJson(value)),
        );
      }
    } catch (e) {
      debugPrint('Erreur chargement tuiles cache: $e');
    }
  }

  /// Obtient la taille d'une région
  Future<double> _getRegionSize(String regionId) async {
    try {
      final regionDir = Directory('$_cacheDirectory/$regionId');
      if (!await regionDir.exists()) return 0.0;

      int totalSize = 0;
      await for (final entity in regionDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }

      return totalSize / (1024 * 1024); // MB
    } catch (e) {
      debugPrint('Erreur calcul taille région: $e');
      return 0.0;
    }
  }

  /// Crée une région par défaut pour Lomé
  OfflineRegion createLomeRegion() {
    return OfflineRegion(
      id: 'lome_region',
      name: 'Lomé et environs',
      bounds: LatLngBounds(
        const LatLng(6.0, 1.0), // Sud-Ouest
        const LatLng(6.4, 1.4), // Nord-Est
      ),
      minZoom: 10,
      maxZoom: 16,
    );
  }

  /// Estime le nombre de tuiles pour une région
  int estimateTiles(LatLngBounds bounds, int minZoom, int maxZoom) {
    int totalTiles = 0;
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      final tileBounds = _getBoundingTileNumbers(bounds, zoom);
      totalTiles +=
          (tileBounds['maxX']! - tileBounds['minX']! + 1) *
          (tileBounds['maxY']! - tileBounds['minY']! + 1);
    }
    return totalTiles;
  }

  /// Estime la taille d'une région en MB
  double estimateSize(LatLngBounds bounds, int minZoom, int maxZoom) {
    final tileCount = estimateTiles(bounds, minZoom, maxZoom);
    // Estimation moyenne de 50KB par tuile
    return (tileCount * 50) / 1024.0; // Convertir en MB
  }

  /// Nettoie tout le cache
  Future<void> clearCache() async {
    try {
      if (_cacheDirectory == null) return;

      final cacheDir = Directory(_cacheDirectory!);
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }

      // Réinitialiser les données
      _regions.clear();
      _cachedTiles.clear();

      await _saveRegions();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur nettoyage cache: $e');
    }
  }
}
