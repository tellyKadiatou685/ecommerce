// lib/widgets/shop/shop_products_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../models/product_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/api_config.dart';
import '../../services/like_service.dart';
import '../../services/cart_service.dart';
import '../../models/like_model.dart';
import '../../models/cart_model.dart';
import '../common/image_viewer_widget.dart';

class ShopProductsWidget extends StatelessWidget {
  final List<Product> products;
  final bool isLoading;

  const ShopProductsWidget({
    Key? key,
    required this.products,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.all(16.0),
        height: 200,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );
    }

    if (products.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(32),
        decoration: _getCardDecoration(),
        child: Column(
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: AppColors.gray400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun produit disponible',
              style: AppTextStyles.heading1.copyWith(
                color: AppColors.gray600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette boutique n\'a pas encore ajouté de produits.',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.gray500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8, // Ajusté pour éviter overflow
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ShopProductCard(product: product);
        },
      ),
    );
  }

  BoxDecoration _getCardDecoration() {
    return BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10.0,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}

// 🔥 COMPOSANT CARTE PRODUIT AVEC CAROUSEL D'IMAGES
class ShopProductCard extends StatefulWidget {
  final Product product;

  const ShopProductCard({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<ShopProductCard> createState() => _ShopProductCardState();
}

class _ShopProductCardState extends State<ShopProductCard> {
  late PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;

  // 🔥 SERVICES
  final LikeService _likeService = LikeService();
  final CartService _cartService = CartService();
  
  // 🔥 VARIABLES LIKES
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isLikeActionInProgress = false;

  // 🔥 VARIABLES PANIER
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Initialiser les compteurs
    _likesCount = widget.product.likesCount ?? 0;
    
    // Debug des URLs d'images
    _debugImageUrls();
    
    // Charger l'état des likes
    _initializeLikes();
    
    // Démarrer le carousel automatique si il y a plusieurs images
    if (widget.product.images.length > 1) {
      _startAutoSlide();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients && widget.product.images.isNotEmpty) {
        final nextIndex = (_currentIndex + 1) % widget.product.images.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // 🔧 INITIALISATION LIKES
  Future<void> _initializeLikes() async {
    try {
      UserReaction? userReaction;
      try {
        userReaction = await _likeService.getUserProductReaction(widget.product.id);
      } catch (e) {
        userReaction = null;
      }

      LikesCount? likesCount;
      try {
        likesCount = await _likeService.getProductLikesCount(widget.product.id);
      } catch (e) {
        likesCount = null;
      }

      if (mounted) {
        setState(() {
          _likesCount = likesCount?.likesCount ?? widget.product.likesCount ?? 0;
          _isLiked = userReaction?.hasLiked ?? false;
        });
      }
    } catch (e) {
      print('❌ [SHOP_PRODUCT] Erreur likes: $e');
    }
  }

  // 🔧 GESTION DU LIKE
  Future<void> _handleLikeToggle() async {
    if (_isLikeActionInProgress) return;

    setState(() {
      _isLikeActionInProgress = true;
    });

    HapticFeedback.lightImpact();

    try {
      final response = await _likeService.toggleProductLike(widget.product.id);
      
      if (mounted) {
        setState(() {
          _likesCount = response.likesCount;
          _isLiked = response.action == 'liked';
          _isLikeActionInProgress = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLiked ? 'Produit aimé ❤️' : 'Like retiré'),
            backgroundColor: _isLiked ? Colors.red : Colors.grey[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ [SHOP_PRODUCT] Erreur like: $e');
      if (mounted) {
        setState(() {
          _isLikeActionInProgress = false;
        });
      }
    }
  }

  // 🔧 GESTION AJOUT AU PANIER
  Future<void> _handleAddToCart() async {
    if (_isAddingToCart || !widget.product.isAvailable) return;

    try {
      setState(() {
        _isAddingToCart = true;
      });

      HapticFeedback.mediumImpact();

      await _cartService.addToCart(widget.product.id, quantity: 1);
      
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.product.name} ajouté au panier'),
            backgroundColor: AppColors.primaryOrange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ [SHOP_PRODUCT] Erreur panier: $e');
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });

        String errorMessage = 'Erreur lors de l\'ajout au panier';
        if (e is CartException) {
          if (e.code == 'SESSION_EXPIRED' || e.code == 'NOT_LOGGED_IN') {
            errorMessage = 'Connectez-vous pour ajouter au panier';
          } else {
            errorMessage = e.message;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 🔧 MÉTHODE DE DEBUG POUR LES URLs D'IMAGES
  void _debugImageUrls() {
    print('🔍 [DEBUG] Analyse des URLs d\'images pour le produit: ${widget.product.name}');
    print('🔍 [DEBUG] Nombre d\'images: ${widget.product.images.length}');
    
    for (int i = 0; i < widget.product.images.length; i++) {
      final image = widget.product.images[i];
      print('🔍 [DEBUG] Image $i:');
      print('  - URL originale: ${image.fullImageUrl}');
      print('  - URL corrigée: ${_getFixedImageUrl(image.fullImageUrl)}');
    }
    
    print('🔍 [DEBUG] ApiConfig.baseUrl: ${ApiConfig.baseUrl}');
  }

  // 🔧 MÉTHODE POUR RÉPARER LES URLs D'IMAGES
  String _getFixedImageUrl(String url) {
    if (url.isEmpty) return '';
    
    // Si l'URL commence déjà par http, on la nettoie
    if (url.startsWith('http')) {
      // Nettoyer les doubles slashes sauf après http:// ou https://
      String cleanUrl = url.replaceAllMapped(
        RegExp(r'(?<!:)//+'),
        (match) => '/',
      );
      
      // Décoder les caractères spéciaux (espaces = %20)
      try {
        cleanUrl = Uri.decodeFull(cleanUrl);
        // Re-encoder proprement
        final uri = Uri.parse(cleanUrl);
        return uri.toString();
      } catch (e) {
        print('❌ Erreur parsing URL: $cleanUrl');
        return cleanUrl;
      }
    }
    
    // Construire l'URL complète
    String baseUrl = ApiConfig.baseUrl;
    
    // S'assurer qu'il n'y a pas de slash à la fin de baseUrl
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    
    // Construire le chemin
    String path = url;
    
    // Ajouter /uploads si ce n'est pas déjà présent
    if (!path.startsWith('/uploads')) {
      if (path.startsWith('/')) {
        path = '/uploads$path';
      } else {
        path = '/uploads/$path';
      }
    }
    
    // S'assurer qu'il y a un slash au début
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    
    // Construire l'URL finale
    String finalUrl = '$baseUrl$path';
    
    // Nettoyer les doubles slashes
    finalUrl = finalUrl.replaceAllMapped(
      RegExp(r'(?<!:)//+'),
      (match) => '/',
    );
    
    print('🔧 [IMAGE_URL] Original: $url -> Fixed: $finalUrl');
    return finalUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔧 AJUSTEMENT FLEX POUR ÉVITER L'OVERFLOW
          Expanded(
            flex: 6, // Augmenté pour plus d'espace pour les images
            child: _buildProductImageCarousel(),
          ),
          Expanded(
            flex: 4, // Ajusté pour les informations
            child: _buildProductInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImageCarousel() {
    final images = widget.product.images;
    
    if (images.isEmpty) {
      return _buildPlaceholderImage();
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16.0),
          ),
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: images.length,
            itemBuilder: (context, index) {
              final imageUrl = _getFixedImageUrl(images[index].fullImageUrl);
              
              return GestureDetector(
                onTap: () {
                  // 🔥 OUVRIR VISUALISEUR D'IMAGES
                  final allImageUrls = images.map((img) => 
                      _getFixedImageUrl(img.fullImageUrl)).toList();
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewerWidget(
                        imageUrls: allImageUrls,
                        initialIndex: index,
                        heroTag: 'shop-product-image-${widget.product.id}-$index',
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'shop-product-image-${widget.product.id}-$index',
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryOrange,
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ [IMAGE_ERROR] URL: $imageUrl');
                      print('❌ [IMAGE_ERROR] Error: $error');
                      
                      // Essayer une URL alternative sans le double slash
                      if (imageUrl.contains('//uploads')) {
                        final fixedUrl = imageUrl.replaceAll('//uploads', '/uploads');
                        print('🔄 [IMAGE_RETRY] Tentative avec: $fixedUrl');
                        
                        return Image.network(
                          fixedUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ [IMAGE_RETRY_FAILED] URL: $fixedUrl');
                            return _buildPlaceholderImage();
                          },
                        );
                      }
                      
                      return _buildPlaceholderImage();
                    },
                  ),
                ),
              );
            },
          ),
        ),

        // 🔥 INDICATEURS DE CAROUSEL
        if (images.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: _currentIndex == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? AppColors.primaryOrange
                        : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

        // 🔥 BADGES DE STATUT
        Positioned(
          top: 8,
          left: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.product.stock <= 5 && widget.product.stock > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Stock faible',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              
              if (widget.product.stock == 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Épuisé',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 🔥 BOUTON LIKE AVEC FONCTIONNALITÉ
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _handleLikeToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (_isLiked && !_isLikeActionInProgress)
                    ? Colors.red.withOpacity(0.9)
                    : Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLikeActionInProgress
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _isLiked ? Colors.white : Colors.red,
                      ),
                    )
                  : Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: _isLiked ? Colors.white : Colors.grey[600],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(16.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryOrange.withOpacity(0.1),
              AppColors.primaryOrange.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag,
              size: 40,
              color: AppColors.primaryOrange.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Aucune image',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primaryOrange.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(8), // Réduit le padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nom du produit
          Text(
            widget.product.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.gray800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 2),
          
          // Description (optionnelle et compacte)
          if (widget.product.description != null && widget.product.description!.isNotEmpty)
            Text(
              widget.product.description!,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 9,
                color: AppColors.gray600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          
          const Spacer(), // Pousse le prix et les actions vers le bas
          
          // Prix
          Text(
            widget.product.formattedPrice,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: widget.product.isAvailable 
                  ? AppColors.primaryOrange 
                  : AppColors.gray500,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // 🔥 LIGNE D'ACTIONS REPOSITIONNÉES COMME ProductCard
          SizedBox(
            height: 20,
            child: Row(
              children: [
                // 🔥 BOUTON PANIER
                GestureDetector(
                  onTap: widget.product.isAvailable ? _handleAddToCart : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: widget.product.isAvailable 
                          ? (_isAddingToCart ? Colors.grey : AppColors.primaryOrange)
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _isAddingToCart 
                        ? const SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.shopping_cart,
                            size: 12,
                            color: Colors.white,
                          ),
                  ),
                ),
                
                const SizedBox(width: 4),
                
                // 🔥 COMPTEUR LIKES AVEC ICÔNE
                const Icon(Icons.favorite, size: 10, color: Colors.red),
                const SizedBox(width: 1),
                Text(
                  '$_likesCount',
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.gray600,
                  ),
                ),
                
                const SizedBox(width: 4),
                
                // 🔥 COMPTEUR COMMENTAIRES AVEC ICÔNE
                Icon(Icons.chat_bubble_outline, size: 10, color: Colors.grey[600]),
                const SizedBox(width: 1),
                Text(
                  '${widget.product.commentsCount ?? 0}',
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.gray600,
                  ),
                ),
                
                const Spacer(),
                
                // 🔥 BADGE STOCK À DROITE
                if (widget.product.stock <= 10 && widget.product.stock > 0)
                  Text(
                    '${widget.product.stock}',
                    style: TextStyle(
                      fontSize: 8,
                      color: widget.product.stock <= 5 ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _getCardDecoration() {
    return BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}