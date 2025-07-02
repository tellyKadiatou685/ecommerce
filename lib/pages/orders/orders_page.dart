// lib/pages/orders/orders_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/api_config.dart';
import '../../screens/chat_screen.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({Key? key}) : super(key: key);

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _tabs = ['Toutes', 'En cours', 'Livrées', 'Annulées'];
  
  final OrderService _orderService = OrderService();
  List<Order> _allOrders = [];
  StreamSubscription<List<Order>>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    
    _initializeOrders();
    _setupOrdersListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadOrders();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _orderService.getOrders();
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _errorMessage = null;
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  void _setupOrdersListener() {
    _ordersSubscription = _orderService.ordersStream.listen(
      (orders) {
        if (mounted) {
          setState(() {
            _allOrders = orders;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = _getErrorMessage(error);
          });
        }
      },
    );
  }

  String _getErrorMessage(dynamic error) {
    if (error is OrderException) {
      switch (error.code) {
        case 'NOT_LOGGED_IN':
          return 'Vous devez être connecté pour voir vos commandes';
        case 'SESSION_EXPIRED':
          return 'Votre session a expiré. Reconnectez-vous.';
        case 'NO_INTERNET':
          return 'Pas de connexion internet. Vérifiez votre réseau.';
        case 'TIMEOUT':
          return 'Le serveur ne répond pas. Réessayez plus tard.';
        case 'FORBIDDEN':
          return 'Action non autorisée';
        case 'NOT_FOUND':
          return 'Commande non trouvée';
        case 'INVALID_STATUS':
          return 'Seules les commandes annulées peuvent être supprimées';
        case 'DELETE_ERROR':
          return 'Erreur lors de la suppression de la commande';
        default:
          return error.message;
      }
    }
    return 'Une erreur inattendue est survenue';
  }

  List<Order> get _filteredOrders {
    switch (_selectedTabIndex) {
      case 1: // En cours (confirmed, shipped)
        return _allOrders.where((order) => 
          order.status == OrderStatus.confirmed || 
          order.status == OrderStatus.shipped
        ).toList();
      case 2: // Livrées
        return _allOrders.where((order) => 
          order.status == OrderStatus.delivered
        ).toList();
      case 3: // Annulées
        return _allOrders.where((order) => 
          order.status == OrderStatus.canceled
        ).toList();
      default: // Toutes
        return _allOrders;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    
    return _buildOrdersList();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios, color: AppColors.gray800),
      ),
      title: Text(
        'Mes Commandes',
        style: AppTextStyles.heading1.copyWith(
          fontSize: 20,
          color: AppColors.gray800,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          onPressed: () => _showSearchDialog(),
          icon: const Icon(Icons.search, color: AppColors.gray600),
        ),
        IconButton(
          onPressed: () => _showFilterDialog(),
          icon: const Icon(Icons.filter_list, color: AppColors.gray600),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primaryOrange,
        indicatorWeight: 2,
        labelColor: AppColors.primaryOrange,
        unselectedLabelColor: AppColors.gray600,
        labelStyle: AppTextStyles.buttonTextSecondary.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: AppTextStyles.buttonTextSecondary.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildOrdersList() {
    final orders = _filteredOrders;

    if (orders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshOrders,
      color: AppColors.primaryOrange,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index], index);
        },
      ),
    );
  }

  // 🆕 CARTE AVEC GESTION DES COMMANDES ANNULÉES
  Widget _buildOrderCard(Order order, int index) {
    // 🚫 Vérifier si la commande est annulée
    bool isCanceled = order.status == OrderStatus.canceled;
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isCanceled ? AppColors.gray100 : AppColors.white, // 🎨 Couleur différente pour annulée
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(isCanceled ? 0.04 : 0.08), // 🎨 Ombre réduite pour annulée
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: isCanceled 
            // 🚫 COMMANDE ANNULÉE : Container non-cliquable
            ? Container(
                padding: const EdgeInsets.all(16),
                child: _buildOrderCardContent(order, isCanceled),
              )
            // ✅ COMMANDE NORMALE : ExpansionTile cliquable
            : ExpansionTile(
                tilePadding: const EdgeInsets.all(16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: _buildStatusIcon(order.status),
                title: _buildOrderTitle(order),
                subtitle: _buildOrderSubtitle(order),
                children: [
                  _buildExpandedOrderDetails(order),
                ],
              ),
        ),
      ),
    );
  }

  // 🆕 MÉTHODE POUR LE CONTENU DE LA CARTE (partagée entre expansible et fixe)
  Widget _buildOrderCardContent(Order order, bool isCanceled) {
    return Row(
      children: [
        _buildStatusIcon(order.status),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildOrderTitle(order)),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 8),
              _buildOrderSubtitle(order),
              if (isCanceled) ...[
                const SizedBox(height: 12),
                // 🚫 MESSAGE POUR COMMANDE ANNULÉE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Commande annulée - Détails non disponibles',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 🆕 MÉTHODE POUR L'ICÔNE DE STATUT (réutilisable)
  Widget _buildStatusIcon(OrderStatus status) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: _getStatusGradient(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getStatusIcon(status),
        color: AppColors.white,
        size: 24,
      ),
    );
  }

  // 🆕 MÉTHODE POUR LE TITRE DE LA COMMANDE (réutilisable)
  Widget _buildOrderTitle(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.formattedOrderNumber,
          style: AppTextStyles.heading1.copyWith(
            fontSize: 16,
            color: order.status == OrderStatus.canceled 
              ? AppColors.gray600  // 🎨 Couleur atténuée pour annulée
              : AppColors.gray800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(order.createdAt),
          style: AppTextStyles.caption.copyWith(
            color: order.status == OrderStatus.canceled 
              ? AppColors.gray500  // 🎨 Couleur atténuée pour annulée
              : AppColors.gray600,
          ),
        ),
      ],
    );
  }

  // 🆕 MÉTHODE POUR LE SOUS-TITRE DE LA COMMANDE (réutilisable)
  Widget _buildOrderSubtitle(Order order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${order.itemsCount} article${order.itemsCount > 1 ? 's' : ''} • ${order.uniqueShops.length} boutique${order.uniqueShops.length > 1 ? 's' : ''}',
          style: AppTextStyles.caption.copyWith(
            color: order.status == OrderStatus.canceled 
              ? AppColors.gray500  // 🎨 Couleur atténuée pour annulée
              : AppColors.gray600,
          ),
        ),
        Text(
          order.formattedTotalAmount,
          style: AppTextStyles.heading1.copyWith(
            fontSize: 18,
            color: order.status == OrderStatus.canceled 
              ? AppColors.gray500  // 🎨 Couleur atténuée pour annulée
              : AppColors.primaryOrange,
          ),
        ),
      ],
    );
  }

  // 🆕 DÉTAILS EXPANSIBLES DE LA COMMANDE
  Widget _buildExpandedOrderDetails(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 16),
        
        // 📝 ARTICLES COMMANDÉS
        _buildExpandedSection(
          'Articles commandés',
          Icons.shopping_bag,
          _buildOrderItemsList(order),
        ),
        
        const SizedBox(height: 16),
        
        // 🏪 MARCHANDS
        _buildExpandedSection(
          'Marchands',
          Icons.store,
          _buildMerchantsList(order),
        ),
        
        const SizedBox(height: 16),
        
        // 📊 PROGRESSION (si applicable)
        if (order.status == OrderStatus.confirmed || order.status == OrderStatus.shipped) ...[
          _buildExpandedSection(
            'Progression',
            Icons.timeline,
            _buildProgressSection(order),
          ),
          const SizedBox(height: 16),
        ],
        
        // ⚡ ACTIONS
        _buildActionButtons(order),
      ],
    );
  }

  // 🔧 SECTION EXPANSIBLE AVEC TITRE ET ICÔNE
  Widget _buildExpandedSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryOrange, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.buttonTextSecondary.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.gray800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  // 📦 LISTE DES ARTICLES DE LA COMMANDE
  Widget _buildOrderItemsList(Order order) {
    return Column(
      children: order.orderItems.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Row(
          children: [
            // Image du produit
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gray200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.product.images.isNotEmpty
                    ? Image.network(
                        _getFullImageUrl(item.product.firstImageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image_not_supported, color: AppColors.gray400);
                        },
                      )
                    : const Icon(Icons.image_not_supported, color: AppColors.gray400),
              ),
            ),
            const SizedBox(width: 12),
            
            // Infos du produit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: AppTextStyles.buttonTextSecondary.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.product.shop.name,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.gray600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Prix et quantité
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.formattedTotalPrice,
                  style: AppTextStyles.buttonTextSecondary.copyWith(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qté: ${item.quantity}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.gray600,
                  ),
                ),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  // 🏪 LISTE DES MARCHANDS SANS BOUTON DE CONTACT INDIVIDUEL
  Widget _buildMerchantsList(Order order) {
    return Column(
      children: order.uniqueShops.map((shop) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray200),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _getMerchantIcon(shop.name),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          title: Text(
            shop.name,
            style: AppTextStyles.buttonTextSecondary.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${_getItemsCountForShop(order, shop)} article${_getItemsCountForShop(order, shop) > 1 ? 's' : ''}',
            style: AppTextStyles.caption.copyWith(color: AppColors.gray600),
          ),
          // 🚫 PLUS DE BOUTON DE CONTACT INDIVIDUEL
        ),
      )).toList(),
    );
  }

  // 🔧 HELPER: Compter les articles pour une boutique
  int _getItemsCountForShop(Order order, OrderShop shop) {
    return order.orderItems
        .where((item) => item.product.shop.id == shop.id)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  LinearGradient _getStatusGradient(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return LinearGradient(
          colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case OrderStatus.shipped:
        return LinearGradient(
          colors: [AppColors.info, AppColors.info.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case OrderStatus.confirmed:
        return LinearGradient(
          colors: [AppColors.primaryOrange, AppColors.primaryOrange.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case OrderStatus.pending:
        return LinearGradient(
          colors: [AppColors.warning, AppColors.warning.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case OrderStatus.canceled:
        return LinearGradient(
          colors: [AppColors.error, AppColors.error.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  // 🔧 ICÔNES POUR LES STATUTS
  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.shipped:
        return Icons.local_shipping;
      case OrderStatus.confirmed:
        return Icons.verified;
      case OrderStatus.pending:
        return Icons.access_time;
      case OrderStatus.canceled:
        return Icons.cancel;
    }
  }

  Widget _buildProgressSection(Order order) {
    double progress = _getOrderProgress(order.status);
    String progressText = _getProgressText(order.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progression de la commande',
          style: AppTextStyles.buttonTextSecondary.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.gray800,
          ),
        ),
        const SizedBox(height: 8),
        
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.gray200,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          progressText,
          style: AppTextStyles.caption.copyWith(color: AppColors.gray600),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Order order) {
    switch (order.status) {
      case OrderStatus.delivered:
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Donner un avis',
                onPressed: () => _rateOrder(order),
                isOutlined: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Racheter',
                onPressed: () => _reorderOrder(order),
              ),
            ),
          ],
        );
      
      case OrderStatus.pending:
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Contacter marchands',
                onPressed: () => _checkOrderConfirmation(order),
                isOutlined: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Annuler',
                onPressed: () => _cancelOrder(order),
                isDestructive: true,
              ),
            ),
          ],
        );

      case OrderStatus.shipped:
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Suivre',
                onPressed: () => _trackOrder(order),
                isOutlined: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Confirmer réception',
                onPressed: () => _confirmDelivery(order),
              ),
            ),
          ],
        );

      case OrderStatus.confirmed:
        return _buildActionButton(
          'Suivre la préparation',
          onPressed: () => _trackOrder(order),
          fullWidth: true,
        );
      
      case OrderStatus.canceled:
        // 🗑️ BOUTON DE SUPPRESSION POUR LES COMMANDES ANNULÉES
        return _buildActionButton(
          'Supprimer définitivement',
          onPressed: () => _deleteOrder(order),
          isDestructive: true,
          fullWidth: true,
        );
      
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton(
    String text, {
    required VoidCallback onPressed,
    bool isOutlined = false,
    bool isDestructive = false,
    bool fullWidth = false,
  }) {
    Color backgroundColor;
    Color foregroundColor;
    Color? borderColor;

    if (isDestructive) {
      backgroundColor = isOutlined ? AppColors.white : AppColors.error;
      foregroundColor = isOutlined ? AppColors.error : AppColors.white;
      borderColor = AppColors.error;
    } else {
      backgroundColor = isOutlined ? AppColors.white : AppColors.primaryOrange;
      foregroundColor = isOutlined ? AppColors.primaryOrange : AppColors.white;
      borderColor = isOutlined ? AppColors.primaryOrange : null;
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: borderColor != null ? BorderSide(color: borderColor) : null,
          elevation: isOutlined ? 0 : 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.buttonText.copyWith(
            color: foregroundColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case OrderStatus.delivered:
        backgroundColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        text = 'Livrée';
        icon = Icons.check_circle;
        break;
      case OrderStatus.shipped:
        backgroundColor = AppColors.info.withOpacity(0.1);
        textColor = AppColors.info;
        text = 'Expédiée';
        icon = Icons.local_shipping;
        break;
      case OrderStatus.confirmed:
        backgroundColor = AppColors.info.withOpacity(0.1);
        textColor = AppColors.info;
        text = 'Confirmée';
        icon = Icons.verified;
        break;
      case OrderStatus.pending:
        backgroundColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        text = 'En attente';
        icon = Icons.access_time;
        break;
      case OrderStatus.canceled:
        backgroundColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        text = 'Annulée';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_selectedTabIndex) {
      case 1:
        message = 'Aucune commande en cours';
        icon = Icons.shopping_cart_outlined;
        break;
      case 2:
        message = 'Aucune commande livrée';
        icon = Icons.check_circle_outline;
        break;
      case 3:
        message = 'Aucune commande annulée';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'Aucune commande trouvée';
        icon = Icons.receipt_long_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: AppColors.gray300,
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: AppTextStyles.heading1.copyWith(
              fontSize: 20,
              color: AppColors.gray600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos commandes apparaîtront ici',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Commencer vos achats',
              style: AppTextStyles.buttonText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryOrange,
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Chargement des commandes...',
            style: TextStyle(
              color: AppColors.gray600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur',
              style: AppTextStyles.heading1.copyWith(
                fontSize: 20,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.gray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _initializeOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Réessayer',
                style: AppTextStyles.buttonText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 DIALOG POUR CONTACTER LES MARCHANDS
  void _showMerchantsContactDialog(Order order, List<OrderMerchant> merchants) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.message, color: AppColors.primaryOrange),
            SizedBox(width: 8),
            Text('Contacter les marchands'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: AppColors.info, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Votre commande est en attente. Vous pouvez contacter les marchands via la messagerie.',
                        style: TextStyle(fontSize: 14, color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              ...merchants.map((merchant) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.pop(context);
                      
                      // ✅ NAVIGATION AVEC INFORMATIONS CORRECTES
                      _navigateToChat(
                        merchant.merchantId, 
                        order, 
                        "${merchant.merchantFirstName ?? ''} ${merchant.merchantLastName ?? ''}".trim(),
                        merchant.merchantPhoto,
                        merchant.isOnline ?? false,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gray200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryOrange.withOpacity(0.1),
                            backgroundImage: merchant.merchantPhoto != null 
                                ? NetworkImage(merchant.merchantPhoto!)
                                : null,
                            child: merchant.merchantPhoto == null
                                ? Icon(
                                    Icons.person,
                                    color: AppColors.primaryOrange,
                                    size: 20,
                                  )
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${merchant.merchantFirstName ?? ''} ${merchant.merchantLastName ?? ''}".trim(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  merchant.shopName,
                                  style: TextStyle(
                                    color: AppColors.gray600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: (merchant.isOnline ?? false) 
                                            ? Colors.green 
                                            : Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      (merchant.isOnline ?? false) 
                                          ? 'En ligne' 
                                          : 'Hors ligne',
                                      style: TextStyle(
                                        color: AppColors.gray500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppColors.gray400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendReminderToAllMerchants(order);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
            ),
            child: Text('Envoyer rappel général'),
          ),
        ],
      ),
    );
  }

  // 🆕 NAVIGATION VERS LE CHAT (version simplifiée)
  void _navigateToChat(
    int merchantId, 
    Order order, 
    String merchantName,
    String? merchantPhoto,
    bool isOnline,
  ) {
    // 🚫 Empêcher le contact pour les commandes annulées
    if (order.status == OrderStatus.canceled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Impossible de contacter le marchand pour une commande annulée'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 💬 CONSTRUIRE LE MESSAGE SIMPLIFIÉ
    String orderMessage = '''Bonjour $merchantName ! 👋

Je viens de passer une commande chez vous (#${order.formattedOrderNumber}).

Pouvez-vous vérifier et me revenir s'il vous plaît ?

Merci ! 😊''';

    // 🚀 NAVIGUER VERS LE CHAT
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          partnerId: merchantId,
          partnerName: merchantName,
          partnerPhoto: merchantPhoto,
          isOnline: isOnline,
          prefilledMessage: orderMessage,
          orderContext: order,
          isFromOrder: true,
        ),
      ),
    ).then((_) {
      _initializeOrders();
    });
  }

  // 🆕 ENVOYER RAPPEL À TOUS LES MARCHANDS
  Future<void> _sendReminderToAllMerchants(Order order) async {
    try {
      setState(() => _isLoading = true);
      
      await _orderService.sendOrderReminder(
        order.id,
        customMessage: 'Bonjour, pouvez-vous me confirmer l\'état de ma commande ? Merci !',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages de rappel envoyés avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🗑️ NOUVELLE MÉTHODE: Supprimer définitivement une commande annulée
  Future<void> _deleteOrder(Order order) async {
    final confirmed = await _showConfirmationDialog(
      'Supprimer la commande',
      'Êtes-vous sûr de vouloir supprimer définitivement cette commande annulée ?\n\nCette action est irréversible.',
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      
      await _orderService.deleteOrder(order.id);
      
      if (mounted) {
        // Supprimer de la liste locale immédiatement
        setState(() {
          _allOrders.removeWhere((o) => o.id == order.id);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Commande supprimée définitivement'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔧 CORRECTION: Méthode pour corriger les URLs d'images
  String _getFullImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    
    // Si l'URL est déjà complète, la retourner telle quelle
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    // Si l'URL commence par file://, la nettoyer et ajouter l'URL de base
    if (imageUrl.startsWith('file://')) {
      imageUrl = imageUrl.substring(7); // Retirer "file://"
    }
    
    // Si l'URL ne commence pas par /, l'ajouter
    if (!imageUrl.startsWith('/')) {
      imageUrl = '/$imageUrl';
    }
    
    // Construire l'URL complète
    return '${ApiConfig.baseUrl}$imageUrl';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getMerchantIcon(String merchantName) {
    if (merchantName.toLowerCase().contains('restaurant')) return '🏪';
    if (merchantName.toLowerCase().contains('café')) return '☕';
    if (merchantName.toLowerCase().contains('boulang')) return '🥖';
    if (merchantName.toLowerCase().contains('supermar')) return '🛒';
    if (merchantName.toLowerCase().contains('pharmacie')) return '💊';
    return '🏪';
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.shipped:
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.canceled:
        return AppColors.error;
    }
  }

  double _getOrderProgress(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0.2;
      case OrderStatus.confirmed:
        return 0.5;
      case OrderStatus.shipped:
        return 0.8;
      case OrderStatus.delivered:
        return 1.0;
      case OrderStatus.canceled:
        return 0.0;
    }
  }

  String _getProgressText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'En attente de confirmation...';
      case OrderStatus.confirmed:
        return 'Commande confirmée, préparation en cours...';
      case OrderStatus.shipped:
        return 'En cours de livraison...';
      case OrderStatus.delivered:
        return 'Livraison terminée';
      case OrderStatus.canceled:
        return 'Commande annulée';
    }
  }

  // 🎯 ACTIONS AVEC SERVICES
  Future<void> _refreshOrders() async {
    try {
      await _orderService.refreshOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commandes actualisées'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'actualisation: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _checkOrderConfirmation(Order order) async {
    try {
      setState(() => _isLoading = true);
      
      final confirmationResponse = await _orderService.checkOrderConfirmation(order.id);
      
      if (mounted) {
        if (confirmationResponse.merchants != null && confirmationResponse.merchants!.isNotEmpty) {
          // Afficher dialog avec navigation vers ChatScreen
          _showMerchantsContactDialog(order, confirmationResponse.merchants!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(confirmationResponse.message),
              backgroundColor: AppColors.info,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await _showConfirmationDialog(
      'Annuler la commande',
      'Êtes-vous sûr de vouloir annuler cette commande ?',
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      
      await _orderService.cancelOrder(order.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande annulée avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelivery(Order order) async {
    final confirmed = await _showConfirmationDialog(
      'Confirmer la réception',
      'Avez-vous bien reçu votre commande ?',
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      
      await _orderService.confirmDelivery(order.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réception confirmée avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _trackOrder(Order order) {
    print('🔄 Suivi commande: ${order.formattedOrderNumber}');
    // TODO: Implémenter le suivi en temps réel
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Suivi de ${order.formattedOrderNumber} - En développement'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  Future<void> _rateOrder(Order order) async {
    try {
      final feedbackResponse = await _orderService.requestMerchantFeedback(order.id);
      
      if (mounted) {
        _showFeedbackDialog(feedbackResponse.merchants);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _reorderOrder(Order order) {
    print('🔄 Recommande: ${order.formattedOrderNumber}');
    // TODO: Implémenter la recommande
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Racheter ${order.formattedOrderNumber} - En développement'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recherche'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher une commande...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Par date'),
              trailing: const Icon(Icons.date_range),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implémenter le filtre par date
              },
            ),
            ListTile(
              title: const Text('Par montant'),
              trailing: const Icon(Icons.attach_money),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implémenter le filtre par montant
              },
            ),
            ListTile(
              title: const Text('Par boutique'),
              trailing: const Icon(Icons.store),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implémenter le filtre par boutique
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // 🎯 DIALOGS UTILITAIRES
  Future<bool?> _showConfirmationDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(List<MerchantInfo> merchants) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Évaluer les marchands'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Veuillez évaluer votre expérience avec ces marchands :',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...merchants.map((merchant) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: AppColors.primaryOrange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    merchant.shopName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Row(
                    children: List.generate(5, (index) => Icon(
                      Icons.star_border,
                      size: 16,
                      color: AppColors.warning,
                    )),
                  ),
                  onTap: () {
                    // TODO: Implémenter l'évaluation
                    print('Évaluer marchand: ${merchant.shopName}');
                  },
                ),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Soumettre les évaluations
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Soumettre'),
          ),
        ],
      ),
    );
  }
}