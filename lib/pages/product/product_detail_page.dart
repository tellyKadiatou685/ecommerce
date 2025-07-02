// lib/pages/product/product_detail_page.dart - VERSION COMPLÈTE CORRIGÉE
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_model.dart';
import '../../models/like_model.dart';
import '../../models/comment_model.dart';
import '../../models/cart_model.dart';
import '../../models/shop_model.dart' as ShopModel;
import '../../services/like_service.dart';
import '../../services/comment_service.dart';
import '../../services/cart_service.dart';
import '../../services/shop_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_dimensions.dart';
import '../shop/shop_detail_page.dart';

// 🔧 CONSTANTES LOCALES POUR LA PAGE
class ProductDetailConstants {
  // Dimensions
  static const double imageCarouselHeight = 320.0;
  static const double likeButtonSize = 48.0;
  static const double quantityButtonSize = 40.0;
  static const double fabHeight = 56.0;
  
  // Durées d'animation
  static const Duration fadeAnimationDuration = Duration(milliseconds: 300);
  static const Duration slideAnimationDuration = Duration(milliseconds: 800);
  static const Duration likeAnimationDuration = Duration(milliseconds: 200);
  
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

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fabController;
  late AnimationController _slideController;
  late AnimationController _likeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _likeScaleAnimation;
  
  int _currentImageIndex = 0;
  int _quantity = 1;
  bool _showFullDescription = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  // 🔥 SYSTÈME DE LIKES
  final LikeService _likeService = LikeService();
  bool _isLiked = false;
  bool _isDisliked = false;
  int _likesCount = 0;
  int _dislikesCount = 0;
  bool _isLoadingLikes = true;
  bool _isLikeActionInProgress = false;

  // 🔥 SYSTÈME DE COMMENTAIRES RÉEL
  final CommentService _commentService = CommentService();
  List<Comment> _comments = [];
  CommentPagination? _commentsPagination;
  bool _isLoadingComments = true;
  bool _isAddingComment = false;
  bool _isLoadingMoreComments = false;
  final Map<int, bool> _isLoadingReplies = {};
  final Map<int, bool> _showReplies = {};
  final Map<int, TextEditingController> _replyControllers = {};
  final Map<int, bool> _showReplyField = {};

  // 🔥 SYSTÈME DE PANIER
  final CartService _cartService = CartService();

  // 🔥 SYSTÈME DE BOUTIQUE
  final ShopService _shopService = ShopService();
  int _cartItemsCount = 0;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _initializeLikes();
    _initializeComments();
    _initializeCart();
    _setupScrollListener();
    _startAnimations();
    
