// lib/pages/shop/shop_detail_page.dart - CORRIGÉ AVEC GESTION DES DONNÉES INCOMPLÈTES
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart' as ProductModel;
import '../../services/product_service.dart';
import '../../services/shop_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../widgets/shop/shop_banner_widget.dart';
import '../../widgets/shop/shop_info_widget.dart';
import '../../widgets/shop/shop_stats_widget.dart';
import '../../widgets/shop/shop_contact_widget.dart';
import '../../widgets/shop/shop_products_widget.dart';

// 🔧 CONSTANTES LOCALES POUR LA PAGE
class ShopDetailConstants {
  // Dimensions
  static const double bannerHeight = 200.0;
  static const double avatarSize = 80.0;
  static const double actionButtonSize = 48.0;
  static const double productGridHeight = 250.0;
  
  // Durées d'animation
  static const Duration fadeAnimationDuration = Duration(milliseconds: 300);
  static const Duration slideAnimationDuration = Duration(milliseconds: 800);
  static const Duration buttonAnimationDuration = Duration(milliseconds: 200);
  
  // Rayons de bordure
  static const double mainBorderRadius = 20.0;
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  
  // Marges et padding
  static const EdgeInsets pageMargin = EdgeInsets.all(16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(20.0);
  static const EdgeInsets smallPadding = EdgeInsets.all(8.0);
  
  // Élévations
  static const double cardElevation = 10.0;
  static const double buttonElevation = 8.0;
  
  // Opacités
  static const double overlayOpacity = 0.9;
  static const double shadowOpacity = 0.1;
}

class ShopDetailPage extends StatefulWidget {
  final Shop shop;

  const ShopDetailPage({
    Key? key,
    required this.shop,
  }) : super(key: key);

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _buttonController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _buttonScaleAnimation;
  
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  int _selectedTabIndex = 0;

  // 🔥 DONNÉES DE LA BOUTIQUE
  final ProductService _productService = ProductService();
  final ShopService _shopService = ShopService();
  List<ProductModel.Product> _shopProducts = [];
  bool _isLoadingProducts = true;

  // ✅ NOUVELLES VARIABLES POUR GÉRER LES DONNÉES INCOMPLÈTES
  bool _isLoadingShopDetails = false;
  Shop? _completeShopData;

  // 🔥 CLÉ GLOBALE POUR RAFRAÎCHIR LES WIDGETS (CORRIGÉE)
  final GlobalKey _statsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _setupScrollListener();
    _startAnimations();
    
    // ✅ VÉRIFIER SI ON A DES DONNÉES INCOMPLÈTES
    _checkAndLoadCompleteData();
    
    _loadShopData();
    
    print('🏪 ShopDetailPage initialisée pour: ${widget.shop.name}');
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // 🔧 MÉTHODES D'INITIALISATION
  void _initializeControllers() {
    _slideController = AnimationController(
      duration: ShopDetailConstants.slideAnimationDuration,
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: ShopDetailConstants.buttonAnimationDuration,
      vsync: this,
    );
  }

  void _initializeAnimations() {
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.elasticOut,
    ));
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  void _startAnimations() {
    _slideController.forward();
  }

  void _disposeControllers() {
    _slideController.dispose();
    _buttonController.dispose();
    _scrollController.dispose();
  }

  // ✅ NOUVELLE MÉTHODE : Vérifier et charger les données complètes
  Future<void> _checkAndLoadCompleteData() async {
    // Vérifier si les données sont incomplètes (données minimales)
    final hasMinimalData = widget.shop.phoneNumber.isEmpty || 
                          (widget.shop.address?.isEmpty ?? true) ||
                          widget.shop.owner == null;
    
    if (hasMinimalData) {
      print('🔄 [SHOP] Données incomplètes détectées, chargement des données complètes...');
      await _loadCompleteShopDetails();
    } else {
      _completeShopData = widget.shop;
    }
  }

  // ✅ NOUVELLE MÉTHODE : Charger les données complètes de la boutique
  Future<void> _loadCompleteShopDetails() async {
    try {
      setState(() {
        _isLoadingShopDetails = true;
      });

      final shopDetails = await _shopService.getShopDetails(widget.shop.id);
      
      if (mounted && shopDetails.shop != null) {
        setState(() {
          _completeShopData = shopDetails.shop;
          _isLoadingShopDetails = false;
        });
        
        print('✅ [SHOP] Données complètes chargées pour: ${_completeShopData!.name}');
      }
    } catch (e) {
      print('⚠️ [SHOP] Erreur chargement données complètes: $e');
      if (mounted) {
        setState(() {
          _completeShopData = widget.shop; // Utiliser les données minimales
          _isLoadingShopDetails = false;
        });
      }
    }
  }

