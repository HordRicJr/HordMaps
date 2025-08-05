import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_service.dart';
import '../features/settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _userProfile = {};
  Map<String, dynamic> _userStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final userService = UserService.instance;
      _userProfile = await userService.getUserProfile();
      _userStats = await userService.getUserStats();
    } catch (e) {
      debugPrint('Erreur lors du chargement des données utilisateur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(isDark),
            const SizedBox(height: 20),
            _buildStatsSection(isDark),
            const SizedBox(height: 20),
            _buildMenuSection(isDark),
            const SizedBox(height: 20),
            _buildContactSection(isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 30,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.person, size: 50, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 16),
          Text(
            _userProfile['name']?.toString().isNotEmpty == true
                ? _userProfile['name'].toString()
                : 'Utilisateur HORDMAPS',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _userProfile['email']?.toString().isNotEmpty == true
                ? _userProfile['email'].toString()
                : 'Explorer le monde avec intelligence',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Modifier le profil'),
            onPressed: () => _editProfile(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2);
  }

  Widget _buildStatsSection(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Trajets',
            '${_userStats['totalTrips'] ?? 0}',
            Icons.route,
            isDark,
          ),
          _buildStatItem(
            'Distance',
            '${(_userStats['totalDistance'] ?? 0.0).toStringAsFixed(1)} km',
            Icons.speed,
            isDark,
          ),
          _buildStatItem(
            'Favoris',
            '${_userStats['totalFavorites'] ?? 0}',
            Icons.favorite,
            isDark,
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3);
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF4CAF50), size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(bool isDark) {
    final menuItems = [
      {
        'title': 'Préférences',
        'subtitle': 'Personnaliser votre expérience',
        'icon': Icons.tune,
        'onTap': () => _openPreferences(),
      },
      {
        'title': 'Historique',
        'subtitle': 'Vos trajets et recherches',
        'icon': Icons.history,
        'onTap': () => _openHistory(),
      },
      {
        'title': 'Mes Favoris',
        'subtitle': 'Lieux sauvegardés',
        'icon': Icons.favorite,
        'onTap': () => _openFavorites(),
      },
      {
        'title': 'Aide et Support',
        'subtitle': 'Assistance et documentation',
        'icon': Icons.help_outline,
        'onTap': () => _openHelp(),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: menuItems
            .map(
              (item) => _buildMenuItem(
                item['title'] as String,
                item['subtitle'] as String,
                item['icon'] as IconData,
                item['onTap'] as VoidCallback,
                isDark,
              ),
            )
            .toList(),
      ),
    ).animate(delay: 400.ms).fadeIn().slideX(begin: 0.3);
  }

  Widget _buildMenuItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF4CAF50), size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      onTap: onTap,
    );
  }

  Widget _buildContactSection(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact & Support',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          _buildContactItem(
            'Email',
            'assounrodrigue5@gmail.com',
            Icons.email,
            () => _launchEmail('assounrodrigue5@gmail.com'),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildContactItem(
            'Téléphone',
            '+22893325501',
            Icons.phone,
            () => _launchPhone('+22893325501'),
            isDark,
          ),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 15),
          Text(
            'HordMaps - Application de navigation intelligente',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Une alternative moderne et complète à Google Maps, offrant une navigation précise, des fonctionnalités avancées et une expérience utilisateur optimale.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Partager l\'app'),
                  onPressed: () => _shareApp(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Paramètres'),
                  onPressed: () => _openSettings(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.3);
  }

  Widget _buildContactItem(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Méthodes de navigation et actions
  void _editProfile() {
    showDialog(
      context: context,
      builder: (context) => _EditProfileDialog(
        currentProfile: _userProfile,
        onSave: (updatedProfile) {
          setState(() {
            _userProfile = updatedProfile;
          });
        },
      ),
    );
  }

  void _openPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _openHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historique'),
        content: const Text(
          'Votre historique de navigation et de recherches sera disponible prochainement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openFavorites() {
    // Navigation vers l'onglet favoris du MainNavigationScreen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aide et Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Besoin d\'aide ?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('• Consultez notre documentation en ligne'),
            Text('• Contactez-nous par email ou téléphone'),
            Text('• Rejoignez notre communauté d\'utilisateurs'),
            SizedBox(height: 15),
            Text(
              'Pour plus d\'informations détaillées, contactez :',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 5),
            Text('📧 assounrodrigue5@gmail.com'),
            Text('📞 +22893325501'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchEmail('assounrodrigue5@gmail.com');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Nous contacter'),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _shareApp() {
    Share.share(
      'Découvrez HordMaps, l\'alternative intelligente à Google Maps ! 🗺️\n\n'
      'Téléchargez l\'application pour une navigation moderne et complète.\n\n'
      'Plus d\'infos : assounrodrigue5@gmail.com',
      subject: 'HordMaps - Navigation intelligente',
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query:
          'subject=Support HordMaps&body=Bonjour, j\'ai une question concernant...',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir l\'email. Copiez : $email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'appeler. Copiez : $phone'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Dialog pour éditer le profil
class _EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> currentProfile;
  final Function(Map<String, dynamic>) onSave;

  const _EditProfileDialog({
    required this.currentProfile,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentProfile['name']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.currentProfile['email']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le profil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _saveProfile(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sauvegarder'),
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final updatedProfile = {
        'name': _nameController.text,
        'email': _emailController.text,
      };

      // Sauvegarder dans UserService
      final userService = UserService.instance;
      await userService.setUserName(_nameController.text);
      await userService.setUserProfile({
        'name': _nameController.text,
        'email': _emailController.text,
      });
      widget.onSave(updatedProfile);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
