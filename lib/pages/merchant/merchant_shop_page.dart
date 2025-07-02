// lib/pages/merchant/merchant_shop_page.dart - CORRIGÉ AVEC FOLLOWERS
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../widgets/navigation/custom_bottom_navigation.dart';
import '../../pages/merchant/merchant_stats_page.dart';
import '../../services/shop_service.dart';
import '../../services/product_service.dart'; // ✅ ProductStatsResponse est ici
import '../../services/auth_service.dart';
import '../../services/merchant_stats_service.dart';
import '../../models/shop_model.dart' hide Product, MerchantStats; // ✅ Cache Product de shop_model
import '../../models/product_model.dart' as ProductModel; // ✅ Alias pour éviter conflit
import '../../models/user_model.dart';
import '../../models/merchant_stats_model.dart';
import '../../widgets/cards/product_card.dart';
import 'widgets/add_product_modal.dart';
import '../../screens/conversations_screen.dart';
import '../followers/followers_page.dart';


class MerchantShopPage extends StatefulWidget {
  @override
  State<MerchantShopPage> createState() => _MerchantShopPageState();
}

class _MerchantShopPageState extends State<MerchantShopPage> {
  bool _isLoading = true;
  bool _hasShop = false;
  Shop? _currentShop;
  ProductStatsResponse? _productStats; // ✅ Vient de product_service.dart
  ProfileData? _userProfile;
  MerchantStats? _merchantStats;
  List<ProductModel.Product> _shopProducts = []; // ✅ Utilise l'alias
  
  // Controllers pour le formulaire de création
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;
  
  // Image picker pour le logo
  final ImagePicker _picker = ImagePicker();
  File? _logoFile;

