// lib/pages/all_shops_page.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/shop_service.dart';
import '../widgets/cards/boutique_card.dart';

class AllShopsPage extends StatefulWidget {
  const AllShopsPage({Key? key}) : super(key: key);

  @override
  State<AllShopsPage> createState() => _AllShopsPageState();
}

class _AllShopsPageState extends State<AllShopsPage> {
  final ShopService _shopService = ShopService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Données
  List<Map<String, dynamic>> allShops = [];
  List<Map<String, dynamic>> filteredShops = [];
  
  // État
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _searchQuery = '';
  
  // Pagination
  static const int _itemsPerPage = 10;
  int _currentPage = 1;
  bool _hasMoreData = true;

  // Filtres
  String _selectedSort = 'name'; // 'name', 'products', 'verified'
  bool _showOnlyVerified = false;

  @override
  void initState() {
    super.initState();
    _loadAllShops();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _currentPage = 1;
      _hasMoreData = true;
    });
    _filterShops();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreShops();
    }
  }

  Future<void> _loadAllShops() async {
    print('🔄 Chargement de toutes les boutiques...');
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final shopResponse = await _shopService.getAllShops();
      print('✅ ${shopResponse.shops.length} boutiques récupérées');
      
      // Récupérer les produits pour chaque boutique
      List<Map<String, dynamic>> shopsWithProducts = [];
      
      for (final shop in shopResponse.shops) {
        try {
          final productsResponse = await _shopService.getShopProducts(shop.id);
          final publishedProductsCount = productsResponse.products
              .where((p) => p.isPublished)
              .length;
          
          shopsWithProducts.add({
            'id': shop.id,
            'name': shop.name,
            'description': shop.description,
            'image': shop.logo,
            'rating': 4.5, // TODO: Vraie note depuis l'API
            'products': publishedProductsCount,
            'category': 'Boutique',
            'address': shop.address,
            'verified': shop.verifiedBadge,
            'owner': shop.owner?.fullName,
            'phone': shop.phoneNumber,
            'createdAt': shop.createdAt,
          });
          
        } catch (e) {
          print('❌ Erreur produits pour ${shop.name}: $e');
          shopsWithProducts.add({
            'id': shop.id,
            'name': shop.name,
            'description': shop.description,
            'image': shop.logo,
            'rating': 4.5,
            'products': 0,
            'category': 'Boutique',
            'address': shop.address,
            'verified': shop.verifiedBadge,
            'owner': shop.owner?.fullName,
            'phone': shop.phoneNumber,
            'createdAt': shop.createdAt,
          });
        }
      }

      setState(() {
        allShops = shopsWithProducts;
        _isLoading = false;
        _currentPage = 1;
      });
      
      _filterShops();

    } catch (e) {
      print('❌ Erreur chargement boutiques: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur de connexion: $e';
      });
    }
  }

  void _filterShops() {
    List<Map<String, dynamic>> filtered = List.from(allShops);
    
    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((shop) {
        final name = (shop['name'] ?? '').toString().toLowerCase();
        final description = (shop['description'] ?? '').toString().toLowerCase();
        final address = (shop['address'] ?? '').toString().toLowerCase();
        final owner = (shop['owner'] ?? '').toString().toLowerCase();
        
        return name.contains(query) ||
               description.contains(query) ||
               address.contains(query) ||
               owner.contains(query);
      }).toList();
    }
    
    // Filtrer par boutiques vérifiées
    if (_showOnlyVerified) {
      filtered = filtered.where((shop) => shop['verified'] == true).toList();
    }
    
    // Trier
    switch (_selectedSort) {
      case 'name':
        filtered.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
        break;
      case 'products':
        filtered.sort((a, b) => (b['products'] ?? 0).compareTo(a['products'] ?? 0));
        break;
      case 'verified':
        filtered.sort((a, b) {
          if (a['verified'] == b['verified']) return 0;
          return a['verified'] ? -1 : 1;
        });
        break;
    }
    
    setState(() {
      filteredShops = filtered;
      _hasMoreData = filtered.length > _itemsPerPage;
    });
  }

  void _loadMoreShops() {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    
    // Simuler un délai de chargement pour UX
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _isLoadingMore = false;
        _hasMoreData = filteredShops.length > (_currentPage * _itemsPerPage);
      });
    });
  }

  List<Map<String, dynamic>> get _paginatedShops {
    final endIndex = _currentPage * _itemsPerPage;
    return filteredShops.take(endIndex).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Toutes les boutiques',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndStats(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndStats() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher une boutique...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryOrange),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryOrange),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 12),
          
          // Statistiques
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredShops.length} boutique(s) trouvée(s)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_showOnlyVerified || _searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Effacer filtres'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryOrange),
            SizedBox(height: 16),
            Text('Chargement des boutiques...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAllShops,
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

    if (filteredShops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Aucune boutique trouvée pour "$_searchQuery"'
                    : 'Aucune boutique disponible',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Essayez avec d\'autres mots-clés',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllShops,
      color: AppColors.primaryOrange,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _paginatedShops.length + (_hasMoreData && !_isLoadingMore ? 0 : 1),
        itemBuilder: (context, index) {
          if (index == _paginatedShops.length) {
            if (_isLoadingMore) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppColors.primaryOrange),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final shop = _paginatedShops[index];
          return BoutiqueCard(
            boutique: shop,
            onTap: () {
              print('🏪 Sélection: ${shop['name']} (ID: ${shop['id']})');
              // TODO: Navigation vers détail
              _showShopDetail(shop);
            },
          );
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtres et tri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Tri
              const Text('Trier par:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildSortChip('name', 'Nom', setModalState),
                  _buildSortChip('products', 'Produits', setModalState),
                  _buildSortChip('verified', 'Vérifiées', setModalState),
                ],
              ),
              const SizedBox(height: 16),
              
              // Filtres
              const Text('Filtres:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Boutiques vérifiées uniquement'),
                value: _showOnlyVerified,
                onChanged: (value) {
                  setModalState(() {
                    _showOnlyVerified = value ?? false;
                  });
                  setState(() {
                    _showOnlyVerified = value ?? false;
                  });
                  _filterShops();
                },
                activeColor: AppColors.primaryOrange,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String value, String label, StateSetter setModalState) {
    final isSelected = _selectedSort == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setModalState(() {
            _selectedSort = value;
          });
          setState(() {
            _selectedSort = value;
          });
          _filterShops();
        }
      },
      selectedColor: AppColors.primaryOrange.withOpacity(0.2),
      checkmarkColor: AppColors.primaryOrange,
    );
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSort = 'name';
      _showOnlyVerified = false;
    });
    _filterShops();
  }

  void _showShopDetail(Map<String, dynamic> shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Image et nom
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      shop['image'] ?? 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: Icon(Icons.store, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shop['name'] ?? 'Boutique',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (shop['verified'] == true)
                              const Icon(Icons.verified, color: AppColors.primaryOrange),
                          ],
                        ),
                        if (shop['owner'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Par ${shop['owner']}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            Text(' ${shop['rating']} • '),
                            Text('${shop['products']} produits'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Description
              if (shop['description'] != null) ...[
                Text(
                  shop['description'],
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
              ],
              
              // Informations
              _buildDetailItem(Icons.location_on, 'Adresse', shop['address'] ?? 'Non spécifiée'),
              if (shop['phone'] != null)
                _buildDetailItem(Icons.phone, 'Téléphone', shop['phone']),
              
              const SizedBox(height: 24),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Navigation vers boutique
                      },
                      icon: const Icon(Icons.store),
                      label: const Text('Voir la boutique'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (shop['phone'] != null)
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Appeler
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Icon(Icons.call),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}