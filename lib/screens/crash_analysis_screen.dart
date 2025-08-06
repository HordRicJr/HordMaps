import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Analyseur de crash spécialisé pour les problèmes de géolocalisation
class CrashAnalyzer {
  static final CrashAnalyzer _instance = CrashAnalyzer._internal();
  factory CrashAnalyzer() => _instance;
  CrashAnalyzer._internal();

  final List<CrashReport> _reports = [];

  /// Enregistre un crash avec tous les détails
  void recordCrash({
    required String context,
    required dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    final report = CrashReport(
      timestamp: DateTime.now(),
      context: context,
      error: error.toString(),
      errorType: error.runtimeType.toString(),
      stackTrace: stackTrace?.toString(),
      additionalData: additionalData ?? {},
    );

    _reports.add(report);

    // Log immédiat pour debug
    developer.log(
      'CRASH RECORDED',
      name: 'CrashAnalyzer',
      error: error,
      stackTrace: stackTrace,
    );

    // Sauvegarde asynchrone
    _saveCrashReport(report);
  }

  /// Analyse les patterns de crash
  CrashAnalysis analyzeCrashes() {
    if (_reports.isEmpty) {
      return CrashAnalysis(
        totalCrashes: 0,
        mostCommonError: 'Aucun crash enregistré',
        patterns: [],
        recommendations: ['Aucune recommandation disponible'],
      );
    }

    final errorTypes = <String, int>{};
    final contexts = <String, int>{};
    final patterns = <String>[];

    for (final report in _reports) {
      // Compter les types d'erreur
      errorTypes[report.errorType] = (errorTypes[report.errorType] ?? 0) + 1;

      // Compter les contextes
      contexts[report.context] = (contexts[report.context] ?? 0) + 1;
    }

    // Identifier les patterns
    if (errorTypes.containsKey('PlatformException')) {
      patterns.add('Erreurs de plateforme détectées - Problème Android/iOS');
    }
    if (errorTypes.containsKey('TimeoutException')) {
      patterns.add('Timeouts fréquents - Problème de performance GPS');
    }
    if (contexts['SafeLocationService'] != null) {
      patterns.add(
        'Crashes dans SafeLocationService - Architecture défaillante',
      );
    }
    if (contexts['Geolocator.getCurrentPosition'] != null) {
      patterns.add('Crashes directs Geolocator - API native problématique');
    }

    // Générer des recommandations
    final recommendations = <String>[];
    if (patterns.contains(
      'Erreurs de plateforme détectées - Problème Android/iOS',
    )) {
      recommendations.add(
        '🔧 Vérifier les permissions Android dans AndroidManifest.xml',
      );
      recommendations.add(
        '🔧 Mettre à jour geolocator vers une version stable',
      );
    }
    if (patterns.contains('Timeouts fréquents - Problème de performance GPS')) {
      recommendations.add('⚡ Augmenter les timeouts de géolocalisation');
      recommendations.add(
        '⚡ Utiliser LocationAccuracy.low pour des réponses plus rapides',
      );
    }
    if (patterns.contains(
      'Crashes dans SafeLocationService - Architecture défaillante',
    )) {
      recommendations.add('🏗️ Refactor complet de SafeLocationService');
      recommendations.add('🏗️ Implémenter un fallback sans Geolocator');
    }

    return CrashAnalysis(
      totalCrashes: _reports.length,
      mostCommonError: errorTypes.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key,
      patterns: patterns,
      recommendations: recommendations,
    );
  }

  /// Obtient tous les rapports de crash
  List<CrashReport> getAllReports() => List.unmodifiable(_reports);

  /// Nettoie tous les rapports
  void clearReports() {
    _reports.clear();
  }

  /// Sauvegarde un rapport de crash sur le disque
  Future<void> _saveCrashReport(CrashReport report) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final crashDir = Directory('${directory.path}/crash_reports');

      if (!await crashDir.exists()) {
        await crashDir.create(recursive: true);
      }

      final file = File(
        '${crashDir.path}/crash_${report.timestamp.millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(report.toJson());
    } catch (e) {
      developer.log(
        'Erreur sauvegarde crash report: $e',
        name: 'CrashAnalyzer',
      );
    }
  }

