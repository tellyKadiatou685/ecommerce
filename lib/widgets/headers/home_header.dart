// lib/widgets/headers/home_header.dart - AVEC NAVIGATION VERS CARTPAGE
import 'package:flutter/material.dart';
import 'dart:async';
import '../../constants/app_colors.dart';
import '../../services/cart_service.dart';
import '../../pages/cart/cart_page.dart'; // 🔥 IMPORT AJOUTÉ

class HomeHeader extends StatefulWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onCameraTap;
  final VoidCallback? onCartTap; // 🔥 OPTIONNEL, SERA REMPLACÉ PAR NAVIGATION AUTOMATIQUE
  final Function(String)? onSearchChanged;

  const HomeHeader({
    Key? key,
    this.onSearchTap,
    this.onCameraTap,
    this.onCartTap,
    this.onSearchChanged,
  }) : super(key: key);

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  final CartService _cartService = CartService();
  int _cartItemCount = 0;
  bool _isLoadingCart = true;

  @override
  void initState() {
    super.initState();
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    try {
      print('🔄 [HOME_HEADER] Initialisation du panier');
      
      // Écouter les changements du panier en temps réel
      _cartService.cartStream.listen((cart) {
        if (mounted) {
          setState(() {
            _cartItemCount = cart?.itemsCount ?? 0;
            _isLoadingCart = false;
          });
          print('🛒 [HOME_HEADER] Panier mis à jour: $_cartItemCount articles');
        }
      });

      // Charger le compteur initial
      final count = await _cartService.getCartItemsCount();
      if (mounted) {
        setState(() {
          _cartItemCount = count;
          _isLoadingCart = false;
        });
        print('🛒 [HOME_HEADER] Articles dans le panier: $count');
      }
    } catch (e) {
      print('❌ [HOME_HEADER] Erreur chargement panier: $e');
      if (mounted) {
        setState(() {
          _cartItemCount = 0;
          _isLoadingCart = false;
        });
      }
    }
  }

  // 🔥 NAVIGATION VERS LA PAGE PANIER
  void _navigateToCart() {
    print('🔄 [HOME_HEADER] Navigation vers le panier ($_cartItemCount articles)');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CartPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSearchField(),
        ),
        const SizedBox(width: 12),
        _buildCameraButton(),
        const SizedBox(width: 8),
        _buildCartButton(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        onChanged: widget.onSearchChanged,
        onTap: widget.onSearchTap,
        decoration: InputDecoration(
          hintText: 'Que cherchez-vous ?',
          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: widget.onCameraTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.camera_alt_outlined, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildCartButton() {
    return GestureDetector(
      onTap: () {
        // 🔥 UTILISER LA NAVIGATION AUTOMATIQUE AU LIEU DU CALLBACK
        if (widget.onCartTap != null) {
          widget.onCartTap!();
        } else {
          _navigateToCart();
        }
      },
      child: Stack(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shopping_cart_outlined, color: Colors.grey.shade700),
          ),
          if (_cartItemCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.primaryOrange,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isLoadingCart
                      ? const SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _cartItemCount > 99 ? '99+' : '$_cartItemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ✅ HERO BANNER STYLE COLLECTION MODE PREMIUM - SANS OVERFLOW
class BibocomHeroBanner extends StatefulWidget {
  final String userType;
  final String userName;
  final VoidCallback? onManageStore;
  final VoidCallback? onGetStarted;
  final Function(String)? onEmailSubmit;

  const BibocomHeroBanner({
    Key? key,
    required this.userType,
    required this.userName,
    this.onManageStore,
    this.onGetStarted,
    this.onEmailSubmit,
  }) : super(key: key);

  @override
  State<BibocomHeroBanner> createState() => _BibocomHeroBannerState();
}

class _BibocomHeroBannerState extends State<BibocomHeroBanner>
    with TickerProviderStateMixin {
  
  // 🎯 IMAGES RÉELLES DANS assets/images/hero/
  final List<Map<String, String>> heroImages = [
    {
      'src': 'assets/images/hero/bb.jpeg',
      'alt': 'Groupe shopping BIBOCOM'
    },
    {
      'src': 'assets/images/hero/bbb.jpeg', 
      'alt': 'Boutique BIBOCOM'
    },
    {
      'src': 'assets/images/hero/bibocom.jpeg',
      'alt': 'Logo BIBOCOM MARKET'
    },
    {
      'src': 'assets/images/hero/bibocom1.jpeg',
      'alt': 'Équipe BIBOCOM 1'
    },
    {
      'src': 'assets/images/hero/bibocom2.jpeg',
      'alt': 'Équipe BIBOCOM 2'
    },
    {
      'src': 'assets/images/hero/vv.jpeg',
      'alt': 'Équipe BIBOCOM 3'
    },
    {
      'src': 'assets/images/hero/bibocom23.jpeg',
      'alt': 'Événement BIBOCOM 2023'
    },
    {
      'src': 'assets/images/hero/cloth.jpeg',
      'alt': 'Design flyer vêtements'
    },
    {
      'src': 'assets/images/hero/ff.jpeg',
      'alt': 'Produits mode'
    },
    {
      'src': 'assets/images/hero/fff.jpeg',
      'alt': 'Collection fashion'
    },
    {
      'src': 'assets/images/hero/jj.jpeg',
      'alt': 'Articles tendance'
    },
    {
      'src': 'assets/images/hero/shop.jpeg',
      'alt': 'Boutique en ligne'
    },
    {
      'src': 'assets/images/hero/shop2.jpeg',
      'alt': 'E-commerce BIBOCOM'
    },
    {
      'src': 'assets/images/hero/ll.jpeg',
      'alt': 'Illustration moderne'
    },
  ];

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;
  
  PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startImageAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    _floatController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _floatAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));

    // Démarrer les animations
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _slideController.forward();
        _fadeController.forward();
        _floatController.repeat(reverse: true);
      }
    });
  }

  void _startImageAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && heroImages.isNotEmpty) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % heroImages.length;
        });
        
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentImageIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutQuart,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _fadeAnimation, _floatAnimation]),
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.all(16),
              height: 200, // 🎯 HAUTEUR OPTIMISÉE
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRect( // 🎯 COUPE PROPREMENT SANS LIGNES JAUNES
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      // 🎯 BACKGROUND PATTERN SUBTIL
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey[50] ?? Colors.grey.shade50,
                                Colors.white,
                                Colors.grey[100] ?? Colors.grey.shade100,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 🎯 CONTENU PRINCIPAL
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 🎯 SECTION TEXTE À GAUCHE (Style Collection)
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Badge "New Collection" style
                                  TweenAnimationBuilder(
                                    duration: const Duration(milliseconds: 1800),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryOrange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: AppColors.primaryOrange.withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 15,
                                                height: 15,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryOrange,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'NOUVELLE COLLECTION',
                                                style: TextStyle(
                                                  color: AppColors.primaryOrange,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Titre principal style magazine
                                  TweenAnimationBuilder(
                                    duration: const Duration(milliseconds: 2200),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    builder: (context, value, child) {
                                      return Transform.translate(
                                        offset: Offset(50 * (1 - value), 0),
                                        child: Opacity(
                                          opacity: value,
                                          child: RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: 'BIBOCOM\n',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade900,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    height: 0.9,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: 'MARKET',
                                                  style: TextStyle(
                                                    color: AppColors.primaryOrange,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    height: 0.9,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  
                                  // Sous-titre élégant
                                  TweenAnimationBuilder(
                                    duration: const Duration(milliseconds: 2600),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    builder: (context, value, child) {
                                      return Transform.translate(
                                        offset: Offset(30 * (1 - value), 0),
                                        child: Opacity(
                                          opacity: value,
                                          child: Text(
                                            widget.userType == 'merchant'
                                              ? 'Votre plateforme de vente'
                                              : 'Découvrez nos tendances mode',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w400,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  
                                  // Bouton style boutique premium
                                  TweenAnimationBuilder(
                                    duration: const Duration(milliseconds: 3000),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.primaryOrange,
                                                AppColors.primaryOrange.withOpacity(0.8),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primaryOrange.withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: widget.onGetStarted ?? widget.onManageStore,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  widget.userType == 'merchant' ? 'Gérer boutique' : 'Découvrir',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Transform.translate(
                                                  offset: Offset(2 * _floatAnimation.value, 0),
                                                  child: const Icon(Icons.arrow_forward, size: 14),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // 🎯 IMAGE SHOWCASE À DROITE (Style Magazine)
                            Expanded(
                              flex: 2,
                              child: TweenAnimationBuilder(
                                duration: const Duration(milliseconds: 2000),
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, animationValue, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      80 * (1 - animationValue),
                                      -15 * _floatAnimation.value,
                                    ),
                                    child: Transform.scale(
                                      scale: 0.8 + (animationValue * 0.2),
                                      child: Container(
                                        height: 150,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.15),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: PageView.builder(
                                            controller: _pageController,
                                            onPageChanged: (index) {
                                              setState(() {
                                                _currentImageIndex = index;
                                              });
                                            },
                                            itemCount: heroImages.length,
                                            itemBuilder: (context, index) {
                                              final imageData = heroImages[index];
                                              return Image.asset(
                                                imageData['src']!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        colors: [
                                                          AppColors.primaryOrange.withOpacity(0.3),
                                                          AppColors.primaryOrange.withOpacity(0.1),
                                                        ],
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            Icons.shopping_bag_outlined,
                                                            color: AppColors.primaryOrange,
                                                            size: 30,
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            'BIBOCOM',
                                                            style: TextStyle(
                                                              color: AppColors.primaryOrange,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          Text(
                                                            'COLLECTION',
                                                            style: TextStyle(
                                                              color: AppColors.primaryOrange.withOpacity(0.7),
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ✅ ANCIENNE BANNIÈRE GARDÉE POUR COMPATIBILITÉ
class WelcomeBanner extends StatelessWidget {
  final String userType;
  final String userName;
  final VoidCallback? onManageStore;

  const WelcomeBanner({
    Key? key,
    required this.userType,
    required this.userName,
    this.onManageStore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ✅ UTILISER LE NOUVEAU HERO BANNER À LA PLACE
    return BibocomHeroBanner(
      userType: userType,
      userName: userName,
      onManageStore: onManageStore,
    );
  }
}