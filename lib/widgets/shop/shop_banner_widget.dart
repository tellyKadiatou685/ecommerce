// lib/widgets/shop/shop_banner_widget.dart
import 'package:flutter/material.dart';
import '../../models/shop_model.dart';
import '../../constants/app_colors.dart';
import '../../services/api_config.dart';
import '../common/image_viewer_widget.dart';

class ShopBannerWidget extends StatelessWidget {
  final Shop shop;
  final double scrollOffset;
  final BuildContext context;

  const ShopBannerWidget({
    Key? key,
    required this.shop,
    required this.scrollOffset,
    required this.context,
  }) : super(key: key);

  // 🔧 MÉTHODE POUR OBTENIR L'URL DE LA PHOTO DE COUVERTURE
  String? _getCoverImageUrl() {
    // TODO: Ajouter le champ coverImage dans votre modèle Shop
    // Pour l'instant, on utilise le logo comme fallback ou une image par défaut
    if (shop.logo != null && shop.logo!.isNotEmpty) {
      if (shop.logo!.startsWith('http')) {
        return shop.logo;
      } else {
        return '${ApiConfig.baseUrl}/uploads/${shop.logo}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200.0,
      margin: const EdgeInsets.all(16.0),
      decoration: _getCardDecoration(),
      child: Stack(
        children: [
          _buildCoverImage(),
          _buildBannerOverlay(),
          _buildShopAvatar(),
        ],
      ),
    );
  }

  Widget _buildCoverImage() {
    final coverImageUrl = _getCoverImageUrl();
    
    return GestureDetector(
      onTap: () {
        if (coverImageUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageViewerWidget(
                imageUrls: [coverImageUrl],
                heroTag: 'shop-cover-${shop.id}',
              ),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF9800), // Orange principal
                Color(0xFFFFB74D), // Orange clair
              ],
            ),
          ),
          child: Stack(
            children: [
              // 🔥 IMAGE DE COUVERTURE SI DISPONIBLE
              if (coverImageUrl != null)
                Positioned.fill(
                  child: Hero(
                    tag: 'shop-cover-${shop.id}',
                    child: Image.network(
                      coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultBackground();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildDefaultBackground();
                      },
                    ),
                  ),
                )
              else
                _buildDefaultBackground(),
              
              // Effet de lumière animé
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.2, -0.8),
                      radius: 1.0,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Pattern décoratif
              Positioned.fill(
                child: CustomPaint(
                  painter: _ShopBannerPainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF9800),
            Color(0xFFFFB74D),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.0),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopAvatar() {
    return Positioned(
      bottom: -40,
      left: 20,
      child: GestureDetector(
        onTap: () {
          if (shop.owner?.photo != null && shop.owner!.photo!.isNotEmpty) {
            String photoUrl = shop.owner!.photo!;
            if (!photoUrl.startsWith('http')) {
              photoUrl = '${ApiConfig.baseUrl}/uploads/$photoUrl';
            }
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerWidget(
                  imageUrls: [photoUrl],
                  heroTag: 'shop-avatar-${shop.id}',
                ),
              ),
            );
          }
        },
        child: Container(
          width: 80.0,
          height: 80.0,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
            ),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: AppColors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _buildAvatarContent(),
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    // 🔥 UTILISER LA PHOTO DE PROFIL DU PROPRIÉTAIRE SI DISPONIBLE
    if (shop.owner?.photo != null && shop.owner!.photo!.isNotEmpty) {
      String photoUrl = shop.owner!.photo!;
      
      // Construire l'URL complète si nécessaire
      if (!photoUrl.startsWith('http')) {
        photoUrl = '${ApiConfig.baseUrl}/uploads/$photoUrl';
      }
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Hero(
          tag: 'shop-avatar-${shop.id}',
          child: Image.network(
            photoUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAvatar();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        shop.name.isNotEmpty ? shop.name[0].toUpperCase() : 'B',
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
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

// 🎨 CUSTOM PAINTER POUR LA BANNIÈRE
class _ShopBannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Dessiner des cercles décoratifs
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      30,
      paint,
    );
    
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      20,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.7),
      15,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}