  // ✅ GETTER pour obtenir les meilleures données disponibles
  Shop get currentShop => _completeShopData ?? widget.shop;

  // 🔥 CHARGEMENT DES DONNÉES DE LA BOUTIQUE
  Future<void> _loadShopData() async {
    await Future.wait([
      _loadShopProducts(),
      _loadShopStats(),
    ]);
  }

  Future<void> _loadShopProducts() async {
    try {
      print('🔄 [SHOP] Chargement des produits pour la boutique ID: ${widget.shop.id}');
      
      setState(() {
        _isLoadingProducts = true;
      });

      final response = await _productService.getAllProducts(
        page: 1,
        limit: 50,
        status: 'PUBLISHED',
      );
      
      if (mounted) {
        setState(() {
          _shopProducts = response.products.where((p) => 
            p.shopId == widget.shop.id && p.status == 'PUBLISHED'
          ).toList();
          _isLoadingProducts = false;
        });
        
        print('✅ [SHOP] ${_shopProducts.length} produits chargés pour la boutique');
      }
    } catch (e) {
      print('❌ [SHOP] Erreur chargement produits: $e');
      if (mounted) {
        setState(() {
          _shopProducts = [];
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _loadShopStats() async {
    try {
      print('🔄 [SHOP] Chargement des statistiques d\'abonnement');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Les stats des abonnés sont maintenant gérées par ShopStatsWidget
      print('✅ [SHOP] Statistiques déléguées au ShopStatsWidget');
    } catch (e) {
      print('❌ [SHOP] Erreur chargement stats: $e');
    }
  }

  // 🔧 MÉTHODES UTILITAIRES
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShopDetailConstants.buttonBorderRadius),
        ),
        margin: ShopDetailConstants.pageMargin,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShopDetailConstants.buttonBorderRadius),
        ),
        margin: ShopDetailConstants.pageMargin,
      ),
    );
  }

  // 🔥 CALLBACK POUR LA MESSAGERIE
  void _handleStartMessage() {
    print('💬 [SHOP] Démarrer conversation avec: ${currentShop.name}');
    _showSuccessSnackBar('Redirection vers la messagerie - Fonctionnalité bientôt disponible');
  }

  // 🔥 CALLBACK POUR RAFRAÎCHIR LES STATS APRÈS UN FOLLOW/UNFOLLOW (CORRIGÉ)
  void _handleFollowChanged() {
    // Rafraîchir les statistiques via la méthode statique
    ShopStatsWidget.refreshFollowersCount(_statsKey);
  }

  void _shareShop() {
    print('📤 Partager: ${currentShop.name}');
    _showSuccessSnackBar('Partage de la boutique - Fonctionnalité bientôt disponible');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray100,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    // 🔥 COMPOSANT BANNIÈRE AVEC PHOTO COUVERTURE - UTILISE currentShop
                    ShopBannerWidget(
                      shop: currentShop,
                      scrollOffset: _scrollOffset,
                      context: context,
                    ),
                    
                    // 🔥 COMPOSANT INFORMATIONS BOUTIQUE AVEC SERVICE DE FOLLOW INTÉGRÉ - UTILISE currentShop
                    ShopInfoWidget(
                      shop: currentShop,
                      buttonController: _buttonController,
                      buttonScaleAnimation: _buttonScaleAnimation,
                      onStartMessage: _handleStartMessage,
                      onFollowChanged: _handleFollowChanged, // 🔥 CALLBACK POUR RAFRAÎCHIR LES STATS
                    ),
                    
                    // ✅ AFFICHER UN INDICATEUR SI CHARGEMENT EN COURS
                    if (_isLoadingShopDetails)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Chargement des détails...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // 🔥 COMPOSANT STATISTIQUES AVEC SERVICE DE FOLLOW - UTILISE currentShop
                    ShopStatsWidget(
                      key: _statsKey, // 🔥 CLÉ POUR RAFRAÎCHIR
                      shop: currentShop,
                      productsCount: _shopProducts.length,
                      likesCount: 0,
                    ),
                    
                    // 🔥 COMPOSANT CONTACT AMÉLIORÉ - UTILISE currentShop
                    ShopContactWidget(
                      shop: currentShop,
                      onShowSuccess: _showSuccessSnackBar,
                      onShowError: _showErrorSnackBar,
                    ),
                    
                    _buildTabsSection(),
                    _buildTabContent(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final opacity = (_scrollOffset / 200).clamp(0.0, 1.0);
    
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: AppColors.white.withOpacity(opacity),
      elevation: opacity * 4,
      leading: _buildAppBarButton(
        icon: Icons.arrow_back_ios_new,
        onPressed: () => Navigator.pop(context),
      ),
      title: opacity > 0.5 ? Text(
        currentShop.name,
        style: AppTextStyles.heading1.copyWith(fontSize: 18),
      ) : null,
      actions: [
        _buildAppBarButton(
          icon: Icons.share,
          onPressed: _shareShop,
        ),
      ],
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: ShopDetailConstants.smallPadding,
      decoration: _getAppBarButtonDecoration(),
      child: IconButton(
        icon: Icon(icon, color: AppColors.gray800),
        onPressed: onPressed,
      ),
    );
  }

  BoxDecoration _getAppBarButtonDecoration() {
    return BoxDecoration(
      color: AppColors.white.withOpacity(ShopDetailConstants.overlayOpacity),
      borderRadius: BorderRadius.circular(ShopDetailConstants.buttonBorderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(ShopDetailConstants.shadowOpacity),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildTabsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTab('Produits', 0),
          _buildTab('À propos', 1),
          _buildTab('Contact', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isActive = _selectedTabIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
          HapticFeedback.selectionClick();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primaryOrange : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.primaryOrange : AppColors.gray600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return ShopProductsWidget(
          products: _shopProducts,
          isLoading: _isLoadingProducts,
        );
      case 1:
        return _buildAboutTab();
      case 2:
        return ShopContactWidget(
          shop: currentShop,
          onShowSuccess: _showSuccessSnackBar,
          onShowError: _showErrorSnackBar,
        );
      default:
        return ShopProductsWidget(
          products: _shopProducts,
          isLoading: _isLoadingProducts,
        );
    }
  }

  // ✅ MODIFIER _buildAboutTab() pour utiliser currentShop ET gérer les données manquantes
  Widget _buildAboutTab() {
    final shop = currentShop;
    
    return Container(
      margin: ShopDetailConstants.pageMargin,
      padding: ShopDetailConstants.cardPadding,
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'À propos de ${shop.name}',
            style: AppTextStyles.heading1.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          
          // ✅ GESTION DES DONNÉES MANQUANTES
          Text(
            shop.description?.isNotEmpty == true 
                ? shop.description! 
                : 'Cette boutique n\'a pas encore ajouté de description.',
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 14,
              fontStyle: shop.description?.isEmpty == true 
                  ? FontStyle.italic 
                  : FontStyle.normal,
              color: shop.description?.isEmpty == true 
                  ? AppColors.gray500 
                  : AppColors.gray700,
            ),
          ),
          
          const SizedBox(height: 24),
          
          if (shop.owner != null) ...[
            Text(
              'Propriétaire',
              style: AppTextStyles.heading1.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              shop.owner!.fullName,
              style: AppTextStyles.subtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
          ],
          
          if (shop.phoneNumber.isNotEmpty) ...[
            Text(
              'Téléphone: ${shop.phoneNumber}',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 14,
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          if (shop.address?.isNotEmpty == true) ...[
            Text(
              'Adresse: ${shop.address}',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 14,
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          const SizedBox(height: 8),
          Text(
            'Informations supplémentaires',
            style: AppTextStyles.heading1.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Boutique créée le ${_formatDate(shop.createdAt)}',
            style: AppTextStyles.subtitle.copyWith(fontSize: 14),
          ),
          
          // ✅ INDICATEUR DE DONNÉES INCOMPLÈTES
          if (_isLoadingShopDetails) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gray300),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.gray600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chargement des informations complètes de la boutique...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.gray600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🔧 MÉTHODES UTILITAIRES POUR LES DÉCORATIONS
  BoxDecoration _getCardDecoration() {
    return BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(ShopDetailConstants.mainBorderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: ShopDetailConstants.cardElevation,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}