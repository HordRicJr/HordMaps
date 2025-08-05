import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/user_service.dart';
import 'modern_home_page.dart';

class UserSetupScreen extends StatefulWidget {
  const UserSetupScreen({super.key});

  @override
  State<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends State<UserSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo et titre
                _buildHeader(isDark).animate().fadeIn().scale(),

                const SizedBox(height: 48),

                // Message de bienvenue
                _buildWelcomeMessage(
                  isDark,
                ).animate().fadeIn(delay: 300.ms).slideY(),

                const SizedBox(height: 32),

                // Champ de nom
                _buildNameField(
                  isDark,
                ).animate().fadeIn(delay: 600.ms).slideY(),

                const SizedBox(height: 32),

                // Bouton continuer
                _buildContinueButton(
                  isDark,
                ).animate().fadeIn(delay: 900.ms).slideY(),

                const SizedBox(height: 16),

                // Bouton ignorer
                _buildSkipButton(isDark).animate().fadeIn(delay: 1200.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/images/africa.svg',
              width: 80,
              height: 80,
              colorFilter: const ColorFilter.mode(
                Color(0xFF4CAF50),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'HORDMAPS',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2E2E2E),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeMessage(bool isDark) {
    return Column(
      children: [
        Text(
          'Bienvenue !',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2E2E2E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Pour personnaliser votre expérience, dites-nous comment vous aimeriez être appelé.',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNameField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Votre nom',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Ex: Marie, Pierre, Sophie...',
            prefixIcon: const Icon(
              Icons.person_outline,
              color: Color(0xFF4CAF50),
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF8F8F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez entrer votre nom';
            }
            if (value.trim().length < 2) {
              return 'Le nom doit contenir au moins 2 caractères';
            }
            return null;
          },
          textCapitalization: TextCapitalization.words,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveName,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Continuer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSkipButton(bool isDark) {
    return TextButton(
      onPressed: _isLoading ? null : _skipSetup,
      child: Text(
        'Ignorer pour l\'instant',
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      await UserService.instance.setUserName(name);

      // Initialiser le profil utilisateur
      await UserService.instance.setUserProfile({
        'name': name,
        'email': '',
        'avatar': '',
        'setupDate': DateTime.now().toIso8601String(),
        'preferences': {
          'theme': 'system',
          'voiceGuidance': true,
          'notifications': true,
          'units': 'metric',
        },
      });

      if (mounted) {
        _navigateToMainApp();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _skipSetup() {
    _navigateToMainApp();
  }

  void _navigateToMainApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ModernHomePage(),
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
