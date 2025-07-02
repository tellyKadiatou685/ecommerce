// lib/services/like_service.dart - CORRIGÉ POUR VOS CLÉS
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/like_model.dart';
import 'api_config.dart';

class LikeService {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  /// Obtient le token d'authentification - CORRIGÉ POUR VOS CLÉS
  Future<String?> _getAuthToken() async {
    try {
      print('🔍 [LIKES] Recherche du token d\'authentification...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // 🔥 UTILISER VOS VRAIES CLÉS
      String? token = prefs.getString('auth_token'); // ✅ VOTRE CLÉ RÉELLE
      
      if (token == null) {
        // Fallback sur les autres clés possibles
        token = prefs.getString('token');
        if (token == null) {
          token = prefs.getString('access_token');
          if (token == null) {
            token = prefs.getString('jwt_token');
          }
        }
      }
      
      if (token == null) {
        print('❌ [LIKES] Aucun token trouvé');
        return null;
      }

      print('✅ [LIKES] Token trouvé sous auth_token, longueur: ${token.length}');

      // Vérifier si le token est expiré
      if (await _isTokenExpired(token)) {
        print('❌ [LIKES] Token expiré');
        await _handleAuthError();
        return null;
      }

      print('✅ [LIKES] Token valide et non expiré');
      return token;
    } catch (e) {
      print('❌ [LIKES] Erreur récupération token: $e');
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
      final isExpired = DateTime.now().isAfter(expirationTime);
      
      if (!isExpired) {
        final timeLeft = expirationTime.difference(DateTime.now());
        print('✅ [LIKES] Token valide, temps restant: $timeLeft');
      }
      
      return isExpired;
    } catch (e) {
      print('❌ [LIKES] Erreur validation token: $e');
      return true;
    }
  }

  /// Gère les erreurs d'authentification
  Future<void> _handleAuthError() async {
    try {
      print('🔄 [LIKES] Session expirée - nettoyage des données');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token'); // ✅ VOTRE CLÉ RÉELLE
      await prefs.remove('user_data');  // ✅ VOTRE CLÉ RÉELLE
      await prefs.remove('token'); // Nettoyage des autres clés possibles
      await prefs.remove('user');
      
      print('⚠️ [LIKES] Session expirée - l\'utilisateur devra se reconnecter');
    } catch (e) {
      print('❌ [LIKES] Erreur lors du nettoyage: $e');
    }
  }

  /// Vérifie si l'utilisateur est connecté - CORRIGÉ POUR VOS CLÉS
  Future<bool> isUserLoggedIn() async {
    try {
      print('🔍 [LIKES] Vérification de la connexion utilisateur...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // 🔥 UTILISER VOS VRAIES CLÉS
      final userStr = prefs.getString('user_data'); // ✅ VOTRE CLÉ RÉELLE
      final token = await _getAuthToken(); // Utilise la méthode corrigée
      
      final isLoggedIn = userStr != null && token != null;
      
      print('👤 [LIKES] User présent (user_data): ${userStr != null}');
      print('🔑 [LIKES] Token présent (auth_token): ${token != null}');
      print('✅ [LIKES] Utilisateur connecté: $isLoggedIn');
      
      return isLoggedIn;
    } catch (e) {
      print('❌ [LIKES] Erreur vérification connexion: $e');
      return false;
    }
  }

  /// Ajoute/retire un like à un produit - AVEC DÉBOGAGE ULTRA-DÉTAILLÉ
  Future<LikeResponse> toggleProductLike(int productId) async {
    try {
      print('\n🔥 ===== DÉBUT TOGGLE LIKE =====');
      print('🔥 Product ID: $productId');

      // Vérification de l'authentification avec les bonnes clés
      final isLoggedIn = await isUserLoggedIn();
      print('🔥 User logged in: $isLoggedIn');
      if (!isLoggedIn) {
        print('❌ [LIKES] Utilisateur non connecté');
        throw LikeException(
          'Vous devez être connecté pour aimer un produit.',
          code: 'NOT_LOGGED_IN'
        );
      }

      final token = await _getAuthToken();
      if (token == null) {
        throw LikeException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED_MOBILE'
        );
      }

      print('✅ [LIKES] Token récupéré, envoi de la requête...');

      // Appeler l'API pour liker/unliker le produit
      final url = '${ApiConfig.baseUrl}/api/products/$productId/like';
      print('🔥 URL: $url');
      
      final headers = {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      };
      print('🔥 Headers: $headers');

      print('🔥 Envoi requête POST...');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      print('🔥 ===== RÉPONSE API =====');
      print('🔥 Status Code: ${response.statusCode}');
      print('🔥 Response Headers: ${response.headers}');
      print('🔥 Response Body BRUT: ${response.body}');
      print('🔥 Response Body Type: ${response.body.runtimeType}');
      print('🔥 Response Body Length: ${response.body.length}');

      if (response.statusCode == 401) {
        print('❌ [LIKES] Erreur 401 - token invalide');
        await _handleAuthError();
        throw LikeException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED_MOBILE'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        print('❌ [LIKES] Erreur ${response.statusCode}: ${errorData['message']}');
        
        throw LikeException(
          errorData['message'] ?? 'Erreur lors de la gestion du like',
          code: errorData['code']
        );
      }

      // 🔥 DÉCODAGE DÉTAILLÉ DE LA RÉPONSE
      print('🔥 ===== DÉCODAGE RÉPONSE =====');
      dynamic data;
      try {
        data = json.decode(response.body);
        print('🔥 JSON décodé avec succès: $data');
        print('🔥 Type de data: ${data.runtimeType}');
        
        if (data is Map<String, dynamic>) {
          print('🔥 Clés disponibles: ${data.keys.toList()}');
          print('🔥 data[\'action\']: ${data['action']} (${data['action'].runtimeType})');
          print('🔥 data[\'message\']: ${data['message']}');
          print('🔥 data[\'liked\']: ${data['liked']}');
          print('🔥 data[\'isLiked\']: ${data['isLiked']}');
          print('🔥 data[\'hasLiked\']: ${data['hasLiked']}');
          print('🔥 data[\'status\']: ${data['status']}');
          print('🔥 data[\'success\']: ${data['success']}');
        }
      } catch (e) {
        print('❌ [LIKES] Erreur décodage JSON: $e');
        print('❌ [LIKES] Body brut: ${response.body}');
        throw LikeException('Erreur de décodage de la réponse du serveur');
      }

      print('🔥 Action API: ${data['action']}');

      // 🔥 RÉCUPÉRER L'ÉTAT UTILISATEUR AVANT ET APRÈS
      print('🔥 ===== VÉRIFICATION ÉTAT UTILISATEUR =====');
      
      // Récupérer le nouveau nombre de likes
      final likesCount = await getProductLikesCount(productId);
      print('🔥 Nouveaux compteurs: likes=${likesCount.likesCount}, dislikes=${likesCount.dislikesCount}');

      // Récupérer la réaction utilisateur
      final userReaction = await getUserProductReaction(productId);
      print('🔥 Nouvelle réaction user: liked=${userReaction.hasLiked}, disliked=${userReaction.hasDisliked}');

      final likeResponse = LikeResponse(
        message: data['message'] ?? "Like ajouté/retiré avec succès",
        action: data['action'] ?? "toggled",
        likesCount: likesCount.likesCount,
        dislikesCount: likesCount.dislikesCount,
      );

      print('🔥 ===== RÉPONSE FINALE =====');
      print('🔥 LikeResponse: $likeResponse');
      print('🔥 ===== FIN TOGGLE LIKE =====\n');

      return likeResponse;
    } on TimeoutException {
      print('❌ [LIKES] Timeout de la requête');
      throw LikeException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      print('❌ [LIKES] Erreur réseau');
      throw LikeException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      print('❌ [LIKES] Erreur: $e');
      if (e is LikeException) {
        rethrow;
      }
      throw LikeException('Erreur lors de la gestion du like: $e');
    }
  }

  /// Ajoute/retire un dislike à un produit
  Future<LikeResponse> toggleProductDislike(int productId) async {
    try {
      print('🔄 [LIKES] Toggle dislike pour le produit ID $productId');

      final token = await _getAuthToken();
      if (token == null) {
        throw LikeException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED_MOBILE'
        );
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/products/$productId/dislike'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleAuthError();
        throw LikeException(
          'Session expirée. Veuillez redémarrer l\'application.',
          code: 'SESSION_EXPIRED_MOBILE'
        );
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        print('❌ [LIKES] Erreur lors du dislike: ${errorData['message']}');
        
        throw LikeException(
          errorData['message'] ?? 'Erreur lors de la gestion du dislike',
          code: errorData['code']
        );
      }

      final data = json.decode(response.body);
      print('✅ [LIKES] Action ${data['action']} effectuée avec succès');

      final likesCount = await getProductLikesCount(productId);

      return LikeResponse(
        message: data['message'] ?? "Dislike ajouté/retiré avec succès",
        action: data['action'] ?? "toggled",
        likesCount: likesCount.likesCount,
        dislikesCount: likesCount.dislikesCount,
      );
    } on TimeoutException {
      throw LikeException(
        'Le serveur ne répond pas. Réessayez plus tard.',
        code: 'TIMEOUT'
      );
    } on SocketException {
      throw LikeException(
        'Pas de connexion réseau. Vérifiez votre connexion.',
        code: 'NO_INTERNET'
      );
    } catch (e) {
      print('❌ [LIKES] Erreur: $e');
      if (e is LikeException) {
        rethrow;
      }
      throw LikeException('Erreur lors de la gestion du dislike: $e');
    }
  }

