import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/merchant_stats_service.dart';
import '../../models/merchant_stats_model.dart';
// 🔧 IMPORT AJOUTÉ POUR OrderException
import '../../models/order_model.dart';
import '../../widgets/navigation/custom_bottom_navigation.dart';
import '../../pages/merchant/merchant_orders_page.dart'; // 🔧 Page à créer

import '../../screens/conversations_screen.dart'; // 🔧 Votre fichier existant
import '../../widgets/charts/custom_revenue_chart.dart';
import '../../services/order_service.dart'; // 🆕 IMPORT AJOUTÉ

class MerchantStatsPage extends StatefulWidget {
  @override
  State<MerchantStatsPage> createState() => _MerchantStatsPageState();
}

class _MerchantStatsPageState extends State<MerchantStatsPage> {
  final MerchantStatsService _statsService = MerchantStatsService();
  final OrderService _orderService = OrderService(); // 🆕 AJOUTÉ
  
  MerchantStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Charger les statistiques
  Future<void> _loadStats() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final stats = await _statsService.getMerchantStats();
      
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _statsService.getErrorMessage(e);
      });
      
      if (e is OrderException && _statsService.shouldLogoutOnError(e)) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  /// Rafraîchir les données
  Future<void> _refreshStats() async {
    try {
      final stats = await _statsService.refreshStats();
      
      setState(() {
        _stats = stats;
        _errorMessage = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Statistiques mises à jour'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${_statsService.getErrorMessage(e)}'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _refreshStats,
        child: _buildBody(),
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: 0, // Index pour stats/accueil
        onTap: (index) => _onBottomNavTap(index),
        userType: 'merchant',
      ),
    );
  }

  void _onBottomNavTap(int index) {
    // Gérer la navigation selon l'index
    switch (index) {
      case 0: // Statistiques (déjà ici)
        break;
      case 1: // Messages  
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ConversationsScreen(), // 🔧 Votre fichier existant
        ));
        break;
      case 2: // Panier (pas applicable pour merchant)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Panier non disponible pour les marchands'))
        );
        break;
      case 3: // Ma Boutique
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ma Boutique - En développement'))
        );
        break;
      case 4: // Profil
        // Navigation déjà gérée dans CustomBottomNavigation
        break;
    }
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        // 📊 HEADER AVEC GRADIENT
        _buildHeader(),
        
        // 📈 CONTENU PRINCIPAL
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (_isLoading) _buildLoadingView(),
              if (_errorMessage != null) _buildErrorView(),
              if (_stats != null) ...[
                // 📊 KPI CARDS
                _buildStatsGrid(),
                SizedBox(height: 24),
                
                // ⚡ ACTIONS RAPIDES
                _buildQuickActions(),
                SizedBox(height: 24),
                
                // 📈 GRAPHIQUE DES VENTES
                _buildRevenueChart(),
                SizedBox(height: 24),
                
                // 📋 COMMANDES RÉCENTES
                _buildRecentOrders(),
                SizedBox(height: 24),
                
                // 🏆 TOP 5 PRODUITS
                _buildTopProducts(),
                SizedBox(height: 20),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  /// 📊 HEADER AVEC GRADIENT - VERSION SANS NOTIFICATIONS
  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 160, // 🔧 Augmenté pour éviter overflow
      floating: false,
      pinned: false,
      backgroundColor: AppColors.primaryOrange,
      automaticallyImplyLeading: false, // 🔧 Désactive le bouton de retour automatique
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF6B35),
                Color(0xFFF7931E),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 🔧 Calcul responsive des espacements
                double availableHeight = constraints.maxHeight;
                double horizontalPadding = 20;
                double verticalPadding = availableHeight * 0.08; // 8% de la hauteur
                
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 🔧 Distribution égale
                    children: [
                      // 🆕 TOP ROW AVEC ICÔNE DE RETOUR SEULEMENT
                      Row(
                        children: [
                          // 🆕 Icône de retour bien positionnée
                          _buildBackButton(),
                          SizedBox(width: 12),
                          
                          // Titre
                          Expanded(
                            child: Text(
                              'Mes Statistiques',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: MediaQuery.of(context).size.width > 360 ? 24 : 20, // 🔧 Responsive
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 🚫 BOUTON NOTIFICATION SUPPRIMÉ
                        ],
                      ),
                      
                      // 🔧 MERCHANT INFO SANS "ElectroShop"
                      Row(
                        children: [
                          _buildMerchantAvatar(),
                          SizedBox(width: 12), // 🔧 Réduit de 15 à 12
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min, // 🔧 Évite l'expansion
                              children: [
                                Text(
                                  'Tableau de bord', // 🔧 Remplace "ElectroShop"
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: MediaQuery.of(context).size.width > 360 ? 18 : 16, // 🔧 Responsive
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2), // 🔧 Petit espacement
                                Text(
                                  'Gérez vos ventes et commandes', // 🔧 Description plus générique
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: MediaQuery.of(context).size.width > 360 ? 14 : 12, // 🔧 Responsive
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 🆕 BOUTON DE RETOUR PERSONNALISÉ
  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // 🔧 Action de retour
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildMerchantAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          'ES', // ElectroShop initials
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 📈 STATS GRID (4 KPI)
  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          'Chiffre d\'Affaires',
          _stats!.formattedShortRevenue,
          _stats!.revenueGrowth,
          Icons.monetization_on,
          Color(0xFF10B981),
          true,
        ),
        _buildStatCard(
          'Total Commandes',
          _stats!.totalOrders.toString(),
          _stats!.ordersGrowth,
          Icons.shopping_bag,
          Color(0xFF3B82F6),
          true,
        ),
        _buildStatCard(
          'En Attente',
          _stats!.pendingOrders.toString(),
          'Action requise',
          Icons.access_time,
          Color(0xFFF59E0B),
          false,
        ),
        _buildStatCard(
          'Taux Succès',
          _stats!.formattedSuccessRate,
          '+5.2%',
          Icons.trending_up,
          Color(0xFF8B5CF6),
          true,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String change, IconData icon, Color color, bool isPositive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🔧 Calculs responsive basés sur la taille disponible
        double cardWidth = constraints.maxWidth;
        double cardHeight = constraints.maxHeight;
        
        // Responsive sizing
        double iconSize = (cardWidth * 0.2).clamp(28.0, 36.0);
        double mainPadding = (cardWidth * 0.08).clamp(12.0, 20.0);
        double fontSize = (cardWidth * 0.12).clamp(18.0, 24.0);
        double labelFontSize = (cardWidth * 0.06).clamp(10.0, 12.0);
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 15,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: Column(
            children: [
              // Top accent bar
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(mainPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon, 
                          color: Colors.white, 
                          size: iconSize * 0.5,
                        ),
                      ),
                      
                      SizedBox(height: cardHeight * 0.08),
                      
                      // Value - Responsive text
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: cardHeight * 0.02),
                      
                      // Label - Responsive text
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: labelFontSize,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      SizedBox(height: cardHeight * 0.06),
                      
                      // Change indicator
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: mainPadding * 0.4, 
                          vertical: 3
                        ),
                        decoration: BoxDecoration(
                          color: isPositive ? Color(0xFFECFDF5) : Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          change,
                          style: TextStyle(
                            fontSize: (labelFontSize * 0.9).clamp(9.0, 11.0),
                            fontWeight: FontWeight.w600,
                            color: isPositive ? Color(0xFF059669) : Color(0xFFDC2626),
                          ),
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
  
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions Rapides',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: 16),
        
        _buildActionCard(
          'Commandes en attente',
          'Nécessitent confirmation',
          Icons.access_time,
          LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)]),
          _stats!.pendingOrders.toString(),
          () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => MerchantOrdersPage(initialFilter: 'pending'),
            ));
          },
        ),
        
        SizedBox(height: 12),
        
        _buildActionCard(
          'Prêtes à expédier',
          'Commandes confirmées',
          Icons.check_circle,
          LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]),
          _stats!.confirmedOrders.toString(),
          () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => MerchantOrdersPage(initialFilter: 'confirmed'),
            ));
          },
        ),
        
        SizedBox(height: 12),
        
        _buildActionCard(
          'Rapport mensuel',
          'Exporter en PDF',
          Icons.description,
          LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)]),
          null,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Rapport PDF - En développement'))
            );
          },
        ),
        
        SizedBox(height: 12),
        
        _buildActionCard(
          'Gérer produits',
          'Ajouter, modifier, stock',
          Icons.inventory,
          LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)]),
          null,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gestion produits - En développement'))
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Gradient gradient, String? badge, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            
            SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Badge (if provided)
            if (badge != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 8),
            ],
            
            // Arrow
            Icon(
              Icons.chevron_right,
              color: Color(0xFFD1D5DB),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 📈 GRAPHIQUE DES VENTES PERSONNALISÉ
  Widget _buildRevenueChart() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Header avec informations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: Color(0xFF6B7280), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Ventes 7 derniers jours',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              // Indicateur de performance
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _stats!.revenueGrowth.startsWith('+') 
                      ? Color(0xFFECFDF5) 
                      : Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _stats!.revenueGrowth,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _stats!.revenueGrowth.startsWith('+')
                        ? Color(0xFF059669)
                        : Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Stats rapides au-dessus du graphique
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat(
                'Total', 
                _stats!.formattedShortRevenue, 
                Icons.monetization_on,
                Color(0xFF10B981),
              ),
              _buildQuickStat(
                'Moyenne/jour', 
                _formatShortNumber(_stats!.averageDailyRevenue), 
                Icons.trending_up,
                Color(0xFF3B82F6),
              ),
              _buildQuickStat(
                'Meilleur jour', 
                _stats!.bestDay != null 
                    ? _formatShortNumber(_stats!.bestDay!.revenue)
                    : '0', 
                Icons.star,
                Color(0xFFF59E0B),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Le graphique personnalisé
          CustomRevenueChart(
            data: _stats!.revenueChart,
            height: 200,
          ),
          
          SizedBox(height: 16),
          
          // Footer avec informations supplémentaires
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Commandes: ${_stats!.revenueChart.fold(0, (sum, data) => sum + data.orderCount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Panier moyen: ${_stats!.formattedShortAverageOrderValue} FCFA',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentOrders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Commandes Récentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => MerchantOrdersPage(),
                ));
              },
              child: Text('Voir tout'),
            ),
          ],
        ),
        SizedBox(height: 16),
        
        ...(_stats!.recentOrders.take(3).map((order) => _buildOrderItem(order)).toList()),
      ],
    );
  }

  Widget _buildOrderItem(RecentOrder order) {
    Color statusColor;
    Color statusBgColor;
    
    switch (order.status.toLowerCase()) {
      case 'pending':
        statusColor = Color(0xFF92400E);
        statusBgColor = Color(0xFFFEF3C7);
        break;
      case 'confirmed':
        statusColor = Color(0xFF065F46);
        statusBgColor = Color(0xFFD1FAE5);
        break;
      case 'shipped':
        statusColor = Color(0xFF1E40AF);
        statusBgColor = Color(0xFFDBEAFE);
        break;
      default:
        statusColor = Color(0xFF6B7280);
        statusBgColor = Color(0xFFF3F4F6);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${order.id}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.displayStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.clientName,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                order.formattedTotalAmount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          // 🆕 ACTIONS AJOUTÉES
          _buildOrderActions(order),
        ],
      ),
    );
  }

  /// 🏆 TOP 5 PRODUITS
  Widget _buildTopProducts() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.star, color: Color(0xFF6B7280), size: 24),
              SizedBox(width: 10),
              Text(
                'Top 5 Produits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Products list
          ...(_stats!.topProducts.take(5).map((product) => _buildProductItem(product)).toList()),
        ],
      ),
    );
  }

  Widget _buildProductItem(TopProduct product) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${product.totalSold} vendus',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            product.formattedTotalRevenue,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔄 LOADING VIEW
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primaryOrange),
          SizedBox(height: 16),
          Text(
            'Chargement des statistiques...',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// ❌ ERROR VIEW
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
            onPressed: _loadStats,
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

  // 🎯 ========== MÉTHODES MANQUANTES AJOUTÉES ==========

  /// Widget pour les statistiques rapides au-dessus du graphique
  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Formater un nombre en version courte (ex: 2.5K, 1.2M)
  String _formatShortNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(0);
    }
  }

  // 🆕 ========== MÉTHODES POUR ACTIONS COMMANDES ==========

  /// Voir les détails d'une commande
  void _viewOrderDetails(RecentOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 8, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header avec gradient
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryOrange,
                    AppColors.primaryOrange.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commande #${order.id}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Détails complets',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.displayStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📞 INFORMATIONS CLIENT COMPLÈTES
                    _buildEnhancedClientInfoFromOrder(order),
                    
                    SizedBox(height: 20),
                    
                    // 💰 RÉSUMÉ FINANCIER
                    _buildFinancialSummaryFromOrder(order),
                    
                    SizedBox(height: 20),
                    
                    // 📦 PRODUITS COMMANDÉS
                    _buildProductsFromOrder(order),
                    
                    SizedBox(height: 20),
                    
                    // ⚡ ACTIONS RAPIDES
                    if (order.status.toLowerCase() == 'pending') 
                      _buildQuickActionsFromOrder(order),
                    
                    SizedBox(height: 20),
                    
                    // 📋 Bouton voir liste complète
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => MerchantOrdersPage(
                              initialFilter: order.status.toLowerCase(),
                            ),
                          ));
                        },
                        icon: Icon(Icons.list, size: 18),
                        label: Text('Voir toutes les commandes ${order.displayStatus.toLowerCase()}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: BorderSide(color: AppColors.primaryOrange),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📞 Informations client pour RecentOrder
  Widget _buildEnhancedClientInfoFromOrder(RecentOrder order) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person, color: Colors.blue[700], size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Informations du client',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Nom complet
          _buildInfoRowFromOrder(
            Icons.badge, 
            'Nom complet', 
            order.clientName,
            Colors.blue[700]!,
          ),
          
          SizedBox(height: 12),
          
          // 🔧 Numéro de téléphone (si disponible dans votre modèle)
          _buildInfoRowFromOrder(
            Icons.phone, 
            'Téléphone', 
            order.clientPhone ?? 'Non renseigné',
            Colors.green[700]!,
            isClickable: order.clientPhone != null,
            onTap: order.clientPhone != null 
              ? () => _callClientFromOrder(order.clientPhone!) 
              : null,
          ),
          
          SizedBox(height: 12),
          
          // Email (si disponible)
          _buildInfoRowFromOrder(
            Icons.email, 
            'Email', 
            order.clientEmail ?? 'Non renseigné',
            Colors.purple[700]!,
          ),
          
          SizedBox(height: 12),
          
          // Adresse de livraison (si disponible)
          _buildInfoRowFromOrder(
            Icons.location_on, 
            'Adresse', 
            order.deliveryAddress ?? 'Non renseignée',
            Colors.red[700]!,
          ),
        ],
      ),
    );
  }

  /// 💰 Résumé financier pour RecentOrder
  Widget _buildFinancialSummaryFromOrder(RecentOrder order) {
    // RecentOrder n'a que totalAmount (pas de détails des frais)
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.monetization_on, color: Colors.green[700], size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Résumé financier',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Message d'information
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Détails financiers complets disponibles dans la liste des commandes',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Total seulement (car c'est ce qu'on a dans RecentOrder)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              Text(
                order.formattedTotalAmount,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 📦 Produits pour RecentOrder
  Widget _buildProductsFromOrder(RecentOrder order) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shopping_bag, color: Colors.orange[700], size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Produits commandés',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${order.totalProductsCount} article${order.totalProductsCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // 🔧 Liste des produits (adaptée selon la structure products de RecentOrder)
          if (order.hasProducts)
            ...order.products!.map((productData) {
              // Extraction des données du Map<String, dynamic>
              final productName = productData['name'] ?? 'Produit sans nom';
              final quantity = productData['quantity'] ?? 1;
              final price = (productData['price'] ?? 0).toDouble();
              final imageUrl = productData['imageUrl'];
              final subtotal = price * quantity;
              
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Photo du produit
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                _buildProductPlaceholder(),
                            )
                          : _buildProductPlaceholder(),
                      ),
                    ),
                    
                    SizedBox(width: 12),
                    
                    // Infos du produit
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          SizedBox(height: 4),
                          
                          Row(
                            children: [
                              Icon(Icons.numbers, size: 14, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                'Qté: $quantity',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 2),
                          
                          Row(
                            children: [
                              Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                'Prix: ${price.toStringAsFixed(0)} FCFA',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 8),
                    
                    // Prix total de l'item
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${subtotal.toStringAsFixed(0)} FCFA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList()
          else
            // Placeholder si pas de produits détaillés
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Détails des produits disponibles dans la liste complète des commandes',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Actions rapides pour RecentOrder
  Widget _buildQuickActionsFromOrder(RecentOrder order) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flash_on, color: Colors.red[700], size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Actions rapides',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[800],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _rejectOrder(order);
                  },
                  icon: Icon(Icons.close, size: 18),
                  label: Text('Refuser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmOrder(order);
                  },
                  icon: Icon(Icons.check, size: 18),
                  label: Text('Confirmer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ligne d'information pour RecentOrder
  Widget _buildInfoRowFromOrder(IconData icon, String label, String value, Color iconColor, {bool isClickable = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            if (isClickable)
              Icon(Icons.call, color: Colors.green, size: 16),
          ],
        ),
      ),
    );
  }

  /// Appeler le client depuis RecentOrder
  void _callClientFromOrder(String phoneNumber) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📞 Appel vers $phoneNumber'),
        action: SnackBarAction(
          label: 'Copier',
          onPressed: () {
            // TODO: Copier le numéro dans le presse-papier
          },
        ),
      ),
    );
  }

  /// Placeholder pour les images de produits
  Widget _buildProductPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            color: Colors.grey[400],
            size: 20,
          ),
          SizedBox(height: 2),
          Text(
            'Photo',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Color(0xFFF59E0B);
      case 'confirmed':
        return Color(0xFF10B981);
      case 'shipped':
        return Color(0xFF3B82F6);
      case 'delivered':
        return Color(0xFF16A34A);
      default:
        return Color(0xFF6B7280);
    }
  }

  Future<void> _confirmOrder(RecentOrder order) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⏳ Confirmation en cours...'))
      );
      
      // 🔧 TODO: Adapter selon ton modèle OrderStatus
      // await _orderService.updateOrderStatus(order.id, OrderStatus.confirmed);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Commande #${order.id} confirmée'))
      );
      
      // Recharger les statistiques
      _loadStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la confirmation'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  /// Refuser une commande
  Future<void> _rejectOrder(RecentOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🚫 Refuser la commande'),
        content: Text('Êtes-vous sûr de vouloir refuser la commande #${order.id} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Refuser'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⏳ Refus en cours...'))
      );
      
      // 🔧 TODO: Adapter selon ton modèle OrderStatus
      // await _orderService.updateOrderStatus(order.id, OrderStatus.canceled);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Commande #${order.id} refusée'))
      );
      
      _loadStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors du refus'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  /// Marquer comme expédiée
  Future<void> _markAsShipped(RecentOrder order) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⏳ Marquage en cours...'))
      );
      
      // 🔧 TODO: Adapter selon ton modèle OrderStatus
      // await _orderService.updateOrderStatus(order.id, OrderStatus.shipped);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🚚 Commande #${order.id} marquée comme expédiée'))
      );
      
      _loadStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors du marquage'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  /// Marquer comme livrée
  Future<void> _markAsDelivered(RecentOrder order) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⏳ Marquage en cours...'))
      );
      
      // 🔧 TODO: Adapter selon ton modèle OrderStatus
      // await _orderService.updateOrderStatus(order.id, OrderStatus.delivered);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Commande #${order.id} marquée comme livrée'))
      );
      
      _loadStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors du marquage'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  /// Widget pour les actions d'une commande récente
  Widget _buildOrderActions(RecentOrder order) {
    switch (order.status.toLowerCase()) {
      case 'pending':
        // 🆕 Pour les commandes en attente : Voir détails + Actions
        return Padding(
          padding: EdgeInsets.only(top: 12),
          child: Column(
            children: [
              // Première ligne : Voir détails
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _viewOrderDetails(order),
                  icon: Icon(Icons.visibility, size: 16),
                  label: Text('Voir détails de la commande', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    side: BorderSide(color: AppColors.primaryOrange),
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                ),
              ),
              
              SizedBox(height: 8),
              
              // Deuxième ligne : Actions (Refuser/Confirmer)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectOrder(order),
                      icon: Icon(Icons.close, size: 14),
                      label: Text('Refuser', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmOrder(order),
                      icon: Icon(Icons.check, size: 14),
                      label: Text('Confirmer', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      
      case 'confirmed':
        return Padding(
          padding: EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _markAsShipped(order),
                  icon: Icon(Icons.local_shipping, size: 14),
                  label: Text('Expédier', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        );
      
      case 'shipped':
        return Padding(
          padding: EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _markAsDelivered(order),
                  icon: Icon(Icons.check_circle, size: 14),
                  label: Text('Livrer', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        );
      
      default:
        return Padding(
          padding: EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewOrderDetails(order),
                  icon: Icon(Icons.visibility, size: 14),
                  label: Text('Voir détails', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    side: BorderSide(color: AppColors.primaryOrange),
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}