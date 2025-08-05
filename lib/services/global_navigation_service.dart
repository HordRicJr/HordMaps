import 'package:flutter/material.dart';

/// Service global pour la navigation et les actions UI
class GlobalNavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  /// Contexte global de l'application
  static BuildContext? get context => navigatorKey.currentContext;

  /// Ouvre le drawer si disponible
  static void openDrawer() {
    if (scaffoldKey.currentState != null) {
      scaffoldKey.currentState!.openDrawer();
    } else {
      // Si pas de scaffold avec clé, essayer via le contexte
      final context = navigatorKey.currentContext;
      if (context != null) {
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        }
      }
    }
  }

  /// Ferme le drawer si ouvert
  static void closeDrawer() {
    if (scaffoldKey.currentState != null &&
        scaffoldKey.currentState!.isDrawerOpen) {
      scaffoldKey.currentState!.closeDrawer();
    } else {
      Navigator.of(context!).pop();
    }
  }

  /// Navigue vers une route
  static Future<T?> navigateTo<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return navigatorKey.currentState!.pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }

  /// Remplace la route actuelle
  static Future<T?> navigateAndReplace<T extends Object?, TO extends Object?>(
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return navigatorKey.currentState!.pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  /// Retour en arrière
  static void goBack<T extends Object?>([T? result]) {
    return navigatorKey.currentState!.pop<T>(result);
  }

  /// Affiche un SnackBar global
  static void showSnackBar(
    String message, {
    Color? backgroundColor,
    IconData? icon,
  }) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Affiche une dialog globale
  static Future<T?> showGlobalDialog<T>({
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
  }) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      return showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: builder,
      );
    }
    return Future.value(null);
  }
}
