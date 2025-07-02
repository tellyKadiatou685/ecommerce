// lib/services/product_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import 'api_config.dart';
import 'package:mime/mime.dart'; // Pour lookupMimeType
import 'package:http_parser/http_parser.dart';

class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] as bool? ?? json['status'] == 'success',
      message: json['message'] as String? ?? 'Opération réussie',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  // ========== MÉTHODES PUBLIQUES (pour tous les utilisateurs) ==========

  // Récupérer tous les produits avec pagination et filtres
   Future<ApiResponse> updateProductWithImages({
    required int productId,
    required String name,
    required String description,
    required String category,
    required double price,
    required int stock,
    List<File>? newImageFiles,
    List<String>? existingImageUrls,
    List<String>? imagesToDelete,
    String? videoUrl,
    File? videoFile,
    required String token,
  }) async {
    try {
      print('🛍️ === UPDATE PRODUCT WITH IMAGES ===');
      print('📋 Paramètres:');
      print('  • ID: $productId');
      print('  • Nouvelles images: ${newImageFiles?.length ?? 0}');
      print('  • Images à conserver: ${existingImageUrls?.length ?? 0}');
      print('  • Images à supprimer: ${imagesToDelete?.length ?? 0}');

      // ✅ URL avec /api/products pour cette nouvelle méthode spécifique
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/products/$productId/update-with-images');
      final request = http.MultipartRequest('PUT', uri);
      
      // Headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      
      // Champs de données
      request.fields.addAll({
        'name': name,
        'description': description,
        'category': category,
        'price': price.toString(),
        'stock': stock.toString(),
      });
      
      // Ajouter les listes d'images
      if (existingImageUrls != null && existingImageUrls.isNotEmpty) {
        request.fields['existingImageUrls'] = jsonEncode(existingImageUrls);
        print('📸 Images à conserver: ${existingImageUrls.length}');
      }
      
      if (imagesToDelete != null && imagesToDelete.isNotEmpty) {
        request.fields['imagesToDelete'] = jsonEncode(imagesToDelete);
        print('🗑️ Images à supprimer: ${imagesToDelete.length}');
      }
      
      if (videoUrl != null && videoUrl.isNotEmpty) {
        request.fields['videoUrl'] = videoUrl;
      }
      
      // Ajouter les nouvelles images
      if (newImageFiles != null && newImageFiles.isNotEmpty) {
        for (int i = 0; i < newImageFiles.length; i++) {
          final file = newImageFiles[i];
          final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
          
          request.files.add(
            await http.MultipartFile.fromPath(
              'productImages',
              file.path,
              contentType: MediaType.parse(mimeType),
            ),
          );
        }
        print('📤 ${newImageFiles.length} nouvelles images ajoutées à la requête');
      }
      
      // Ajouter la vidéo si présente
      if (videoFile != null) {
        final mimeType = lookupMimeType(videoFile.path) ?? 'video/mp4';
        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            videoFile.path,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }
      
      print('📤 Envoi de la requête de mise à jour...');
      final streamedResponse = await request.send().timeout(
        Duration(seconds: 45),
        onTimeout: () => throw TimeoutException('Timeout lors de la mise à jour', Duration(seconds: 45)),
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      print('📥 Réponse reçue: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Produit mis à jour avec succès');
        print('📊 Statistiques: ${data['stats']}');
        
        if (data['warnings'] != null) {
          print('⚠️ Avertissements: ${data['warnings']['message']}');
        }
        
        return ApiResponse(
          success: true,
          message: data['message'] ?? 'Produit mis à jour avec succès',
          data: data,
        );
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ Erreur ${response.statusCode}: ${errorData['message']}');
        
        throw ApiError(
          status: 'error',
          code: errorData['code'] ?? 'UPDATE_ERROR',
          message: errorData['message'] ?? 'Erreur lors de la mise à jour',
        );
      }
      
    } catch (e) {
      print('❌ Erreur updateProductWithImages: $e');
      
      if (e is TimeoutException) {
        throw ApiError(status: 'error', code: 'TIMEOUT', message: 'La mise à jour a pris trop de temps');
      } else if (e is SocketException) {
        throw ApiError(status: 'error', code: 'NETWORK_ERROR', message: 'Problème de connexion réseau');
      } else if (e is ApiError) {
        rethrow;
      } else {
        throw ApiError(status: 'error', code: 'UNKNOWN_ERROR', message: 'Une erreur inattendue est survenue');
      }
    }
  }
  
  Future<ProductResponse> getAllProducts({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    String? order,
    int page = 1,
    int limit = 10,
    String status = 'PUBLISHED',
  }) async {
    try {
      print('🛍️ Récupération de tous les produits...');
      
      // Construire les paramètres de requête
      Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'status': status,
      };
      
      if (category != null) queryParams['category'] = category;
      if (minPrice != null) queryParams['minPrice'] = minPrice.toString();
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice.toString();
      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (order != null) queryParams['order'] = order;
      
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/produit').replace(
        queryParameters: queryParams,
      );
      
      print('🌐 URL: $uri');

      final response = await http.get(
        uri,
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 15));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body (preview): ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('✅ JSON décodé avec succès');
        print('🛍️ Nombre de produits: ${(data['products'] as List).length}');
        
        return ProductResponse.fromJson(data);
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur HTTP ${response.statusCode}',
          );
        }
      }
      
    } on TimeoutException catch (e) {
      print('❌ Timeout de connexion: $e');
      throw ApiError(
        status: 'error',
        code: 'TIMEOUT',
        message: 'Le serveur ne répond pas. Réessayez plus tard.',
      );
    } on SocketException catch (e) {
      print('❌ Erreur de socket (pas de réseau): $e');
      throw ApiError(
        status: 'error',
        code: 'NO_INTERNET',
        message: 'Pas de connexion réseau. Vérifiez votre connexion.',
      );
    } catch (e) {
      print('❌ Erreur lors de la récupération des produits: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur: $e',
      );
    }
  }

  // Récupérer un produit par ID avec détails
  Future<Product> getProductById(int productId) async {
    try {
      print('🛍️ Récupération des détails du produit $productId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/$productId');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/$productId'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return Product.fromJson(data);
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

  // Rechercher des produits
  Future<ProductResponse> searchProducts({
    required String query,
    String? category,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      print('🔍 Recherche de produits pour: "$query"...');
      
      Map<String, String> queryParams = {
        'query': query,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (category != null) queryParams['category'] = category;
      
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/produit/search').replace(
        queryParameters: queryParams,
      );

      print('🌐 URL: $uri');

      final response = await http.get(
        uri,
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('✅ Résultats récupérés pour "$query"');
        return ProductResponse.fromJson(data);
      } else if (response.statusCode == 404) {
        print('⚠️ Aucun résultat trouvé pour "$query"');
        return ProductResponse(
          products: [],
          pagination: null,
        );
      } else {
        print('❌ Erreur HTTP ${response.statusCode} pour recherche "$query"');
        return ProductResponse(
          products: [],
          pagination: null,
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la recherche de produits: $e');
      return ProductResponse(
        products: [],
        pagination: null,
      );
    }
  }

  // Récupérer les derniers produits
  Future<List<Product>> getLatestProducts({int limit = 10}) async {
    try {
      print('🆕 Récupération des derniers produits...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/latest?limit=$limit');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/latest?limit=$limit'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ Derniers produits récupérés');
        return data.map((product) => Product.fromJson(product)).toList();
      } else {
        print('❌ Erreur HTTP ${response.statusCode} pour derniers produits');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des derniers produits: $e');
      return [];
    }
  }

  // Récupérer les produits en vedette
  Future<List<Product>> getFeaturedProducts({int limit = 10}) async {
    try {
      print('⭐ Récupération des produits en vedette...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/featured?limit=$limit');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/featured?limit=$limit'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ Produits vedettes récupérés');
        return data.map((product) => Product.fromJson(product)).toList();
      } else {
        print('❌ Erreur HTTP ${response.statusCode} pour produits vedettes');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des produits vedettes: $e');
      return [];
    }
  }

  // Récupérer les produits par catégorie
  Future<ProductResponse> getProductsByCategory({
    required String category,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      print('📂 Récupération des produits de la catégorie: $category...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/category/$category?page=$page&limit=$limit');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/category/$category?page=$page&limit=$limit'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('✅ Produits de catégorie récupérés pour $category');
        return ProductResponse.fromJson(data);
      } else {
        print('❌ Erreur HTTP ${response.statusCode} pour catégorie $category');
        return ProductResponse(
          products: [],
          pagination: null,
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des produits par catégorie: $e');
      return ProductResponse(
        products: [],
        pagination: null,
      );
    }
  }

  // Récupérer toutes les catégories
  Future<List<String>> getProductCategories() async {
    try {
      print('📁 Récupération des catégories...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/categories');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/categories'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ Catégories récupérées');
        return data.map((category) => category.toString()).toList();
      } else {
        print('❌ Erreur HTTP ${response.statusCode} pour catégories');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des catégories: $e');
      return [];
    }
  }

  // Récupérer les produits d'un marchand
  Future<ProductResponse> getMerchantProducts({
    required int merchantId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      print('👤 Récupération des produits du marchand $merchantId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/merchant/$merchantId?page=$page&limit=$limit');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/merchant/$merchantId?page=$page&limit=$limit'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('✅ Produits du marchand récupérés pour $merchantId');
        return ProductResponse.fromJson(data);
      } else {
        print('❌ Erreur HTTP ${response.statusCode} pour marchand $merchantId');
        return ProductResponse(
          products: [],
          pagination: null,
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des produits du marchand: $e');
      return ProductResponse(
        products: [],
        pagination: null,
      );
    }
  }

  // Récupérer les produits similaires
  Future<List<Product>> getRelatedProducts({
    required int productId,
    int limit = 5,
  }) async {
    try {
      print('🔗 Récupération des produits similaires pour $productId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/$productId/related?limit=$limit');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/$productId/related?limit=$limit'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ Produits similaires récupérés pour $productId');
        return data.map((product) => Product.fromJson(product)).toList();
      } else {
        print('❌ Erreur HTTP ${response.statusCode} pour produits similaires');
        return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des produits similaires: $e');
      return [];
    }
  }

  // ========== NOUVELLES MÉTHODES POUR LES COMMERÇANTS ==========

  // 🆕 Créer un produit (avec upload d'images et vidéo)
  Future<CreateProductResponse> createProduct({
    required String name,
    required String description,
    required double price,
    required int stock,
    required String category,
    String? videoUrl,
    File? videoFile,
    List<File>? imageFiles,
    String status = 'DRAFT',
    required String token,
  }) async {
    try {
      print('🛍️ Création d\'un nouveau produit...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/produit'),
      );

      // Headers d'authentification
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Champs de texte
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['price'] = price.toString();
      request.fields['stock'] = stock.toString();
      request.fields['category'] = category;
      request.fields['status'] = status;
      if (videoUrl != null) request.fields['videoUrl'] = videoUrl;

      // Ajouter les images
      if (imageFiles != null && imageFiles.isNotEmpty) {
        for (int i = 0; i < imageFiles.length; i++) {
          var multipartFile = await http.MultipartFile.fromPath(
            'productImages',
            imageFiles[i].path,
          );
          request.files.add(multipartFile);
        }
      }

      // Ajouter la vidéo si présente
      if (videoFile != null) {
        var multipartFile = await http.MultipartFile.fromPath(
          'video',
          videoFile.path,
        );
        request.files.add(multipartFile);
      }

      print('📤 Envoi de la requête de création...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return CreateProductResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la création du produit',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la création du produit: $e');
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

  // 🆕 Mettre à jour un produit
  Future<UpdateProductResponse> updateProduct({
    required int productId,
    String? name,
    String? description,
    double? price,
    int? stock,
    String? category,
    String? videoUrl,
    File? videoFile,
    List<File>? imageFiles,
    required String token,
  }) async {
    try {
      print('🛍️ Mise à jour du produit $productId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/$productId');

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiConfig.baseUrl}/api/produit/$productId'),
      );

      // Headers d'authentification
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Champs de texte (seulement ceux qui sont fournis)
      if (name != null) request.fields['name'] = name;
      if (description != null) request.fields['description'] = description;
      if (price != null) request.fields['price'] = price.toString();
      if (stock != null) request.fields['stock'] = stock.toString();
      if (category != null) request.fields['category'] = category;
      if (videoUrl != null) request.fields['videoUrl'] = videoUrl;

      // Ajouter les images si présentes
      if (imageFiles != null && imageFiles.isNotEmpty) {
        for (int i = 0; i < imageFiles.length; i++) {
          var multipartFile = await http.MultipartFile.fromPath(
            'productImages',
            imageFiles[i].path,
          );
          request.files.add(multipartFile);
        }
      }

      // Ajouter la vidéo si présente
      if (videoFile != null) {
        var multipartFile = await http.MultipartFile.fromPath(
          'video',
          videoFile.path,
        );
        request.files.add(multipartFile);
      }

      print('📤 Envoi de la mise à jour...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return UpdateProductResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la mise à jour du produit',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du produit: $e');
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

  // 🆕 Mettre à jour le stock d'un produit
  Future<UpdateStockResponse> updateProductStock({
    required int productId,
    required int stock,
    required String token,
  }) async {
    try {
      print('📦 Mise à jour du stock du produit $productId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/$productId/stock');

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/$productId/stock'),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'stock': stock,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return UpdateStockResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la mise à jour du stock',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du stock: $e');
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

  // 🆕 Supprimer un produit
  Future<DeleteProductResponse> deleteProduct({
    required int productId,
    required String token,
  }) async {
    try {
      print('🗑️ Suppression du produit $productId...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/$productId');

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/$productId'),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return DeleteProductResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la suppression du produit',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression du produit: $e');
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

  // 🆕 Récupérer les statistiques du commerçant
  Future<ProductStatsResponse> getProductStats(String token) async {
    try {
      print('📊 Récupération des statistiques produits...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/stats');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/stats'),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return ProductStatsResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors de la récupération des statistiques',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des statistiques: $e');
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

  // 🆕 Changer le statut d'un produit (DRAFT/PUBLISHED)
  Future<UpdateStatusResponse> updateProductStatus({
    required int productId,
    required String status, // 'DRAFT' ou 'PUBLISHED'
    required String token,
  }) async {
    try {
      print('📝 Changement de statut du produit $productId vers $status...');
      print('🌐 URL: ${ApiConfig.baseUrl}/api/produit/$productId/status');

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/produit/$productId/status'),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return UpdateStatusResponse.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw ApiError.fromJson(errorData);
        } catch (e) {
          throw ApiError(
            status: 'error',
            code: 'HTTP_${response.statusCode}',
            message: 'Erreur lors du changement de statut',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors du changement de statut: $e');
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

  // Tester la connexion
  Future<bool> testConnection() async {
    try {
      print('🧪 Test de connexion...');
      print('🌐 URL de test: ${ApiConfig.baseUrl}/api/produit');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/produit'),
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
}

// ========== NOUVELLES CLASSES DE RÉPONSE ==========

class CreateProductResponse {
  final String status;
  final String message;
  final Product product;

  CreateProductResponse({
    required this.status,
    required this.message,
    required this.product,
  });

  factory CreateProductResponse.fromJson(Map<String, dynamic> json) {
    return CreateProductResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      product: Product.fromJson(json['product']),
    );
  }

  bool get success => status == 'success';
}

class UpdateProductResponse {
  final String message;
  final Product product;

  UpdateProductResponse({
    required this.message,
    required this.product,
  });

  factory UpdateProductResponse.fromJson(Map<String, dynamic> json) {
    return UpdateProductResponse(
      message: json['message'] as String,
      product: Product.fromJson(json['product']),
    );
  }
}

class UpdateStockResponse {
  final String message;
  final Product product;

  UpdateStockResponse({
    required this.message,
    required this.product,
  });

  factory UpdateStockResponse.fromJson(Map<String, dynamic> json) {
    return UpdateStockResponse(
      message: json['message'] as String,
      product: Product.fromJson(json['product']),
    );
  }
}

class DeleteProductResponse {
  final String message;

  DeleteProductResponse({required this.message});

  factory DeleteProductResponse.fromJson(Map<String, dynamic> json) {
    return DeleteProductResponse(
      message: json['message'] as String,
    );
  }
}

class UpdateStatusResponse {
  final String message;
  final Product product;

  UpdateStatusResponse({
    required this.message,
    required this.product,
  });

  factory UpdateStatusResponse.fromJson(Map<String, dynamic> json) {
    return UpdateStatusResponse(
      message: json['message'] as String,
      product: Product.fromJson(json['product']),
    );
  }
}

class ProductStatsResponse {
  final int totalProducts;
  final int lowStockCount;
  final List<CategoryStat> categoryStats;

  ProductStatsResponse({
    required this.totalProducts,
    required this.lowStockCount,
    required this.categoryStats,
  });

  factory ProductStatsResponse.fromJson(Map<String, dynamic> json) {
    return ProductStatsResponse(
      totalProducts: json['totalProducts'] as int,
      lowStockCount: json['lowStockCount'] as int,
      categoryStats: (json['categoryStats'] as List<dynamic>)
          .map((stat) => CategoryStat.fromJson(stat))
          .toList(),
    );
  }
}

class CategoryStat {
  final String category;
  final int count;

  CategoryStat({
    required this.category,
    required this.count,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      category: json['category'] as String,
      count: json['count'] as int,
    );
  }
}

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