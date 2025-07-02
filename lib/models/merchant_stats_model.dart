// lib/models/merchant_stats_model.dart - VERSION CORRIGÉE SANS DUPLICATION

// 🔧 IMPORT de OrderException depuis order_model.dart
import 'order_model.dart';

/// Modèle pour un produit dans le top 5
class TopProduct {
  final int productId;
  final String productName;
  final int totalSold;
  final double totalRevenue;
  final int orderCount;

  TopProduct({
    required this.productId,
    required this.productName,
    required this.totalSold,
    required this.totalRevenue,
    required this.orderCount,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: json['productId'] ?? 0,
      productName: json['productName'] ?? '',
      totalSold: json['totalSold'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      orderCount: json['orderCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'totalSold': totalSold,
      'totalRevenue': totalRevenue,
      'orderCount': orderCount,
    };
  }

  /// Revenus formatés
  String get formattedTotalRevenue => '${_formatNumber(totalRevenue)} FCFA';

  /// Revenus courts (ex: 2.5K)
  String get formattedShortRevenue {
    if (totalRevenue >= 1000000) {
      return '${(totalRevenue / 1000000).toStringAsFixed(1)}M';
    } else if (totalRevenue >= 1000) {
      return '${(totalRevenue / 1000).toStringAsFixed(1)}K';
    } else {
      return totalRevenue.toStringAsFixed(0);
    }
  }

  /// Pourcentage de performance (basé sur les ventes)
  double getPerformancePercentage(List<TopProduct> allProducts) {
    if (allProducts.isEmpty) return 0;
    
    final maxSold = allProducts.map((p) => p.totalSold).reduce((a, b) => a > b ? a : b);
    return maxSold > 0 ? (totalSold / maxSold * 100) : 0;
  }

  /// Formate un nombre avec des espaces comme séparateurs de milliers
  String _formatNumber(double number) {
    final numberStr = number.toStringAsFixed(0);
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return numberStr.replaceAllMapped(regex, (Match match) => '${match[1]} ');
  }

  @override
  String toString() {
    return 'TopProduct(productName: $productName, totalSold: $totalSold, totalRevenue: $totalRevenue)';
  }
}

/// Modèle pour une commande récente simplifiée - VERSION FINALE
class RecentOrder {
  final int id;
  final String clientName;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final String? clientPhone;
  final String? clientEmail;
  final String? deliveryAddress;
  final List<dynamic>? products;

  RecentOrder({
    required this.id,
    required this.clientName,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.clientPhone,
    this.clientEmail,
    this.deliveryAddress,
    this.products,
  });

  factory RecentOrder.fromJson(Map<String, dynamic> json) {
    // 🔧 Parser selon la vraie structure API
    final clientData = json['client'] as Map<String, dynamic>?;
    final firstName = clientData?['firstName'] ?? '';
    final lastName = clientData?['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    return RecentOrder(
      id: json['id'] ?? 0,
      
      // 🔧 Nom complet depuis client.firstName + client.lastName
      clientName: fullName.isNotEmpty ? fullName : (json['clientName'] ?? 'Client inconnu'),
      
      // 🔧 Téléphone depuis client.phoneNumber
      clientPhone: clientData?['phoneNumber'] ?? json['clientPhone'],
                   
      // 🔧 Email depuis client.email
      clientEmail: clientData?['email'] ?? json['clientEmail'],
                   
      // 🔧 Adresse de livraison
      deliveryAddress: json['deliveryAddress'],
      
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: json['status'] ?? 'PENDING',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      
      // 🔧 Produits depuis items[] ou products[]
      products: (json['items'] ?? json['products']) as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientEmail': clientEmail,
      'deliveryAddress': deliveryAddress,
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'products': products,
    };
  }

  /// Montant formaté
  String get formattedTotalAmount => '${_formatNumber(totalAmount)} FCFA';

  /// Numéro de commande formaté
  String get formattedOrderNumber => 'COMMANDE-$id';

  /// Date formatée (ex: "12 Jan")
  String get formattedDate {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 
                   'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${createdAt.day} ${months[createdAt.month - 1]}';
  }

  /// Date complète formatée (ex: "12 janvier 2024")
  String get formattedFullDate {
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
                   'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year}';
  }

  /// Temps écoulé (ex: "Il y a 2 heures")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  /// Statut formaté pour l'affichage
  String get displayStatus {
    switch (status.toUpperCase()) {
      case 'PENDING': return 'En attente';
      case 'CONFIRMED': return 'Confirmée';
      case 'SHIPPED': return 'Expédiée';
      case 'DELIVERED': return 'Livrée';
      case 'CANCELED': return 'Annulée';
      default: return status;
    }
  }

  /// Obtenir le nombre total de produits
  int get totalProductsCount {
    if (products == null || products!.isEmpty) return 0;
    
    return products!.fold<int>(0, (total, product) {
      // Gérer différentes structures possibles
      int quantity = 0;
      if (product is Map<String, dynamic>) {
        quantity = product['quantity'] ?? product['qty'] ?? 1;
      } else {
        quantity = 1;
      }
      return total + quantity;
    });
  }

  /// Vérifier si la commande a des produits
  bool get hasProducts => products != null && products!.isNotEmpty;

  /// Formate un nombre avec des espaces comme séparateurs de milliers
  String _formatNumber(double number) {
    final numberStr = number.toStringAsFixed(0);
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return numberStr.replaceAllMapped(regex, (Match match) => '${match[1]} ');
  }

  @override
  String toString() {
    return 'RecentOrder(id: $id, clientName: $clientName, clientPhone: $clientPhone, totalAmount: $totalAmount, status: $status, productsCount: $totalProductsCount)';
  }
}

/// Modèle pour les données du graphique des revenus
class RevenueChartData {
  final DateTime date;
  final double revenue;
  final int orderCount;

  RevenueChartData({
    required this.date,
    required this.revenue,
    required this.orderCount,
  });

  factory RevenueChartData.fromJson(Map<String, dynamic> json) {
    return RevenueChartData(
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      revenue: (json['revenue'] ?? 0).toDouble(),
      orderCount: json['orderCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'revenue': revenue,
      'orderCount': orderCount,
    };
  }

  /// Revenus formatés
  String get formattedRevenue => '${_formatNumber(revenue)} FCFA';

  /// Revenus courts pour graphique
  String get shortRevenue {
    if (revenue >= 1000000) {
      return '${(revenue / 1000000).toStringAsFixed(1)}M';
    } else if (revenue >= 1000) {
      return '${(revenue / 1000).toStringAsFixed(1)}K';
    } else {
      return revenue.toStringAsFixed(0);
    }
  }

  /// Date formatée pour graphique (JJ/MM)
  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  /// Jour de la semaine court (Lun, Mar, etc.)
  String get dayOfWeek {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[date.weekday - 1];
  }

  /// Panier moyen pour ce jour
  double get averageOrderValue {
    return orderCount > 0 ? revenue / orderCount : 0;
  }

  /// Formate un nombre avec des espaces comme séparateurs de milliers
  String _formatNumber(double number) {
    final numberStr = number.toStringAsFixed(0);
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return numberStr.replaceAllMapped(regex, (Match match) => '${match[1]} ');
  }

  @override
  String toString() {
    return 'RevenueChartData(date: ${formattedDate}, revenue: $revenue, orderCount: $orderCount)';
  }
}

/// Modèle principal pour les statistiques du marchand
class MerchantStats {
  final double totalRevenue;
  final int totalOrders;
  final int pendingOrders;
  final int confirmedOrders;
  final int shippedOrders;
  final int deliveredOrders;
  final int canceledOrders;
  final double successRate;
  final double averageOrderValue;
  final List<TopProduct> topProducts;
  final List<RecentOrder> recentOrders;
  final List<RevenueChartData> revenueChart;

  MerchantStats({
    required this.totalRevenue,
    required this.totalOrders,
    required this.pendingOrders,
    required this.confirmedOrders,
    required this.shippedOrders,
    required this.deliveredOrders,
    required this.canceledOrders,
    required this.successRate,
    required this.averageOrderValue,
    required this.topProducts,
    required this.recentOrders,
    required this.revenueChart,
  });

  factory MerchantStats.fromJson(Map<String, dynamic> json) {
    return MerchantStats(
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalOrders: json['totalOrders'] ?? 0,
      pendingOrders: json['pendingOrders'] ?? 0,
      confirmedOrders: json['confirmedOrders'] ?? 0,
      shippedOrders: json['shippedOrders'] ?? 0,
      deliveredOrders: json['deliveredOrders'] ?? 0,
      canceledOrders: json['canceledOrders'] ?? 0,
      successRate: (json['successRate'] ?? 0).toDouble(),
      averageOrderValue: (json['averageOrderValue'] ?? 0).toDouble(),
      topProducts: (json['topProducts'] as List<dynamic>?)
          ?.map((product) => TopProduct.fromJson(product))
          .toList() ?? [],
      recentOrders: (json['recentOrders'] as List<dynamic>?)
          ?.map((order) => RecentOrder.fromJson(order))
          .toList() ?? [],
      revenueChart: (json['revenueChart'] as List<dynamic>?)
          ?.map((data) => RevenueChartData.fromJson(data))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'pendingOrders': pendingOrders,
      'confirmedOrders': confirmedOrders,
      'shippedOrders': shippedOrders,
      'deliveredOrders': deliveredOrders,
      'canceledOrders': canceledOrders,
      'successRate': successRate,
      'averageOrderValue': averageOrderValue,
      'topProducts': topProducts.map((product) => product.toJson()).toList(),
      'recentOrders': recentOrders.map((order) => order.toJson()).toList(),
      'revenueChart': revenueChart.map((data) => data.toJson()).toList(),
    };
  }

  // =====================================================
  // PROPRIÉTÉS CALCULÉES ET FORMATAGE
  // =====================================================

  /// Revenus totaux formatés
  String get formattedTotalRevenue {
    return '${_formatNumber(totalRevenue)} FCFA';
  }

  /// Revenus en format court (ex: 2.8M)
  String get formattedShortRevenue {
    if (totalRevenue >= 1000000) {
      return '${(totalRevenue / 1000000).toStringAsFixed(1)}M';
    } else if (totalRevenue >= 1000) {
      return '${(totalRevenue / 1000).toStringAsFixed(1)}K';
    } else {
      return totalRevenue.toStringAsFixed(0);
    }
  }

  /// Taux de succès formaté
  String get formattedSuccessRate => '${successRate.toStringAsFixed(1)}%';

  /// Panier moyen formaté
  String get formattedAverageOrderValue => '${_formatNumber(averageOrderValue)} FCFA';

  /// Panier moyen en format court
  String get formattedShortAverageOrderValue {
    if (averageOrderValue >= 1000000) {
      return '${(averageOrderValue / 1000000).toStringAsFixed(1)}M';
    } else if (averageOrderValue >= 1000) {
      return '${(averageOrderValue / 1000).toStringAsFixed(1)}K';
    } else {
      return averageOrderValue.toStringAsFixed(0);
    }
  }

  // =====================================================
  // INDICATEURS DE PERFORMANCE
  // =====================================================

  /// Calculer l'évolution des revenus (en %)
  String get revenueGrowth {
    if (revenueChart.length < 2) return '+0%';
    
    // Prendre les 3 derniers jours et les 3 précédents
    final chartLength = revenueChart.length;
    if (chartLength < 6) return '+0%';
    
    final recent = revenueChart.sublist(chartLength - 3);
    final previous = revenueChart.sublist(chartLength - 6, chartLength - 3);
    
    if (recent.isEmpty || previous.isEmpty) return '+0%';
    
    final recentAvg = recent.fold(0.0, (sum, data) => sum + data.revenue) / recent.length;
    final previousAvg = previous.fold(0.0, (sum, data) => sum + data.revenue) / previous.length;
    
    if (previousAvg == 0) return '+0%';
    
    final growth = ((recentAvg - previousAvg) / previousAvg) * 100;
    final sign = growth >= 0 ? '+' : '';
    return '$sign${growth.toStringAsFixed(1)}%';
  }

  /// Calculer l'évolution des commandes
  String get ordersGrowth {
    if (revenueChart.length < 2) return '+0';
    
    // Prendre les 3 derniers jours et les 3 précédents
    final chartLength = revenueChart.length;
    if (chartLength < 6) return '+0';
    
    final recent = revenueChart.sublist(chartLength - 3);
    final previous = revenueChart.sublist(chartLength - 6, chartLength - 3);
    
    if (recent.isEmpty || previous.isEmpty) return '+0';
    
    final recentSum = recent.fold(0, (sum, data) => sum + data.orderCount);
    final previousSum = previous.fold(0, (sum, data) => sum + data.orderCount);
    
    final growth = recentSum - previousSum;
    final sign = growth >= 0 ? '+' : '';
    return '$sign$growth';
  }

  /// Revenus d'aujourd'hui
  double get todayRevenue {
    final today = DateTime.now();
    final todayData = revenueChart.where((data) {
      return data.date.day == today.day && 
             data.date.month == today.month && 
             data.date.year == today.year;
    });
    
    return todayData.isNotEmpty ? todayData.first.revenue : 0;
  }

  /// Revenus d'hier
  double get yesterdayRevenue {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayData = revenueChart.where((data) {
      return data.date.day == yesterday.day && 
             data.date.month == yesterday.month && 
             data.date.year == yesterday.year;
    });
    
    return yesterdayData.isNotEmpty ? yesterdayData.first.revenue : 0;
  }

  /// Performance du jour (comparé à hier)
  String get dailyPerformance {
    if (yesterdayRevenue == 0) return '+0%';
    
    final growth = ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
    final sign = growth >= 0 ? '+' : '';
    return '$sign${growth.toStringAsFixed(1)}%';
  }

  // =====================================================
  // PROPRIÉTÉS UTILITAIRES
  // =====================================================

  /// Vérifier si les données sont vides
  bool get isEmpty => totalOrders == 0;

  /// Obtenir le produit le plus vendu
  TopProduct? get topProduct => topProducts.isNotEmpty ? topProducts.first : null;

  /// Obtenir la commande la plus récente
  RecentOrder? get latestOrder => recentOrders.isNotEmpty ? recentOrders.first : null;

  /// Nombre de commandes actives (pending + confirmed + shipped)
  int get activeOrders => pendingOrders + confirmedOrders + shippedOrders;

  /// Pourcentage de commandes actives
  double get activeOrdersPercentage {
    return totalOrders > 0 ? (activeOrders / totalOrders) * 100 : 0;
  }

  /// Revenue moyen par jour
  double get averageDailyRevenue {
    if (revenueChart.isEmpty) return 0;
    
    final totalChartRevenue = revenueChart.fold(0.0, (sum, data) => sum + data.revenue);
    return totalChartRevenue / revenueChart.length;
  }

  /// Jour le plus performant
  RevenueChartData? get bestDay {
    if (revenueChart.isEmpty) return null;
    
    return revenueChart.reduce((a, b) => a.revenue > b.revenue ? a : b);
  }

  /// Résumé textuel des performances
  String get performanceSummary {
    if (isEmpty) return 'Aucune donnée disponible';
    
    final growthDirection = revenueGrowth.startsWith('+') ? 'en hausse' : 'en baisse';
    return 'CA $growthDirection de ${revenueGrowth.replaceAll('+', '')} avec ${ordersGrowth.replaceAll('+', '')} commandes';
  }

  // =====================================================
  // MÉTHODES UTILITAIRES PRIVÉES
  // =====================================================

  /// Formate un nombre avec des espaces comme séparateurs de milliers
  String _formatNumber(double number) {
    final numberStr = number.toStringAsFixed(0);
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return numberStr.replaceAllMapped(regex, (Match match) => '${match[1]} ');
  }

  @override
  String toString() {
    return 'MerchantStats(totalRevenue: $totalRevenue, totalOrders: $totalOrders, successRate: $successRate, topProducts: ${topProducts.length})';
  }
}

// 🔧 SUPPRESSION DE LA DUPLICATION - OrderException est maintenant importée depuis order_model.dart