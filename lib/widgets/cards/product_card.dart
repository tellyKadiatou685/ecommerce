// lib/widgets/cards/product_card.dart - AVEC API CONFIG PROPRE
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../constants/app_colors.dart';
import '../../models/product_model.dart';
import '../../models/like_model.dart';
import '../../models/comment_model.dart';
import '../../models/cart_model.dart';
import '../../services/like_service.dart';
import '../../services/comment_service.dart';
import '../../services/cart_service.dart';
import '../../services/api_config.dart'; // 🔥 NOUVEAU IMPORT - CHEMIN CORRIGÉ
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
  late AnimationController _likeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _likeScaleAnimation;
  
  int _currentIndex = 0;
  bool _isNavigating = false;

  // 🔧 SERVICES
  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  final CartService _cartService = CartService();
  
  // 🔧 VARIABLES LIKES
  bool _isLiked = false;
  bool _isDisliked = false;
  int _likesCount = 0;
  int _dislikesCount = 0;
  bool _isLoadingLikes = true;
  bool _isLikeActionInProgress = false;

  // 🔧 VARIABLES COMMENTAIRES
  int _commentsCount = 0;
  bool _isLoadingComments = false;

  // 🔧 VARIABLES PANIER
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _likeScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.elasticOut),
    );
    
    _fadeController.forward();
    
    // 🔧 INITIALISATION
    _likesCount = widget.product.likesCount ?? 0;
    _commentsCount = widget.product.commentsCount ?? 0;
    
    // Charger les données réelles depuis l'API
    _initializeLikes();
    _initializeComments();
    
    if (widget.product.images.length > 1) {
      _startAutoSlide();
    }

    print('🏗️ [PRODUCT_CARD] Init: ${widget.product.name}');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _fadeController.dispose();
    _likeController.dispose();
    super.dispose();
  }

  // 🔧 INITIALISATION LIKES
  Future<void> _initializeLikes() async {
    try {
      print('🔄 [PRODUCT_CARD] Chargement likes: ${widget.product.name}');
      
      UserReaction? userReaction;
      try {
        userReaction = await _likeService.getUserProductReaction(widget.product.id);
        print('👤 [PRODUCT_CARD] Réaction user: liked=${userReaction?.hasLiked ?? false}');
      } catch (e) {
        userReaction = null;
      }

      LikesCount? likesCount;
      try {
        likesCount = await _likeService.getProductLikesCount(widget.product.id);
        print('📊 [PRODUCT_CARD] Compteurs: likes=${likesCount.likesCount}');
      } catch (e) {
        likesCount = null;
      }

      if (mounted) {
        setState(() {
          _likesCount = likesCount?.likesCount ?? widget.product.likesCount ?? 0;
          _dislikesCount = likesCount?.dislikesCount ?? 0;
          _isLiked = userReaction?.hasLiked ?? false;
          _isDisliked = userReaction?.hasDisliked ?? false;
          _isLoadingLikes = false;
        });
      }
    } catch (e) {
      print('❌ [PRODUCT_CARD] Erreur likes: $e');
      if (mounted) {
        setState(() {
          _isLiked = false;
          _isDisliked = false;
          _likesCount = widget.product.likesCount ?? 0;
          _isLoadingLikes = false;
        });
      }
    }
  }

  // 🔧 INITIALISATION COMMENTAIRES
  Future<void> _initializeComments() async {
    try {
      print('🔄 [PRODUCT_CARD] Chargement commentaires: ${widget.product.name}');
      setState(() {
        _isLoadingComments = true;
      });

      final result = await _commentService.getProductComments(
        widget.product.id,
        page: 1,
        limit: 1, // Juste pour avoir le total
      );

      if (mounted) {
        setState(() {
          _commentsCount = result.pagination.total;
          _isLoadingComments = false;
        });
        print('💬 [PRODUCT_CARD] Commentaires: $_commentsCount');
      }
    } catch (e) {
      print('❌ [PRODUCT_CARD] Erreur commentaires: $e');
      if (mounted) {
        setState(() {
          _commentsCount = widget.product.commentsCount ?? 0;
          _isLoadingComments = false;
        });
      }
    }
  }

  // 🔧 GESTION DU LIKE
  Future<void> _handleLikeToggle() async {
    if (_isLikeActionInProgress || _isLoadingLikes) return;

    setState(() {
      _isLikeActionInProgress = true;
    });

    HapticFeedback.lightImpact();
    _likeController.forward().then((_) {
      _likeController.reverse();
    });

    try {
      final response = await _likeService.toggleProductLike(widget.product.id);
      
      if (mounted) {
        setState(() {
          _likesCount = response.likesCount;
          _dislikesCount = response.dislikesCount;
          
          switch (response.action) {
            case 'liked':
              _isLiked = true;
              _isDisliked = false;
              break;
            case 'unliked':
              _isLiked = false;
              break;
            case 'disliked':
              _isLiked = false;
              _isDisliked = true;
              break;
            case 'undisliked':
              _isDisliked = false;
              break;
          }
          
          _isLikeActionInProgress = false;
        });

        widget.onLike?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(_isLiked ? 'Produit aimé ❤️' : 'Like retiré'),
              ],
            ),
            backgroundColor: _isLiked ? Colors.red : Colors.grey[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ [PRODUCT_CARD] Erreur: $e');
      if (mounted) {
        setState(() {
          _isLikeActionInProgress = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // 🔧 GESTION AJOUT AU PANIER
  Future<void> _handleAddToCart() async {
    if (_isAddingToCart) return;

    try {
      setState(() {
        _isAddingToCart = true;
      });

      print('🛒 [PRODUCT_CARD] Ajout au panier: ${widget.product.name}');
      HapticFeedback.mediumImpact();

      final response = await _cartService.addToCart(widget.product.id, quantity: 1);
      
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });

        // Appeler le callback personnalisé si fourni
        if (widget.onAddToCart != null) {
          widget.onAddToCart!();
        }

        // Afficher le message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.product.name} ajouté au panier',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        print('✅ [PRODUCT_CARD] Produit ajouté avec succès au panier');
      }
    } catch (e) {
      print('❌ [PRODUCT_CARD] Erreur ajout panier: $e');
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
            content: Row(
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(errorMessage),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
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

  // 🔥 NOUVELLE MÉTHODE - UTILISE API CONFIG AU LIEU D'URL DIRECTE
  String _getImageUrl(String originalUrl) {
    // ✅ UTILISE LA MÉTHODE CENTRALISÉE DE L'API CONFIG
    return ApiConfig.getImageUrl(originalUrl);
  }

  void _handleProductTap() {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      if (widget.onTap != null) {
        widget.onTap!();
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: widget.product),
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _isNavigating = false;
            });
            // Recharger au retour
            _initializeLikes();
            _initializeComments();
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
        onTap: _handleProductTap,
        behavior: HitTestBehavior.opaque,
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
                          Icon(Icons.broken_image, size: 30, color: Colors.grey[400]),
                          const SizedBox(height: 4),
                          Text(
                            'Image\nindisponible',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 8, color: Colors.grey[400]),
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

        // Badges stock
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

        // Bouton like
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: _handleLikeToggle,
            child: ScaleTransition(
              scale: _likeScaleAnimation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (_isLiked && !_isLoadingLikes && !_isLikeActionInProgress)
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
                child: _buildLikeIcon(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLikeIcon() {
    if (_isLikeActionInProgress) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _isLiked ? Colors.white : AppColors.primaryOrange,
        ),
      );
    }

    if (_isLoadingLikes) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryOrange,
        ),
      );
    }

    return Icon(
      _isLiked ? Icons.favorite : Icons.favorite_border,
      size: 16,
      color: _isLiked ? Colors.white : Colors.grey[600],
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
            Icon(Icons.shopping_bag, size: 30, color: Colors.grey[400]),
            const SizedBox(height: 4),
            Text(
              'Aucune image',
              style: TextStyle(fontSize: 8, color: Colors.grey[400]),
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

          if (widget.showShopInfo && widget.product.shop != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.product.shopName,
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.product.isShopVerified)
                  Icon(Icons.verified, size: 8, color: AppColors.primaryOrange),
              ],
            ),
            const SizedBox(height: 2),
          ],

          const Expanded(child: SizedBox(height: 1)),

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

          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          // Bouton panier avec animation
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

          // 🔧 COMPTEUR LIKES DYNAMIQUE
          const Icon(Icons.favorite, size: 10, color: Colors.red),
          const SizedBox(width: 1),
          _isLoadingLikes
              ? SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    color: AppColors.primaryOrange,
                  ),
                )
              : Text(
                  '$_likesCount',
                  style: const TextStyle(fontSize: 8),
                ),
          const SizedBox(width: 4),

          // 🔧 COMPTEUR COMMENTAIRES DYNAMIQUE
          Icon(Icons.chat_bubble_outline, size: 10, color: Colors.grey[600]),
          const SizedBox(width: 1),
          _isLoadingComments
              ? SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    color: AppColors.primaryOrange,
                  ),
                )
              : Text(
                  '$_commentsCount',
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