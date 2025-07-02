// lib/screens/home_screen.dart - ESPACEMENT CORRIGÉ ENTRE BOUTIQUES ET PRODUITS
import 'package:flutter/material.dart';
import '../widgets/headers/home_header.dart';
import '../widgets/cards/boutique_card.dart';
import '../widgets/sections/products_section.dart';
import '../widgets/navigation/custom_bottom_navigation.dart';
import '../constants/app_colors.dart';
import '../pages/all_products_page.dart';

class HomeScreen extends StatefulWidget {
  final String userType;
  final String userName;

  const HomeScreen({
    Key? key,
    required this.userType,
    required this.userName,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _selectedIndex == 0 ? _buildHomeContent() : _buildOtherPages(),
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _selectedIndex,
        userType: widget.userType,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    return CustomScrollView(
      slivers: [
        // App Bar personnalisé
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.white,
          elevation: 0,
          title: HomeHeader(
            onSearchTap: _handleSearchTap,
            onCameraTap: _handleCameraTap,
            onCartTap: _handleCartTap,
            onSearchChanged: _handleSearchChanged,
          ),
          automaticallyImplyLeading: false,
        ),
        
        // Bannière de bienvenue avec espacement
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 8), // Espacement après header
              WelcomeBanner(
                userType: widget.userType,
                userName: widget.userName,
                onManageStore: _handleManageStore,
              ),
              const SizedBox(height: 24), // Espacement après bannière
            ],
          ),
        ),
        
        // Section Produits Récents EN HAUT
        SliverToBoxAdapter(
          child: Column(
            children: [
              ProductsSection(
                title: '🆕 Produits Récents',
                maxProducts: 4,
                onSeeMore: _handleSeeMoreProducts,
              ),
              const SizedBox(height: 40), // Espacement après produits
            ],
          ),
        ),
        
        // Section Boutiques EN BAS
        SliverToBoxAdapter(
          child: Column(
            children: [
              const BoutiquesSection(),
              const SizedBox(height: 40), // Espacement final
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherPages() {
    String title;
    String description;
    IconData icon;

    switch (_selectedIndex) {
      case 1:
        title = 'Favoris';
        description = 'Vos produits préférés apparaîtront ici.\nAjoutez des produits à vos favoris en appuyant sur ❤️';
        icon = Icons.favorite_outline;
        break;
      case 2:
        title = 'Panier';
        description = 'Votre panier est vide pour le moment.\nAjoutez des produits depuis la page d\'accueil !';
        icon = Icons.shopping_cart_outlined;
        break;
      case 3:
        if (widget.userType == 'merchant') {
          title = 'Ma Boutique';
          description = 'Gérez vos produits, suivez vos ventes\net interagissez avec vos clients.';
          icon = Icons.store_outlined;
        } else {
          title = 'Notifications';
          description = 'Aucune notification pour le moment.\nVous serez notifié des offres spéciales !';
          icon = Icons.notifications_outlined;
        }
        break;
      case 4:
        title = 'Profil';
        description = 'Gérez votre compte, vos paramètres\net vos informations personnelles.';
        icon = Icons.person_outline;
        break;
      default:
        title = 'Page en construction';
        description = 'Cette fonctionnalité sera bientôt disponible !\nRestez connecté pour les mises à jour.';
        icon = Icons.construction;
    }

    return UnderConstructionPage(
      title: title,
      description: description,
      icon: icon,
    );
  }

  // Handlers pour les actions
  void _handleSearchTap() {
    print('🔍 Recherche activée');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AllProductsPage()),
    );
  }

  void _handleSearchChanged(String query) {
    print('🔍 Recherche: $query');
    if (query.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AllProductsPage()),
      );
    }
  }

  void _handleCameraTap() {
    print('📷 Scanner un produit');
    _showSnackBar('Scanner un produit - Fonctionnalité bientôt disponible');
  }

  void _handleCartTap() {
    print('🛒 Ouvrir le panier');
    setState(() {
      _selectedIndex = 2;
    });
  }

  void _handleManageStore() {
    print('🏪 Gérer la boutique');
    setState(() {
      _selectedIndex = 3;
    });
  }

  void _handleSeeMoreProducts() {
    print('🛍️ Voir plus de produits');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AllProductsPage()),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Widget pour les pages en construction (gardé identique)
class UnderConstructionPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const UnderConstructionPage({
    Key? key,
    required this.title,
    required this.description,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 50,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.construction,
                    size: 16,
                    color: AppColors.primaryOrange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'En développement',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}