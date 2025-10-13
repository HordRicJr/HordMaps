import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service de journalisation des erreurs avec différents niveaux de sévérité
/// Permet de capturer, stocker et analyser les erreurs de l'application
class ErrorLoggingService {
  static final ErrorLoggingService _instance = ErrorLoggingService._internal();
  factory ErrorLoggingService() => _instance;
  ErrorLoggingService._internal() {
    _initializeErrorHandlers();
  }

  // Niveaux de sévérité
  static const String levelInfo = 'INFO';
  static const String levelWarning = 'WARNING';
  static const String levelError = 'ERROR';
  static const String levelCritical = 'CRITICAL';

  // Limites de stockage
  static const int _maxLogEntries = 1000;
  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5 MB

  // Stockage des logs en mémoire
  final List<Map<String, dynamic>> _memoryLogs = [];
  
  // Identifiant de session unique
  final String _sessionId = const Uuid().v4();
  
  // Compteurs d'erreurs
  int _infoCount = 0;
  int _warningCount = 0;
  int _errorCount = 0;
  int _criticalCount = 0;
  
  // Contrôle du logging
  bool _isInitialized = false;
  bool _isEnabled = true;
  bool _isVerbose = false;
  
  /// Initialise le service de logging
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('error_logging_enabled') ?? true;
      _isVerbose = prefs.getBool('error_logging_verbose') ?? false;
      
      // Nettoyer les anciens logs si nécessaire
      await _cleanupOldLogs();
      
