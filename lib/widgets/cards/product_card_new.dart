// lib/widgets/cards/product_card_new.dart - AVEC API CONFIG PROPRE
import 'package:flutter/material.dart';
import 'dart:async';
import '../../constants/app_colors.dart';
import '../../models/product_model.dart';
import '../../services/api_config.dart'; // 🔥 NOUVEAU IMPORT
import '../../pages/product/product_detail_page.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onLike;
  final bool showShopInfo;

  const ProductCard({
    Key? key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.onLike,
    this.showShopInfo = true,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with TickerProviderStateMixin {
  late PageController _pageController;
  Timer? _timer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  int _currentIndex = 0;
  bool _isLiked = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    
    _fadeController.forward();
    
    if (widget.product.images.length > 1) {
      _startAutoSlide();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _fadeController.dispose();
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

  void _pauseAutoSlide() {
    _timer?.cancel();
  }

  void _resumeAutoSlide() {
    if (widget.product.images.length > 1) {
      _startAutoSlide();
    }
  }

  // 🔥 NOUVELLE MÉTHODE - UTILISE API CONFIG AU LIEU D'URL DIRECTE
  String _getImageUrl(String originalUrl) {
    // ✅ UTILISE LA MÉTHODE CENTRALISÉE DE L'API CONFIG
    return ApiConfig.getImageUrl(originalUrl);
  }

  // NAVIGATION UNIQUE ET DIRECTE
  void _handleProductTap() {
    if (_isNavigating) {
      print('⏸️ Navigation déjà en cours, ignoré');
      return;
    }

    print('🎯 === CLIC SUR PRODUIT ===');
    print('📱 Produit: ${widget.product.name}');
    print('🔒 Verrouillage navigation...');
    
    setState(() {
      _isNavigating = true;
    });

    // Petite pause pour éviter les doubles clics
    Future.delayed(const Duration(milliseconds: 50), () {
      if (widget.onTap != null) {
        print('📞 Callback personnalisé détecté');
        widget.onTap!();
      } else {
        print('🚀 Navigation vers ProductDetailPage...');
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              print('🏗️ Construction de ProductDetailPage');
              return ProductDetailPage(product: widget.product);
            },
          ),
        ).then((_) {
          print('🔙 Retour de ProductDetailPage');
          if (mounted) {
            setState(() {
              _isNavigating = false;
            });
          }
        }).catchError((error) {
          print('❌ Erreur navigation: $error');
          if (mounted) {
            setState(() {
              _isNavigating = false;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: _handleProductTap, // UN SEUL GESTIONNAIRE
        behavior: HitTestBehavior.opaque, // Capturer tous les taps
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 140,
                child: _buildProductImageCarousel(),
              ),
              Expanded(
                child: _buildProductInfo(),
              ),
            ],
          ),
        ),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: images.length,
            itemBuilder: (context, index) {
              // 🔥 UTILISE LA NOUVELLE MÉTHODE CENTRALISÉE
              final imageUrl = _getImageUrl(images[index].fullImageUrl);
              
              return Hero(
                tag: 'product-image-${widget.product.id}',
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryOrange,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 30,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Image\nindisponible',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // Indicateurs
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
                  width: _currentIndex == index ? 12 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? AppColors.primaryOrange
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),

        // Badges
        if (widget.product.stock <= 5 && widget.product.stock > 0)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Stock faible',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        if (widget.product.stock == 0)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Rupture',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Bouton like - EMPÊCHE LA PROPAGATION
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: () {
              // EMPÊCHER LA PROPAGATION vers _handleProductTap
              print('❤️ Like: ${widget.product.name}');
              setState(() {
                _isLiked = !_isLiked;
              });
              widget.onLike?.call();
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                size: 14,
                color: _isLiked ? Colors.red : Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag,
              size: 30,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 4),
            Text(
              'Aucune image',
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom du produit
          Text(
            widget.product.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // Info boutique
          if (widget.showShopInfo && widget.product.shop != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.product.shopName,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.product.isShopVerified)
                  Icon(
                    Icons.verified,
                    size: 8,
                    color: AppColors.primaryOrange,
                  ),
              ],
            ),
            const SizedBox(height: 2),
          ],

          const Expanded(child: SizedBox(height: 1)),

          // Prix
          Text(
            widget.product.formattedPrice,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: widget.product.isAvailable 
                  ? AppColors.primaryOrange 
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),

          // Actions
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final likesCount = widget.product.count?.likes ?? widget.product.likesCount;
    final commentsCount = widget.product.count?.comments ?? widget.product.commentsCount;

    return SizedBox(
      height: 20,
      child: Row(
        children: [
          // Bouton panier - EMPÊCHE LA PROPAGATION
          GestureDetector(
            onTap: widget.product.isAvailable 
                ? () {
                    // EMPÊCHER LA PROPAGATION vers _handleProductTap
                    print('🛒 Ajout panier: ${widget.product.name}');
                    if (widget.onAddToCart != null) {
                      widget.onAddToCart!();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${widget.product.name} ajouté au panier'),
                          backgroundColor: AppColors.primaryOrange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  }
                : null,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: widget.product.isAvailable 
                    ? AppColors.primaryOrange 
                    : Colors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.shopping_cart,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Likes
          const Icon(Icons.favorite, size: 10, color: Colors.red),
          const SizedBox(width: 1),
          Text(
            likesCount.toString(),
            style: const TextStyle(fontSize: 8),
          ),
          const SizedBox(width: 4),

          // Commentaires
          Icon(
            Icons.chat_bubble_outline,
            size: 10,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 1),
          Text(
            commentsCount.toString(),
            style: const TextStyle(fontSize: 8),
          ),

          const Spacer(),

          // Stock
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
    );
  }
}