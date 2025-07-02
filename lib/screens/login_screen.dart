import 'package:flutter/material.dart';
import '../widgets/layout/login_header.dart';
import '../widgets/ui/custom_text_field.dart';
import '../widgets/ui/primary_button.dart';
import '../widgets/ui/secondary_button.dart';
import '../widgets/ui/text_link.dart';
import '../widgets/ui/page_indicators.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart'; // 🔧 AJOUTÉ POUR UTILISER L'IP CORRECTE
import '../models/user_model.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray100,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray700),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header avec logo
                    const LoginHeader(),
                    
                    // Titre de la page
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          const Text(
                            "Welcome back !",
                            style: AppTextStyles.heading1,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Connectez-vous à votre compte",
                            style: AppTextStyles.subtitle,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Champs de saisie
                    CustomTextField(
                      labelText: "Email",
                      hintText: "Entrez votre email",
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Veuillez entrer un email valide';
                        }
                        return null;
                      },
                    ),
                    
                    CustomTextField(
                      labelText: "Mot de passe",
                      hintText: "Entrez votre mot de passe",
                      controller: _passwordController,
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre mot de passe';
                        }
                        return null;
                      },
                    ),
                    
                    // Lien "Mot de passe oublié"
                    Container(
                      alignment: Alignment.centerRight,
                      margin: const EdgeInsets.only(right: 24, top: 8),
                      child: TextLink(
                        text: "Mot de passe oublié ?",
                        onTap: _handleForgotPassword,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Bouton de connexion avec état de chargement
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: SizedBox(
                              height: 56,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                            ),
                          )
                        : PrimaryButton(
                            text: "Se connecter",
                            onPressed: _handleLogin,
                          ),
                    
                    const SizedBox(height: 16),
                    
                    // Bouton retour vers l'accueil
                    SecondaryButton(
                      text: "Retour à l'accueil",
                      onPressed: () => Navigator.pop(context),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Lien d'inscription
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Vous n'avez pas de compte ? ",
                            style: TextStyle(
                              color: AppColors.gray600,
                              fontSize: 14,
                            ),
                          ),
                          TextLink(
                            text: "Inscrivez-vous",
                            onTap: _handleSignUp,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                    
                    // Indicateurs de pagination
                    const PageIndicators(
                      currentPage: 1,
                      totalPages: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔧 FONCTION DE CONNEXION CORRIGÉE
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('🔍 Test de connexion au serveur...');
      print('🌐 URL utilisée: ${ApiConfig.baseUrl}'); // 🔧 AJOUTÉ POUR DEBUG
      
      final isConnected = await _authService.testConnection();
      if (!isConnected) {
        // 🔧 MESSAGE D'ERREUR CORRIGÉ AVEC L'IP DYNAMIQUE
        _showErrorDialog(
          'Serveur inaccessible',
          'Impossible de contacter le serveur.\n\nVérifiez que :\n• Votre backend est démarré\n• L\'adresse IP est correcte (${ApiConfig.baseUrl})\n• Vous êtes sur le même réseau WiFi',
        );
        return;
      }

      print('✅ Serveur accessible, tentative de connexion...');
      
      final response = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (response.status == 'success' && response.user != null) {
        print('✅ Connexion réussie ! Redirection vers HomeScreen...');
        
        // ✨ NAVIGATION VERS HOMESCREEN
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                userType: response.user!.role?.toLowerCase() == 'client' 
                    ? 'client' 
                    : 'merchant',
                userName: '${response.user!.firstName} ${response.user!.lastName}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Erreur: $e');
      String errorMessage = 'Une erreur est survenue';
      
      if (e is ApiError) {
        switch (e.code) {
          case 'INVALID_CREDENTIALS':
            errorMessage = 'Email ou mot de passe incorrect';
            break;
          case 'NOT_VERIFIED':
            errorMessage = 'Compte non vérifié. Vérifiez vos emails.';
            break;
          case 'NETWORK_ERROR':
            errorMessage = e.message;
            break;
          default:
            errorMessage = e.message;
        }
      }
      
      _showErrorDialog('Erreur de connexion', errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔧 DIALOG D'ERREUR AMÉLIORÉ
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            // 🔧 AJOUTÉ : Info de debug
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔍 Debug Info:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'URL: ${ApiConfig.baseUrl}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                  Text(
                    'Endpoint: ${ApiConfig.loginEndpoint}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          // 🔧 AJOUTÉ : Bouton pour retester
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogin(); // Retester la connexion
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.green)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fermer le dialog
              Navigator.pop(context); // Retourner à l'écran d'accueil
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleSignUp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Redirection vers l\'inscription')),
    );
  }

  void _handleForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Récupération du mot de passe')),
    );
  }
}