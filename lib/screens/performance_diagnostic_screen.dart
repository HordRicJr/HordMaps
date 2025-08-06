import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/performance_monitor_service.dart';
import '../services/event_throttle_service.dart';

/// Écran de diagnostic et optimisation des performances
class PerformanceDiagnosticScreen extends StatefulWidget {
  const PerformanceDiagnosticScreen({super.key});

  @override
  State<PerformanceDiagnosticScreen> createState() =>
      _PerformanceDiagnosticScreenState();
}

class _PerformanceDiagnosticScreenState
    extends State<PerformanceDiagnosticScreen>
    with TickerProviderStateMixin {
  bool _isMonitoring = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Diagnostic Performance'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleMonitoring,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _resetData),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de monitoring
            _buildMonitoringHeader(),
            const SizedBox(height: 20),

            // Métriques temps réel
            _buildRealTimeMetrics(),
            const SizedBox(height: 20),

            // Statistiques d'événements
            _buildEventStats(),
            const SizedBox(height: 20),

            // Optimisations disponibles
            _buildOptimizations(),
            const SizedBox(height: 20),

            // Logs de performance
            _buildPerformanceLogs(),
            const SizedBox(height: 20),

            // Actions d'optimisation
            _buildOptimizationActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isMonitoring
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.grey.shade300, Colors.grey.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isMonitoring)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: const Icon(
                    Icons.monitor_heart,
                    size: 48,
                    color: Colors.white,
                  ),
                );
              },
            )
          else
            const Icon(
              Icons.monitor_heart_outlined,
              size: 48,
              color: Colors.white,
            ),
          const SizedBox(height: 12),
          Text(
            _isMonitoring ? 'MONITORING ACTIF' : 'MONITORING ARRÊTÉ',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isMonitoring
                ? 'Analyse des performances en temps réel'
                : 'Toucher le bouton Play pour démarrer',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeMetrics() {
    return Consumer<PerformanceMonitorService>(
      builder: (context, monitor, child) {
        final metrics = monitor.getCurrentMetrics();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Métriques Temps Réel',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (metrics.isEmpty)
                  const Text(
                    'Démarrer le monitoring pour voir les métriques',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ...metrics.values.map((metric) => _buildMetricRow(metric)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricRow(PerformanceMetric metric) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              metric.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: _getProgressValue(metric),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                metric.isWarning ? Colors.red : Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: metric.isWarning
                  ? Colors.red.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${metric.value.toStringAsFixed(1)} ${metric.unit}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: metric.isWarning
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getProgressValue(PerformanceMetric metric) {
    switch (metric.name) {
      case 'FPS moyen':
        return (metric.value / 60).clamp(0.0, 1.0);
      case 'Utilisation mémoire':
        return (metric.value / 200).clamp(0.0, 1.0);
      case 'Utilisation CPU':
        return (metric.value / 100).clamp(0.0, 1.0);
      default:
        return 0.5;
    }
  }

  Widget _buildEventStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Statistiques d\'Événements',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            FutureBuilder<Map<String, int>>(
              future: Future.value(EventThrottleService().getEventStats()),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {};

                if (stats.isEmpty) {
                  return const Text(
                    'Aucun événement enregistré',
                    style: TextStyle(color: Colors.grey),
                  );
                }

                return Column(
                  children: stats.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              entry.key.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getEventColor(entry.value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getEventColor(int count) {
    if (count > 50) return Colors.red;
    if (count > 20) return Colors.orange;
    if (count > 10) return Colors.blue;
    return Colors.green;
  }

  Widget _buildOptimizations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Optimisations Appliquées',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...[
              '✅ Throttling des événements de localisation (500ms)',
              '✅ Limitation des mises à jour de carte (100ms)',
              '✅ Debounce des entrées de recherche (300ms)',
              '✅ Pool d\'objets pour réduire les allocations',
              '✅ Monitoring des frames à 60fps max',
              '✅ Nettoyage automatique des timers',
              '✅ Gestion optimisée des streams',
            ].map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text.substring(2), // Retirer l'emoji
                        style: const TextStyle(fontSize: 13),
                      ),
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

  Widget _buildPerformanceLogs() {
    return Consumer<PerformanceMonitorService>(
      builder: (context, monitor, child) {
        final logs = monitor.getPerformanceLogs();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Logs de Performance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  height: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun log disponible',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log =
                                logs[logs.length -
                                    1 -
                                    index]; // Plus récent en haut
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                log,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptimizationActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  'Actions d\'Optimisation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _forceGarbageCollection,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Nettoyer Mémoire'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetEventStats,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Stats'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exportDiagnosticReport,
                icon: const Icon(Icons.download),
                label: const Text('Exporter Rapport Diagnostic'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
    });

    if (_isMonitoring) {
      PerformanceMonitorService().startMonitoring();
      _pulseController.repeat();
    } else {
      PerformanceMonitorService().stopMonitoring();
      _pulseController.stop();
    }
  }

  void _resetData() {
    PerformanceMonitorService().clearData();
    EventThrottleService().resetStats();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Données de performance réinitialisées'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _forceGarbageCollection() {
    MemoryOptimizationService().forceGarbageCollection();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nettoyage mémoire effectué'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _resetEventStats() {
    EventThrottleService().resetStats();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Statistiques d\'événements réinitialisées'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _exportDiagnosticReport() {
    // Simulation de l'export - en réalité il faudrait sauvegarder dans un fichier
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rapport diagnostic exporté (simulé)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}