  @override
  void initState() {
    super.initState();
    _checkUserShop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _checkUserShop() async {
    try {
      setState(() => _isLoading = true);
      
      final shopService = ShopService();
      final authService = AuthService();
      final merchantStatsService = MerchantStatsService();
      
      // Récupérer le profil utilisateur
      try {
        final userProfile = await authService.getUserProfile();
        setState(() => _userProfile = userProfile);
      } catch (e) {
        print('Erreur profil: $e');
      }
      
      // Vérifier si l'utilisateur a une boutique
      final shop = await shopService.getCurrentUserShop();
      
      if (shop != null) {
        setState(() {
          _hasShop = true;
          _currentShop = shop;
        });
        
        // ✅ Charger les VRAIES données en parallèle
        await Future.wait([
          _loadRealProductStats(),
          _loadMerchantStats(),
          _loadShopProducts(),
        ]);
      }
      
      setState(() => _isLoading = false);
      
    } catch (e) {
      print('Erreur vérification boutique: $e');
      setState(() {
        _hasShop = false;
        _isLoading = false;
      });
    }
  }

  // ✅ CHARGER LES VRAIES STATISTIQUES PRODUITS
  Future<void> _loadRealProductStats() async {
    try {
      final productService = ProductService();
      final token = await _getAuthToken();
      
      if (token != null) {
        final stats = await productService.getProductStats(token);
        setState(() => _productStats = stats);
      }
    } catch (e) {
      print('Erreur stats produits: $e');
    }
  }

  // ✅ CHARGER LES VRAIES STATISTIQUES MARCHAND
  Future<void> _loadMerchantStats() async {
    try {
      final merchantStatsService = MerchantStatsService();
      final stats = await merchantStatsService.getMerchantStats();
      setState(() => _merchantStats = stats);
      
      print('✅ Stats chargées: ${stats.totalOrders} commandes, CA: ${stats.formattedTotalRevenue}');
    } catch (e) {
      print('❌ Erreur stats marchand: $e');
    }
  }

  // ✅ CHARGER LES PRODUITS DE LA BOUTIQUE - CORRIGÉ
  Future<void> _loadShopProducts() async {
    try {
      if (_currentShop == null) return;
      
      final shopService = ShopService();
      final response = await shopService.getShopProducts(_currentShop!.id);
      
      // ✅ SOLUTION: Convertir les Product de shop_model vers product_model
      setState(() {
        _shopProducts = response.products.map((shopProduct) {
          return ProductModel.Product(
            id: shopProduct.id,
            name: shopProduct.name,
            description: shopProduct.description,
            price: shopProduct.price,
            stock: shopProduct.stock,
            videoUrl: shopProduct.videoUrl,
            category: shopProduct.category,
            shopId: shopProduct.shopId,
            userId: shopProduct.userId,
            status: shopProduct.status,
            likesCount: shopProduct.likesCount,
            commentsCount: shopProduct.commentsCount,
            sharesCount: shopProduct.sharesCount,
            createdAt: shopProduct.createdAt.toIso8601String(), // ✅ DateTime → String
            updatedAt: shopProduct.updatedAt.toIso8601String(), // ✅ DateTime → String
            images: shopProduct.images.map((img) => ProductModel.ProductImage(
              id: img.id,
              productId: img.productId,
              imageUrl: img.imageUrl,
            )).toList(),
          );
        }).toList();
      });
      
      print('✅ ${_shopProducts.length} produits convertis et chargés');
    } catch (e) {
      print('❌ Erreur chargement produits: $e');
    }
  }

  Future<String?> _getAuthToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() => _logoFile = File(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection de l\'image'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final shopService = ShopService();
      final token = await _getAuthToken();
      
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final response = await shopService.createShop(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        logoFile: _logoFile,
        token: token,
      );

      if (response.success) {
        setState(() {
          _hasShop = true;
          _currentShop = response.shop;
        });
        
        // Charger les données après création
        await _loadMerchantStats();
        await _loadShopProducts();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Boutique créée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  // ✅ RAFRAÎCHIR TOUTES LES DONNÉES
  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    
    await Future.wait([
      _loadRealProductStats(),
      _loadMerchantStats(),
      _loadShopProducts(),
    ]);
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Données actualisées'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: _isLoading 
          ? _buildLoadingState()
          : _hasShop 
              ? _buildModernShopDashboard()
              : _buildCreateShopForm(),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: 3,
        onTap: (index) => _onBottomNavTap(index),
        userType: 'merchant',
      ),
    );
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => MerchantStatsPage(),
        ));
        break;
      case 1:
      case 2:
      case 4:
        // Navigation gérée dans CustomBottomNavigation
        break;
      case 3:
        // Déjà ici
        break;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement de votre boutique...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NOUVEAU DESIGN MODERNE INSPIRÉ DE L'IMAGE
  Widget _buildModernShopDashboard() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.primaryOrange,
      child: CustomScrollView(
        slivers: [
          // ✅ HEADER SIMPLIFIÉ ET MODERNE
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: false,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar utilisateur
                        _buildUserAvatar(),
                        SizedBox(width: 16),
                        
                        // Infos utilisateur
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _buildWelcomeMessage(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Gérez votre activité commerciale',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Bouton notifications
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // ✅ CONTENU PRINCIPAL
          SliverPadding(
            padding: EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ✅ STATISTIQUES PRINCIPALES (DESIGN INSPIRÉ IMAGE)
                _buildMainStatsCards(),
                SizedBox(height: 24),
                
                // ✅ ACTIONS RAPIDES
                _buildQuickActions(),
                SizedBox(height: 24),
                
                // ✅ CARTE BOUTIQUE (EN BAS COMME DEMANDÉ)
                _buildShopInfoCard(),
                SizedBox(height: 24),
                
                // ✅ NOUVELLE SECTION : MES PRODUITS
                _buildMyProductsSection(),
                SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ AVATAR UTILISATEUR MODERNE
  Widget _buildUserAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: _userProfile?.photo != null && _userProfile!.photo!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                _userProfile!.photo!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
              ),
            )
          : _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    String initials = 'U';
    
    if (_userProfile != null) {
      final firstName = _userProfile!.firstName ?? '';
      final lastName = _userProfile!.lastName ?? '';
      
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        initials = '${firstName[0]}${lastName[0]}'.toUpperCase();
      } else if (firstName.isNotEmpty) {
        initials = firstName[0].toUpperCase();
      }
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryOrange, Color(0xFFF7931E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _buildWelcomeMessage() {
    if (_userProfile != null) {
      final firstName = _userProfile!.firstName ?? '';
      if (firstName.isNotEmpty) {
        return 'Bonjour $firstName';
      }
    }
    return 'Tableau de bord';
  }

  // ✅ STATISTIQUES PRINCIPALES (STYLE IMAGE)
  Widget _buildMainStatsCards() {
    // Calculer les vraies valeurs
    final totalProducts = _shopProducts.length;
    final publishedProducts = _shopProducts.where((p) => p.status == 'published' || p.status == 'PUBLISHED').length;
    final totalOrders = _merchantStats?.totalOrders ?? 0;
    final pendingOrders = _merchantStats?.pendingOrders ?? 0;
    final totalRevenue = _merchantStats?.totalRevenue ?? 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aperçu de votre activité',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: 16),
        
        // Première ligne
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Produits',
                value: publishedProducts.toString(),
                subtitle: '$totalProducts au total',
                icon: Icons.inventory_2_outlined,
                color: Color(0xFF10B981),
                backgroundIcon: Color(0xFF10B981).withOpacity(0.1),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Commandes',
                value: totalOrders.toString(),
                subtitle: '$pendingOrders en attente',
                icon: Icons.shopping_bag_outlined,
                color: Color(0xFF3B82F6),
                backgroundIcon: Color(0xFF3B82F6).withOpacity(0.1),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12),
        
        // Deuxième ligne
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Chiffre d\'affaires',
                value: _formatCurrency(totalRevenue),
                subtitle: 'Ce mois',
                icon: Icons.trending_up_outlined,
                color: Color(0xFFF59E0B),
                backgroundIcon: Color(0xFFF59E0B).withOpacity(0.1),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Taux de succès',
                value: _merchantStats?.formattedSuccessRate ?? '0%',
                subtitle: 'Commandes livrées',
                icon: Icons.check_circle_outline,
                color: Color(0xFF8B5CF6),
                backgroundIcon: Color(0xFF8B5CF6).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ✅ CARTE DE STATISTIQUE MODERNE
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color backgroundIcon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: backgroundIcon,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M FCFA';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K FCFA';
    }
    return '${amount.toInt()} FCFA';
  }

  // ✅ ACTIONS RAPIDES REDESIGNÉES - CORRIGÉ AVEC FOLLOWERS
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Ajouter produit',
                Icons.add_circle_outline,
                LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]),
                () => _addProduct(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Mes Followers', // ✅ Titre correct
                Icons.people_outline, // ✅ Icône followers (plus appropriée)
                LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)]),
                () => _viewFollowers(), // ✅ CORRIGÉ : Appel _viewFollowers
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Statistiques',
                Icons.bar_chart_outlined,
                LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)]),
                () => _goToStats(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Messages clients',
                Icons.message_outlined,
                LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)]),
                () => _goToMessages(),
              ),
            ),
          ],
        ),
      ],
    );
  }
