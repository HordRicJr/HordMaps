import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../shared/extensions/color_extensions.dart';

/// Types de notifications
enum NotificationType { info, success, warning, error }

/// Configuration d'une notification
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback? onTap;
  final bool isDismissible;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.type = NotificationType.info,
    this.duration = const Duration(seconds: 4),
    this.onTap,
    this.isDismissible = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  IconData get icon {
    switch (type) {
      case NotificationType.info:
        return Icons.info_outline;
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.error:
        return Icons.error_outline;
    }
  }

  Color getColor(BuildContext context) {
    switch (type) {
      case NotificationType.info:
        return Theme.of(context).primaryColor;
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
    }
  }
}

/// Provider pour la gestion des notifications
class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  bool get hasNotifications => _notifications.isNotEmpty;
  int get notificationCount => _notifications.length;

  /// Affiche une notification
  void showNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
    bool isDismissible = true,
    bool withHaptic = true,
  }) {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      duration: duration,
      onTap: onTap,
      isDismissible: isDismissible,
    );

    _notifications.add(notification);
    notifyListeners();

    // Feedback haptique
    if (withHaptic) {
      switch (type) {
        case NotificationType.success:
          HapticFeedback.lightImpact();
          break;
        case NotificationType.warning:
        case NotificationType.error:
          HapticFeedback.mediumImpact();
          break;
        case NotificationType.info:
          HapticFeedback.selectionClick();
          break;
      }
    }

    // Auto-suppression
    if (duration != Duration.zero) {
      Future.delayed(duration, () {
        dismissNotification(notification.id);
      });
    }
  }

  /// Affiche une notification d'information
  void showInfo(String title, String message, {VoidCallback? onTap}) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.info,
      onTap: onTap,
    );
  }

  /// Affiche une notification de succès
  void showSuccess(String title, String message, {VoidCallback? onTap}) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.success,
      onTap: onTap,
    );
  }

  /// Affiche une notification d'avertissement
  void showWarning(String title, String message, {VoidCallback? onTap}) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.warning,
      duration: const Duration(seconds: 6),
      onTap: onTap,
    );
  }

  /// Affiche une notification d'erreur
  void showError(String title, String message, {VoidCallback? onTap}) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.error,
      duration: const Duration(seconds: 8),
      onTap: onTap,
    );
  }

  /// Supprime une notification
  void dismissNotification(String id) {
    _notifications.removeWhere((notification) => notification.id == id);
    notifyListeners();
  }

  /// Supprime toutes les notifications
  void dismissAll() {
    _notifications.clear();
    notifyListeners();
  }

  /// Supprime les notifications par type
  void dismissByType(NotificationType type) {
    _notifications.removeWhere((notification) => notification.type == type);
    notifyListeners();
  }

  /// Obtient une notification par ID
  AppNotification? getNotification(String id) {
    try {
      return _notifications.firstWhere((notification) => notification.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Vérifie si une notification existe
  bool hasNotification(String id) {
    return _notifications.any((notification) => notification.id == id);
  }

  /// Notifications rapides pour les actions courantes
  void showLocationGranted() {
    showSuccess('Position activée', 'L\'accès à votre position a été accordé');
  }

  void showLocationDenied() {
    showWarning(
      'Position refusée',
      'L\'accès à la position est nécessaire pour certaines fonctionnalités',
    );
  }

  void showRouteCalculated(double distance, double duration) {
    final distanceText = distance < 1000
        ? '${distance.round()}m'
        : '${(distance / 1000).toStringAsFixed(1)}km';
    final durationText = duration < 60
        ? '${duration.round()}min'
        : '${(duration / 60).round()}h${(duration % 60).round()}min';

    showSuccess(
      'Itinéraire calculé',
      'Distance: $distanceText • Durée: $durationText',
    );
  }

  void showFavoriteAdded(String name) {
    showSuccess('Favori ajouté', '"$name" a été ajouté à vos favoris');
  }

  void showFavoriteRemoved(String name) {
    showInfo('Favori supprimé', '"$name" a été retiré de vos favoris');
  }

  void showOfflineMode() {
    showWarning(
      'Mode hors ligne',
      'Certaines fonctionnalités peuvent être limitées',
    );
  }

  void showOnlineMode() {
    showSuccess(
      'Connexion rétablie',
      'Toutes les fonctionnalités sont disponibles',
    );
  }

  void showDownloadStarted(String name) {
    showInfo(
      'Téléchargement en cours',
      'Téléchargement de "$name" en arrière-plan',
    );
  }

  void showDownloadCompleted(String name) {
    showSuccess(
      'Téléchargement terminé',
      '"$name" est maintenant disponible hors ligne',
    );
  }

  void showDownloadFailed(String name) {
    showError('Échec du téléchargement', 'Impossible de télécharger "$name"');
  }

  void showSearchNoResults(String query) {
    showInfo('Aucun résultat', 'Aucun lieu trouvé pour "$query"');
  }

  void showNetworkError() {
    showError('Erreur de connexion', 'Vérifiez votre connexion internet');
  }

  void showGenericError() {
    showError(
      'Une erreur est survenue',
      'Veuillez réessayer dans quelques instants',
    );
  }
}

/// Widget pour afficher les notifications
class NotificationOverlay extends StatelessWidget {
  const NotificationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (!provider.hasNotifications) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Column(
            children: provider.notifications
                .take(3) // Limite à 3 notifications visibles
                .map(
                  (notification) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NotificationCard(notification: notification),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      context.read<NotificationProvider>().dismissNotification(
        widget.notification.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.notification
                        .getColor(context)
                        .withCustomOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: widget.notification.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.notification
                                .getColor(context)
                                .withCustomOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.notification.icon,
                            color: widget.notification.getColor(context),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.notification.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.notification.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (widget.notification.isDismissible)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _dismiss,
                            splashRadius: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
