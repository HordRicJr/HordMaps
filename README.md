# HordMaps 🗺️

Une application de navigation moderne et complète développée avec Flutter, offrant une alternative avancée à Google Maps avec navigation temps réel, services en arrière-plan et interface utilisateur sophistiquée.

[![Flutter](https://img.shields.io/badge/Flutter-3.19+-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.3+-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-orange.svg)](CHANGELOG.md)

## � Fonctionnalités principales

### 🗺️ Navigation Avancée
- **Calcul d'itinéraires optimisés** avec OpenStreetMap (OSRM + OpenRouteService)
- **Navigation temps réel** avec suivi GPS continu et instructions turn-by-turn
- **Multi-modal** : 🚗 Voiture, 🏍️ Moto, 🚶 Marche, 🚴 Vélo, 🚌 Transport public
- **Guidance vocale** avec synthèse vocale intelligente
- **Recalcul automatique** en cas de déviation de route
- **Cache intelligent** pour navigation hors-ligne partielle

### 📱 Services en Arrière-plan
- **Navigation persistante** avec service Android foreground
- **Notifications enrichies** avec progression temps réel
- **Overlay système** pour affichage par-dessus autres applications
- **Gestion automatique** des permissions et optimisations batterie
- **Actions rapides** : Arrêt/ouverture depuis notifications

### 🎨 Interface Moderne
- **Material Design 3** avec animations fluides
- **Mode sombre/clair** adaptatif selon préférences système
- **Responsive design** optimisé pour toutes tailles d'écran
- **Composants réutilisables** avec architecture modulaire
- **Performance optimisée** avec gestion d'état Provider

### 🧭 Navigation et itinéraires
- **Calcul d'itinéraires** multi-modal (voiture, vélo, marche, transport public)
- **Instructions vocales** turn-by-turn
- **Navigation temps réel** avec recalcul automatique
- **Évitement du trafic** et routes alternatives
- **Mode navigation** avec interface simplifiée

### ⭐ Gestion des favoris
- **Sauvegarde de lieux** avec descriptions personnalisées
- **Organisation par catégories** (Maison, Travail, Restaurants, etc.)
- **Tags personnalisés** pour une meilleure organisation
- **Import/Export** des favoris
- **Synchronisation** entre appareils

### 📊 Outils de mesure
- **Mesure de distances** entre points
- **Calcul de superficies** pour zones délimitées
- **Mesures en temps réel** avec affichage dynamique
- **Support des unités** métriques et impériales
- **Outil règle** pour mesures précises

### 🎨 Personnalisation avancée
- **Thèmes personnalisables** (clair/sombre)
- **Couleurs configurables** pour interface et marqueurs
- **Types de marqueurs** variés (classique, moderne, épingle, étoile)
- **Taille des éléments** ajustable
- **Animations configurables** avec vitesse variable

### 🔄 Partage et QR codes
- **Partage de position** via lien ou QR code
- **Partage d'itinéraires** avec détails complets
- **Génération de QR codes** pour accès rapide
- **Export vers réseaux sociaux** et messageries
- **Liens courts** pour faciliter le partage

### 📱 Interface utilisateur moderne
- **Design Material 3** avec animations fluides
- **Mode sombre/clair** automatique ou manuel
- **Animations contextuelles** pour une UX premium
- **Feedback haptique** pour les interactions
- **Interface adaptative** tablette/mobile

### ⌨️ Raccourcis et gestes
- **Raccourcis clavier** pour actions courantes
- **Gestes tactiles** intuitifs (pincer, glisser, rotation)
- **Actions rapides** avec feedback visuel
- **Boussole intégrée** pour orientation
- **Navigation clavier** complète

### 💾 Stockage et cache
- **Cache intelligent** pour cartes hors ligne
- **Stockage local** avec SharedPreferences
- **Optimisation mémoire** et performances
- **Nettoyage automatique** du cache
- **Sauvegarde incrémentale** des données

### 🔔 Notifications intelligentes
- **Alertes contextuelles** avec types variés (info, succès, warning, erreur)
- **Feedback haptique** différencié par type
- **Notifications non-intrusives** avec auto-dismissal
- **Historique des notifications** accessible
- **Notifications push** pour navigation

## 🏗️ Architecture technique

### 📁 Structure du projet
```
lib/
├── core/
│   └── theme/
│       └── app_theme.dart          # Thèmes et styles globaux
├── features/
│   ├── favorites/
│   │   └── providers/
│   │       └── favorites_provider.dart    # Gestion des favoris
│   ├── help/
│   │   └── help_screen.dart        # Écran d'aide et raccourcis
│   ├── map/
│   │   ├── providers/
│   │   │   └── map_provider.dart   # État de la carte
│   │   ├── screens/
│   │   │   └── map_screen.dart     # Écran principal de la carte
│   │   └── widgets/
│   │       ├── navigation_panel.dart      # Panneau de navigation
│   │       └── search_results_sheet.dart  # Résultats de recherche
│   ├── navigation/
│   │   └── providers/
│   │       └── navigation_provider.dart   # Calcul d'itinéraires
│   ├── notifications/
│   │   └── notification_provider.dart     # Système de notifications
│   ├── search/
│   │   └── providers/
│   │       └── search_provider.dart       # Recherche et géocodage
│   └── settings/
│       ├── map_customization_screen.dart  # Personnalisation carte
│       └── settings_screen.dart           # Paramètres généraux
└── shared/
    ├── services/
    │   ├── compass_service.dart            # Service boussole
    │   ├── location_service.dart           # Géolocalisation
    │   ├── map_customization_service.dart  # Personnalisation
    │   ├── measurement_service.dart        # Outils de mesure
    │   ├── share_service.dart              # Partage et QR codes
    │   ├── shortcut_service.dart           # Raccourcis et gestes
    │   └── storage_service.dart            # Stockage local
    └── widgets/
        ├── animated_fab.dart               # Bouton flottant animé
        ├── animated_search_bar.dart        # Barre de recherche
        ├── app_drawer.dart                 # Menu latéral
        ├── loading_indicator.dart          # Indicateurs de chargement
        ├── location_button.dart            # Bouton géolocalisation
        └── map_controls.dart               # Contrôles de carte
```

### 🛠️ Technologies utilisées
- **Flutter 3.8.1+** - Framework UI cross-platform
- **OpenStreetMap** - Données cartographiques libres
- **flutter_map** - Rendu de cartes interactives
- **Provider** - Gestion d'état réactive
- **SharedPreferences** - Stockage local léger
- **Geolocator** - Services de géolocalisation
- **Dio** - Client HTTP pour API externes
- **flutter_animate** - Animations fluides

### 🎯 Packages principaux
```yaml
dependencies:
  flutter_map: ^7.0.2              # Cartes interactives
  latlong2: ^0.9.1                 # Coordonnées géographiques
  provider: ^6.1.2                 # Gestion d'état
  shared_preferences: ^2.2.3       # Stockage local
  geolocator: ^12.0.0              # Géolocalisation
  permission_handler: ^11.3.1      # Permissions système
  dio: ^5.4.3+1                    # Client HTTP
  google_fonts: ^6.2.1             # Polices Google
  flutter_animate: ^4.5.0          # Animations
  url_launcher: ^6.3.0             # Lancement d'URLs
  share_plus: ^9.0.0               # Partage système
  qr_flutter: ^4.1.0               # Génération QR codes
```

## 🚀 Installation et utilisation

### Prérequis
- Flutter SDK 3.8.1 ou supérieur
- Dart SDK 3.0.0 ou supérieur
- Android Studio / VS Code avec extension Flutter

### Installation
```bash
# Cloner le projet
git clone https://github.com/votre-repo/hordmaps.git
cd hordmaps

# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run
```

### Configuration
1. **Permissions** : L'application demande automatiquement les permissions de localisation
2. **Cache** : Le cache des cartes est géré automatiquement
3. **Thème** : Le thème s'adapte aux préférences système par défaut

## 📖 Guide d'utilisation

### Navigation de base
- **Glisser** pour déplacer la carte
- **Pincer** pour zoomer/dézoomer
- **Double-tap** pour zoomer rapidement
- **Appui long** pour ajouter un marqueur

### Raccourcis clavier
- **+/-** : Zoom/Dézoom
- **Espace** : Centrer sur position
- **M** : Changer style de carte
- **S** ou **Ctrl+F** : Recherche
- **N** : Mode navigation
- **R** : Outil de mesure
- **Échap** : Menu principal

### Recherche avancée
1. Taper une adresse ou lieu dans la barre de recherche
2. Sélectionner un résultat dans la liste déroulante
3. Le lieu s'affiche avec marqueur et détails
4. Appuyer sur "Itinéraire" pour calculer le chemin

### Gestion des favoris
1. **Ajouter** : Appui long sur un lieu ou bouton étoile
2. **Organiser** : Menu Favoris > Catégories
3. **Modifier** : Appui long sur favori > Éditer
4. **Partager** : Sélectionner favori > Bouton partage

## 🎨 Personnalisation

### Styles de carte disponibles
- **Standard** : Carte classique détaillée
- **Sombre** : Thème nuit pour conduite nocturne
- **Satellite** : Images satellite haute résolution
- **Terrain** : Relief et topographie
- **Cyclable** : Optimisé pour cyclistes

### Options de personnalisation
- **Couleurs** : Primaire et accent configurables
- **Marqueurs** : 5 styles différents avec tailles ajustables
- **Animations** : Vitesse et effets configurables
- **Interface** : Mode sombre/clair automatique

## 🔧 Développement

### Ajouter une nouvelle fonctionnalité
1. Créer le provider dans `features/nom_feature/providers/`
2. Implémenter l'interface dans `features/nom_feature/widgets/`
3. Ajouter les services nécessaires dans `shared/services/`
4. Mettre à jour `main.dart` pour inclure le provider

### Architecture Pattern
- **Provider Pattern** pour la gestion d'état
- **Service Layer** pour la logique métier
- **Repository Pattern** pour l'accès aux données
- **Widget Composition** pour l'interface utilisateur

## 📄 Licence et crédits

### Données cartographiques
- **OpenStreetMap** © contributeurs OpenStreetMap
- **Données sous licence** Open Database License (ODbL)

### Icônes et ressources
- **Material Design Icons** par Google
- **Google Fonts** pour les polices personnalisées

### Licence
Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add some AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📞 Support

Pour toute question ou problème :
- Ouvrir une [issue](https://github.com/votre-repo/hordmaps/issues)
- Consulter la [documentation](https://github.com/votre-repo/hordmaps/wiki)
- Contact : support@hordmaps.com

---

**HordMaps** - Navigation intelligente et moderne 🚗🗺️
