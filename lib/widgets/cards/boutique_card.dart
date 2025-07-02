// lib/widgets/cards/boutique_card.dart - AVEC AUTO-SCROLL HORIZONTAL
import 'package:flutter/material.dart';
import 'dart:async';
import '../../constants/app_colors.dart';
import '../../services/shop_service.dart';
import '../../pages/all_shops_page.dart';
import '../../pages/shop/shop_detail_page.dart'; // ✅ Import ajouté
import '../../models/shop_model.dart'; // ✅ Import ajouté

class BoutiqueCard extends StatelessWidget {
  final Map<String, dynamic> boutique;
  final VoidCallback? onTap;

  const BoutiqueCard({
    Key? key,
    required this.boutique,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
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
            _buildBoutiqueImage(),
            _buildBoutiqueInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildBoutiqueImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Image.network(
            boutique['image'] ?? 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
            height: 100,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 100,
                color: Colors.grey[200],
                child: Icon(
                  Icons.store, 
                  size: 40, 
                  color: Colors.grey[400],
                ),
              );
            },
          ),
        ),
        // Badge vérifié si la boutique est vérifiée
        if (boutique['verified'] == true)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 12),
                  SizedBox(width: 2),
                  Text(
                    'Vérifié',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBoutiqueInfo() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            boutique['name'] ?? 'Boutique',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                '${boutique['rating'] ?? 0.0}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
              Text(
                '${boutique['products'] ?? 0} produits',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Section des boutiques avec AUTO-SCROLL HORIZONTAL
class BoutiquesSection extends StatefulWidget {
  final VoidCallback? onSeeMore;

  const BoutiquesSection({
    Key? key,
    this.onSeeMore,
  }) : super(key: key);

  @override
  State<BoutiquesSection> createState() => _BoutiquesSectionState();
}

class _BoutiquesSectionState extends State<BoutiquesSection> {
  final ShopService _shopService = ShopService();
  List<Map<String, dynamic>> boutiques = []; // ✅ Variable boutiques réajoutée
  List<Shop> _shopsData = []; // ✅ Stocker les objets Shop complets
  bool _isLoading = true;
  String? _errorMessage;

  // Variables pour l'auto-scroll horizontal
  ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _isScrolling = false;
  double _scrollSpeed = 3.0; // ✅ Plus rapide - Pixels par frame

  @override
  void initState() {
    super.initState();
    _loadBoutiques();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (boutiques.length <= 2) return; // Pas besoin de scroll s'il y a peu de boutiques

    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) { // ✅ Plus fluide - 30ms au lieu de 50ms
      if (_scrollController.hasClients && !_isScrolling) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;

        // Si on arrive à la fin, revenir au début
        if (currentScroll >= maxScroll) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          // Défiler plus rapidement vers la droite
          _scrollController.animateTo(
            currentScroll + _scrollSpeed,
            duration: const Duration(milliseconds: 30), // ✅ Animation plus rapide
            curve: Curves.linear,
          );
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  void _onUserInteraction() {
    _isScrolling = true;
    _stopAutoScroll();
    
    // Reprendre l'auto-scroll après 2 secondes d'inactivité (plus réactif)
    Timer(const Duration(seconds: 2), () {
      _isScrolling = false;
      _startAutoScroll();
    });
  }

  Future<void> _loadBoutiques() async {
    print('🔄 Début chargement des boutiques...');
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        boutiques = [];
        _shopsData = []; // ✅ Vider aussi les données des shops
      });

      print('📡 Appel API getAllShops()...');
      final shopResponse = await _shopService.getAllShops();
      print('✅ Réponse getAllShops reçue: ${shopResponse.shops.length} boutiques');
      
      if (shopResponse.shops.isEmpty) {
        print('⚠️ Aucune boutique retournée par l\'API');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Aucune boutique disponible';
          boutiques = [];
          _shopsData = []; // ✅ Vider aussi les données des shops
        });
        return;
      }

      // Récupérer le nombre de produits pour chaque boutique
      List<Map<String, dynamic>> boutiquesWithProducts = [];
      List<Shop> shopsDataList = []; // ✅ Liste pour stocker les objets Shop complets
      
      print('🔍 Récupération des produits pour chaque boutique...');
      for (int i = 0; i < shopResponse.shops.length; i++) { // ✅ TOUTES les boutiques (pas de limite)
        final shop = shopResponse.shops[i];
        print('📦 Traitement boutique ${i + 1}: ${shop.name} (ID: ${shop.id})');
        
        try {
          print('📡 Appel getShopProducts pour boutique ${shop.id}...');
          final productsResponse = await _shopService.getShopProducts(shop.id);
          final publishedProductsCount = productsResponse.products.where((p) => p.isPublished).length;
          
          print('✅ Boutique ${shop.name}: ${publishedProductsCount} produits publiés sur ${productsResponse.products.length} total');
          
          boutiquesWithProducts.add({
            'id': shop.id,
            'name': shop.name,
            'image': shop.logo,
            'rating': 4.5,
            'products': publishedProductsCount,
            'category': 'Boutique',
            'address': shop.address,
            'verified': shop.verifiedBadge,
            'description': shop.description,
            'owner': shop.owner?.fullName,
          });
          
          // ✅ Stocker l'objet Shop complet
          shopsDataList.add(shop);
          
        } catch (e) {
          print('❌ Erreur récupération produits pour boutique ${shop.name}: $e');
          
          boutiquesWithProducts.add({
            'id': shop.id,
            'name': shop.name,
            'image': shop.logo,
            'rating': 4.5,
            'products': 0,
            'category': 'Boutique',
            'address': shop.address,
            'verified': shop.verifiedBadge,
            'description': shop.description,
            'owner': shop.owner?.fullName,
          });
          
          // ✅ Stocker l'objet Shop complet même en cas d'erreur
          shopsDataList.add(shop);
        }
      }

      print('✅ Chargement terminé: ${boutiquesWithProducts.length} boutiques traitées');
      
      setState(() {
        boutiques = boutiquesWithProducts;
        _shopsData = shopsDataList; // ✅ Stocker les objets Shop complets
        _isLoading = false;
        _errorMessage = null;
      });

      // Démarrer le défilement auto après chargement
      if (boutiquesWithProducts.length > 2) {
        // Attendre un peu que la ListView soit construite
        Future.delayed(const Duration(milliseconds: 500), () {
          _startAutoScroll();
        });
      }

    } catch (e, stackTrace) {
      print('❌ ERREUR CRITIQUE lors du chargement des boutiques:');
      print('Erreur: $e');
      print('StackTrace: $stackTrace');
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur de connexion: $e';
        boutiques = [];
        _shopsData = []; // ✅ Vider aussi les données des shops
      });
    }
  }

  void _retryLoading() {
    print('🔄 Nouvelle tentative de chargement...');
    _loadBoutiques();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🏪 Boutiques',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllShopsPage(),
                    ),
                  );
                },
                child: const Text(
                  'Voir plus',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryOrange),
            SizedBox(height: 8),
            Text('Chargement des boutiques...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[600]),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _retryLoading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (boutiques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Aucune boutique disponible',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _retryLoading,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Actualiser'),
            ),
          ],
        ),
      );
    }

    // ✅ LISTVIEW HORIZONTAL AVEC AUTO-SCROLL
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollStartNotification) {
          _onUserInteraction(); // L'utilisateur commence à faire défiler
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: boutiques.length,
        itemBuilder: (context, index) {
          final boutique = boutiques[index];
          final shop = _shopsData[index]; // ✅ Récupérer l'objet Shop complet correspondant
          
          return BoutiqueCard(
            boutique: boutique,
            onTap: () {
              _onUserInteraction(); // Arrêter l'auto-scroll lors du tap
              print('🏪 Sélection boutique: ${boutique['name']} (ID: ${boutique['id']})');
              
              // ✅ NAVIGATION VERS SHOP DETAIL PAGE
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopDetailPage(shop: shop),
                ),
              );
            },
          );
        },
      ),
    );
  }
}