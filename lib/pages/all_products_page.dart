// lib/pages/all_products_page.dart - NAVIGATION CORRIGÉE
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/product_service.dart';
import '../models/product_model.dart';
import '../widgets/cards/product_card.dart'; // ✅ Import correct
import '../pages/product/product_detail_page.dart'; // ✅ Import ajouté

class AllProductsPage extends StatefulWidget {
  const AllProductsPage({Key? key}) : super(key: key);

  @override
  State<AllProductsPage> createState() => _AllProductsPageState();
}

class _AllProductsPageState extends State<AllProductsPage> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Product> _products = [];
  List<String> _categories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  
  // Filtres
  String? _selectedCategory;
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';
  double? _minPrice;
  double? _maxPrice;
  
  // Pagination
  int _currentPage = 1;
  bool _hasMoreProducts = true;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _productService.getProductCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('❌ Erreur chargement catégories: $e');
    }
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _products.clear();
        _hasMoreProducts = true;
      });
    }

    try {
      setState(() {
        refresh ? _isLoading = true : _isLoadingMore = true;
        _error = null;
      });

      final response = await _productService.getAllProducts(
        category: _selectedCategory,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sortBy: _sortBy,
        order: _sortOrder,
        page: _currentPage,
        limit: _limit,
      );

      setState(() {
        if (refresh) {
          _products = response.products;
        } else {
          _products.addAll(response.products);
        }
        
        _hasMoreProducts = response.pagination?.hasNextPage ?? false;
        _currentPage++;
        _isLoading = false;
        _isLoadingMore = false;
      });
      
    } catch (e) {
      print('❌ Erreur chargement produits: $e');
      setState(() {
        _error = 'Erreur de chargement';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      _loadProducts(refresh: true);
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await _productService.searchProducts(
        query: query.trim(),
        category: _selectedCategory,
        page: 1,
        limit: _limit,
      );

      setState(() {
        _products = response.products;
        _currentPage = 2;
        _hasMoreProducts = response.pagination?.hasNextPage ?? false;
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Erreur recherche: $e');
      setState(() {
        _error = 'Erreur de recherche';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        title: const Text('Tous les Produits'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFiltersChips(),
          Expanded(
            child: _buildProductsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un produit...',
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadProducts(refresh: true);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: _searchProducts,
        onChanged: (value) {
          setState(() {}); // Pour afficher/cacher le bouton clear
        },
      ),
    );
  }

  Widget _buildFiltersChips() {
    if (_selectedCategory == null && _minPrice == null && _maxPrice == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_selectedCategory != null)
            _buildFilterChip(
              label: _selectedCategory!,
              onDeleted: () {
                setState(() {
                  _selectedCategory = null;
                });
                _loadProducts(refresh: true);
              },
            ),
          if (_minPrice != null || _maxPrice != null)
            _buildFilterChip(
              label: 'Prix: ${_minPrice?.toInt() ?? 0} - ${_maxPrice?.toInt() ?? '∞'} FCFA',
              onDeleted: () {
                setState(() {
                  _minPrice = null;
                  _maxPrice = null;
                });
                _loadProducts(refresh: true);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onDeleted}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        onDeleted: onDeleted,
        backgroundColor: AppColors.primaryOrange.withOpacity(0.1),
        deleteIconColor: AppColors.primaryOrange,
      ),
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
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _loadProducts(refresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun produit trouvé',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos filtres',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
            _hasMoreProducts &&
            !_isLoadingMore) {
          _loadProducts();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _products.length + (_isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _products.length) {
            // Loading indicators pour pagination
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                ),
              ),
            );
          }

          final product = _products[index];
          return ProductCard(
            product: product,
            // ✅ SUPPRESSION DE onTap - laissons ProductCard gérer la navigation automatiquement
            onAddToCart: () => _onAddToCart(product),
            onLike: () => _onLikeProduct(product),
            showShopInfo: true,
          );
        },
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterSheet(),
    );
  }

  Widget _buildFilterSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtres',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                      _minPrice = null;
                      _maxPrice = null;
                      _sortBy = 'createdAt';
                      _sortOrder = 'desc';
                    });
                    Navigator.pop(context);
                    _loadProducts(refresh: true);
                  },
                  child: Text(
                    'Réinitialiser',
                    style: TextStyle(color: AppColors.primaryOrange),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCategoryFilter(),
                const SizedBox(height: 24),
                _buildPriceRangeFilter(),
                const SizedBox(height: 24),
                _buildSortFilter(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadProducts(refresh: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Appliquer les filtres'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catégorie',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCategoryChip('Toutes', null),
            ..._categories.map((category) => _buildCategoryChip(category, category)),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? value : null;
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: AppColors.primaryOrange.withOpacity(0.2),
      checkmarkColor: AppColors.primaryOrange,
    );
  }

  Widget _buildPriceRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fourchette de prix (FCFA)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Prix min',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _minPrice = double.tryParse(value);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Prix max',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _maxPrice = double.tryParse(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trier par',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSortChip('Plus récents', 'createdAt', 'desc'),
            _buildSortChip('Plus anciens', 'createdAt', 'asc'),
            _buildSortChip('Prix croissant', 'price', 'asc'),
            _buildSortChip('Prix décroissant', 'price', 'desc'),
            _buildSortChip('Nom A-Z', 'name', 'asc'),
            _buildSortChip('Nom Z-A', 'name', 'desc'),
          ],
        ),
      ],
    );
  }

  Widget _buildSortChip(String label, String sortBy, String order) {
    final isSelected = _sortBy == sortBy && _sortOrder == order;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _sortBy = sortBy;
            _sortOrder = order;
          });
        }
      },
      backgroundColor: Colors.grey[100],
      selectedColor: AppColors.primaryOrange.withOpacity(0.2),
      checkmarkColor: AppColors.primaryOrange,
    );
  }

  // ✅ MÉTHODE PLUS UTILISÉE - ProductCard gère maintenant la navigation automatiquement
  void _onProductTap(Product product) {
    print('🛍️ Produit sélectionné: ${product.name}');
    // Cette méthode n'est plus nécessaire car ProductCard navigue automatiquement vers ProductDetailPage
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
            Expanded(child: Text('${product.name} ajouté au panier')),
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

  void _onLikeProduct(Product product) {
    print('❤️ Like produit: ${product.name}');
    // Ici vous pouvez ajouter la logique pour gérer les likes
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}