Widget _buildActionCard(String label, IconData icon, Gradient gradient, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ✅ Animation du bouton au tap
          AnimatedContainer(
            duration: Duration(milliseconds: 150),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// ✅ CARTE BOUTIQUE EN BAS (STYLE IMAGE) - CORRIGÉE
Widget _buildShopInfoCard() {
  // ✅ Calculer le total des likes de tous les produits
  final totalLikes = _shopProducts.fold(0, (sum, product) => sum + product.likesCount);
  
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 15,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        // En-tête
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ma boutique',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  SizedBox(width: 4),
                  Text(
                    _currentShop?.verifiedBadge == true ? 'Vérifiée' : 'En attente',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 20),
        
        // Infos boutique
        Row(
          children: [
            // Logo boutique
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: _currentShop?.logo != null && _currentShop!.logo!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        _currentShop!.logo!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildDefaultShopIcon(),
                      ),
                    )
                  : _buildDefaultShopIcon(),
            ),
            
            SizedBox(width: 16),
            
            // Détails boutique
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentShop?.name ?? 'Ma boutique',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _currentShop?.description ?? 'Description de la boutique',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 16, color: Color(0xFF9CA3AF)),
                      SizedBox(width: 4),
                      Text(
                        _currentShop?.phoneNumber ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF9CA3AF)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _currentShop?.address ?? 'Adresse non renseignée',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 20),
        
        // Statistiques rapides boutique
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildShopStat('Créée le', _formatDate(_currentShop?.createdAt)),
              ),
              Container(width: 1, height: 30, color: Color(0xFFE5E7EB)),
              Expanded(
                child: _buildShopStat(
                  'J\'aimes', // ✅ Remplacé "Vues" par "J'aimes"
                  _formatNumber(totalLikes), // ✅ Utilise les vraies données de likes
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ✅ NOUVELLE FONCTION: Formatage des nombres
String _formatNumber(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toString();
}

  Widget _buildDefaultShopIcon() {
    return Icon(
      Icons.store_outlined,
      size: 32,
      color: AppColors.primaryOrange,
    );
  }

  Widget _buildShopStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ✅ NOUVELLE SECTION : MES PRODUITS - AJOUTÉE
  Widget _buildMyProductsSection() {
    final publishedProducts = _shopProducts.where((p) => p.status == 'published' || p.status == 'PUBLISHED').toList();
    final draftProducts = _shopProducts.where((p) => p.status == 'draft' || p.status == 'DRAFT').toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes produits',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: 16),
        
        // Onglets Publiés / Brouillons
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildProductTab(
                  'Publiés (${publishedProducts.length})',
                  true,
                  () => _showPublishedProducts(),
                ),
              ),
              Expanded(
                child: _buildProductTab(
                  'Brouillons (${draftProducts.length})',
                  false,
                  () => _showDraftProducts(),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // Grille des produits
        _shopProducts.isEmpty 
            ? _buildEmptyProductsState()
            : _buildProductsGrid(),
      ],
    );
  }

  Widget _buildProductTab(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Color(0xFF1F2937) : Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProductsState() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: Color(0xFF9CA3AF),
          ),
          SizedBox(height: 16),
          Text(
            'Aucun produit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Commencez par ajouter votre premier produit',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _addProduct,
            icon: Icon(Icons.add, size: 18),
            label: Text('Ajouter un produit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _shopProducts.length,
      itemBuilder: (context, index) {
        final product = _shopProducts[index];
        return Stack(
          children: [
            ProductCard(
              product: product,
              showShopInfo: false, // Pas besoin d'afficher les infos boutique
              onTap: () => _editProduct(product),
            ),
            // Badge statut + bouton publier pour les brouillons
            Positioned(
              top: 8,
              left: 8,
              child: _buildProductStatusBadge(product),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductStatusBadge(ProductModel.Product product) {
    final isPublished = product.status == 'published' || product.status == 'PUBLISHED';
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublished ? Color(0xFF10B981) : Color(0xFFF59E0B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublished ? Icons.visibility : Icons.visibility_off,
            size: 12,
            color: Colors.white,
          ),
          SizedBox(width: 4),
          Text(
            isPublished ? 'Publié' : 'Brouillon',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (!isPublished) ...[
            SizedBox(width: 4),
            GestureDetector(
              onTap: () => _publishProduct(product),
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.publish,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ NOUVELLES MÉTHODES D'ACTION - AJOUTÉES
  void _showPublishedProducts() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📋 Filtrage produits publiés')),
    );
  }

  void _showDraftProducts() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📝 Filtrage brouillons')),
    );
  }

// ✅ NOUVELLE MÉTHODE (à utiliser)
void _editProduct(ProductModel.Product product) {
  if (_currentShop == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Boutique non trouvée'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  // ✅ Ouvrir le modal en mode édition
  showEditProductModal(
    context,
    _currentShop!.id.toString(),
    product,
    onProductUpdated: () async {
      // ✅ Recharger toutes les données après modification
      await Future.wait([
        _loadShopProducts(),
        _loadRealProductStats(),
        _loadMerchantStats(),
      ]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Produit modifié et données actualisées'),
          backgroundColor: Colors.green,
        ),
      );
    },
  );
}
  
void _viewFollowers() {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => FollowersPage(
        userId: null, // null = utilisateur connecté
        title: 'Mes Followers',
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // ✅ Animation slide élégante de droite vers gauche
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: Duration(milliseconds: 350),
    ),
  );
}
  
  Future<void> _publishProduct(ProductModel.Product product) async {
    try {
      final productService = ProductService();
      final token = await _getAuthToken();
      
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Token d\'authentification manquant'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // ✅ Appel API pour publier le produit
      final response = await productService.updateProductStatus(
        productId: product.id, // ✅ Directement l'int
        status: 'PUBLISHED',
        token: token,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${product.name} publié avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Recharger les produits
      await _loadShopProducts();
    } catch (e) {
      print('❌ Erreur publication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la publication'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addProduct() {
    if (_currentShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Boutique non trouvée'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showAddProductModal(
      context,
      _currentShop!.id.toString(),  // ✅ Convertir int → String
      onProductAdded: () async {
        await Future.wait([
          _loadShopProducts(),
          _loadRealProductStats(),
          _loadMerchantStats(),
        ]);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Données actualisées'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  void _goToStats() {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => MerchantStatsPage(),
    ));
  }

  void _goToMessages() {
   Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => ConversationsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    ),
  );
}

  void _editShop() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🔧 Modification de boutique - En développement')),
    );
  }

  // Form creation (reste identique)
  Widget _buildCreateShopForm() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40),
              
              // En-tête de bienvenue
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.store_outlined,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Créez votre boutique',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Quelques informations pour commencer\nà vendre vos produits',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 40),
              
              // Logo de la boutique
              Text(
                'Logo de la boutique',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              SizedBox(height: 12),
              
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _logoFile != null ? AppColors.primaryOrange : Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _logoFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            _logoFile!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 32,
                              color: Color(0xFF9CA3AF),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Ajouter un logo',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Optionnel',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Formulaire
              _buildInputField(
                controller: _nameController,
                label: 'Nom de la boutique',
                icon: Icons.store,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom de la boutique est requis';
                  }
                  if (value.trim().length < 3) {
                    return 'Le nom doit contenir au moins 3 caractères';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 20),
              
              _buildInputField(
                controller: _descriptionController,
                label: 'Description',
                icon: Icons.description,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La description est requise';
                  }
                  if (value.trim().length < 10) {
                    return 'La description doit contenir au moins 10 caractères';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 20),
              
              _buildInputField(
                controller: _phoneController,
                label: 'Numéro de téléphone',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le numéro de téléphone est requis';
                  }
                  if (value.trim().length < 9) {
                    return 'Numéro de téléphone invalide';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 20),
              
              _buildInputField(
                controller: _addressController,
                label: 'Adresse',
                icon: Icons.location_on,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'L\'adresse est requise';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 40),
              
              // Bouton de création
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createShop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isCreating
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Créer ma boutique',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Color(0xFF9CA3AF)),
            hintText: 'Entrez ${label.toLowerCase()}',
            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}