  /// Récupère le nombre de likes et dislikes d'un produit
  Future<LikesCount> getProductLikesCount(int productId) async {
    try {
      print('🔄 [LIKES] Récupération des likes pour le produit ID $productId');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/products/$productId/likes'),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        print('❌ [LIKES] Erreur ${response.statusCode}: ${errorData['message']}');
        return LikesCount(likesCount: 0, dislikesCount: 0);
      }

      final data = json.decode(response.body);
      final likes = (data['likes'] as List? ?? [])
          .map((like) => ProductLike.fromJson(like))
          .toList();

      final likesCount = likes.where((like) => like.type == ReactionType.LIKE).length;
      final dislikesCount = likes.where((like) => like.type == ReactionType.DISLIKE).length;

      print('✅ [LIKES] Compteurs: likes=$likesCount, dislikes=$dislikesCount');
      return LikesCount(likesCount: likesCount, dislikesCount: dislikesCount);
    } on TimeoutException {
      print('❌ [LIKES] Timeout lors de la récupération des compteurs');
      return LikesCount(likesCount: 0, dislikesCount: 0);
    } on SocketException {
      print('❌ [LIKES] Pas de réseau lors de la récupération des compteurs');
      return LikesCount(likesCount: 0, dislikesCount: 0);
    } catch (e) {
      print('❌ [LIKES] Erreur lors de la récupération des compteurs: $e');
      return LikesCount(likesCount: 0, dislikesCount: 0);
    }
  }

  /// Vérifie si l'utilisateur a aimé ou non un produit - AVEC DÉBOGAGE DÉTAILLÉ
  Future<UserReaction> getUserProductReaction(int productId) async {
    try {
      print('\n🔍 ===== RÉCUPÉRATION RÉACTION UTILISATEUR =====');
      print('🔍 Product ID: $productId');

      final token = await _getAuthToken();
      if (token == null) {
        print('⚠️ [LIKES] Pas de token, retour par défaut');
        return UserReaction.defaultState();
      }

      final url = '${ApiConfig.baseUrl}/api/products/$productId/user-reaction';
      print('🔍 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('🔍 ===== RÉPONSE USER-REACTION =====');
      print('🔍 Status Code: ${response.statusCode}');
      print('🔍 Response Body BRUT: ${response.body}');

      if (response.statusCode == 401) {
        await _handleAuthError();
        print('⚠️ [LIKES] Session expirée lors de la vérification de réaction');
        return UserReaction.defaultState();
      }

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorData = _parseErrorResponse(response.body);
        print('❌ [LIKES] Erreur lors de la vérification de la réaction: ${errorData['message']}');
        return UserReaction.defaultState();
      }

      // 🔍 DÉCODAGE DÉTAILLÉ
      dynamic data;
      try {
        data = json.decode(response.body);
        print('🔍 JSON décodé: $data');
        print('🔍 Type: ${data.runtimeType}');
        
        if (data is Map<String, dynamic>) {
          print('🔍 Clés disponibles: ${data.keys.toList()}');
          print('🔍 data[\'hasLiked\']: ${data['hasLiked']} (${data['hasLiked'].runtimeType})');
          print('🔍 data[\'hasDisliked\']: ${data['hasDisliked']} (${data['hasDisliked'].runtimeType})');
          print('🔍 data[\'liked\']: ${data['liked']}');
          print('🔍 data[\'disliked\']: ${data['disliked']}');
          print('🔍 data[\'isLiked\']: ${data['isLiked']}');
          print('🔍 data[\'isDisliked\']: ${data['isDisliked']}');
        }
      } catch (e) {
        print('❌ [LIKES] Erreur décodage JSON user-reaction: $e');
        return UserReaction.defaultState();
      }

      final userReaction = UserReaction.fromJson(data);
      print('🔍 UserReaction créé: $userReaction');
      print('🔍 ===== FIN RÉCUPÉRATION RÉACTION =====\n');

      return userReaction;
    } on TimeoutException {
      print('❌ [LIKES] Timeout lors de la vérification de la réaction');
      return UserReaction.defaultState();
    } on SocketException {
      print('❌ [LIKES] Pas de réseau lors de la vérification de la réaction');
      return UserReaction.defaultState();
    } catch (e) {
      print('❌ [LIKES] Erreur lors de la vérification de la réaction: $e');
      return UserReaction.defaultState();
    }
  }

  /// Méthode pour vérifier rapidement si l'utilisateur peut liker
  Future<bool> canUserLike() async {
    try {
      final token = await _getAuthToken();
      return token != null;
    } catch (e) {
      print('❌ [LIKES] Erreur vérification capacité à liker: $e');
      return false;
    }
  }

  /// Méthode pour gérer les erreurs de session côté UI
  bool shouldLogoutOnError(LikeException error) {
    return error.code == 'SESSION_EXPIRED_MOBILE' || 
           error.code == 'TOKEN_MISSING' ||
           error.code == 'SESSION_EXPIRED' ||
           error.code == 'NOT_LOGGED_IN';
  }

  /// Utilitaire pour déboguer l'état des likes
  Future<void> debugLikesInfo(int productId) async {
    try {
      print('🔍 [LIKES] Débogage des likes pour le produit ID $productId');
      
      final canLike = await canUserLike();
      print('👤 [LIKES] Utilisateur peut liker: $canLike');
      
      final token = await _getAuthToken();
      print('🔑 [LIKES] Token présent: ${token != null}');
      
      if (canLike) {
        try {
          final likesCount = await getProductLikesCount(productId);
          print('👍 [LIKES] Nombre de likes: ${likesCount.likesCount}');
          print('👎 [LIKES] Nombre de dislikes: ${likesCount.dislikesCount}');
          
          final userReaction = await getUserProductReaction(productId);
          print('🤔 [LIKES] Utilisateur a aimé: ${userReaction.hasLiked}');
          print('🤔 [LIKES] Utilisateur n\'a pas aimé: ${userReaction.hasDisliked}');
        } catch (e) {
          print('❌ [LIKES] Erreur lors de la récupération des données: $e');
        }
      }
    } catch (error) {
      print('❌ [LIKES] Erreur lors du débogage: $error');
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