    print('🎯 ProductDetailPage initialisée pour: ${widget.product.name}');
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // 🔧 MÉTHODES D'INITIALISATION
  void _initializeControllers() {
    _pageController = PageController();
    
    _fabController = AnimationController(
      duration: ProductDetailConstants.fadeAnimationDuration,
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: ProductDetailConstants.slideAnimationDuration,
      vsync: this,
    );

    _likeController = AnimationController(
      duration: ProductDetailConstants.likeAnimationDuration,
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

    _likeScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _likeController,
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
    _fabController.forward();
  }

  void _disposeControllers() {
    _pageController.dispose();
    _fabController.dispose();
    _slideController.dispose();
    _likeController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    
    // Nettoyer les contrôleurs de réponses
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
  }

  // 🔥 GESTION DES LIKES
  Future<void> _initializeLikes() async {
    try {
      print('🔄 [DETAIL] Chargement des likes pour: ${widget.product.name}');
      
      setState(() {
        _isLoadingLikes = true;
        _isLiked = false;
        _isDisliked = false;
        _likesCount = widget.product.likesCount ?? 0;
      });

      final likesCount = await _likeService.getProductLikesCount(widget.product.id);
      
      UserReaction? userReaction;
      try {
        userReaction = await _likeService.getUserProductReaction(widget.product.id);
      } catch (e) {
        print('⚠️ [DETAIL] Erreur réaction user: $e');
        userReaction = UserReaction.defaultState();
      }

      if (mounted) {
        setState(() {
          _likesCount = likesCount.likesCount;
          _dislikesCount = likesCount.dislikesCount;
          _isLiked = userReaction?.hasLiked ?? false;
          _isDisliked = userReaction?.hasDisliked ?? false;
          _isLoadingLikes = false;
        });
      }
    } catch (e) {
      print('❌ [DETAIL] Erreur initialisation likes: $e');
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

  // 🔥 GESTION DES COMMENTAIRES RÉELS
  Future<void> _initializeComments() async {
    try {
      print('🔄 [DETAIL] Chargement des commentaires pour: ${widget.product.name}');
      
      setState(() {
        _isLoadingComments = true;
      });

      final result = await _commentService.getProductComments(widget.product.id);
      
      if (mounted) {
        setState(() {
          _comments = result.comments;
          _commentsPagination = result.pagination;
          _isLoadingComments = false;
        });
        
        print('✅ [DETAIL] ${_comments.length} commentaires chargés');
      }
    } catch (e) {
      print('❌ [DETAIL] Erreur chargement commentaires: $e');
      if (mounted) {
        setState(() {
          _comments = [];
          _isLoadingComments = false;
        });
      }
    }
  }

  // 🔥 GESTION DU PANIER
  Future<void> _initializeCart() async {
    try {
      print('🔄 [DETAIL] Chargement du panier');
      
      // Écouter les changements du panier
      _cartService.cartStream.listen((cart) {
        if (mounted) {
          setState(() {
            _cartItemsCount = cart?.itemsCount ?? 0;
          });
        }
      });

      // Charger le compteur initial
      final count = await _cartService.getCartItemsCount();
      if (mounted) {
        setState(() {
          _cartItemsCount = count;
        });
        print('🛒 [DETAIL] Articles dans le panier: $count');
      }
    } catch (e) {
      print('❌ [DETAIL] Erreur chargement panier: $e');
      if (mounted) {
        setState(() {
          _cartItemsCount = 0;
        });
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMoreComments || 
        _commentsPagination == null || 
        !_commentsPagination!.hasNextPage) return;

    try {
      setState(() {
        _isLoadingMoreComments = true;
      });

      final result = await _commentService.getProductComments(
        widget.product.id,
        page: _commentsPagination!.page + 1,
      );
      
      if (mounted) {
        setState(() {
          _comments.addAll(result.comments);
          _commentsPagination = result.pagination;
          _isLoadingMoreComments = false;
        });
      }
    } catch (e) {
      print('❌ [DETAIL] Erreur chargement plus de commentaires: $e');
      if (mounted) {
        setState(() {
          _isLoadingMoreComments = false;
        });
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || _isAddingComment) return;

    try {
      setState(() {
        _isAddingComment = true;
      });

      final newComment = NewComment(comment: _commentController.text.trim());
      final response = await _commentService.addComment(widget.product.id, newComment);
      
      if (mounted) {
        setState(() {
          _comments.insert(0, response.comment);
          _commentController.clear();
          _isAddingComment = false;
          // Mettre à jour le total
          if (_commentsPagination != null) {
            _commentsPagination = CommentPagination(
              total: _commentsPagination!.total + 1,
              page: _commentsPagination!.page,
              limit: _commentsPagination!.limit,
              totalPages: _commentsPagination!.totalPages,
            );
          }
        });
        
        _showSuccessSnackBar('Commentaire ajouté avec succès');
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      print('❌ [DETAIL] Erreur ajout commentaire: $e');
      if (mounted) {
        setState(() {
          _isAddingComment = false;
        });
        _showErrorSnackBar('Erreur lors de l\'ajout du commentaire');
      }
    }
  }

  Future<void> _addReply(int commentId) async {
    final controller = _replyControllers[commentId];
    if (controller == null || controller.text.trim().isEmpty) return;

    try {
      setState(() {
        _isLoadingReplies[commentId] = true;
      });

      final newReply = NewReply(reply: controller.text.trim());
      final response = await _commentService.replyToComment(commentId, newReply);
      
      if (mounted) {
        setState(() {
          // Trouver le commentaire et ajouter la réponse
          final commentIndex = _comments.indexWhere((c) => c.id == commentId);
          if (commentIndex != -1) {
            final updatedComment = _comments[commentIndex].copyWithReplies([
              ..._comments[commentIndex].replies,
              response.reply,
            ]);
            _comments[commentIndex] = updatedComment;
          }
          
          controller.clear();
          _showReplyField[commentId] = false;
          _showReplies[commentId] = true;
          _isLoadingReplies[commentId] = false;
        });
        
        _showSuccessSnackBar('Réponse ajoutée avec succès');
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      print('❌ [DETAIL] Erreur ajout réponse: $e');
      if (mounted) {
        setState(() {
          _isLoadingReplies[commentId] = false;
        });
        _showErrorSnackBar('Erreur lors de l\'ajout de la réponse');
      }
    }
  }

  Future<void> _toggleLike() async {
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

        _showLikeSnackBar();
      }
    } catch (e) {
      print('❌ [DETAIL] Erreur like: $e');
      if (mounted) {
        setState(() {
          _isLikeActionInProgress = false;
        });
        _showErrorSnackBar(e);
      }
    }
  }

  // 🔧 MÉTHODES UTILITAIRES
  String _getFixedImageUrl(String url) {
    if (url.contains('://') && url.contains('//uploads')) {
      return url.replaceAll('//uploads', '/uploads');
    }
    if (url.startsWith('file:///uploads')) {
      return 'http://192.168.1.13:3000${url.substring(7)}';
    }
    if (url.startsWith('/uploads')) {
      return 'http://192.168.1.13:3000$url';
    }
    return url;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
        ),
        margin: ProductDetailConstants.pageMargin,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLikeSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: AppColors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(_isLiked && !_isDisliked ? 'Produit aimé ❤️' : 'Like retiré 💔'),
          ],
        ),
        backgroundColor: _isLiked && !_isDisliked ? Colors.red : AppColors.gray600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
        ),
        margin: ProductDetailConstants.pageMargin,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showErrorSnackBar(dynamic error) {
    String errorMessage = 'Une erreur s\'est produite';
    if (error is LikeException) {
      if (error.code == 'SESSION_EXPIRED_MOBILE') {
        errorMessage = 'Session expirée. Redémarrez l\'application.';
      } else {
        errorMessage = error.message;
      }
    } else if (error is CommentException) {
      if (error.code == 'SESSION_EXPIRED' || error.code == 'NOT_LOGGED_IN') {
        errorMessage = 'Session expirée. Redémarrez l\'application.';
      } else {
        errorMessage = error.message;
      }
    } else if (error is String) {
      errorMessage = error;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
        ),
        margin: ProductDetailConstants.pageMargin,
      ),
    );
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
                    _buildImageCarousel(),
                    _buildProductInfo(),
                    _buildSellerInfo(),
                    _buildFeatures(),
                    _buildDescription(),
                    _buildQuantitySelector(),
                    _buildCommentsSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
      actions: [
        _buildAppBarButton(
          icon: Icons.share,
          onPressed: _shareProduct,
        ),
        _buildCartButton(),
      ],
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: ProductDetailConstants.smallPadding,
      decoration: _getAppBarButtonDecoration(),
      child: IconButton(
        icon: Icon(icon, color: AppColors.gray800),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCartButton() {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      decoration: _getAppBarButtonDecoration(),
      child: Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: AppColors.gray800),
            onPressed: _goToCart,
          ),
          Positioned(
            right: 8,
            top: 8,
            child: _cartItemsCount > 0 ? Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _cartItemsCount > 99 ? '99+' : '$_cartItemsCount',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  BoxDecoration _getAppBarButtonDecoration() {
    return BoxDecoration(
      color: AppColors.white.withOpacity(ProductDetailConstants.overlayOpacity),
      borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(ProductDetailConstants.shadowOpacity),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    return Container(
      height: ProductDetailConstants.imageCarouselHeight,
      margin: ProductDetailConstants.pageMargin,
      decoration: _getCardDecoration(),
      child: Stack(
        children: [
          _buildImagePageView(),
          _buildPromoBadge(),
          _buildLikeButton(),
          _buildPhotoCounter(),
          _buildPageIndicators(),
        ],
      ),
    );
  }

  Widget _buildImagePageView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ProductDetailConstants.mainBorderRadius),
      child: widget.product.images.isEmpty 
          ? _buildPlaceholderImage() 
          : PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
                HapticFeedback.lightImpact();
              },
              itemCount: widget.product.images.length,
              itemBuilder: (context, index) {
                final originalUrl = widget.product.images[index].fullImageUrl;
                final fixedUrl = _getFixedImageUrl(originalUrl);
                
                return Hero(
                  tag: 'product-image-${widget.product.id}',
                  child: Image.network(
                    fixedUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildImageLoader(loadingProgress);
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildImageError(fixedUrl);
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildImageLoader(ImageChunkEvent loadingProgress) {
    return Container(
      color: AppColors.gray200,
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryOrange,
          value: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
              : null,
        ),
      ),
    );
  }

  Widget _buildImageError(String url) {
    return Container(
      color: AppColors.gray200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 80,
            color: AppColors.gray600,
          ),
          const SizedBox(height: 8),
          Text(
            'Image indisponible',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.gray600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBadge() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.red, Colors.redAccent],
          ),
          borderRadius: BorderRadius.circular(ProductDetailConstants.mainBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          '-19%',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLikeButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: GestureDetector(
        onTap: _toggleLike,
        child: ScaleTransition(
          scale: _likeScaleAnimation,
          child: AnimatedContainer(
            duration: ProductDetailConstants.fadeAnimationDuration,
            width: ProductDetailConstants.likeButtonSize,
            height: ProductDetailConstants.likeButtonSize,
            decoration: _getLikeButtonDecoration(),
            child: _buildLikeIcon(),
          ),
        ),
      ),
    );
  }

  BoxDecoration _getLikeButtonDecoration() {
    return BoxDecoration(
      color: AppColors.white.withOpacity(ProductDetailConstants.overlayOpacity),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(ProductDetailConstants.shadowOpacity),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildLikeIcon() {
    if (_isLikeActionInProgress) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryOrange,
        ),
      );
    }

    if (_isLoadingLikes) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryOrange,
        ),
      );
    }

    return Icon(
      _isLiked ? Icons.favorite : Icons.favorite_border,
      color: _isLiked ? Colors.red : AppColors.gray600,
      size: 24,
    );
  }

  Widget _buildPhotoCounter() {
    if (widget.product.images.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(ProductDetailConstants.mainBorderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt, color: AppColors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              '${_currentImageIndex + 1}/${widget.product.images.length}',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    if (widget.product.images.length <= 1) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.product.images.length,
          (index) => AnimatedContainer(
            duration: ProductDetailConstants.fadeAnimationDuration,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _currentImageIndex == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentImageIndex == index
                  ? AppColors.primaryOrange
                  : AppColors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.gray200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag,
            size: 100,
            color: AppColors.gray600,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune image disponible',
            style: AppTextStyles.heading1.copyWith(
              fontSize: 18,
              color: AppColors.gray600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: ProductDetailConstants.cardPadding,
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.name,
            style: AppTextStyles.heading1,
          ),
          const SizedBox(height: 12),
          _buildPriceRow(),
          const SizedBox(height: 16),
          _buildStatsContainer(),
        ],
      ),
    );
  }

  Widget _buildPriceRow() {
    return Row(
      children: [
        Text(
          widget.product.formattedPrice,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryOrange,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '1599 FCFA',
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 18,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const Spacer(),
        _buildStockBadge(),
      ],
    );
  }

  Widget _buildStockBadge() {
    final isLowStock = widget.product.stock <= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isLowStock ? Colors.orange : Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(ProductDetailConstants.mainBorderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 14,
            color: isLowStock ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.product.stock} en stock',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isLowStock ? Colors.orange : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContainer() {
    return Container(
      padding: ProductDetailConstants.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(ProductDetailConstants.cardBorderRadius),
      ),
      child: Row(
        children: [
          _buildStatItem(Icons.star, '4.8', '(2.8K)', Colors.amber),
          _buildStatDivider(),
          _buildStatItem(
            Icons.favorite, 
            _isLoadingLikes ? '...' : '$_likesCount', 
            'J\'aime', 
            Colors.red
          ),
          _buildStatDivider(),
          _buildStatItem(Icons.visibility, '8.2K', 'Vues', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.subtitle.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.gray200,
    );
  }

  Widget _buildSellerInfo() {
    return Container(
      margin: ProductDetailConstants.pageMargin,
      padding: ProductDetailConstants.cardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryOrange.withOpacity(0.1),
            AppColors.primaryOrange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(ProductDetailConstants.mainBorderRadius),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          _buildSellerAvatar(),
          const SizedBox(width: 12),
          _buildSellerDetails(),
          _buildShopButton(),
        ],
      ),
    );
  }

  Widget _buildSellerAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: AppColors.orangeGradient,
        borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
      ),
      child: const Center(
        child: Text(
          'TS',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSellerDetails() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.product.shopName,
                style: AppTextStyles.heading1.copyWith(fontSize: 16),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.verified,
                size: 16,
                color: AppColors.primaryOrange,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.star, size: 12, color: Colors.amber),
              const SizedBox(width: 2),
              const Text('4.9', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Text(
                '• 5K+ ventes',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopButton() {
    return ElevatedButton(
      onPressed: _goToShop,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryOrange,
        elevation: 0,
        side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
        ),
      ),
      child: Text(
        'Boutique',
        style: AppTextStyles.buttonTextSecondary.copyWith(fontSize: 12),
      ),
    );
  }

  Widget _buildFeatures() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFeatureItem(Icons.security, 'Garantie 2ans', Colors.green),
          const SizedBox(width: 12),
          _buildFeatureItem(Icons.local_shipping, 'Livraison 24h', Colors.blue),
          const SizedBox(width: 12),
          _buildFeatureItem(Icons.keyboard_return, 'Retour 30j', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, Color color) {
    return Expanded(
      child: Container(
        padding: ProductDetailConstants.cardPadding,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ProductDetailConstants.cardBorderRadius),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      margin: ProductDetailConstants.pageMargin,
      padding: ProductDetailConstants.cardPadding,
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: AppTextStyles.heading1.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: Text(
              widget.product.description ?? 'Aucune description disponible',
              style: AppTextStyles.subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            secondChild: Text(
              widget.product.description ?? 'Aucune description disponible',
              style: AppTextStyles.subtitle,
            ),
            crossFadeState: _showFullDescription
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: ProductDetailConstants.fadeAnimationDuration,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _showFullDescription = !_showFullDescription;
              });
            },
            child: Text(
              _showFullDescription ? 'Voir moins' : 'Voir plus',
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: ProductDetailConstants.cardPadding,
      decoration: _getCardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Quantité',
            style: AppTextStyles.heading1.copyWith(fontSize: 16),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(ProductDetailConstants.cardBorderRadius),
            ),
            child: Row(
              children: [
                _buildQuantityButton(Icons.remove, () => _updateQuantity(_quantity - 1)),
                Container(
                  width: ProductDetailConstants.quantityButtonSize,
                  height: ProductDetailConstants.quantityButtonSize,
                  alignment: Alignment.center,
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildQuantityButton(Icons.add, () => _updateQuantity(_quantity + 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: ProductDetailConstants.quantityButtonSize,
        height: ProductDetailConstants.quantityButtonSize,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: AppColors.gray700,
        ),
      ),
    );
  }

  // 🔥 SECTION COMMENTAIRES RÉELS
  Widget _buildCommentsSection() {
    return Container(
      margin: ProductDetailConstants.pageMargin,
      padding: ProductDetailConstants.cardPadding,
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentsHeader(),
          const SizedBox(height: 16),
          _buildAddCommentField(),
          const SizedBox(height: 16),
          _buildCommentsList(),
        ],
      ),
    );
  }

  Widget _buildCommentsHeader() {
    final totalComments = _commentsPagination?.total ?? _comments.length;
    
    return Row(
      children: [
        const Icon(
          Icons.chat_bubble_outline,
          color: AppColors.primaryOrange,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Avis clients',
          style: AppTextStyles.heading1.copyWith(fontSize: 18),
        ),
        const SizedBox(width: 4),
        if (_isLoadingComments)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryOrange,
            ),
          )
        else
          Text(
            '($totalComments)',
            style: AppTextStyles.subtitle.copyWith(fontSize: 16),
          ),
      ],
    );
  }

  Widget _buildAddCommentField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(ProductDetailConstants.cardBorderRadius),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        children: [
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              hintText: 'Partagez votre avis sur ce produit...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: AppColors.gray600),
            ),
            maxLines: 3,
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _addPhoto,
                icon: const Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: AppColors.primaryOrange,
                ),
                label: const Text(
                  'Photo',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 12,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _commentController.text.trim().isNotEmpty && !_isAddingComment
                    ? _addComment 
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
                  ),
                  elevation: 0,
                ),
                child: _isAddingComment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        'Publier',
                        style: AppTextStyles.buttonText.copyWith(fontSize: 12),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoadingComments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );
    }

    if (_comments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.gray400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun avis pour le moment',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.gray600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Soyez le premier à donner votre avis !',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.gray500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ..._comments.map((comment) => _buildCommentItem(comment)),
        if (_commentsPagination?.hasNextPage == true) ...[
          const SizedBox(height: 16),
          _buildLoadMoreButton(),
        ],
      ],
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final showReplies = _showReplies[comment.id] ?? false;
    final showReplyField = _showReplyField[comment.id] ?? false;
    final isLoadingReply = _isLoadingReplies[comment.id] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du commentaire
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCommentAvatar(comment.user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.user?.fullName ?? 'Utilisateur',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.gray800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTimeAgo(comment.createdAt),
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 12,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      comment.comment,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Actions du commentaire
          const SizedBox(height: 12),
          Row(
            children: [
              if (comment.replies.isNotEmpty) ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showReplies[comment.id] = !showReplies;
                    });
                  },
                  icon: Icon(
                    showReplies ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppColors.primaryOrange,
                  ),
                  label: Text(
                    '${comment.replies.length} réponse${comment.replies.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showReplyField[comment.id] = !showReplyField;
                    if (_showReplyField[comment.id] == true && 
                        _replyControllers[comment.id] == null) {
                      _replyControllers[comment.id] = TextEditingController();
                    }
                  });
                },
                icon: const Icon(
                  Icons.reply,
                  size: 16,
                  color: AppColors.primaryOrange,
                ),
                label: const Text(
                  'Répondre',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          // Champ de réponse
          if (showReplyField) ...[
            const SizedBox(height: 12),
            _buildReplyField(comment.id, isLoadingReply),
          ],
          
          // Liste des réponses
          if (showReplies && comment.replies.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...comment.replies.map((reply) => _buildReplyItem(reply)),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentAvatar(CommentUser? user) {
    final initials = user != null 
        ? '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
        : '?';
        
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            color: AppColors.primaryOrange,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyField(int commentId, bool isLoading) {
    final controller = _replyControllers[commentId]!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Écrivez votre réponse...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: AppColors.gray600),
            ),
            maxLines: 2,
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _showReplyField[commentId] = false;
                    controller.clear();
                  });
                },
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: AppColors.gray600, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: controller.text.trim().isNotEmpty && !isLoading
                    ? () => _addReply(commentId)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        'Répondre',
                        style: AppTextStyles.buttonText.copyWith(fontSize: 12),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(Reply reply) {
    return Container(
      margin: const EdgeInsets.only(left: 24, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReplyAvatar(reply.user),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.user?.fullName ?? 'Utilisateur',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.gray800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimeAgo(reply.createdAt),
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 10,
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.reply,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyAvatar(CommentUser? user) {
    final initials = user != null 
        ? '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
        : '?';
        
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            color: AppColors.primaryOrange,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _isLoadingMoreComments ? null : _loadMoreComments,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryOrange,
          side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
          ),
        ),
        child: _isLoadingMoreComments
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryOrange,
                ),
              )
            : Text(
                'Voir plus de commentaires',
                style: AppTextStyles.buttonTextSecondary.copyWith(fontSize: 14),
              ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: ProductDetailConstants.pageMargin,
        child: Row(
          children: [
            _buildChatButton(),
            const SizedBox(width: 8),
            _buildAddToCartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatButton() {
    return Expanded(
      flex: 1,
      child: SizedBox(
        height: ProductDetailConstants.fabHeight,
        child: ElevatedButton.icon(
          onPressed: _startChat,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange.withOpacity(0.1),
            foregroundColor: AppColors.primaryOrange,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ProductDetailConstants.cardBorderRadius),
              side: BorderSide(
                color: AppColors.primaryOrange.withOpacity(0.3),
              ),
            ),
          ),
          icon: const Icon(Icons.chat_bubble_outline, size: 20),
          label: Text(
            'Chat',
            style: AppTextStyles.buttonTextSecondary.copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildAddToCartButton() {
    return Expanded(
      flex: 2,
      child: SizedBox(
        height: ProductDetailConstants.fabHeight,
        child: ElevatedButton.icon(
          onPressed: (widget.product.isAvailable && !_isAddingToCart) ? _addToCart : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.product.isAvailable 
                ? AppColors.primaryOrange 
                : AppColors.gray600,
            foregroundColor: AppColors.white,
            elevation: ProductDetailConstants.buttonElevation,
            shadowColor: AppColors.primaryOrange.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ProductDetailConstants.cardBorderRadius),
            ),
          ),
          icon: _isAddingToCart 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.shopping_cart, size: 20),
          label: Text(
            _isAddingToCart 
                ? 'Ajout...'
                : 'Ajouter • ${(widget.product.price * _quantity).toStringAsFixed(0)} FCFA',
            style: AppTextStyles.buttonText.copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }

  // 🔧 MÉTHODES UTILITAIRES POUR LES DÉCORATIONS
  BoxDecoration _getCardDecoration() {
    return BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(ProductDetailConstants.mainBorderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: ProductDetailConstants.cardElevation,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  // 🔥 MÉTHODES D'ACTION
  void _shareProduct() {
    print('📤 Partager: ${widget.product.name}');
    // Implémentation du partage
  }

  void _goToCart() {
    print('🛒 Aller au panier');
    // Navigation vers le panier
  }

  // 🔥 NAVIGATION VERS LA BOUTIQUE - VERSION SIMPLIFIÉE ET ROBUSTE
  void _goToShop() async {
    print('🏪 Navigation vers la boutique: ${widget.product.shopName}');
    
    // ✅ VÉRIFICATIONS PRÉALABLES
    if (widget.product.shopId == null || widget.product.shopId <= 0) {
      print('❌ [DETAIL] shopId invalide: ${widget.product.shopId}');
      _showErrorSnackBar('Boutique non disponible');
      return;
    }

    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );

      print('🔄 [DETAIL] Tentative de récupération des données boutique...');

      // ✅ ESSAYER D'ABORD AVEC L'API COMPLÈTE
      try {
        final shopDetails = await _shopService.getShopDetails(widget.product.shopId);
        
        // Fermer l'indicateur de chargement
        if (mounted) Navigator.of(context).pop();

        if (shopDetails.shop != null) {
          // Navigation avec les vraies données de l'API
          _navigateToShopPage(shopDetails.shop);
          print('✅ [DETAIL] Navigation API réussie vers: ${shopDetails.shop.name}');
          return;
        }
      } catch (apiError) {
        print('❌ [DETAIL] Erreur API: $apiError');
        // Continuer avec le fallback
      }

      // ✅ SOLUTION DE FALLBACK SIMPLE
      print('🔄 [DETAIL] Utilisation du fallback...');
      
      // Essayer de créer un Shop minimal - version très simple
      try {
        // Créer un Shop avec TOUS les paramètres requis
        final fallbackShop = ShopModel.Shop(
          id: widget.product.shopId,
          name: widget.product.shopName.isNotEmpty 
              ? widget.product.shopName 
              : 'Boutique',
          description: 'Boutique de ${widget.product.shopName}',
          phoneNumber: '', // Champ requis - valeur par défaut
          address: '',     // Champ optionnel mais on le met vide
          userId: widget.product.userId,
          verifiedBadge: false, // Champ requis - valeur par défaut
          createdAt: DateTime.now(), // Champ requis - valeur par défaut
          updatedAt: DateTime.now(), // Champ requis - valeur par défaut
          owner: null, // Champ optionnel
        );

        // Fermer l'indicateur si encore ouvert
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Navigation avec données minimales
        _navigateToShopPage(fallbackShop);
        _showSuccessSnackBar('Boutique ouverte');
        print('✅ [DETAIL] Navigation fallback réussie');
        return;

      } catch (fallbackError) {
        print('❌ [DETAIL] Erreur fallback: $fallbackError');
      }

      // ✅ SI TOUT ÉCHOUE, FERMER ET AFFICHER ERREUR
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      _showErrorSnackBar('Boutique temporairement indisponible');
      
    } catch (e) {
      print('❌ [DETAIL] Erreur générale: $e');
      
      // Fermer l'indicateur si encore ouvert
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      _showErrorSnackBar('Erreur lors de l\'ouverture de la boutique');
    }
  }

  // ✅ MÉTHODE HELPER POUR LA NAVIGATION
  void _navigateToShopPage(ShopModel.Shop shop) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            ShopDetailPage(shop: shop),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // Feedback haptique
    HapticFeedback.lightImpact();
  }

  void _updateQuantity(int newQuantity) {
    if (newQuantity >= 1 && newQuantity <= widget.product.stock) {
      setState(() {
        _quantity = newQuantity;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _addPhoto() {
    print('📷 Ajouter une photo');
    // Ouvrir caméra/galerie
  }

  void _startChat() {
    print('💬 Chat avec: ${widget.product.shopName}');
    // Démarrer chat
  }

  void _addToCart() async {
    if (_isAddingToCart) return;

    try {
      setState(() {
        _isAddingToCart = true;
      });

      print('🛒 [DETAIL] Ajout au panier: ${widget.product.name} x $_quantity');
      HapticFeedback.mediumImpact();

      final response = await _cartService.addToCart(
        widget.product.id,
        quantity: _quantity,
      );
      
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });

        // Afficher le message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.product.name} ajouté au panier',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
            ),
            margin: ProductDetailConstants.pageMargin,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Voir panier',
              textColor: AppColors.white,
              onPressed: _goToCart,
            ),
          ),
        );

        print('✅ [DETAIL] Produit ajouté avec succès au panier');
      }
    } catch (e) {
      print('❌ [DETAIL] Erreur ajout panier: $e');
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
                  color: AppColors.white,
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
              borderRadius: BorderRadius.circular(ProductDetailConstants.buttonBorderRadius),
            ),
            margin: ProductDetailConstants.pageMargin,
          ),
        );
      }
    }
  }
}