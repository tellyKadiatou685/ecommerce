// lib/services/merchant_stats_service.dart - SERVICE CORRIGÉ SANS CONFLIT D'IMPORTS

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/merchant_stats_model.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import 'api_config.dart';

class MerchantStatsService {
  static final MerchantStatsService _instance = MerchantStatsService._internal();
  factory MerchantStatsService() => _instance;
  MerchantStatsService._internal();

  // 🆕 AJOUT: Dépendance à OrderService pour récupérer les commandes
  final OrderService _orderService = OrderService();

  // Cache pour éviter les appels répétés
  MerchantStats? _cachedStats;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Obtient le token d'authentification
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      String? token = prefs.getString('auth_token');
      if (token == null) {
        token = prefs.getString('token');
        if (token == null) {
          token = prefs.getString('access_token');
        }
      }
      
      if (token == null) {
        print('❌ [STATS] Aucun token trouvé');
        return null;
      }

      if (_isTokenExpired(token)) {
        print('❌ [STATS] Token expiré');
        await _handleAuthError();
        return null;
      }

      return token;
    } catch (e) {
      print('❌ [STATS] Erreur récupération token: $e');
      return null;
    }
  }

  /// Vérifie si le token JWT est expiré
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
      );

      final exp = payload['exp'] as int?;
      if (exp == null) return true;

      final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expirationTime);
    } catch (e) {
      print('❌ [STATS] Erreur validation token: $e');
      return true;
    }
  }

  /// Gère les erreurs d'authentification
  Future<void> _handleAuthError() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      await prefs.remove('token');
      await prefs.remove('user');
      print('⚠️ [STATS] Session expirée - données nettoyées');
      
      _clearCache();
    } catch (e) {
      print('❌ [STATS] Erreur lors du nettoyage: $e');
    }
  }

  /// Vérifie si l'utilisateur est connecté
  Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user_data');
      final token = await _getAuthToken();
      
      return userStr != null && token != null;
    } catch (e) {
      print('❌ [STATS] Erreur vérification connexion: $e');
      return false;
    }
  }

  /// 📊 MÉTHODE CORRIGÉE - RÉCUPÉRER LES STATISTIQUES DEPUIS LES COMMANDES
  Future<MerchantStats> getMerchantStats({bool forceRefresh = false}) async {
    try {
      print('📊 [STATS] Récupération des statistiques marchand depuis les commandes');

      // Vérifier le cache
      if (!forceRefresh && _isValidCache()) {
        print('✅ [STATS] Utilisation du cache');
        return _cachedStats!;
      }

      if (!await isUserLoggedIn()) {
        throw OrderException(
          'NOT_LOGGED_IN',
          'Vous devez être connecté pour accéder aux statistiques'
        );
      }

      // 🔧 UTILISER OrderService pour récupérer les commandes réelles
      final List<MerchantOrder> merchantOrders = await _orderService.getMerchantOrders();
      
      print('📋 [STATS] ${merchantOrders.length} commandes récupérées pour calcul des statistiques');

      // 🔧 CALCULER LES STATISTIQUES À PARTIR DES VRAIES DONNÉES
      final stats = _calculateStatsFromOrders(merchantOrders);
      
      // Mettre en cache
      _cacheStats(stats);
      
      print('✅ [STATS] Statistiques calculées: CA ${stats.formattedTotalRevenue}, ${stats.totalOrders} commandes');
      return stats;
      
    } on TimeoutException {
      throw OrderException(
        'TIMEOUT',
        'Le serveur ne répond pas. Réessayez plus tard.'
      );
    } on SocketException {
      throw OrderException(
        'NO_INTERNET',
        'Pas de connexion réseau. Vérifiez votre connexion.'
      );
    } catch (e) {
      if (e is OrderException) {
        rethrow;
      }
      print('❌ [STATS] Erreur statistiques: $e');
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors de la récupération des statistiques: $e');
    }
  }

  /// 🆕 CALCUL DES STATISTIQUES À PARTIR DES COMMANDES RÉELLES
  MerchantStats _calculateStatsFromOrders(List<MerchantOrder> orders) {
    print('🔢 [STATS] Calcul des statistiques à partir de ${orders.length} commandes');

    // Grouper par statut
    final pendingOrders = orders.where((o) => o.status == OrderStatus.pending).length;
    final confirmedOrders = orders.where((o) => o.status == OrderStatus.confirmed).length;
    final shippedOrders = orders.where((o) => o.status == OrderStatus.shipped).length;
    final deliveredOrders = orders.where((o) => o.status == OrderStatus.delivered).length;
    final canceledOrders = orders.where((o) => o.status == OrderStatus.canceled).length;

    // Calculer le revenu total (exclure les commandes annulées)
    final nonCanceledOrders = orders.where((o) => o.status != OrderStatus.canceled);
    final totalRevenue = nonCanceledOrders.fold<double>(0, (sum, order) => sum + order.totalAmount);
    
    // Calculer le taux de succès (livré / total non annulé)
    final nonCanceledCount = nonCanceledOrders.length;
    final successRate = nonCanceledCount > 0 
        ? (deliveredOrders / nonCanceledCount) * 100 
        : 0.0;

    // Calculer le panier moyen (basé sur les commandes non annulées)
    final averageOrderValue = nonCanceledCount > 0 
        ? totalRevenue / nonCanceledCount 
        : 0.0;

    // 🔧 Convertir MerchantOrder en RecentOrder pour l'affichage
    final sortedOrders = List<MerchantOrder>.from(orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    final recentOrders = sortedOrders
        .take(10)
        .map((merchantOrder) => _convertToRecentOrder(merchantOrder))
        .toList();

    // Générer le graphique des revenus
    final revenueChart = _generateRevenueChartFromOrders(orders);

    // Calculer le top produits
    final topProducts = _generateTopProductsFromOrders(orders);

    final stats = MerchantStats(
      totalRevenue: totalRevenue,
      totalOrders: orders.length,
      pendingOrders: pendingOrders,
      confirmedOrders: confirmedOrders,
      shippedOrders: shippedOrders,
      deliveredOrders: deliveredOrders,
      canceledOrders: canceledOrders,
      successRate: successRate,
      averageOrderValue: averageOrderValue,
      topProducts: topProducts,
      recentOrders: recentOrders,
      revenueChart: revenueChart,
    );

    print('📊 [STATS] Statistiques calculées - CA: ${stats.formattedTotalRevenue}, Succès: ${stats.formattedSuccessRate}');
    return stats;
  }

  /// 🔧 CONVERSION MerchantOrder → RecentOrder avec toutes les données client
  RecentOrder _convertToRecentOrder(MerchantOrder merchantOrder) {
    return RecentOrder(
      id: merchantOrder.id,
      clientName: merchantOrder.client.fullName,
      
      // 🔧 IMPORTANT: Récupérer le vrai numéro de téléphone depuis l'API
      clientPhone: merchantOrder.client.phoneNumber,
      clientEmail: merchantOrder.client.email,
      
      totalAmount: merchantOrder.totalAmount,
      status: merchantOrder.status.value,
      createdAt: merchantOrder.createdAt,
      
      // 🔧 Convertir les items en products pour le modal
      products: merchantOrder.items.map((item) => {
        'name': item.product.name,
        'quantity': item.quantity,
        'price': item.price,
        'subtotal': item.subtotal,
        'imageUrl': item.product.firstImageUrl,
      }).toList(),
    );
  }

  /// 🔧 GÉNÉRER GRAPHIQUE DE REVENUS BASÉ SUR LES VRAIES DONNÉES
  List<RevenueChartData> _generateRevenueChartFromOrders(List<MerchantOrder> orders) {
    final Map<String, double> dailyRevenue = {};
    final Map<String, int> dailyOrderCount = {};
    
    // Initialiser les 7 derniers jours
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = _formatDateKey(date);
      dailyRevenue[dateKey] = 0.0;
      dailyOrderCount[dateKey] = 0;
    }

    // Calculer les revenus réels par jour (exclure les annulées)
    for (final order in orders) {
      if (order.status == OrderStatus.canceled) continue; // Exclure les annulées
      
      final orderDate = order.createdAt;
      final dateKey = _formatDateKey(orderDate);
      
      if (dailyRevenue.containsKey(dateKey)) {
        dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + order.totalAmount;
        dailyOrderCount[dateKey] = (dailyOrderCount[dateKey] ?? 0) + 1;
      }
    }

    // Convertir en RevenueChartData
    return dailyRevenue.entries.map((entry) {
      return RevenueChartData(
        date: DateTime.parse(entry.key),
        revenue: entry.value,
        orderCount: dailyOrderCount[entry.key] ?? 0,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// 🔧 GÉNÉRER TOP PRODUITS BASÉ SUR LES VRAIES DONNÉES
  List<TopProduct> _generateTopProductsFromOrders(List<MerchantOrder> orders) {
    final Map<int, Map<String, dynamic>> productStats = {};

    // Analyser tous les produits des commandes non annulées
    for (final order in orders) {
      if (order.status == OrderStatus.canceled) continue; // Exclure les annulées
      
      for (final item in order.items) {
        final productId = item.product.id;
        
        if (!productStats.containsKey(productId)) {
          productStats[productId] = {
            'name': item.product.name,
            'totalSold': 0,
            'totalRevenue': 0.0,
            'orderCount': 0,
          };
        }
        
        productStats[productId]!['totalSold'] += item.quantity;
        productStats[productId]!['totalRevenue'] += item.subtotal;
        productStats[productId]!['orderCount'] += 1;
      }
    }

    // Convertir en TopProduct et trier par revenus
    final topProducts = productStats.entries.map((entry) {
      return TopProduct(
        productId: entry.key,
        productName: entry.value['name'],
        totalSold: entry.value['totalSold'],
        totalRevenue: entry.value['totalRevenue'].toDouble(),
        orderCount: entry.value['orderCount'],
      );
    }).toList();

    // Trier par revenus décroissants et prendre le top 5
    topProducts.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return topProducts.take(5).toList();
  }

  /// 🔧 MÉTHODES CONSERVÉES MAIS MODIFIÉES POUR UTILISER LES VRAIES DONNÉES

  /// 🏆 RÉCUPÉRER LE TOP 5 DES PRODUITS (utilise maintenant les commandes)
  Future<List<TopProduct>> getTopProducts() async {
    try {
      print('🏆 [STATS] Calcul du top 5 produits depuis les commandes');
      
      final merchantOrders = await _orderService.getMerchantOrders();
      final topProducts = _generateTopProductsFromOrders(merchantOrders);
      
      print('✅ [STATS] ${topProducts.length} top produits calculés');
      return topProducts;
      
    } catch (e) {
      if (e is OrderException) {
        rethrow;
      }
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors du calcul des top produits: $e');
    }
  }

  /// 📈 RÉCUPÉRER LES DONNÉES DU GRAPHIQUE (utilise maintenant les commandes)
  Future<List<RevenueChartData>> getRevenueChart({int days = 7}) async {
    try {
      print('📈 [STATS] Calcul du graphique des ventes ($days jours) depuis les commandes');
      
      final merchantOrders = await _orderService.getMerchantOrders();
      final chartData = _generateRevenueChartFromOrders(merchantOrders);
      
      print('✅ [STATS] Données graphique calculées: ${chartData.length} points');
      return chartData;
      
    } catch (e) {
      if (e is OrderException) {
        rethrow;
      }
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors du calcul du graphique: $e');
    }
  }

  /// 🔄 RAFRAÎCHIR LES STATISTIQUES
  Future<MerchantStats> refreshStats() async {
    print('🔄 [STATS] Rafraîchissement forcé des statistiques');
    return await getMerchantStats(forceRefresh: true);
  }

  /// 📊 OBTENIR LES STATS DEPUIS LE CACHE (Si disponible)
  MerchantStats? getCachedStats() {
    if (_isValidCache()) {
      print('📊 [STATS] Retour des stats depuis le cache');
      return _cachedStats;
    }
    return null;
  }

  /// 🔍 MÉTHODE DE DÉBOGAGE CORRIGÉE
  Future<void> debugMerchantStats() async {
    try {
      print('🔍 [STATS] === DÉBOGAGE STATISTIQUES MARCHAND ===');
      
      final isLoggedIn = await isUserLoggedIn();
      print('👤 [STATS] Utilisateur connecté: $isLoggedIn');
      
      if (isLoggedIn) {
        try {
          // Test de récupération des commandes d'abord
          final orders = await _orderService.getMerchantOrders();
          print('📦 [STATS] Commandes récupérées: ${orders.length}');
          
          // Puis calcul des statistiques
          final stats = await getMerchantStats();
          print('📊 [STATS] === RÉSULTATS ===');
          print('💰 [STATS] CA Total: ${stats.formattedTotalRevenue}');
          print('📦 [STATS] Total Commandes: ${stats.totalOrders}');
          print('⏳ [STATS] En Attente: ${stats.pendingOrders}');
          print('✅ [STATS] Confirmées: ${stats.confirmedOrders}');
          print('🚚 [STATS] Expédiées: ${stats.shippedOrders}');
          print('📋 [STATS] Livrées: ${stats.deliveredOrders}');
          print('❌ [STATS] Annulées: ${stats.canceledOrders}');
          print('📈 [STATS] Taux Succès: ${stats.formattedSuccessRate}');
          print('💳 [STATS] Panier Moyen: ${stats.formattedAverageOrderValue}');
          print('🏆 [STATS] Top Produits: ${stats.topProducts.length}');
          print('📋 [STATS] Commandes Récentes: ${stats.recentOrders.length}');
          
          // Déboguer les commandes récentes
          for (var order in stats.recentOrders.take(3)) {
            print('   📦 Commande #${order.id}: ${order.clientName} - ${order.clientPhone} - ${order.formattedTotalAmount}');
          }
          
          print('========================================');
        } catch (e) {
          print('❌ [STATS] Erreur lors du débogage: $e');
        }
      }
    } catch (error) {
      print('❌ [STATS] Erreur lors du débogage des statistiques: $error');
    }
  }

  /// ⚠️ GESTION D'ERREURS CONVIVIALES
  String getErrorMessage(dynamic error) {
    if (error is OrderException) {
      switch (error.code) {
        case 'NOT_LOGGED_IN':
          return 'Vous devez être connecté pour voir les statistiques';
        case 'SESSION_EXPIRED':
          return 'Votre session a expiré. Reconnectez-vous.';
        case 'NO_INTERNET':
          return 'Pas de connexion internet. Vérifiez votre réseau.';
        case 'TIMEOUT':
          return 'Le serveur ne répond pas. Réessayez plus tard.';
        case 'NOT_MERCHANT':
          return 'Accès réservé aux marchands';
        case 'PARSE_ERROR':
          return 'Erreur de communication avec le serveur';
        default:
          return error.message;
      }
    }
    return 'Une erreur inattendue est survenue';
  }

  /// Vérifier si une déconnexion est nécessaire
  bool shouldLogoutOnError(OrderException error) {
    return error.code == 'SESSION_EXPIRED' || 
           error.code == 'NOT_LOGGED_IN';
  }

  // =====================================================
  // MÉTHODES PRIVÉES UTILITAIRES
  // =====================================================

  /// Formater une date pour les clés de cache
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Vérifier si le cache est valide
  bool _isValidCache() {
    if (_cachedStats == null || _lastCacheTime == null) {
      return false;
    }
    
    final now = DateTime.now();
    final cacheAge = now.difference(_lastCacheTime!);
    
    return cacheAge < _cacheValidDuration;
  }

  /// Mettre en cache les statistiques
  void _cacheStats(MerchantStats stats) {
    _cachedStats = stats;
    _lastCacheTime = DateTime.now();
    print('💾 [STATS] Statistiques mises en cache');
  }

  /// Vider le cache
  void _clearCache() {
    _cachedStats = null;
    _lastCacheTime = null;
    print('🗑️ [STATS] Cache vidé');
  }

  /// Vérifier le code de statut HTTP
  bool _isSuccessStatusCode(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  /// Parser la réponse d'erreur
  Map<String, dynamic> _parseErrorResponse(String responseBody) {
    try {
      return json.decode(responseBody);
    } catch (e) {
      return {
        'message': 'Erreur de réponse du serveur',
        'code': 'PARSE_ERROR'
      };
    }
  }

  /// Nettoyer les ressources
  void dispose() {
    _clearCache();
    print('🧹 [STATS] MerchantStatsService nettoyé');
  }
}