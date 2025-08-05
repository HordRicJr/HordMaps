import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/advanced_location_service.dart';
import '../services/cache_service.dart';

class RecentRoutesList extends StatelessWidget {
  const RecentRoutesList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdvancedLocationService>(
      builder: (context, locationService, child) {
        return FutureBuilder<List<RecentRoute>>(
          future: _getRecentRoutes(locationService),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingRoutes();
            }

            final routes = snapshot.data ?? [];

            if (routes.isEmpty) {
              return _buildEmptyState(context, locationService);
            }

            return Column(
              children: routes.take(3).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final route = entry.value;

                return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _RouteCard(
                        route: route,
                        onTap: () => _onRouteSelected(context, route),
                      ),
                    )
                    .animate(delay: Duration(milliseconds: index * 100))
                    .slideX(begin: 0.3, duration: 400.ms)
                    .fadeIn();
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AdvancedLocationService locationService,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.route,
            size: 48,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune route récente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Commencez votre premier trajet pour voir l\'historique',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (locationService.nearbyPlaces.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildQuickSuggestions(context, locationService),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions(
    BuildContext context,
    AdvancedLocationService locationService,
  ) {
    final suggestions = locationService.nearbyPlaces.take(3).toList();

    return Column(
      children: [
        Text(
          'Destinations populaires près de vous',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        ...suggestions.map((place) => _buildSuggestionCard(context, place)),
      ],
    );
  }

  Widget _buildSuggestionCard(BuildContext context, NearbyPlace place) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(place.category),
          child: Icon(
            _getCategoryIcon(place.category),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          place.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${(place.distance / 1000).toStringAsFixed(1)} km • ${place.category}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _navigateToPlace(context, place),
      ),
    );
  }

  Future<List<RecentRoute>> _getRecentRoutes(
    AdvancedLocationService locationService,
  ) async {
    try {
      // Récupérer les routes sauvegardées
      final routes = await CacheService.getRecentRoutes();

      // Enrichir avec des données de géolocalisation si disponible
      if (locationService.currentPosition != null) {
        for (var route in routes) {
          route.updateDistanceFromCurrentLocation(
            locationService.currentPosition!.latitude,
            locationService.currentPosition!.longitude,
          );
        }
      }

      return routes..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Erreur récupération routes récentes: $e');
      return [];
    }
  }

  void _onRouteSelected(BuildContext context, RecentRoute route) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation vers ${route.destination}'),
        action: SnackBarAction(
          label: 'Démarrer',
          onPressed: () {
            // Ici on pourrait démarrer la navigation
          },
        ),
      ),
    );
  }

  void _navigateToPlace(BuildContext context, NearbyPlace place) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation vers ${place.name}'),
        action: SnackBarAction(
          label: 'Démarrer',
          onPressed: () {
            // Ici on pourrait démarrer la navigation
          },
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'restaurant':
        return Colors.orange;
      case 'health':
        return Colors.red;
      case 'shopping':
        return Colors.purple;
      case 'tourism':
        return Colors.blue;
      case 'education':
        return Colors.green;
      case 'finance':
        return Colors.indigo;
      case 'fuel':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'restaurant':
        return Icons.restaurant;
      case 'health':
        return Icons.medical_services;
      case 'shopping':
        return Icons.shopping_bag;
      case 'tourism':
        return Icons.attractions;
      case 'education':
        return Icons.school;
      case 'finance':
        return Icons.account_balance;
      case 'fuel':
        return Icons.local_gas_station;
      default:
        return Icons.place;
    }
  }
}

class _LoadingRoutes extends StatelessWidget {
  const _LoadingRoutes();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Chargement des trajets récents...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RecentRoute route;
  final VoidCallback? onTap;

  const _RouteCard({required this.route, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getRouteTypeColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getRouteTypeIcon(),
                color: _getRouteTypeColor(),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${route.departure} → ${route.destination}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        route.formattedDistance,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        route.formattedDuration,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(route.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRouteTypeIcon() {
    switch (route.routeType) {
      case 'walking':
        return Icons.directions_walk;
      case 'cycling':
        return Icons.directions_bike;
      case 'transit':
        return Icons.directions_transit;
      case 'driving':
        return Icons.directions_car;
      default:
        return Icons.directions_car;
    }
  }

  Color _getRouteTypeColor() {
    switch (route.routeType) {
      case 'walking':
        return Colors.green;
      case 'cycling':
        return Colors.blue;
      case 'transit':
        return Colors.orange;
      case 'driving':
        return Colors.indigo;
      default:
        return Colors.indigo;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inHours < 24) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min';
      }
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
