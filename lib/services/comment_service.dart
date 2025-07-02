// lib/services/comment_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comment_model.dart';
import 'api_config.dart';

class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  /// Obtient le token d'authentification depuis SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Utiliser les mêmes clés que le LikeService
      String? token = prefs.getString('auth_token');
      if (token == null) {
        token = prefs.getString('token');
        if (token == null) {
          token = prefs.getString('access_token');
        }
      }
      
      if (token == null) {
        print('❌ [COMMENTS] Aucun token trouvé');
        return null;
      }

      // Vérifier si le token est expiré
      if (await _isTokenExpired(token)) {
        print('❌ [COMMENTS] Token expiré');
        await _handleAuthError();
        return null;
      }

      return token;
    } catch (e) {
      print('❌ [COMMENTS] Erreur récupération token: $e');
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
      print('❌ [COMMENTS] Erreur validation token: $e');
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
      print('⚠️ [COMMENTS] Session expirée - données nettoyées');
    } catch (e) {
      print('❌ [COMMENTS] Erreur lors du nettoyage: $e');
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
      print('❌ [COMMENTS] Erreur vérification connexion: $e');
      return false;
    }
  }

  /// Récupère les commentaires d'un produit avec pagination
  Future<PaginatedComments> getProductComments(
    int productId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      print('🔄 [COMMENTS] Récupération des commentaires pour le produit ID $productId (page $page, limite $limit)');

      final url = '${ApiConfig.baseUrl}/api/products/$productId/comments?page=$page&limit=$limit';
      
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      print('📥 [COMMENTS] Réponse status: ${response.statusCode}');

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        print('❌ [COMMENTS] Erreur ${response.statusCode}: ${errorData['message']}');
        
        // Retourner un objet vide en cas d'erreur
        return PaginatedComments(
          comments: [],
          pagination: CommentPagination(
            total: 0,
            page: page,
            limit: limit,
            totalPages: 0,
          ),
        );
      }

      final data = json.decode(response.body);
      print('✅ [COMMENTS] Commentaires récupérés avec succès');
      
      return PaginatedComments.fromJson(data);
    } on TimeoutException {
      print('❌ [COMMENTS] Timeout lors de la récupération des commentaires');
      return PaginatedComments(
        comments: [],
        pagination: CommentPagination(
          total: 0,
          page: page,
          limit: limit,
          totalPages: 0,
        ),
      );
    } on SocketException {
      print('❌ [COMMENTS] Pas de réseau lors de la récupération des commentaires');
      return PaginatedComments(
        comments: [],
        pagination: CommentPagination(
          total: 0,
          page: page,
          limit: limit,
          totalPages: 0,
        ),
      );
    } catch (e) {
      print('❌ [COMMENTS] Erreur lors de la récupération des commentaires: $e');
      return PaginatedComments(
        comments: [],
        pagination: CommentPagination(
          total: 0,
          page: page,
          limit: limit,
          totalPages: 0,
        ),
      );
    }
  }

  /// Ajoute un commentaire à un produit
  Future<CommentResponse> addComment(int productId, NewComment commentData) async {
    try {
      print('🔄 [COMMENTS] Ajout d\'un commentaire pour le produit ID $productId');

      // Vérification de l'authentification
      if (!await isUserLoggedIn()) {
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'NOT_LOGGED_IN'
        );
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/products/$productId/comments';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: json.encode(commentData.toJson()),
      ).timeout(const Duration(seconds: 10));

      print('📥 [COMMENTS] Réponse ajout commentaire: ${response.statusCode}');

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        print('❌ [COMMENTS] Erreur lors de l\'ajout du commentaire: ${errorData['message']}');
        
        throw CommentException(
          errorData['message'] ?? 'Erreur lors de l\'ajout du commentaire',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      print('✅ [COMMENTS] Commentaire ajouté avec succès');

      return CommentResponse.fromJson(data);
    } on TimeoutException {
      throw CommentException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CommentException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      print('❌ [COMMENTS] Erreur: $e');
      if (e is CommentException) {
        rethrow;
      }
      throw CommentException('Erreur lors de l\'ajout du commentaire: $e');
    }
  }

  /// Ajoute une réponse à un commentaire
  Future<ReplyResponse> replyToComment(int commentId, NewReply replyData) async {
    try {
      print('🔄 [COMMENTS] Ajout d\'une réponse au commentaire ID $commentId');

      // Vérification de l'authentification
      if (!await isUserLoggedIn()) {
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'NOT_LOGGED_IN'
        );
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/comments/$commentId/replies';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: json.encode(replyData.toJson()),
      ).timeout(const Duration(seconds: 10));

      print('📥 [COMMENTS] Réponse ajout réponse: ${response.statusCode}');

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        print('❌ [COMMENTS] Erreur lors de l\'ajout de la réponse: ${errorData['message']}');
        
        throw CommentException(
          errorData['message'] ?? 'Erreur lors de l\'ajout de la réponse',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      print('✅ [COMMENTS] Réponse ajoutée avec succès');

      return ReplyResponse.fromJson(data);
    } on TimeoutException {
      throw CommentException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CommentException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      print('❌ [COMMENTS] Erreur: $e');
      if (e is CommentException) {
        rethrow;
      }
      throw CommentException('Erreur lors de l\'ajout de la réponse: $e');
    }
  }

  /// Met à jour un commentaire
  Future<CommentResponse> updateComment(int commentId, NewComment commentData) async {
    try {
      print('🔄 [COMMENTS] Mise à jour du commentaire ID $commentId');

      final token = await _getAuthToken();
      if (token == null) {
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/comments/$commentId';
      
      final response = await http.put(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: json.encode(commentData.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw CommentException(
          errorData['message'] ?? 'Erreur lors de la mise à jour du commentaire',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      print('✅ [COMMENTS] Commentaire mis à jour avec succès');

      return CommentResponse.fromJson(data);
    } on TimeoutException {
      throw CommentException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CommentException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      if (e is CommentException) {
        rethrow;
      }
      throw CommentException('Erreur lors de la mise à jour du commentaire: $e');
    }
  }

  /// Supprime un commentaire
  Future<ApiResponse> deleteComment(int commentId) async {
    try {
      print('🔄 [COMMENTS] Suppression du commentaire ID $commentId');

      final token = await _getAuthToken();
      if (token == null) {
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/comments/$commentId';
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw CommentException(
          errorData['message'] ?? 'Erreur lors de la suppression du commentaire',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      print('✅ [COMMENTS] Commentaire supprimé avec succès');

      return ApiResponse.fromJson(data);
    } on TimeoutException {
      throw CommentException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CommentException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      if (e is CommentException) {
        rethrow;
      }
      throw CommentException('Erreur lors de la suppression du commentaire: $e');
    }
  }

  /// Supprime une réponse
  Future<ApiResponse> deleteReply(int replyId) async {
    try {
      print('🔄 [COMMENTS] Suppression de la réponse ID $replyId');

      final token = await _getAuthToken();
      if (token == null) {
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      final url = '${ApiConfig.baseUrl}/api/replies/$replyId';
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw CommentException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        throw CommentException(
          errorData['message'] ?? 'Erreur lors de la suppression de la réponse',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      print('✅ [COMMENTS] Réponse supprimée avec succès');

      return ApiResponse.fromJson(data);
    } on TimeoutException {
      throw CommentException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw CommentException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      if (e is CommentException) {
        rethrow;
      }
      throw CommentException('Erreur lors de la suppression de la réponse: $e');
    }
  }

  /// Méthode pour vérifier rapidement si l'utilisateur peut commenter
  Future<bool> canUserComment() async {
    try {
      final token = await _getAuthToken();
      return token != null;
    } catch (e) {
      print('❌ [COMMENTS] Erreur vérification capacité à commenter: $e');
      return false;
    }
  }

  /// Méthode pour gérer les erreurs de session côté UI
  bool shouldLogoutOnError(CommentException error) {
    return error.code == 'SESSION_EXPIRED' || 
           error.code == 'NOT_LOGGED_IN';
  }

  /// Utilitaire pour déboguer l'état des commentaires
  Future<void> debugCommentsInfo(int productId) async {
    try {
      print('🔍 [COMMENTS] Débogage des commentaires pour le produit ID $productId');
      
      final canComment = await canUserComment();
      print('👤 [COMMENTS] Utilisateur peut commenter: $canComment');
      
      final token = await _getAuthToken();
      print('🔑 [COMMENTS] Token présent: ${token != null}');
      
      if (canComment) {
        try {
          final result = await getProductComments(productId);
          print('💬 [COMMENTS] Nombre de commentaires: ${result.comments.length}');
          print('📊 [COMMENTS] Pagination: ${result.pagination}');
          
          result.comments.asMap().forEach((index, comment) {
            print('📝 [COMMENTS] Commentaire #${index + 1}:');
            print('   ID: ${comment.id}');
            print('   Utilisateur: ${comment.user?.fullName ?? 'Inconnu'}');
            print('   Texte: ${comment.comment}');
            print('   Date: ${comment.createdAt}');
            print('   Nombre de réponses: ${comment.replies.length}');
          });
        } catch (e) {
          print('❌ [COMMENTS] Erreur lors de la récupération des commentaires: $e');
        }
      }
    } catch (error) {
      print('❌ [COMMENTS] Erreur lors du débogage: $error');
    }
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