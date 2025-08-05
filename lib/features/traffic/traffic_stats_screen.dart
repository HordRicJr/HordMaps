import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/services/traffic_analysis_service.dart';

class TrafficStatsScreen extends StatefulWidget {
  const TrafficStatsScreen({super.key});

  @override
  State<TrafficStatsScreen> createState() => _TrafficStatsScreenState();
}

class _TrafficStatsScreenState extends State<TrafficStatsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Analyse du trafic'),
        actions: [
          Consumer<TrafficAnalysisService>(
            builder: (context, trafficService, child) {
              return IconButton(
                icon: trafficService.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: trafficService.isLoading
                    ? null
                    : () => trafficService.updateTrafficData(),
                tooltip: 'Actualiser',
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.timeline), text: 'Temps réel'),
            Tab(icon: Icon(Icons.warning), text: 'Incidents'),
            Tab(icon: Icon(Icons.settings), text: 'Paramètres'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRealTimeTab(),
          _buildIncidentsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildRealTimeTab() {
    return Consumer<TrafficAnalysisService>(
      builder: (context, trafficService, child) {
        if (trafficService.trafficSegments.isEmpty &&
            !trafficService.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.traffic, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucune donnée de trafic',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Activez l\'analyse de trafic pour voir les données',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final stats = trafficService.getTrafficStats();

        return RefreshIndicator(
          onRefresh: () => trafficService.updateTrafficData(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatsCard(stats),
              const SizedBox(height: 16),
              _buildSpeedChart(trafficService),
              const SizedBox(height: 16),
              _buildTrafficLevelChart(stats),
              const SizedBox(height: 16),
              _buildRecentSegments(trafficService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncidentsTab() {
    return Consumer<TrafficAnalysisService>(
      builder: (context, trafficService, child) {
        final activeIncidents = trafficService.incidents
            .where((incident) => incident.isActive)
            .toList();

        if (activeIncidents.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'Aucun incident signalé',
                  style: TextStyle(fontSize: 18, color: Colors.green),
                ),
                SizedBox(height: 8),
                Text(
                  'La circulation semble fluide',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeIncidents.length,
          itemBuilder: (context, index) {
            final incident = activeIncidents[index];
            return _buildIncidentCard(incident, trafficService)
                .animate()
                .fadeIn(delay: Duration(milliseconds: index * 100))
                .slideX(begin: 0.3, end: 0);
          },
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return Consumer<TrafficAnalysisService>(
      builder: (context, trafficService, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Paramètres généraux'),
                  ),
                  SwitchListTile(
                    title: const Text('Analyse du trafic'),
                    subtitle: const Text('Activer l\'analyse en temps réel'),
                    value: trafficService.isEnabled,
                    onChanged: trafficService.setEnabled,
                  ),
                  SwitchListTile(
                    title: const Text('Afficher les incidents'),
                    subtitle: const Text('Montrer les accidents et travaux'),
                    value: trafficService.showIncidents,
                    onChanged: trafficService.setShowIncidents,
                  ),
                  SwitchListTile(
                    title: const Text('Éviter le trafic'),
                    subtitle: const Text(
                      'Proposer des itinéraires alternatifs',
                    ),
                    value: trafficService.avoidTraffic,
                    onChanged: trafficService.setAvoidTraffic,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text('Fréquence de mise à jour'),
                  ),
                  ListTile(
                    title: const Text('Intervalle'),
                    subtitle: Text('${trafficService.updateInterval} minutes'),
                    trailing: PopupMenuButton<int>(
                      initialValue: trafficService.updateInterval,
                      onSelected: trafficService.setUpdateInterval,
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 1, child: Text('1 minute')),
                        const PopupMenuItem(value: 2, child: Text('2 minutes')),
                        const PopupMenuItem(value: 5, child: Text('5 minutes')),
                        const PopupMenuItem(
                          value: 10,
                          child: Text('10 minutes'),
                        ),
                        const PopupMenuItem(
                          value: 15,
                          child: Text('15 minutes'),
                        ),
                      ],
                    ),
                  ),
                  if (trafficService.lastUpdate != null)
                    ListTile(
                      title: const Text('Dernière mise à jour'),
                      subtitle: Text(
                        _formatDateTime(trafficService.lastUpdate!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics),
                const SizedBox(width: 8),
                Text(
                  'Statistiques en temps réel',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Vitesse moyenne',
                    '${stats['averageSpeed'].toStringAsFixed(0)} km/h',
                    Icons.speed,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Retard total',
                    '${stats['totalDelay'].toStringAsFixed(0)} min',
                    Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Incidents actifs',
                    '${stats['activeIncidents']}',
                    Icons.warning,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Segments analysés',
                    '${(stats['segmentsByLevel'] as Map<TrafficLevel, int>).values.fold(0, (a, b) => a + b)}',
                    Icons.timeline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedChart(TrafficAnalysisService trafficService) {
    final segments = trafficService.trafficSegments.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vitesses par segment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: segments.isEmpty
                  ? const Center(child: Text('Aucune donnée disponible'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: segments.length,
                      itemBuilder: (context, index) {
                        final segment = segments[index];
                        final height = (segment.speed / 100 * 150)
                            .clamp(10.0, 150.0)
                            .toDouble();

                        return Container(
                          width: 30,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: height,
                                decoration: BoxDecoration(
                                  color: trafficService.getTrafficColor(
                                    segment.level,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${segment.speed.toInt()}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficLevelChart(Map<String, dynamic> stats) {
    final segmentsByLevel = stats['segmentsByLevel'] as Map<TrafficLevel, int>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition du trafic',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...TrafficLevel.values
                .where((level) => level != TrafficLevel.unknown)
                .map((level) {
                  final count = segmentsByLevel[level] ?? 0;
                  final total = segmentsByLevel.values.fold(0, (a, b) => a + b);
                  final percentage = total > 0 ? (count / total * 100) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: context
                                .read<TrafficAnalysisService>()
                                .getTrafficColor(level),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context
                                .read<TrafficAnalysisService>()
                                .getTrafficDescription(level),
                          ),
                        ),
                        Text('$count (${percentage.toStringAsFixed(1)}%)'),
                      ],
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSegments(TrafficAnalysisService trafficService) {
    final recentSegments = trafficService.trafficSegments.take(5).toList();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Segments récents',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...recentSegments.map(
            (segment) => ListTile(
              leading: CircleAvatar(
                backgroundColor: trafficService.getTrafficColor(segment.level),
                child: const Icon(Icons.timeline, color: Colors.white),
              ),
              title: Text('${segment.speed.toStringAsFixed(0)} km/h'),
              subtitle: Text(
                trafficService.getTrafficDescription(segment.level),
              ),
              trailing: segment.delay > 0
                  ? Text('+${segment.delay.toStringAsFixed(0)} min')
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(
    TrafficIncident incident,
    TrafficAnalysisService trafficService,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: trafficService.getTrafficColor(incident.severity),
          child: _getIncidentIcon(incident.type),
        ),
        title: Text(incident.type),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(incident.description),
            const SizedBox(height: 4),
            Text(
              'Depuis ${_formatDuration(DateTime.now().difference(incident.startTime))}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('Détails'),
              ),
            ),
            const PopupMenuItem(
              child: ListTile(
                leading: Icon(Icons.navigation),
                title: Text('Éviter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getIncidentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'accident':
        return const Icon(Icons.car_crash, color: Colors.white);
      case 'travaux':
        return const Icon(Icons.construction, color: Colors.white);
      case 'véhicule en panne':
        return const Icon(Icons.car_repair, color: Colors.white);
      case 'manifestation':
        return const Icon(Icons.group, color: Colors.white);
      case 'contrôle police':
        return const Icon(Icons.local_police, color: Colors.white);
      case 'route fermée':
        return const Icon(Icons.block, color: Colors.white);
      default:
        return const Icon(Icons.warning, color: Colors.white);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}j ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}min';
    } else {
      return '${duration.inMinutes}min';
    }
  }
}
