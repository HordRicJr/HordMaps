# Android 15 - Guide des Permissions d'Overlay

## Problème
Android 15 a renforcé les restrictions sur les permissions d'overlay (SYSTEM_ALERT_WINDOW), ce qui peut empêcher l'application de fonctionner correctement.

## Solution pour les utilisateurs

### Étape 1: Activer les permissions d'overlay manuellement

1. **Ouvrez les Paramètres Android**
2. **Naviguez vers Applications** (ou "Apps" selon votre version)
3. **Trouvez "HordMaps"** dans la liste des applications
4. **Appuyez sur l'application HordMaps**
5. **Sélectionnez "Permissions"**
6. **Recherchez "Affichage par-dessus d'autres applications"** ou "Display over other apps"
7. **Activez cette permission**

### Étape 2: Permissions spéciales Android 15

1. **Retournez aux Paramètres**
2. **Allez dans "Permissions spéciales"** ou "Special permissions"
3. **Sélectionnez "Affichage par-dessus d'autres applications"**
4. **Trouvez HordMaps et activez la permission**

### Étape 3: Autorisations système (si nécessaire)

1. **Paramètres → Sécurité et confidentialité**
2. **Permissions d'appareil**
3. **Sources inconnues ou permissions spéciales**
4. **Autorisez HordMaps pour les overlays**

### Étape 4: Redémarrage

1. **Fermez complètement l'application HordMaps**
2. **Redémarrez votre téléphone**
3. **Relancez HordMaps**

## Permissions requises par l'application

L'application demande automatiquement :
- ✅ **Localisation** (GPS)
- ✅ **Notifications**
- ✅ **Overlay/Affichage par-dessus** (pour la navigation)
- ✅ **Alarmes exactes** (pour les alertes de navigation)
- ✅ **Services en arrière-plan** (pour la navigation continue)

## Dépannage

### Si les permissions ne s'activent pas :
1. Vérifiez que vous avez la dernière version d'Android
2. Redémarrez le téléphone après avoir activé les permissions
3. Désinstallez et réinstallez l'application
4. Contactez le support si le problème persiste

### Erreurs courantes :
- **"Permission refusée"** → Suivez les étapes ci-dessus
- **"Overlay bloqué"** → Vérifiez les permissions spéciales
- **"Service indisponible"** → Redémarrez l'application

## Notes techniques

- **Minimum SDK**: Android 7.0 (API 24)
- **Target SDK**: Android 15 (API 35)
- **Permissions critiques**: SYSTEM_ALERT_WINDOW, ACCESS_FINE_LOCATION
- **Conformité**: Android 15 security requirements

---

*Cette documentation est mise à jour pour Android 15. Les étapes peuvent varier selon le fabricant de votre téléphone (Samsung, Xiaomi, OnePlus, etc.).*
