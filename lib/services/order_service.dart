// lib/services/order_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import 'api_config.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final StreamController<List<Order>> _ordersController = StreamController<List<Order>>.broadcast();
  Stream<List<Order>> get ordersStream => _ordersController.stream;

  List<Order> _currentOrders = [];
  List<Order> get currentOrders => _currentOrders;

  /// Obtient le token d'authentification depuis SharedPreferences
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
        print('❌ [ORDER] Aucun token trouvé');
        return null;
      }

      if (await _isTokenExpired(token)) {
        print('❌ [ORDER] Token expiré');
        await _handleAuthError();
        return null;
      }

      return token;
    } catch (e) {
      print('❌ [ORDER] Erreur récupération token: $e');
      return null;
    }
  }

  /// Vérifie si le token JWT est expiré
  Future<bool> _isTokenExpired(String token) async {
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
      print('❌ [ORDER] Erreur validation token: $e');
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
      print('⚠️ [ORDER] Session expirée - données nettoyées');
      
      _currentOrders = [];
      _ordersController.add(_currentOrders);
    } catch (e) {
      print('❌ [ORDER] Erreur lors du nettoyage: $e');
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
      print('❌ [ORDER] Erreur vérification connexion: $e');
      return false;
    }
  }

  /// 🗑️ SUPPRIMER DÉFINITIVEMENT UNE COMMANDE ANNULÉE
  Future<void> deleteOrder(int orderId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw OrderException('NOT_LOGGED_IN', 'Token d\'authentification manquant');
      }

      print('🗑️ [ORDER_SERVICE] Suppression commande: $orderId');

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/orders/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw OrderException('TIMEOUT', 'Délai d\'attente dépassé');
        },
      );

      print('🗑️ [ORDER_SERVICE] Réponse suppression: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ [ORDER_SERVICE] Commande supprimée: ${responseData['message']}');
        
        // 🔧 CORRECTION: Utiliser _currentOrders au lieu de _ordersController.value
        _currentOrders.removeWhere((order) => order.id == orderId);
        _ordersController.add(_currentOrders);
        
      } else if (response.statusCode == 403) {
        throw OrderException('FORBIDDEN', 'Vous n\'êtes pas autorisé à supprimer cette commande');
      } else if (response.statusCode == 404) {
        throw OrderException('NOT_FOUND', 'Commande non trouvée');
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw OrderException('INVALID_STATUS', errorData['message'] ?? 'Seules les commandes annulées peuvent être supprimées');
      } else {
        final errorData = json.decode(response.body);
        throw OrderException('DELETE_ERROR', errorData['message'] ?? 'Erreur lors de la suppression');
      }
    } on SocketException {
      throw OrderException('NO_INTERNET', 'Pas de connexion internet');
    } on TimeoutException {
      throw OrderException('TIMEOUT', 'Délai d\'attente dépassé');
    } on FormatException {
      throw OrderException('INVALID_RESPONSE', 'Réponse serveur invalide');
    } catch (e) {
      if (e is OrderException) {
        rethrow;
      }
      print('❌ [ORDER_SERVICE] Erreur suppression: $e');
      throw OrderException('UNKNOWN_ERROR', 'Erreur inconnue lors de la suppression');
    }
  }

  /// Récupérer toutes les commandes du client
  Future<List<Order>> getOrders() async {
    try {
      print('🔄 [ORDER] Récupération des commandes');

      if (!await isUserLoggedIn()) {
        throw OrderException(
          'NOT_LOGGED_IN',
          'Vous devez être connecté pour accéder aux commandes'
        );
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/orders';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('📥 [ORDER] Réponse récupération: ${response.statusCode}');

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw OrderException(
          errorData['code'] ?? 'UNKNOWN_ERROR',
          errorData['message'] ?? 'Erreur lors de la récupération des commandes'
        );
      }

      final data = json.decode(response.body);
      final orders = (data['orders'] as List<dynamic>?)
          ?.map((order) => Order.fromJson(order))
          .toList() ?? [];
      
      _currentOrders = orders;
      _ordersController.add(_currentOrders);
      
      print('✅ [ORDER] ${orders.length} commandes récupérées');
      return orders;
      
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
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors de la récupération des commandes: $e');
    }
  }

  /// Récupérer une commande spécifique par son ID
  Future<Order> getOrderById(int orderId) async {
    try {
      print('🔄 [ORDER] Récupération de la commande ID $orderId');

      if (!await isUserLoggedIn()) {
        throw OrderException(
          'NOT_LOGGED_IN',
          'Vous devez être connecté pour accéder aux commandes'
        );
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/orders/$orderId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      if (response.statusCode == 404) {
        throw OrderException(
          'ORDER_NOT_FOUND',
          'Commande non trouvée'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw OrderException(
          errorData['code'] ?? 'UNKNOWN_ERROR',
          errorData['message'] ?? 'Erreur lors de la récupération de la commande'
        );
      }

      final data = json.decode(response.body);
      final order = Order.fromJson(data['order'] ?? {});
      
      print('✅ [ORDER] Commande récupérée: ${order.formattedOrderNumber}');
      return order;
      
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
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors de la récupération de la commande: $e');
    }
  }

  /// Mettre à jour le statut d'une commande
  Future<Order> updateOrderStatus(int orderId, OrderStatus newStatus) async {
    try {
      print('🔄 [ORDER] Mise à jour du statut de la commande ID $orderId vers ${newStatus.value}');

      final token = await _getAuthToken();
      if (token == null) {
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/orders/$orderId/status';
      
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'status': newStatus.value,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      if (response.statusCode == 403) {
        throw OrderException(
          'FORBIDDEN',
          'Vous n\'êtes pas autorisé à effectuer cette action'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw OrderException(
          errorData['code'] ?? 'UNKNOWN_ERROR',
          errorData['message'] ?? 'Erreur lors de la mise à jour du statut'
        );
      }

      final data = json.decode(response.body);
      final updatedOrder = Order.fromJson(data['order'] ?? {});
      
      final index = _currentOrders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _currentOrders[index] = updatedOrder;
        _ordersController.add(_currentOrders);
      }
      
      print('✅ [ORDER] Statut mis à jour: ${updatedOrder.status.value}');
      return updatedOrder;
      
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
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors de la mise à jour du statut: $e');
    }
  }

  /// Annuler une commande
  Future<Order> cancelOrder(int orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.canceled);
  }

  /// Confirmer la réception d'une commande
  Future<Order> confirmDelivery(int orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.delivered);
  }

  /// Récupérer les commandes pour un marchand
  Future<List<MerchantOrder>> getMerchantOrders() async {
    try {
      print('🔄 [ORDER] Récupération des commandes marchand');

      if (!await isUserLoggedIn()) {
        throw OrderException(
          'NOT_LOGGED_IN',
          'Vous devez être connecté pour accéder aux commandes'
        );
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/merchant/orders';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      if (response.statusCode == 403) {
        throw OrderException(
          'NOT_MERCHANT',
          'Accès refusé. Vous n\'êtes pas un marchand.'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw OrderException(
          errorData['code'] ?? 'UNKNOWN_ERROR',
          errorData['message'] ?? 'Erreur lors de la récupération des commandes marchand'
        );
      }

      final data = json.decode(response.body);
      final orders = (data['orders'] as List<dynamic>?)
          ?.map((order) => MerchantOrder.fromJson(order))
          .toList() ?? [];
      
      print('✅ [ORDER] ${orders.length} commandes marchand récupérées');
      return orders;
      
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
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors de la récupération des commandes marchand: $e');
    }
  }

  /// Vérifier la confirmation d'une commande
  Future<OrderConfirmationResponse> checkOrderConfirmation(int orderId) async {
    try {
      print('🔄 [ORDER] Vérification de la confirmation de la commande ID $orderId');

      final token = await _getAuthToken();
      if (token == null) {
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/orders/$orderId/check-confirmation';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      if (response.statusCode == 404) {
        throw OrderException(
          'ORDER_NOT_FOUND',
          'Commande non trouvée'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw OrderException(
          errorData['code'] ?? 'UNKNOWN_ERROR',
          errorData['message'] ?? 'Erreur lors de la vérification de la commande'
        );
      }

      final data = json.decode(response.body);
      final confirmationResponse = OrderConfirmationResponse.fromJson(data);
      
      print('✅ [ORDER] Vérification terminée pour la commande $orderId');
      return confirmationResponse;
      
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
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors de la vérification de la commande: $e');
    }
  }

  /// Demander un feedback sur le marchand
  Future<MerchantFeedbackResponse> requestMerchantFeedback(int orderId) async {
    try {
      print('🔄 [ORDER] Demande de feedback pour la commande ID $orderId');

      final token = await _getAuthToken();
      if (token == null) {
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/orders/$orderId/request-feedback';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      if (response.statusCode == 404) {
        throw OrderException(
          'ORDER_NOT_FOUND',
          'Commande confirmée non trouvée'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw OrderException(
          errorData['code'] ?? 'UNKNOWN_ERROR',
          errorData['message'] ?? 'Erreur lors de la demande de feedback'
        );
      }

      final data = json.decode(response.body);
      final feedbackResponse = MerchantFeedbackResponse.fromJson(data);
      
      print('✅ [ORDER] Feedback demandé pour la commande $orderId');
      return feedbackResponse;
      
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
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors de la demande de feedback: $e');
    }
  }

  /// Envoyer un rappel aux marchands
  Future<void> sendOrderReminder(int orderId, {String? customMessage}) async {
    try {
      print('🔄 [ORDER] Envoi de rappel pour la commande ID $orderId');

      final token = await _getAuthToken();
      if (token == null) {
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/orders/$orderId/send-reminder';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          if (customMessage != null) 'customMessage': customMessage,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      if (response.statusCode == 404) {
        throw OrderException(
          'ORDER_NOT_FOUND',
          'Commande non trouvée'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw OrderException(
          errorData['code'] ?? 'UNKNOWN_ERROR',
          errorData['message'] ?? 'Erreur lors de l\'envoi du rappel'
        );
      }

      print('✅ [ORDER] Rappel envoyé pour la commande $orderId');
      
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
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors de l\'envoi du rappel: $e');
    }
  }

  /// Auto-confirmer les livraisons après 48h
  Future<void> autoConfirmDeliveries() async {
    try {
      print('🔄 [ORDER] Auto-confirmation des livraisons');

      final token = await _getAuthToken();
      if (token == null) {
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/orders/auto-confirm-deliveries';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw OrderException(
          'SESSION_EXPIRED',
          'Session expirée. Veuillez redémarrer l\'application.'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw OrderException(
          errorData['code'] ?? 'UNKNOWN_ERROR',
          errorData['message'] ?? 'Erreur lors de l\'auto-confirmation'
        );
      }

      print('✅ [ORDER] Auto-confirmation terminée');
      
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
      throw OrderException('UNKNOWN_ERROR', 'Erreur lors de l\'auto-confirmation: $e');
    }
  }

  /// Filtrer les commandes par statut
  List<Order> getOrdersByStatus(OrderStatus status) {
    return _currentOrders.where((order) => order.status == status).toList();
  }

  /// Obtenir les commandes en attente
  List<Order> get pendingOrders => getOrdersByStatus(OrderStatus.pending);

  /// Obtenir les commandes confirmées
  List<Order> get confirmedOrders => getOrdersByStatus(OrderStatus.confirmed);

  /// Obtenir les commandes expédiées
  List<Order> get shippedOrders => getOrdersByStatus(OrderStatus.shipped);

  /// Obtenir les commandes livrées
  List<Order> get deliveredOrders => getOrdersByStatus(OrderStatus.delivered);

  /// Obtenir les commandes annulées
  List<Order> get canceledOrders => getOrdersByStatus(OrderStatus.canceled);

  /// Obtenir une commande par son ID depuis le cache local
  Order? getOrderFromCache(int orderId) {
    try {
      return _currentOrders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Rafraîchir les commandes
  Future<void> refreshOrders() async {
    try {
      if (await isUserLoggedIn()) {
        await getOrders();
      }
    } catch (e) {
      print('⚠️ [ORDER] Erreur rafraîchissement: $e');
    }
  }

  /// Initialiser les commandes au démarrage de l'app
  Future<void> initializeOrders() async {
    try {
      if (await isUserLoggedIn()) {
        await getOrders();
      }
    } catch (e) {
      print('⚠️ [ORDER] Erreur initialisation: $e');
    }
  }

  /// Obtenir le nombre total de commandes
  int get totalOrdersCount => _currentOrders.length;

  /// Obtenir le nombre de commandes par statut
  int getOrdersCountByStatus(OrderStatus status) {
    return getOrdersByStatus(status).length;
  }

  /// Vérifier si une commande peut être annulée
  bool canCancelOrder(int orderId) {
    final order = getOrderFromCache(orderId);
    return order?.canBeCanceled ?? false;
  }

  /// Vérifier si une commande peut être marquée comme livrée
  bool canMarkAsDelivered(int orderId) {
    final order = getOrderFromCache(orderId);
    return order?.canBeMarkedAsDelivered ?? false;
  }

  /// Méthode pour déboguer l'état des commandes
  Future<void> debugOrdersInfo() async {
    try {
      print('🔍 [ORDER] Débogage des commandes');
      
      final isLoggedIn = await isUserLoggedIn();
      print('👤 [ORDER] Utilisateur connecté: $isLoggedIn');
      
      final token = await _getAuthToken();
      print('🔑 [ORDER] Token présent: ${token != null}');
      
      if (isLoggedIn) {
        try {
          final orders = await getOrders();
          print('📋 [ORDER] Nombre de commandes: ${orders.length}');
          
          for (var status in OrderStatus.values) {
            final count = getOrdersCountByStatus(status);
            print('📊 [ORDER] ${status.displayName}: $count commandes');
          }
          
          orders.asMap().forEach((index, order) {
            print('📦 [ORDER] Commande #${index + 1}:');
            print('   ID: ${order.formattedOrderNumber}');
            print('   Statut: ${order.status.displayName}');
            print('   Montant: ${order.formattedTotalAmount}');
            print('   Articles: ${order.itemsCount}');
            print('   Date: ${order.createdAt}');
          });
        } catch (e) {
          print('❌ [ORDER] Erreur lors de la récupération des commandes: $e');
        }
      }
    } catch (error) {
      print('❌ [ORDER] Erreur lors du débogage: $error');
    }
  }

  /// Méthode pour gérer les erreurs de session côté UI
  bool shouldLogoutOnError(OrderException error) {
    return error.code == 'SESSION_EXPIRED' || 
           error.code == 'NOT_LOGGED_IN';
  }

  /// Nettoyer les ressources
  void dispose() {
    _ordersController.close();
  }

  // Méthodes utilitaires privées
  bool _isSuccessStatusCode(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

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

  /// Obtenir un message d'erreur convivial
  String getErrorMessage(dynamic error) {
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
        case 'ORDER_NOT_FOUND':
          return 'Cette commande n\'existe pas ou ne vous appartient pas';
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
}
