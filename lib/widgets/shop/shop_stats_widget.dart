// lib/widgets/shop/shop_stats_widget.dart
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/shop_model.dart';
import '../../services/follow_service.dart';
import '../../models/follow_model.dart';

class ShopStatsWidget extends StatefulWidget {
  final Shop shop; // Ajout du shop pour obtenir l'userId
  final int productsCount;
  final int likesCount;

  const ShopStatsWidget({
    Key? key,
    required this.shop,
    required this.productsCount,
    required this.likesCount,
  }) : super(key: key);

  @override
  State<ShopStatsWidget> createState() => _ShopStatsWidgetState();

  // 🔥 MÉTHODE STATIQUE POUR RAFRAÎCHIR DEPUIS L'EXTÉRIEUR
  static void refreshFollowersCount(GlobalKey key) {
    final state = key.currentState;
    if (state != null && state is _ShopStatsWidgetState) {
      state._loadFollowersCount();
    }
  }
}

class _ShopStatsWidgetState extends State<ShopStatsWidget> {
  // 🔥 SERVICE DE FOLLOW
  final FollowService _followService = FollowService();
  
  // 🔥 VARIABLES D'ÉTAT
  int _followersCount = 0;
  bool _isLoadingFollowers = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadFollowersCount();
  }

  // 🔧 CHARGEMENT DU NOMBRE D'ABONNÉS (public pour être accessible)
  Future<void> _loadFollowersCount() async {
    try {
      print('🔄 [SHOP_STATS] Chargement du nombre d\'abonnés pour userId: ${widget.shop.userId}');
      
      setState(() {
        _isLoadingFollowers = true;
        _hasError = false;
      });

      // Récupérer le nombre d'abonnés via le service
      final followersResponse = await _followService.getUserFollowers(
        widget.shop.userId,
        page: 1,
        limit: 1, // On veut juste le total
      );

      if (mounted) {
        setState(() {
          _followersCount = followersResponse.pagination.total;
          _isLoadingFollowers = false;
        });
        
        print('✅ [SHOP_STATS] Nombre d\'abonnés chargé: $_followersCount');
      }
    } catch (e) {
      print('❌ [SHOP_STATS] Erreur chargement abonnés: $e');
      
      if (mounted) {
        setState(() {
          _followersCount = 0;
          _isLoadingFollowers = false;
          _hasError = true;
        });
      }
    }
  }

  // 🔧 MÉTHODE PUBLIQUE POUR RAFRAÎCHIR DEPUIS L'EXTÉRIEUR
  Future<void> refreshFollowersCount() async {
    await _loadFollowersCount();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            '${widget.productsCount}', 
            'Produits', 
            Icons.shopping_bag_outlined,
            isLoading: false,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            _getFollowersDisplay(), 
            'Abonnés', 
            Icons.people_outline,
            isLoading: _isLoadingFollowers,
            hasError: _hasError,
            onTap: _hasError ? _loadFollowersCount : null,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            '${widget.likesCount}', 
            'Likes', 
            Icons.favorite_outline,
            isLoading: false,
          ),
        ],
      ),
    );
  }

  // 🔧 AFFICHAGE CONDITIONNEL DU NOMBRE D'ABONNÉS
  String _getFollowersDisplay() {
    if (_isLoadingFollowers) {
      return '...';
    } else if (_hasError) {
      return '?';
    } else {
      return '$_followersCount';
    }
  }

  Widget _buildStatCard(
    String value, 
    String label, 
    IconData icon, {
    bool isLoading = false,
    bool hasError = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryOrange.withOpacity(0.05),
                AppColors.primaryOrange.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: hasError 
                  ? Colors.red.withOpacity(0.3)
                  : AppColors.primaryOrange.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              // 🔥 ICÔNE AVEC ÉTAT
              _buildStatIcon(icon, isLoading, hasError),
              
              const SizedBox(height: 8),
              
              // 🔥 VALEUR AVEC ANIMATION
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: hasError 
                        ? Colors.red 
                        : AppColors.primaryOrange,
                  ),
                ),
              ),
              
              const SizedBox(height: 4),
              
              // 🔥 LABEL AVEC INDICATEUR D'ERREUR
              Text(
                hasError ? '$label (Tap pour réessayer)' : label,
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: hasError ? 10 : 12,
                  color: hasError 
                      ? Colors.red.withOpacity(0.7)
                      : AppColors.gray600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, bool isLoading, bool hasError) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryOrange,
        ),
      );
    }
    
    if (hasError) {
      return Icon(
        Icons.refresh,
        color: Colors.red,
        size: 24,
      );
    }
    
    return Icon(
      icon,
      color: AppColors.primaryOrange,
      size: 24,
    );
  }
}