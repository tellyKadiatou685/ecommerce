// lib/services/cart_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_model.dart';
import 'api_config.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  // StreamController pour notifier les changements du panier
  final StreamController<Cart?> _cartController = StreamController<Cart?>.broadcast();
  Stream<Cart?> get cartStream => _cartController.stream;

  Cart? _currentCart;
  Cart? get currentCart => _currentCart;

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
        print('❌ [CART] Aucun token trouvé');
        return null;
      }

      // Vérifier si le token est expiré
      if (await _isTokenExpired(token)) {
        print('❌ [CART] Token expiré');
        await _handleAuthError();
        return null;
      }

      return token;
    } catch (e) {
      print('❌ [CART] Erreur récupération token: $e');
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
      print('❌ [CART] Erreur validation token: $e');
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
      print('⚠️ [CART] Session expirée - données nettoyées');
      
      // Notifier que le panier est vide
      _currentCart = null;
      _cartController.add(null);
    } catch (e) {
      print('❌ [CART] Erreur lors du nettoyage: $e');
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
      print('❌ [CART] Erreur vérification connexion: $e');
      return false;
    }
  }

  /// Ajouter un produit au panier
  Future<CartApiResponse> addToCart(int productId, {int quantity = 1}) async {
    try {
      print('🔄 [CART] Ajout du produit ID $productId (quantité: $quantity)');

      if (!await isUserLoggedIn()) {
        throw CartException(
          'Vous devez être connecté pour ajouter au panier',
          code: 'NOT_LOGGED_IN'
        );
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/cart';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'productId': productId,
          'quantity': quantity,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📥 [CART] Réponse ajout: ${response.statusCode}');

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        print('❌ [CART] Erreur lors de l\'ajout: ${errorData['message']}');
        
        throw CartException(
          errorData['message'] ?? 'Erreur lors de l\'ajout au panier',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      final apiResponse = CartApiResponse.fromJson(data);
      
      // Mettre à jour le panier local et notifier
      if (apiResponse.cart != null) {
        _currentCart = apiResponse.cart;
        _cartController.add(_currentCart);
      }
      
      print('✅ [CART] Produit ajouté avec succès');
      return apiResponse;
      
    } on TimeoutException {
      throw CartException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CartException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      print('❌ [CART] Erreur: $e');
      if (e is CartException) {
        rethrow;
      }
      throw CartException('Erreur lors de l\'ajout au panier: $e');
    }
  }

  /// Récupérer le contenu du panier
  Future<Cart> getCart() async {
    try {
      print('🔄 [CART] Récupération du panier');

      if (!await isUserLoggedIn()) {
        throw CartException(
          'Vous devez être connecté pour accéder au panier',
          code: 'NOT_LOGGED_IN'
        );
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/cart';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('📥 [CART] Réponse récupération: ${response.statusCode}');

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw CartException(
          errorData['message'] ?? 'Erreur lors de la récupération du panier',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      final cart = Cart.fromJson(data['cart'] ?? {});
      
      // Mettre à jour le panier local et notifier
      _currentCart = cart;
      _cartController.add(_currentCart);
      
      print('✅ [CART] Panier récupéré: ${cart.itemsCount} articles');
      return cart;
      
    } on TimeoutException {
      throw CartException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CartException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      if (e is CartException) {
        rethrow;
      }
      throw CartException('Erreur lors de la récupération du panier: $e');
    }
  }

  /// Mettre à jour la quantité d'un article dans le panier
  Future<CartApiResponse> updateCartItem(int itemId, int quantity) async {
    try {
      print('🔄 [CART] Mise à jour article ID $itemId (quantité: $quantity)');

      final token = await _getAuthToken();
      if (token == null) {
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/cart/items/$itemId';
      
      final response = await http.put(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'quantity': quantity}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw CartException(
          errorData['message'] ?? 'Erreur lors de la mise à jour du panier',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      final apiResponse = CartApiResponse.fromJson(data);
      
      // Mettre à jour le panier local et notifier
      if (apiResponse.cart != null) {
        _currentCart = apiResponse.cart;
        _cartController.add(_currentCart);
      }
      
      print('✅ [CART] Article mis à jour avec succès');
      return apiResponse;
      
    } on TimeoutException {
      throw CartException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CartException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      if (e is CartException) {
        rethrow;
      }
      throw CartException('Erreur lors de la mise à jour du panier: $e');
    }
  }

  /// Supprimer un article du panier
  Future<void> removeFromCart(int itemId) async {
    try {
      print('🔄 [CART] Suppression article ID $itemId');

      final token = await _getAuthToken();
      if (token == null) {
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/cart/items/$itemId';
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw CartException(
          errorData['message'] ?? 'Erreur lors de la suppression de l\'article',
          code: errorData['code']
        );
      }

      // Recharger le panier après suppression
      await getCart();
      
      print('✅ [CART] Article supprimé avec succès');
      
    } on TimeoutException {
      throw CartException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CartException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      if (e is CartException) {
        rethrow;
      }
      throw CartException('Erreur lors de la suppression de l\'article: $e');
    }
  }

  /// Vider le panier
  Future<void> clearCart() async {
    try {
      print('🔄 [CART] Vidage du panier');

      final token = await _getAuthToken();
      if (token == null) {
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/cart';
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw CartException(
          errorData['message'] ?? 'Erreur lors du vidage du panier',
          code: errorData['code']
        );
      }

      // Mettre à jour le panier local (vide)
      _currentCart = null;
      _cartController.add(null);
      
      print('✅ [CART] Panier vidé avec succès');
      
    } on TimeoutException {
      throw CartException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CartException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      if (e is CartException) {
        rethrow;
      }
      throw CartException('Erreur lors du vidage du panier: $e');
    }
  }

  /// Partager le panier via WhatsApp
  Future<WhatsAppShareResponse> shareCartViaWhatsApp({String message = ''}) async {
    try {
      print('🔄 [CART] Partage du panier via WhatsApp');

      final token = await _getAuthToken();
      if (token == null) {
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/cart/share/whatsapp';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'message': message}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw CartException(
          errorData['message'] ?? 'Erreur lors du partage du panier',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      
      // Vérifier la présence des liens WhatsApp
      if (data['whatsappLinks'] == null || !(data['whatsappLinks'] is List)) {
        print('❌ [CART] Format de réponse invalide: $data');
        throw CartException(
          'Format de réponse invalide pour les liens WhatsApp',
          code: 'INVALID_RESPONSE'
        );
      }
      
      final shareResponse = WhatsAppShareResponse.fromJson(data);
      print('✅ [CART] Panier partagé: ${shareResponse.whatsappLinks.length} liens');
      
      return shareResponse;
      
    } on TimeoutException {
      throw CartException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CartException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      print('❌ [CART] Erreur partage: $e');
      if (e is CartException) {
        rethrow;
      }
      throw CartException('Erreur lors du partage du panier: $e');
    }
  }

  /// Créer une commande à partir du panier
  Future<OrderResponse> createOrderFromCart({String message = ''}) async {
    try {
      print('🔄 [CART] Création d\'une commande');

      final token = await _getAuthToken();
      if (token == null) {
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/cart/order';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'message': message}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CartException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw CartException(
          errorData['message'] ?? 'Erreur lors de la création de la commande',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      final orderResponse = OrderResponse.fromJson(data);
      
      // Recharger le panier (il devrait être vide après la commande)
      await getCart();
      
      print('✅ [CART] Commande créée: ID ${orderResponse.order.id}');
      return orderResponse;
      
    } on TimeoutException {
      throw CartException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CartException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      print('❌ [CART] Erreur création commande: $e');
      if (e is CartException) {
        rethrow;
      }
      throw CartException('Erreur lors de la création de la commande: $e');
    }
  }

  /// Obtenir le nombre d'articles dans le panier
  Future<int> getCartItemsCount() async {
    try {
      if (!await isUserLoggedIn()) {
        return 0;
      }
      
      // Si on a déjà le panier en cache, utiliser sa valeur
      if (_currentCart != null) {
        return _currentCart!.itemsCount;
      }
      
      // Sinon, récupérer le panier
      final cart = await getCart();
      return cart.itemsCount;
      
    } catch (e) {
      print('❌ [CART] Erreur comptage articles: $e');
      return 0;
    }
  }

  /// Vérifier si un produit est dans le panier
  bool isProductInCart(int productId) {
    if (_currentCart == null) return false;
    return _currentCart!.getItemByProductId(productId) != null;
  }

  /// Obtenir la quantité d'un produit dans le panier
  int getProductQuantityInCart(int productId) {
    if (_currentCart == null) return 0;
    final item = _currentCart!.getItemByProductId(productId);
    return item?.quantity ?? 0;
  }

  /// Initialiser le panier au démarrage de l'app
  Future<void> initializeCart() async {
    try {
      if (await isUserLoggedIn()) {
        await getCart();
      }
    } catch (e) {
      print('⚠️ [CART] Erreur initialisation: $e');
      // Ne pas rethrow pour éviter de bloquer l'app
    }
  }

  /// Méthode pour déboguer l'état du panier
  Future<void> debugCartInfo() async {
    try {
      print('🔍 [CART] Débogage du panier');
      
      final isLoggedIn = await isUserLoggedIn();
      print('👤 [CART] Utilisateur connecté: $isLoggedIn');
      
      final token = await _getAuthToken();
      print('🔑 [CART] Token présent: ${token != null}');
      
      if (isLoggedIn) {
        try {
          final cart = await getCart();
          print('🛒 [CART] Nombre d\'articles: ${cart.itemsCount}');
          print('💰 [CART] Prix total: ${cart.formattedTotalPrice}');
          
          cart.items.asMap().forEach((index, item) {
            print('📦 [CART] Article #${index + 1}:');
            print('   ID: ${item.id}');
            print('   Produit: ${item.product.name}');
            print('   Quantité: ${item.quantity}');
            print('   Prix: ${item.formattedTotalPrice}');
          });
        } catch (e) {
          print('❌ [CART] Erreur lors de la récupération du panier: $e');
        }
      }
    } catch (error) {
      print('❌ [CART] Erreur lors du débogage: $error');
    }
  }

  /// Méthode pour gérer les erreurs de session côté UI
  bool shouldLogoutOnError(CartException error) {
    return error.code == 'SESSION_EXPIRED' || 
           error.code == 'NOT_LOGGED_IN';
  }

  /// Rafraîchir le panier
  Future<void> refreshCart() async {
    try {
      if (await isUserLoggedIn()) {
        await getCart();
      }
    } catch (e) {
      print('⚠️ [CART] Erreur rafraîchissement: $e');
    }
  }

  /// Nettoyer les ressources
  void dispose() {
    _cartController.close();
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
}