      _isInitialized = true;
      log(levelInfo, 'ErrorLoggingService', 'Service initialisé avec succès');
    } catch (e) {
      debugPrint('❌ Erreur initialisation ErrorLoggingService: $e');
      // Continuer même en cas d'erreur
      _isInitialized = true;
    }
  }
  
  /// Enregistre un message de log
  void log(String level, String source, String message, {dynamic details, StackTrace? stackTrace}) {
    if (!_isEnabled) return;
    
    try {
      // Incrémenter le compteur approprié
      switch (level) {
        case levelInfo:
          _infoCount++;
          break;
        case levelWarning:
          _warningCount++;
          break;
        case levelError:
          _errorCount++;
          break;
        case levelCritical:
          _criticalCount++;
          break;
      }
      
      // Créer l'entrée de log
      final logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'level': level,
        'source': source,
        'message': message,
        'sessionId': _sessionId,
        'details': details != null ? _sanitizeDetails(details) : null,
        'stackTrace': stackTrace?.toString(),
      };
      
      // Ajouter au stockage mémoire
      _addToMemoryLog(logEntry);
      
      // Afficher dans la console de debug
      _printToConsole(logEntry);
      
      // Sauvegarder de manière asynchrone
      _saveLogToStorage(logEntry);
    } catch (e) {
      // Éviter les boucles infinies
      debugPrint('❌ Erreur logging: $e');
    }
  }
  
  /// Enregistre une information
  void info(String source, String message, {dynamic details}) {
    log(levelInfo, source, message, details: details);
  }
  
  /// Enregistre un avertissement
  void warning(String source, String message, {dynamic details}) {
    log(levelWarning, source, message, details: details);
  }
  
  /// Enregistre une erreur
  void error(String source, String message, {dynamic details, StackTrace? stackTrace}) {
    log(levelError, source, message, details: details, stackTrace: stackTrace);
  }
  
  /// Enregistre une erreur critique
  void critical(String source, String message, {dynamic details, StackTrace? stackTrace}) {
    log(levelCritical, source, message, details: details, stackTrace: stackTrace);
  }
  
  /// Enregistre une exception avec stack trace
  void logException(String source, dynamic exception, {StackTrace? stackTrace}) {
    final actualStackTrace = stackTrace ?? StackTrace.current;
    log(
      levelError, 
      source, 
      'Exception: ${exception.toString()}',
      details: exception is Error ? exception.toString() : exception,
      stackTrace: actualStackTrace,
    );
  }
  
  /// Ajoute une entrée au log mémoire
  void _addToMemoryLog(Map<String, dynamic> logEntry) {
    _memoryLogs.add(logEntry);
    
    // Limiter la taille du log mémoire
    if (_memoryLogs.length > _maxLogEntries) {
      _memoryLogs.removeAt(0);
    }
  }
  
  /// Affiche le log dans la console
  void _printToConsole(Map<String, dynamic> logEntry) {
    final level = logEntry['level'];
    final source = logEntry['source'];
    final message = logEntry['message'];
    
    String prefix;
    switch (level) {
      case levelInfo:
        prefix = '📘 INFO';
        break;
      case levelWarning:
        prefix = '⚠️ WARNING';
        break;
      case levelError:
        prefix = '❌ ERROR';
        break;
      case levelCritical:
        prefix = '🚨 CRITICAL';
        break;
      default:
        prefix = '📝 LOG';
    }
    
    debugPrint('$prefix [$source] $message');
    
    // Afficher les détails en mode verbose
    if (_isVerbose) {
      final details = logEntry['details'];
      final stackTrace = logEntry['stackTrace'];
      
      if (details != null) {
        debugPrint('  Details: $details');
      }
      
      if (stackTrace != null) {
        debugPrint('  StackTrace: $stackTrace');
      }
    }
  }
  
  /// Sauvegarde le log dans le stockage persistant
  Future<void> _saveLogToStorage(Map<String, dynamic> logEntry) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final logFile = File('${directory.path}/hordmaps_error_log.json');
        
        // Créer le fichier s'il n'existe pas
        if (!await logFile.exists()) {
          await logFile.create(recursive: true);
          await logFile.writeAsString('[]');
        }
        
        // Vérifier la taille du fichier
        final fileSize = await logFile.length();
        if (fileSize > _maxLogFileSize) {
          // Si trop grand, tronquer le fichier
          await _truncateLogFile(logFile);
        }
        
        // Lire le contenu actuel
        final content = await logFile.readAsString();
        List<dynamic> logs = [];
        
        try {
          logs = jsonDecode(content) as List<dynamic>;
        } catch (e) {
          // Si le JSON est corrompu, réinitialiser
          logs = [];
        }
        
        // Ajouter la nouvelle entrée
        logs.add(logEntry);
        
        // Limiter le nombre d'entrées
        if (logs.length > _maxLogEntries) {
          logs = logs.sublist(logs.length - _maxLogEntries);
        }
        
        // Écrire le fichier
        await logFile.writeAsString(jsonEncode(logs));
      } catch (e) {
        debugPrint('❌ Erreur sauvegarde log: $e');
      }
    }
  }
  
  /// Tronque le fichier de log pour éviter qu'il ne devienne trop grand
  Future<void> _truncateLogFile(File logFile) async {
    try {
      final content = await logFile.readAsString();
      List<dynamic> logs = [];
      
      try {
        logs = jsonDecode(content) as List<dynamic>;
      } catch (e) {
        // Si le JSON est corrompu, réinitialiser
        logs = [];
        await logFile.writeAsString('[]');
        return;
      }
      
      // Garder seulement les 500 dernières entrées
      if (logs.length > 500) {
        logs = logs.sublist(logs.length - 500);
        await logFile.writeAsString(jsonEncode(logs));
      }
    } catch (e) {
      debugPrint('❌ Erreur troncature log: $e');
    }
  }
  
  /// Nettoie les anciens logs
  Future<void> _cleanupOldLogs() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final logFile = File('${directory.path}/hordmaps_error_log.json');
        
        if (await logFile.exists()) {
          final lastModified = await logFile.lastModified();
          final now = DateTime.now();
          
          // Si le fichier date de plus de 7 jours, le supprimer
          if (now.difference(lastModified).inDays > 7) {
            await logFile.delete();
            debugPrint('🧹 Ancien fichier de log supprimé');
          }
        }
      } catch (e) {
        debugPrint('❌ Erreur nettoyage logs: $e');
      }
    }
  }
  
  /// Récupère les logs en mémoire
  List<Map<String, dynamic>> getMemoryLogs() {
    return List.from(_memoryLogs);
  }
  
  /// Récupère les logs stockés
  Future<List<Map<String, dynamic>>> getStoredLogs() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final logFile = File('${directory.path}/hordmaps_error_log.json');
        
        if (await logFile.exists()) {
          final content = await logFile.readAsString();
          final logs = jsonDecode(content) as List<dynamic>;
          return logs.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint('❌ Erreur lecture logs stockés: $e');
      }
    }
    
    return [];
  }
  
  /// Efface tous les logs
  Future<void> clearAllLogs() async {
    _memoryLogs.clear();
    
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final logFile = File('${directory.path}/hordmaps_error_log.json');
        
        if (await logFile.exists()) {
          await logFile.delete();
        }
      } catch (e) {
        debugPrint('❌ Erreur suppression logs: $e');
      }
    }
    
    _infoCount = 0;
    _warningCount = 0;
    _errorCount = 0;
    _criticalCount = 0;
    
    debugPrint('🧹 Tous les logs ont été effacés');
  }
  
  /// Active ou désactive le logging
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('error_logging_enabled', enabled);
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde préférence logging: $e');
    }
    
    debugPrint(_isEnabled ? '✅ Logging activé' : '🛑 Logging désactivé');
  }
  
  /// Active ou désactive le mode verbose
  Future<void> setVerbose(bool verbose) async {
    _isVerbose = verbose;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('error_logging_verbose', verbose);
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde préférence verbose: $e');
    }
    
    debugPrint(_isVerbose ? '✅ Mode verbose activé' : '🛑 Mode verbose désactivé');
  }
  
  /// Obtient les statistiques de logging
  Map<String, dynamic> getStats() {
    return {
      'sessionId': _sessionId,
      'infoCount': _infoCount,
      'warningCount': _warningCount,
      'errorCount': _errorCount,
      'criticalCount': _criticalCount,
      'totalCount': _infoCount + _warningCount + _errorCount + _criticalCount,
      'memoryLogsCount': _memoryLogs.length,
      'isEnabled': _isEnabled,
      'isVerbose': _isVerbose,
    };
  }
  
  /// Sanitize les détails pour éviter les objets trop complexes
  dynamic _sanitizeDetails(dynamic details) {
    if (details == null) return null;
    
    try {
      if (details is String || details is num || details is bool) {
        return details;
      }
      
      if (details is Map) {
        final sanitizedMap = <String, dynamic>{};
        for (final entry in details.entries) {
          final key = entry.key.toString();
          sanitizedMap[key] = _sanitizeDetails(entry.value);
        }
        return sanitizedMap;
      }
      
      if (details is List) {
        return details.map((item) => _sanitizeDetails(item)).toList();
      }
      
      // Pour les autres types, convertir en string
      return details.toString();
    } catch (e) {
      return 'Error sanitizing details: $e';
    }
  }
  
  /// Initialise les handlers d'erreurs globaux
  void _initializeErrorHandlers() {
    // Capture des erreurs Flutter non catchées
    FlutterError.onError = (FlutterErrorDetails details) {
      log(
        levelCritical,
        'Flutter',
        'Uncaught Flutter error: ${details.exception}',
        details: details.exception,
        stackTrace: details.stack,
      );
      
      // Propager l'erreur pour le comportement par défaut
      FlutterError.presentError(details);
    };
    
    // Capture des erreurs de zone non catchées
    runZonedGuarded(() {}, (error, stackTrace) {
      log(
        levelCritical,
        'Zone',
        'Uncaught async error: $error',
        details: error,
        stackTrace: stackTrace,
      );
    });
  }
}