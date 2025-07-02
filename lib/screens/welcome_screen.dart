
import 'package:flutter/material.dart';
import '../widgets/layout/header_widget.dart';
import '../widgets/layout/welcome_message.dart';
import '../widgets/ui/primary_button.dart';
import '../widgets/ui/secondary_button.dart';
import '../widgets/ui/page_indicators.dart';
import '../constants/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray100,
      body: SafeArea(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header avec logo
                const HeaderWidget(),
                
                // Message de bienvenue
                const WelcomeMessage(
                  title: "Bienvenue !",
                  subtitle: "Découvrez une nouvelle expérience",
                ),
                
                // Boutons d'action
                PrimaryButton(
                  text: "Créer un compte",
                  onPressed: () => _handleCreateAccount(context),
                ),
                
                const SizedBox(height: 16),
                
                SecondaryButton(
                  text: "Se connecter",
                  onPressed: () => _handleLogin(context),
                ),
                
                // Indicateurs de pagination - Page 0 (première page)
                const PageIndicators(
                  currentPage: 0,
                  totalPages: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCreateAccount(BuildContext context) {
    // Logique pour créer un compte
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Créer un compte - Page suivante')),
    );
  }

  void _handleLogin(BuildContext context) {
    // Navigation vers la page de connexion
    Navigator.pushNamed(context, '/login');
  }
}
