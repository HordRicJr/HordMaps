import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/advanced_location_service.dart';

class WeatherWidget extends StatelessWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdvancedLocationService>(
      builder: (context, locationService, child) {
        final weather = locationService.currentWeather;

        if (weather == null) {
          return _buildLoadingWeather();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: _getWeatherGradient(weather.description),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weather.cityName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        weather.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        _getWeatherIcon(weather.iconCode),
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${weather.temperature.round()}°C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWeatherDetail(
                    Icons.water_drop,
                    '${weather.humidity}%',
                    'Humidité',
                  ),
                  _buildWeatherDetail(
                    Icons.air,
                    '${weather.windSpeed.toStringAsFixed(1)} km/h',
                    'Vent',
                  ),
                  _buildWeatherDetail(
                    Icons.compress,
                    '${weather.pressure} hPa',
                    'Pression',
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2);
      },
    );
  }

  Widget _buildLoadingWeather() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Chargement météo...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  LinearGradient _getWeatherGradient(String description) {
    if (description.toLowerCase().contains('soleil') ||
        description.toLowerCase().contains('clear')) {
      return LinearGradient(
        colors: [Colors.orange.shade400, Colors.amber.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (description.toLowerCase().contains('pluie') ||
        description.toLowerCase().contains('rain')) {
      return LinearGradient(
        colors: [Colors.blue.shade600, Colors.indigo.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (description.toLowerCase().contains('nuage') ||
        description.toLowerCase().contains('cloud')) {
      return LinearGradient(
        colors: [Colors.grey.shade500, Colors.blueGrey.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [Colors.blue.shade400, Colors.blue.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  IconData _getWeatherIcon(String iconCode) {
    switch (iconCode.substring(0, 2)) {
      case '01':
        return Icons.wb_sunny;
      case '02':
        return Icons.wb_cloudy;
      case '03':
      case '04':
        return Icons.cloud;
      case '09':
      case '10':
        return Icons.grain;
      case '11':
        return Icons.flash_on;
      case '13':
        return Icons.ac_unit;
      case '50':
        return Icons.blur_on;
      default:
        return Icons.wb_sunny;
    }
  }
}