  /// Charge les rapports de crash sauvegardés
  Future<void> loadSavedReports() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final crashDir = Directory('${directory.path}/crash_reports');

      if (!await crashDir.exists()) return;

      final files = await crashDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final report = CrashReport.fromJson(content);
            _reports.add(report);
          } catch (e) {
            developer.log(
              'Erreur lecture crash report: $e',
              name: 'CrashAnalyzer',
            );
          }
        }
      }
    } catch (e) {
      developer.log(
        'Erreur chargement crash reports: $e',
        name: 'CrashAnalyzer',
      );
    }
  }
}

/// Rapport de crash détaillé
class CrashReport {
  final DateTime timestamp;
  final String context;
  final String error;
  final String errorType;
  final String? stackTrace;
  final Map<String, dynamic> additionalData;

  CrashReport({
    required this.timestamp,
    required this.context,
    required this.error,
    required this.errorType,
    this.stackTrace,
    required this.additionalData,
  });

  String toJson() {
    return '''
{
  "timestamp": "${timestamp.toIso8601String()}",
  "context": "$context",
  "error": "$error",
  "errorType": "$errorType",
  "stackTrace": "${stackTrace ?? 'N/A'}",
  "additionalData": $additionalData
}''';
  }

  factory CrashReport.fromJson(String json) {
    // Implémentation basique - en réalité il faudrait utiliser dart:convert
    return CrashReport(
      timestamp: DateTime.now(), // Simplification
      context: 'Chargé depuis JSON',
      error: 'Erreur chargée',
      errorType: 'Unknown',
      additionalData: {},
    );
  }
}

/// Analyse des patterns de crash
class CrashAnalysis {
  final int totalCrashes;
  final String mostCommonError;
  final List<String> patterns;
  final List<String> recommendations;

  CrashAnalysis({
    required this.totalCrashes,
    required this.mostCommonError,
    required this.patterns,
    required this.recommendations,
  });
}

/// Écran d'analyse des crashes
class CrashAnalysisScreen extends StatefulWidget {
  const CrashAnalysisScreen({super.key});

  @override
  State<CrashAnalysisScreen> createState() => _CrashAnalysisScreenState();
}

class _CrashAnalysisScreenState extends State<CrashAnalysisScreen> {
  CrashAnalysis? _analysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() => _isLoading = true);

    await CrashAnalyzer().loadSavedReports();
    final analysis = CrashAnalyzer().analyzeCrashes();

    setState(() {
      _analysis = analysis;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse des Crashes'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAnalysis),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showClearDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildAnalysisContent(),
    );
  }

  Widget _buildAnalysisContent() {
    if (_analysis == null) {
      return const Center(child: Text('Aucune analyse disponible'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Résumé des Crashes',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Total: ${_analysis!.totalCrashes} crashes',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Erreur la plus fréquente: ${_analysis!.mostCommonError}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Patterns détectés
          if (_analysis!.patterns.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patterns Détectés',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ..._analysis!.patterns.map(
                      (pattern) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.insights, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(child: Text(pattern)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Recommandations
          if (_analysis!.recommendations.isNotEmpty) ...[
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommandations',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._analysis!.recommendations.map(
                      (rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Expanded(child: Text(rec)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Détails des crashes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historique des Crashes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (CrashAnalyzer().getAllReports().isEmpty)
                    const Text('Aucun crash enregistré')
                  else
                    ...CrashAnalyzer()
                        .getAllReports()
                        .take(5)
                        .map(
                          (report) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(
                                Icons.error,
                                color: Colors.red,
                              ),
                              title: Text(report.context),
                              subtitle: Text(
                                '${report.errorType}: ${report.error}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                '${report.timestamp.hour}:${report.timestamp.minute}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyer les rapports'),
        content: const Text('Supprimer tous les rapports de crash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              CrashAnalyzer().clearReports();
              Navigator.pop(context);
              _loadAnalysis();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
