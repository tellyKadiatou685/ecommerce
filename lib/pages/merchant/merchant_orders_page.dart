import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/order_service.dart';
import '../../models/order_model.dart';

class MerchantOrdersPage extends StatefulWidget {
  final String? initialFilter;
  
  const MerchantOrdersPage({
    Key? key,
    this.initialFilter,
  }) : super(key: key);

  @override
  State<MerchantOrdersPage> createState() => _MerchantOrdersPageState();
}

class _MerchantOrdersPageState extends State<MerchantOrdersPage> with TickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  
  List<MerchantOrder> _orders = [];
  List<MerchantOrder> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';
  
  late TabController _tabController;
  final List<String> _filterTabs = ['all', 'pending', 'confirmed', 'shipped', 'delivered'];

  @override
  void initState() {
    super.initState();
    
    // 🔧 CORRECTION: Valider le filtre initial avant de l'utiliser
    _selectedFilter = _validateFilter(widget.initialFilter ?? 'all');
    
    // 🔧 CORRECTION: S'assurer que l'index est toujours valide
    final initialIndex = _filterTabs.indexOf(_selectedFilter);
    final safeInitialIndex = initialIndex >= 0 ? initialIndex : 0;
    
    _tabController = TabController(
      length: _filterTabs.length,
      vsync: this,
      initialIndex: safeInitialIndex,
    );
    
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 🔧 AJOUT: Valider que le filtre existe dans la liste
  String _validateFilter(String filter) {
    return _filterTabs.contains(filter) ? filter : 'all';
  }

  /// Charger les commandes
  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final orders = await _orderService.getMerchantOrders();
      
      setState(() {
        _orders = orders;
        _applyFilter(_selectedFilter);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _orderService.getErrorMessage(e);
      });
    }
  }

  /// Appliquer un filtre
  void _applyFilter(String filter) {
    // 🔧 CORRECTION: Valider le filtre avant de l'appliquer
    final validFilter = _validateFilter(filter);
    
    setState(() {
      _selectedFilter = validFilter;
      
      if (validFilter == 'all') {
        _filteredOrders = List.from(_orders);
      } else {
        _filteredOrders = _orders.where((order) => 
          order.status.value.toLowerCase() == validFilter.toLowerCase()
        ).toList();
      }
      
      // Trier par date (plus récent en premier)
      _filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Mes Commandes',
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
            icon: Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Recherche - En développement'))
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (index) {
            // 🔧 CORRECTION: Vérifier que l'index est valide
            if (index >= 0 && index < _filterTabs.length) {
              _applyFilter(_filterTabs[index]);
            }
          },
          tabs: [
            Tab(text: 'Toutes'),
            Tab(text: 'En attente'),
            Tab(text: 'Confirmées'),
            Tab(text: 'Expédiées'),
            Tab(text: 'Livrées'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    }
    
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return Column(
      children: [
        // Header avec stats rapides
        _buildStatsHeader(),
        
        // Liste des commandes
        Expanded(
          child: _filteredOrders.isEmpty 
            ? _buildEmptyView()
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _filteredOrders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(_filteredOrders[index]);
                },
              ),
        ),
      ],
    );
  }

  /// Header avec statistiques rapides
  Widget _buildStatsHeader() {
    final totalOrders = _orders.length;
    final pendingCount = _orders.where((o) => o.status.value.toLowerCase() == 'pending').length;
    final confirmedCount = _orders.where((o) => o.status.value.toLowerCase() == 'confirmed').length;
    final shippedCount = _orders.where((o) => o.status.value.toLowerCase() == 'shipped').length;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', totalOrders.toString(), Color(0xFF3B82F6)),
          _buildStatItem('En attente', pendingCount.toString(), Color(0xFFF59E0B)),
          _buildStatItem('Confirmées', confirmedCount.toString(), Color(0xFF10B981)),
          _buildStatItem('Expédiées', shippedCount.toString(), Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Carte d'une commande
  Widget _buildOrderCard(MerchantOrder order) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          // Header de la commande
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.05),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getFormattedOrderNumber(order.id),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      _getFormattedDate(order.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(order.status),
              ],
            ),
          ),
          
          // Contenu de la commande
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Client info
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Color(0xFF6B7280)),
                    SizedBox(width: 8),
                    Text(
                      order.client.fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                // Montant total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      order.formattedTotalAmount,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Actions
                _buildOrderActions(order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color backgroundColor;
    Color textColor;
    String displayText;
    
    switch (status.value.toLowerCase()) {
      case 'pending':
        backgroundColor = Color(0xFFFEF3C7);
        textColor = Color(0xFF92400E);
        displayText = 'En attente';
        break;
      case 'confirmed':
        backgroundColor = Color(0xFFD1FAE5);
        textColor = Color(0xFF065F46);
        displayText = 'Confirmée';
        break;
      case 'shipped':
        backgroundColor = Color(0xFFDBEAFE);
        textColor = Color(0xFF1E40AF);
        displayText = 'Expédiée';
        break;
      case 'delivered':
        backgroundColor = Color(0xFFDCFCE7);
        textColor = Color(0xFF166534);
        displayText = 'Livrée';
        break;
      case 'canceled':
        backgroundColor = Color(0xFFFEE2E2);
        textColor = Color(0xFFDC2626);
        displayText = 'Annulée';
        break;
      default:
        backgroundColor = Color(0xFFF3F4F6);
        textColor = Color(0xFF6B7280);
        displayText = status.displayName;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status.value.toLowerCase()) {
      case 'pending': return Color(0xFFF59E0B);
      case 'confirmed': return Color(0xFF10B981);
      case 'shipped': return Color(0xFF3B82F6);
      case 'delivered': return Color(0xFF16A34A);
      case 'canceled': return Color(0xFFEF4444);
      default: return Color(0xFF6B7280);
    }
  }

  Widget _buildOrderActions(MerchantOrder order) {
    List<Widget> actions = [];

    switch (order.status.value.toLowerCase()) {
      case 'pending':
        actions = [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectOrder(order),
              icon: Icon(Icons.close, size: 16),
              label: Text('Refuser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _confirmOrder(order),
              icon: Icon(Icons.check, size: 16),
              label: Text('Confirmer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ];
        break;
      
      case 'confirmed':
        actions = [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _markAsShipped(order),
              icon: Icon(Icons.local_shipping, size: 16),
              label: Text('Marquer expédiée'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ];
        break;
      
      case 'shipped':
        actions = [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _markAsDelivered(order),
              icon: Icon(Icons.check_circle, size: 16),
              label: Text('Marquer livrée'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ];
        break;
      
      default:
        actions = [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _viewOrderDetails(order),
              icon: Icon(Icons.visibility, size: 16),
              label: Text('Voir détails'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: BorderSide(color: AppColors.primaryOrange),
              ),
            ),
          ),
        ];
    }

    return Row(children: actions);
  }

  String _getFormattedOrderNumber(int id) {
    return 'COMMANDE-$id';
  }

  String _getFormattedDate(DateTime date) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 
                   'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${date.day} ${months[date.month - 1]}';
  }

  // Actions sur les commandes
  Future<void> _confirmOrder(MerchantOrder order) async {
    try {
      await _orderService.updateOrderStatus(order.id, OrderStatus.confirmed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Commande ${_getFormattedOrderNumber(order.id)} confirmée'))
      );
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: ${_orderService.getErrorMessage(e)}'), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _rejectOrder(MerchantOrder order) async {
    try {
      await _orderService.updateOrderStatus(order.id, OrderStatus.canceled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Commande ${_getFormattedOrderNumber(order.id)} refusée'))
      );
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: ${_orderService.getErrorMessage(e)}'), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _markAsShipped(MerchantOrder order) async {
    try {
      await _orderService.updateOrderStatus(order.id, OrderStatus.shipped);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🚚 Commande ${_getFormattedOrderNumber(order.id)} expédiée'))
      );
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: ${_orderService.getErrorMessage(e)}'), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _markAsDelivered(MerchantOrder order) async {
    try {
      await _orderService.updateOrderStatus(order.id, OrderStatus.delivered);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Commande ${_getFormattedOrderNumber(order.id)} livrée'))
      );
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: ${_orderService.getErrorMessage(e)}'), backgroundColor: Colors.red)
      );
    }
  }

  // 🔧 MODIFICATION: Afficher les détails dans un modal au lieu de naviguer
  void _viewOrderDetails(MerchantOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Détails de la commande',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                      color: Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order info
                      _buildDetailCard(
                        'Informations de la commande',
                        [
                          _buildDetailRow('Numéro', _getFormattedOrderNumber(order.id)),
                          _buildDetailRow('Date', _getFormattedDate(order.createdAt)),
                          _buildDetailRow('Statut', _getStatusText(order.status)),
                          _buildDetailRow('Total', order.formattedTotalAmount),
                        ],
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Client info
                      _buildDetailCard(
                        'Informations du client',
                        [
                          _buildDetailRow('Nom complet', order.client.fullName),
                          _buildDetailRow('Email', order.client.email ?? 'Non renseigné'),
                          _buildDetailRow('Téléphone', order.client.phoneNumber ?? 'Non renseigné'),
                        ],
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Products
                      _buildProductsList(order),
                      
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  String _formatPrice(double price) {
  return '${price.toStringAsFixed(0)} FCFA';
}

  Widget _buildProductsList(MerchantOrder order) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produits commandés',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 12),
          
          // Si pas d'items disponibles, on affiche un message
          if (order.items.isEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Liste des produits en cours de chargement...',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            // Liste des produits
            ...order.items.map((item) => Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  // Image du produit (placeholder)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shopping_bag,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  // Infos du produit
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Quantité: ${item.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          'Prix unitaire: ${_formatPrice(item.price)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Prix total de l'item
                  Text(
                    item.formattedSubtotal,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            )).toList(),
        ],
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status.value.toLowerCase()) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmée';
      case 'shipped': return 'Expédiée';
      case 'delivered': return 'Livrée';
      case 'canceled': return 'Annulée';
      default: return status.displayName;
    }
  }

  /// Vue de chargement
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primaryOrange),
          SizedBox(height: 16),
          Text(
            'Chargement des commandes...',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Vue d'erreur
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          SizedBox(height: 16),
          Text(
            'Erreur',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  /// Vue vide
  Widget _buildEmptyView() {
    String message;
    IconData icon;
    
    switch (_selectedFilter) {
      case 'pending':
        message = 'Aucune commande en attente';
        icon = Icons.access_time;
        break;
      case 'confirmed':
        message = 'Aucune commande confirmée';
        icon = Icons.check_circle_outline;
        break;
      case 'shipped':
        message = 'Aucune commande expédiée';
        icon = Icons.local_shipping_outlined;
        break;
      case 'delivered':
        message = 'Aucune commande livrée';
        icon = Icons.done_all;
        break;
      default:
        message = 'Aucune commande trouvée';
        icon = Icons.shopping_bag_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Les nouvelles commandes apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}