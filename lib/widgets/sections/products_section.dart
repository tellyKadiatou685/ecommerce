// lib/widgets/sections/products_section.dart - COMPLÈTE AVEC LIKES
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/product_service.dart';
import '../../services/like_service.dart';
import '../../models/product_model.dart';
import '../../models/like_model.dart';
import '../cards/product_card.dart';

class ProductsSection extends StatefulWidget {
  final String title;
  final int maxProducts;
  final VoidCallback? onSeeMore;

  const ProductsSection({
    Key? key,
    this.title = '🛍️ Produits Recommandés',
    this.maxProducts = 4,
    this.onSeeMore,
  }) : super(key: key);

  @override
  State<ProductsSection> createState() => _ProductsSectionState();
}

class _ProductsSectionState extends State<ProductsSection> {
  final ProductService _productService = ProductService();
  final LikeService _likeService = LikeService();
  
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  // Cache pour éviter les appels API répétés
  Map<int, LikesCount> _likesCache = {};
  Map<int, UserReaction> _userReactionsCache = {};
  bool _likesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Récupérer les derniers produits
      final products = await _productService.getLatestProducts(
        limit: widget.maxProducts,
      );

      setState(() {
        _products = products;
        _isLoading = false;
      });

      // Charger les likes en arrière-plan
      _loadLikesForProducts(products);
      
    } catch (e) {
      print('❌ Erreur chargement produits: $e');
      setState(() {
        _error = 'Erreur de chargement';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLikesForProducts(List<Product> products) async {
    if (_likesLoaded) return;

    try {
      // Vérifier si l'utilisateur est connecté
      final isLoggedIn = await _likeService.isUserLoggedIn();
      
      // Charger les likes pour chaque produit
      for (final product in products) {
        try {
          // Compteurs de likes
          final likesCount = await _likeService.getProductLikesCount(product.id);
          _likesCache[product.id] = likesCount;
          
          // Réaction utilisateur si connecté
          if (isLoggedIn) {
            try {
              final userReaction = await _likeService.getUserProductReaction(product.id);
              _userReactionsCache[product.id] = userReaction;
            } catch (e) {
              print('⚠️ Erreur réaction utilisateur produit ${product.id}: $e');
              _userReactionsCache[product.id] = UserReaction.defaultState();
            }
          } else {
            _userReactionsCache[product.id] = UserReaction.defaultState();
          }
        } catch (e) {
          print('⚠️ Erreur likes produit ${product.id}: $e');
          _likesCache[product.id] = LikesCount(likesCount: product.likesCount, dislikesCount: 0);
          _userReactionsCache[product.id] = UserReaction.defaultState();
        }
      }

      if (mounted) {
        setState(() {
          _likesLoaded = true;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement likes: $e');
    }
  }

  Future<void> _refreshProductLikes(int productId) async {
    try {
      final likesCount = await _likeService.getProductLikesCount(productId);
      final isLoggedIn = await _likeService.isUserLoggedIn();
      
      UserReaction userReaction = UserReaction.defaultState();
      if (isLoggedIn) {
        try {
          userReaction = await _likeService.getUserProductReaction(productId);
        } catch (e) {
          print('⚠️ Erreur réaction utilisateur: $e');
        }
      }

      if (mounted) {
        setState(() {
          _likesCache[productId] = likesCount;
          _userReactionsCache[productId] = userReaction;
        });
      }
    } catch (e) {
      print('❌ Erreur rafraîchissement likes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(),
          const SizedBox(height: 16),
          _buildProductsContent(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (widget.onSeeMore != null)
          GestureDetector(
            onTap: widget.onSeeMore,
            child: Row(
              children: [
                Text(
                  'Voir plus',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppColors.primaryOrange,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProductsContent() {
    if (_isLoading) {
      return _buildLoadingGrid();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_products.isEmpty) {
      return _buildEmptyState();
    }

    return _buildProductsGrid();
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryOrange,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 14,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Aucun produit disponible',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Revenez plus tard !',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    final displayProducts = _products.take(widget.maxProducts).toList();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (context, index) {
        final product = displayProducts[index];
        
        print('🏗️ Construction ProductCard pour: ${product.name}');
        
        return ProductCard(
          product: product,
          onAddToCart: () => _onAddToCart(product),
          onLike: () => _onLikeProduct(product),
          showShopInfo: true,
        );
      },
    );
  }

  void _onAddToCart(Product product) {
    if (!product.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} n\'est pas disponible'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    print('🛒 Ajout au panier: ${product.name}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${product.name} ajouté au panier'),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryOrange,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _onLikeProduct(Product product) async {
    print('❤️ Like produit depuis section: ${product.name}');
    
    try {
      // Vérifier si connecté
      final isLoggedIn = await _likeService.isUserLoggedIn();
      if (!isLoggedIn) {
        _showLoginRequiredDialog();
        return;
      }

      // Optimistic update
      final currentLikes = _likesCache[product.id] ?? 
          LikesCount(likesCount: product.likesCount, dislikesCount: 0);
      final currentReaction = _userReactionsCache[product.id] ?? 
          UserReaction.defaultState();
      
      // Mise à jour optimiste de l'interface
      setState(() {
        if (currentReaction.hasLiked) {
          // Retirer le like
          _likesCache[product.id] = LikesCount(
            likesCount: currentLikes.likesCount - 1,
            dislikesCount: currentLikes.dislikesCount,
          );
          _userReactionsCache[product.id] = UserReaction(
            hasLiked: false, 
            hasDisliked: currentReaction.hasDisliked,
          );
        } else {
          // Ajouter le like
          _likesCache[product.id] = LikesCount(
            likesCount: currentLikes.likesCount + 1,
            dislikesCount: currentReaction.hasDisliked 
                ? currentLikes.dislikesCount - 1 
                : currentLikes.dislikesCount,
          );
          _userReactionsCache[product.id] = UserReaction(
            hasLiked: true, 
            hasDisliked: false,
          );
        }
      });

      // Appel API réel
      final response = await _likeService.toggleProductLike(product.id);
      
      // Mise à jour avec les données du serveur
      if (mounted) {
        setState(() {
          _likesCache[product.id] = LikesCount(
            likesCount: response.likesCount,
            dislikesCount: response.dislikesCount,
          );
          _userReactionsCache[product.id] = UserReaction(
            hasLiked: response.action == 'liked',
            hasDisliked: false,
          );
        });

        // Feedback visuel
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  response.action == 'liked' ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  response.action == 'liked' 
                      ? '${product.name} aimé ❤️' 
                      : 'Like retiré de ${product.name}',
                ),
              ],
            ),
            backgroundColor: response.action == 'liked' 
                ? Colors.red 
                : Colors.grey[600],
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
      print('❌ Erreur like produit: $e');
      
      // Rollback en cas d'erreur
      await _refreshProductLikes(product.id);
      
      if (mounted) {
        String errorMessage = 'Erreur lors du like';
        if (e is LikeException) {
          errorMessage = e.message;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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


  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.login, color: AppColors.primaryOrange),
            SizedBox(width: 8),
            Text('Connexion requise'),
          ],
        ),
        content: const Text(
          'Vous devez vous connecter pour aimer ce produit.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigation vers la page de connexion
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Nettoyer les caches
    _likesCache.clear();
    _userReactionsCache.clear();
    super.dispose();
  }
}