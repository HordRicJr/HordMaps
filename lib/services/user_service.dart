import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserService {
  static const String _userNameKey = 'user_name';
  static const String _userProfileKey = 'user_profile';
  static const String _userStatsKey = 'user_stats';

  // Singleton pattern
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._();
  UserService._();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get prefs async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  // Gestion du nom utilisateur
  Future<void> setUserName(String name) async {
    final p = await prefs;
    await p.setString(_userNameKey, name);
  }

  Future<String> getUserName() async {
    final p = await prefs;
    return p.getString(_userNameKey) ?? '';
  }

  Future<bool> get hasUserName async {
    final name = await getUserName();
    return name.isNotEmpty;
  }

  Future<bool> hasUserProfile() async {
    final profile = await getUserProfile();
    return profile['name']?.toString().isNotEmpty == true;
  }

  // Gestion du profil utilisateur
  Future<void> setUserProfile(Map<String, dynamic> profile) async {
    final p = await prefs;
    final jsonString = json.encode(profile);
    await p.setString(_userProfileKey, jsonString);
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final p = await prefs;
    final jsonString = p.getString(_userProfileKey);
    if (jsonString == null) {
      return {
        'name': '',
        'email': '',
        'avatar': '',
        'preferences': {
          'theme': 'system',
          'voiceGuidance': true,
          'notifications': true,
          'units': 'metric',
        },
      };
    }
    return json.decode(jsonString);
  }

  // Gestion des statistiques utilisateur
  Future<void> updateUserStats({
    int? totalTrips,
    double? totalDistance,
    int? totalFavorites,
    DateTime? lastActivity,
  }) async {
    final currentStats = await getUserStats();

    final updatedStats = {
      'totalTrips': totalTrips ?? currentStats['totalTrips'],
      'totalDistance': totalDistance ?? currentStats['totalDistance'],
      'totalFavorites': totalFavorites ?? currentStats['totalFavorites'],
      'lastActivity': (lastActivity ?? DateTime.now()).toIso8601String(),
    };

    final p = await prefs;
    final jsonString = json.encode(updatedStats);
    await p.setString(_userStatsKey, jsonString);
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final p = await prefs;
    final jsonString = p.getString(_userStatsKey);
    if (jsonString == null) {
      return {
        'totalTrips': 0,
        'totalDistance': 0.0,
        'totalFavorites': 0,
        'lastActivity': DateTime.now().toIso8601String(),
      };
    }
    return json.decode(jsonString);
  }

  // Incrémenter les statistiques
  Future<void> incrementTrips() async {
    final stats = await getUserStats();
    await updateUserStats(totalTrips: (stats['totalTrips'] as int) + 1);
  }

  Future<void> addDistance(double distance) async {
    final stats = await getUserStats();
    await updateUserStats(
      totalDistance: (stats['totalDistance'] as double) + distance,
    );
  }

  Future<void> incrementFavorites() async {
    final stats = await getUserStats();
    await updateUserStats(totalFavorites: (stats['totalFavorites'] as int) + 1);
  }

  Future<void> decrementFavorites() async {
    final stats = await getUserStats();
    final current = stats['totalFavorites'] as int;
    await updateUserStats(totalFavorites: current > 0 ? current - 1 : 0);
  }

  // Effacer toutes les données utilisateur
  Future<void> clearUserData() async {
    final p = await prefs;
    await p.remove(_userNameKey);
    await p.remove(_userProfileKey);
    await p.remove(_userStatsKey);
  }

  // Vérifier si c'est la première utilisation
  Future<bool> get isFirstTime async {
    final p = await prefs;
    return !p.containsKey(_userNameKey);
  }

  // Vérifier si l'utilisateur a un profil configuré
  Future<bool> get hasUserProfileConfigured async {
    final p = await prefs;
    return p.containsKey(_userProfileKey) && p.containsKey(_userNameKey);
  }
}
