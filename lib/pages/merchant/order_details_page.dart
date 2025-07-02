// lib/pages/merchant/order_details_page.dart - PAGE DÉTAILS COMMANDE

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';

class OrderDetailsPage extends StatefulWidget {
  final MerchantOrder order;
  
  const OrderDetailsPage({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final OrderService _orderService = OrderService();
  late MerchantOrder _order;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Commande #${_order.id}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 En-tête commande
            _buildOrderHeader(),
            SizedBox(height: 20),
            
            // 👤 CLIENT
            _buildClientSection(),
            SizedBox(height: 20),
            
            // 📦 Produits commandés
            _buildProductsList(),
            SizedBox(height: 30),
            
            // 🎯 Actions principales
            _buildMainActions(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 📋 En-tête de la commande
  Widget _buildOrderHeader() {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMMANDE-${_order.id}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    _formatDate(_order.createdAt),
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(_order.status),
            ],
          ),
          
          SizedBox(height: 16),
          
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Montant total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  _order.formattedTotalAmount,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 👤 SECTION CLIENT
  Widget _buildClientSection() {
    return Container(
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
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            // Avatar client
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  _order.client.fullName.isNotEmpty 
                      ? _order.client.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            SizedBox(width: 16),
            
            // Informations client
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _order.client.fullName.isNotEmpty 
                        ? _order.client.fullName
                        : 'Client #${_order.id}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Client de la boutique',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            
            // ID CLIENT
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ID: ${_order.client.id}',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📦 Liste des produits
  Widget _buildProductsList() {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag, color: Color(0xFF6B7280), size: 20),
              SizedBox(width: 8),
              Text(
                'Produits commandés',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          ...(_order.items.map((item) => _buildProductItem(item)).toList()),
          
          // Résumé financier
          SizedBox(height: 20),
          Divider(),
          SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total de la commande',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                _order.formattedTotalAmount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(MerchantOrderItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Image produit
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildProductImage(item.product),
            ),
          ),
          
          SizedBox(width: 12),
          
          // Infos produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getProductName(item),
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
                SizedBox(height: 2),
                Text(
                  'Produit ID: ${item.product.id}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Total item
          Text(
            _getFormattedTotalPrice(item),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  /// IMAGE DU PRODUIT
  Widget _buildProductImage(product) {
    // Vérifier si le produit a des images
    if (product.images != null && product.images.isNotEmpty) {
      final imageUrl = product.images[0];
      
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: 60,
        height: 60,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: AppColors.primaryOrange,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    }
    
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.inventory_2,
        color: Color(0xFF6B7280),
        size: 24,
      ),
    );
  }

  // Méthodes helper
  String _getProductName(MerchantOrderItem item) {
    return item.product.name.isNotEmpty ? item.product.name : 'Produit #${item.id}';
  }

  String _getFormattedTotalPrice(MerchantOrderItem item) {
    return item.formattedSubtotal;
  }

  /// Actions principales
  Widget _buildMainActions() {
    List<Widget> actions = [];

    switch (_order.status.value.toLowerCase()) {
      case 'pending':
        actions = [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isUpdating ? null : () => _rejectOrder(),
              icon: Icon(Icons.close, size: 18),
              label: Text('Refuser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : () => _confirmOrder(),
              icon: _isUpdating 
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.check, size: 18),
              label: Text(_isUpdating ? 'Confirmation...' : 'Confirmer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ];
        break;
      
      case 'confirmed':
        actions = [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : () => _markAsShipped(),
              icon: _isUpdating 
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.local_shipping, size: 18),
              label: Text(_isUpdating ? 'Expédition...' : 'Marquer expédiée'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ];
        break;
      
      case 'shipped':
        actions = [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : () => _markAsDelivered(),
              icon: _isUpdating 
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.check_circle, size: 18),
              label: Text(_isUpdating ? 'Livraison...' : 'Marquer livrée'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ];
        break;
      
      default:
        actions = [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, size: 18),
              label: Text('Retour'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: BorderSide(color: AppColors.primaryOrange),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ];
    }

    return Row(children: actions);
  }

  // Méthodes utilitaires
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Actions sur la commande
  Future<void> _confirmOrder() async {
    setState(() => _isUpdating = true);
    
    try {
      await _orderService.updateOrderStatus(_order.id, OrderStatus.confirmed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Commande confirmée'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la confirmation'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _rejectOrder() async {
    setState(() => _isUpdating = true);
    
    try {
      await _orderService.updateOrderStatus(_order.id, OrderStatus.canceled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Commande refusée'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors du refus'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAsShipped() async {
    setState(() => _isUpdating = true);
    
    try {
      await _orderService.updateOrderStatus(_order.id, OrderStatus.shipped);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🚚 Commande expédiée'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de l\'expédition'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAsDelivered() async {
    setState(() => _isUpdating = true);
    
    try {
      await _orderService.updateOrderStatus(_order.id, OrderStatus.delivered);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Commande livrée'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la livraison'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }
}