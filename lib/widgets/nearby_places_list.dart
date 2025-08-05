import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/advanced_location_service.dart';

class NearbyPlacesList extends StatelessWidget {
  const NearbyPlacesList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdvancedLocationService>(
      builder: (context, locationService, child) {
        if (locationService.nearbyPlaces.isEmpty) {
          return _buildEmptyState(context);
        }

        return SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: locationService.nearbyPlaces.length,
            itemBuilder: (context, index) {
              final place = locationService.nearbyPlaces[index];
              return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    child: _PlaceCard(place: place),
                  )
                  .animate(delay: Duration(milliseconds: index * 100))
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: 0.3);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Aucun lieu trouvé',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Activez la géolocalisation',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final NearbyPlace place;

  const _PlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _onPlaceTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getCategoryColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getCategoryIcon(),
                      color: _getCategoryColor(),
                      size: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.orange[700]),
                        const SizedBox(width: 2),
                        Text(
                          place.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                place.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatCategory(place.category),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${(place.distance / 1000).toStringAsFixed(1)} km',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPlaceTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation vers ${place.name}'),
        action: SnackBarAction(
          label: 'Voir détails',
          onPressed: () {
            _showPlaceDetails(context);
          },
        ),
      ),
    );
  }

  void _showPlaceDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(),
                    color: _getCategoryColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatCategory(place.category),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.star,
              label: 'Note',
              value: '${place.rating.toStringAsFixed(1)}/5',
              color: Colors.orange,
            ),
            _DetailRow(
              icon: Icons.location_on,
              label: 'Distance',
              value: '${(place.distance / 1000).toStringAsFixed(1)} km',
              color: Colors.blue,
            ),
            _DetailRow(
              icon: Icons.category,
              label: 'Catégorie',
              value: _formatCategory(place.category),
              color: _getCategoryColor(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Navigation vers ${place.name} démarrée'),
                    ),
                  );
                },
                icon: const Icon(Icons.directions),
                label: const Text('Aller ici'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (place.category) {
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

  IconData _getCategoryIcon() {
    switch (place.category) {
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

  String _formatCategory(String category) {
    switch (category) {
      case 'restaurant':
        return 'Restaurant';
      case 'health':
        return 'Santé';
      case 'shopping':
        return 'Commerce';
      case 'tourism':
        return 'Tourisme';
      case 'education':
        return 'Éducation';
      case 'finance':
        return 'Banque';
      case 'fuel':
        return 'Station-service';
      default:
        return 'Lieu';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
