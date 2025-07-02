// lib/services/shop_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/shop_model.dart';
import '../services/auth_service.dart';
import 'api_config.dart';

class ShopService {
  static final ShopService _instance = ShopService._internal();
  factory ShopService() => _instance;
  ShopService._internal();

  // ========== MÉTHODES PUBLIQUES (pour tous les utilisateurs) ==========

  // Récupérer toutes les boutiques (COMPATIBLE avec votre code existant)
  Future<ShopResponse> getAllShops() async {
    try {
      print('🏪 Récupération de toutes les boutiques...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/shop');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/shop'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body (preview): ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('✅ JSON décodé avec succès');
        print('📦 Status API: ${data['status']}');
        print('🏪 Nombre de boutiques: ${(data['shops'] as List).length}');
        
        return ShopResponse.fromJson(data);
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        throw ApiError(
          status: 'error',
          code: 'HTTP_${response.statusCode}',
          message: 'Erreur HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des boutiques: $e');
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur: $e',
      );
    }
  }

  // Récupérer une boutique par ID avec détails du commerçant
  Future<ShopDetailResponse> getShopDetails(int shopId) async {
    try {
      print('🏪 Récupération des détails de la boutique $shopId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/shop/$shopId/details');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/$shopId/details'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return ShopDetailResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la récupération des détails',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des détails: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur.',
      );
    }
  }

  // Récupérer les produits d'une boutique
  Future<ShopProductsResponse> getShopProducts(int shopId) async {
    try {
      print('🛍️ Récupération des produits de la boutique $shopId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/shop/$shopId/products');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/$shopId/products'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('✅ Produits récupérés pour boutique $shopId');
        return ShopProductsResponse.fromJson(data);
      } else if (response.statusCode == 404) {
        print('⚠️ Aucun produit trouvé pour la boutique $shopId');
        return ShopProductsResponse(
          status: 'success',
          message: 'Aucun produit trouvé',
          products: [],
        );
      } else {
        print('❌ Erreur HTTP ${response.statusCode} pour produits boutique $shopId');
        return ShopProductsResponse(
          status: 'error',
          message: 'Erreur lors de la récupération des produits',
          products: [],
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des produits: $e');
      return ShopProductsResponse(
        status: 'error',
        message: 'Erreur de connexion',
        products: [],
      );
    }
  }

  // Contacter un commerçant
  Future<ContactResponse> contactMerchant({
    required int shopId,
    required String subject,
    required String message,
    required String token,
  }) async {
    try {
      print('📧 Envoi de message au commerçant...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/shop/$shopId/contact');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/$shopId/contact'),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'subject': subject,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return ContactResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de l\'envoi du message',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi du message: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur.',
      );
    }
  }

  // ========== MÉTHODES POUR LES COMMERÇANTS ==========

  // 🆕 Récupérer sa propre boutique (commerçant connecté)
  Future<MyShopResponse> getMyShop(String token) async {
    try {
      print('🏪 Récupération de ma boutique...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/shop/my-shop');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/my-shop'),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return MyShopResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la récupération de votre boutique',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de ma boutique: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur.',
      );
    }
  }

  // 🆕 NOUVELLE MÉTHODE: Récupérer la boutique de l'utilisateur connecté (sans token)
  Future<Shop?> getCurrentUserShop() async {
    try {
      print('🏪 Récupération de la boutique utilisateur connecté...');
      
      // Importer le service d'authentification pour récupérer le token
      final AuthService authService = AuthService();
      final String? token = await authService.getToken();
      
      if (token == null) {
        print('⚠️ Aucun token d\'authentification trouvé');
        return null;
      }
      
      // Utiliser la méthode getMyShop existante
      try {
        final response = await getMyShop(token);
        if (response.success) {
          print('✅ Boutique utilisateur trouvée');
          return response.shop;
        } else {
          print('⚠️ Aucune boutique trouvée pour cet utilisateur');
          return null;
        }
      } catch (e) {
        // Si erreur (ex: 404), cela signifie que l'utilisateur n'a pas de boutique
        print('⚠️ Utilisateur sans boutique: $e');
        return null;
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de la boutique utilisateur: $e');
      // Ne pas lancer d'erreur, retourner null si pas de boutique
      return null;
    }
  }

  // 🆕 Créer une boutique (pour les commerçants)
  Future<CreateShopResponse> createShop({
    required String name,
    required String phoneNumber,
    String? description,
    String? address,
    File? logoFile,
    required String token,
  }) async {
    try {
      print('🏪 Création d\'une nouvelle boutique...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/shop');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/shop'),
      );

      // Headers d'authentification
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Champs de texte
      request.fields['name'] = name;
      request.fields['phoneNumber'] = phoneNumber;
      if (description != null) request.fields['description'] = description;
      if (address != null) request.fields['address'] = address;

      // Fichier logo si présent
      if (logoFile != null) {
        var multipartFile = await http.MultipartFile.fromPath(
          'logo',
          logoFile.path,
        );
        request.files.add(multipartFile);
      }

      print('📤 Envoi de la requête de création...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return CreateShopResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la création de la boutique',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la création de la boutique: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur.',
      );
    }
  }

  // 🆕 Mettre à jour sa boutique
  Future<UpdateShopResponse> updateShop({
    required int shopId,
    String? name,
    String? phoneNumber,
    String? description,
    String? address,
    File? logoFile,
    required String token,
  }) async {
    try {
      print('🏪 Mise à jour de la boutique $shopId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/shop/$shopId');

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiConfig.baseUrl}/api/shop/$shopId'),
      );

      // Headers d'authentification
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Champs de texte (seulement ceux qui sont fournis)
      if (name != null) request.fields['name'] = name;
      if (phoneNumber != null) request.fields['phoneNumber'] = phoneNumber;
      if (description != null) request.fields['description'] = description;
      if (address != null) request.fields['address'] = address;

      // Fichier logo si présent
      if (logoFile != null) {
        var multipartFile = await http.MultipartFile.fromPath(
          'logo',
          logoFile.path,
        );
        request.files.add(multipartFile);
      }

      print('📤 Envoi de la mise à jour...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return UpdateShopResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la mise à jour de la boutique',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de la boutique: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur.',
      );
    }
  }

  // 🆕 Supprimer sa boutique
  Future<DeleteShopResponse> deleteShop({
    required int shopId,
    required String token,
  }) async {
    try {
      print('🗑️ Suppression de la boutique $shopId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/shop/$shopId');

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/$shopId'),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return DeleteShopResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la suppression de la boutique',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression de la boutique: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur.',
      );
    }
  }

  // 🆕 Récupérer tous ses messages/contacts (commerçant)
  Future<MessagesResponse> getAllUserMessages(String token) async {
    try {
      print('📬 Récupération de tous les messages...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/shop/dashboard/messages');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/shop/dashboard/messages'),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return MessagesResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la récupération des messages',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des messages: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur.',
      );
    }
  }

  // ========== MÉTHODES UTILITAIRES ==========

  // Rechercher des boutiques
  Future<List<Shop>> searchShops(String query) async {
    try {
      final response = await getAllShops();
      
      if (query.isEmpty) return response.shops;
      
      final lowercaseQuery = query.toLowerCase();
      return response.shops.where((shop) {
        final name = shop.name.toLowerCase();
        final description = shop.description?.toLowerCase() ?? '';
        final address = shop.address?.toLowerCase() ?? '';
        
        return name.contains(lowercaseQuery) ||
               description.contains(lowercaseQuery) ||
               address.contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      print('❌ Erreur lors de la recherche de boutiques: $e');
      rethrow;
    }
  }

  // Tester la connexion
  Future<bool> testConnection() async {
    try {
      print('🧪 Test de connexion...');
      print('🌐 URL de test: ${ApiConfig.baseUrl}/api/shop');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/shop'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 5));
      
      print('📡 Test Status: ${response.statusCode}');
      
      bool isConnected = response.statusCode == 200;
      print(isConnected ? '✅ Connexion réussie!' : '❌ Connexion échouée');
      
      return isConnected;
    } catch (e) {
      print('❌ Test de connexion échoué: $e');
      return false;
    }
  }

  // 🆕 Vérifier si l'utilisateur a déjà une boutique
  Future<bool> hasShop(String token) async {
    try {
      await getMyShop(token);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ========== CLASSES DE RÉPONSE ==========

// Classes manquantes pour les méthodes existantes
class ShopResponse {
  final String status;
  final List<Shop> shops;
  final Pagination? pagination;

  ShopResponse({
    required this.status,
    required this.shops,
    this.pagination,
  });

  factory ShopResponse.fromJson(Map<String, dynamic> json) {
    return ShopResponse(
      status: json['status'] as String,
      shops: (json['shops'] as List<dynamic>)
          .map((shop) => Shop.fromJson(shop))
          .toList(),
      pagination: json['pagination'] != null 
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }

  bool get success => status == 'success';
}

class ShopDetailResponse {
  final String status;
  final Shop shop;
  final List<Product> recentProducts;
  final ShopStats? stats;

  ShopDetailResponse({
    required this.status,
    required this.shop,
    required this.recentProducts,
    this.stats,
  });

  factory ShopDetailResponse.fromJson(Map<String, dynamic> json) {
    return ShopDetailResponse(
      status: json['status'] as String,
      shop: Shop.fromJson(json['shop']),
      recentProducts: (json['recentProducts'] as List<dynamic>)
          .map((product) => Product.fromJson(product))
          .toList(),
      stats: json['stats'] != null ? ShopStats.fromJson(json['stats']) : null,
    );
  }

  bool get success => status == 'success';
}

class ShopProductsResponse {
  final String status;
  final String message;
  final List<Product> products;
  final Pagination? pagination;

  ShopProductsResponse({
    required this.status,
    required this.message,
    required this.products,
    this.pagination,
  });

  factory ShopProductsResponse.fromJson(Map<String, dynamic> json) {
    return ShopProductsResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      products: (json['products'] as List<dynamic>)
          .map((product) => Product.fromJson(product))
          .toList(),
      pagination: json['pagination'] != null 
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }

  bool get success => status == 'success';
}

class ContactResponse {
  final String status;
  final String message;

  ContactResponse({
    required this.status,
    required this.message,
  });

  factory ContactResponse.fromJson(Map<String, dynamic> json) {
    return ContactResponse(
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }

  bool get success => status == 'success';
}

class CreateShopResponse {
  final String status;
  final String message;
  final Shop shop;

  CreateShopResponse({
    required this.status,
    required this.message,
    required this.shop,
  });

  factory CreateShopResponse.fromJson(Map<String, dynamic> json) {
    return CreateShopResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      shop: Shop.fromJson(json['shop']),
    );
  }

  bool get success => status == 'success';
}

class MyShopResponse {
  final String status;
  final String message;
  final Shop shop;
  final List<Product> products;

  MyShopResponse({
    required this.status,
    required this.message,
    required this.shop,
    required this.products,
  });

  factory MyShopResponse.fromJson(Map<String, dynamic> json) {
    return MyShopResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      shop: Shop.fromJson(json['shop']),
      products: (json['products'] as List<dynamic>?)
          ?.map((product) => Product.fromJson(product))
          .toList() ?? [],
    );
  }

  bool get success => status == 'success';
}

class UpdateShopResponse {
  final String status;
  final String message;
  final Shop shop;

  UpdateShopResponse({
    required this.status,
    required this.message,
    required this.shop,
  });

  factory UpdateShopResponse.fromJson(Map<String, dynamic> json) {
    return UpdateShopResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      shop: Shop.fromJson(json['shop']),
    );
  }

  bool get success => status == 'success';
}

class DeleteShopResponse {
  final String status;
  final String message;

  DeleteShopResponse({
    required this.status,
    required this.message,
  });

  factory DeleteShopResponse.fromJson(Map<String, dynamic> json) {
    return DeleteShopResponse(
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }

  bool get success => status == 'success';
}

class MessagesResponse {
  final String status;
  final List<MerchantMessage> messages;
  final int totalCount;

  MessagesResponse({
    required this.status,
    required this.messages,
    required this.totalCount,
  });

  factory MessagesResponse.fromJson(Map<String, dynamic> json) {
    return MessagesResponse(
      status: json['status'] as String,
      messages: (json['messages'] as List<dynamic>)
          .map((message) => MerchantMessage.fromJson(message))
          .toList(),
      totalCount: json['totalCount'] as int,
    );
  }

  bool get success => status == 'success';
}

class MerchantMessage {
  final int id;
  final String subject;
  final String message;
  final String senderEmail;
  final String status;
  final DateTime createdAt;
  final MessageSender? sender;
  final MessageShop? shop;
  final List<MessageResponse> responses;

  MerchantMessage({
    required this.id,
    required this.subject,
    required this.message,
    required this.senderEmail,
    required this.status,
    required this.createdAt,
    this.sender,
    this.shop,
    required this.responses,
  });

  factory MerchantMessage.fromJson(Map<String, dynamic> json) {
    return MerchantMessage(
      id: json['id'] as int,
      subject: json['subject'] as String,
      message: json['message'] as String,
      senderEmail: json['senderEmail'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt']),
      sender: json['sender'] != null ? MessageSender.fromJson(json['sender']) : null,
      shop: json['shop'] != null ? MessageShop.fromJson(json['shop']) : null,
      responses: (json['responses'] as List<dynamic>?)
          ?.map((response) => MessageResponse.fromJson(response))
          .toList() ?? [],
    );
  }

  bool get isUnread => status == 'UNREAD';
  bool get hasResponse => responses.isNotEmpty;
}

class MessageSender {
  final String firstName;
  final String lastName;
  final String email;

  MessageSender({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
    );
  }

  String get fullName => '$firstName $lastName';
}

class MessageShop {
  final String name;

  MessageShop({required this.name});

  factory MessageShop.fromJson(Map<String, dynamic> json) {
    return MessageShop(
      name: json['name'] as String,
    );
  }
}

class MessageResponse {
  final int id;
  final String response;
  final DateTime createdAt;

  MessageResponse({
    required this.id,
    required this.response,
    required this.createdAt,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      id: json['id'] as int,
      response: json['response'] as String,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

// Classes utilitaires
class Pagination {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  Pagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}

class ShopStats {
  final int totalProducts;
  final int totalOrders;
  final double totalRevenue;
  final double averageRating;

  ShopStats({
    required this.totalProducts,
    required this.totalOrders,
    required this.totalRevenue,
    required this.averageRating,
  });

  factory ShopStats.fromJson(Map<String, dynamic> json) {
    return ShopStats(
      totalProducts: json['totalProducts'] as int,
      totalOrders: json['totalOrders'] as int,
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      averageRating: (json['averageRating'] as num).toDouble(),
    );
  }
}

// Classes pour Product - SUPPRIMÉ (on utilise le vrai modèle importé)
// La classe Product est maintenant importée depuis '../models/product_model.dart'

// Classe d'erreur API
class ApiError implements Exception {
  final String status;
  final String code;
  final String message;
  final Map<String, dynamic>? errors;

  ApiError({
    required this.status,
    required this.code,
    required this.message,
    this.errors,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      status: json['status'] as String? ?? 'error',
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      message: json['message'] as String? ?? 'Une erreur est survenue',
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'ApiError(status: $status, code: $code, message: $message)';
  }
}