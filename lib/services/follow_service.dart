// lib/services/follow_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/follow_model.dart';
import 'api_config.dart';

class FollowService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user';

  // 🔧 MÉTHODES UTILITAIRES PRIVÉES

  /// Récupère le token d'authentification
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('❌ [FOLLOW_SERVICE] Erreur récupération token: $e');
      return null;
    }
  }

  /// Récupère les headers d'authentification
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Gère les erreurs API
  void _handleApiError(dynamic error, String defaultMessage) {
    if (error is Map<String, dynamic>) {
      final message = error['message'] ?? defaultMessage;
      final code = error['code'];
      throw FollowException(message, code: code);
    }
    throw FollowException(defaultMessage);
  }

  /// Vérifie si l'utilisateur est connecté
  Future<bool> _isAuthenticated() async {
    final token = await _getAuthToken();
    return token != null && token.isNotEmpty;
  }

  // 🔥 MÉTHODES PRINCIPALES

  /// Suivre ou ne plus suivre un utilisateur (toggle)
  Future<FollowResponse> toggleFollow(int userId) async {
    try {
      print('🔄 [FOLLOW_SERVICE] Basculement du suivi pour l\'utilisateur ID $userId');
      
      // Vérifier l'authentification
      if (!await _isAuthenticated()) {
        throw FollowException(
          'Vous devez être connecté pour suivre ou ne plus suivre un utilisateur',
          code: 'NOT_AUTHENTICATED',
        );
      }
      
      // Préparer la requête
      final url = Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/toggle-follow');
      final headers = await _getAuthHeaders();
      
      print('🌐 [FOLLOW_SERVICE] URL: $url');
      
      // Effectuer la requête
      final response = await http.post(url, headers: headers);
      
      print('📡 [FOLLOW_SERVICE] Code de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final followResponse = FollowResponse.fromJson(data);
        
        print('✅ [FOLLOW_SERVICE] Suivi basculé avec succès: ${followResponse.action}');
        return followResponse;
      } else {
        final errorData = json.decode(response.body);
        print('❌ [FOLLOW_SERVICE] Erreur API: $errorData');
        _handleApiError(errorData, 'Erreur lors du basculement du suivi');
        throw FollowException('Erreur inattendue');
      }
    } catch (e) {
      print('❌ [FOLLOW_SERVICE] Exception: $e');
      if (e is FollowException) {
        rethrow;
      }
      throw FollowException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Récupère la liste des abonnés d'un utilisateur
  Future<FollowersResponse> getUserFollowers(
    int userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      print('🔄 [FOLLOW_SERVICE] Récupération des abonnés de l\'utilisateur ID $userId');
      
      // Préparer la requête
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/users/$userId/followers?page=$page&limit=$limit',
      );
      final headers = await _getAuthHeaders();
      
      print('🌐 [FOLLOW_SERVICE] URL: $url');
      
      // Effectuer la requête
      final response = await http.get(url, headers: headers);
      
      print('📡 [FOLLOW_SERVICE] Code de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final followersResponse = FollowersResponse.fromJson(data);
        
        print('✅ [FOLLOW_SERVICE] Abonnés récupérés avec succès: ${followersResponse.followers.length}');
        return followersResponse;
      } else {
        final errorData = json.decode(response.body);
        print('❌ [FOLLOW_SERVICE] Erreur API: $errorData');
        _handleApiError(errorData, 'Erreur lors de la récupération des abonnés');
        throw FollowException('Erreur inattendue');
      }
    } catch (e) {
      print('❌ [FOLLOW_SERVICE] Exception: $e');
      if (e is FollowException) {
        rethrow;
      }
      throw FollowException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Récupère la liste des abonnements d'un utilisateur
  Future<FollowingResponse> getUserFollowing(
    int userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      print('🔄 [FOLLOW_SERVICE] Récupération des abonnements de l\'utilisateur ID $userId');
      
      // Préparer la requête
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/users/$userId/following?page=$page&limit=$limit',
      );
      final headers = await _getAuthHeaders();
      
      print('🌐 [FOLLOW_SERVICE] URL: $url');
      
      // Effectuer la requête
      final response = await http.get(url, headers: headers);
      
      print('📡 [FOLLOW_SERVICE] Code de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final followingResponse = FollowingResponse.fromJson(data);
        
        print('✅ [FOLLOW_SERVICE] Abonnements récupérés avec succès: ${followingResponse.following.length}');
        return followingResponse;
      } else {
        final errorData = json.decode(response.body);
        print('❌ [FOLLOW_SERVICE] Erreur API: $errorData');
        _handleApiError(errorData, 'Erreur lors de la récupération des abonnements');
        throw FollowException('Erreur inattendue');
      }
    } catch (e) {
      print('❌ [FOLLOW_SERVICE] Exception: $e');
      if (e is FollowException) {
        rethrow;
      }
      throw FollowException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Vérifie si l'utilisateur connecté suit un autre utilisateur
  Future<IsFollowingResponse> checkIfFollowing(int userId) async {
    try {
      print('🔄 [FOLLOW_SERVICE] Vérification si l\'utilisateur suit l\'ID $userId');
      
      // Vérifier l'authentification
      if (!await _isAuthenticated()) {
        throw FollowException(
          'Vous devez être connecté pour vérifier si vous suivez un utilisateur',
          code: 'NOT_AUTHENTICATED',
        );
      }
      
      // Préparer la requête
      final url = Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/isFollowing');
      final headers = await _getAuthHeaders();
      
      print('🌐 [FOLLOW_SERVICE] URL: $url');
      
      // Effectuer la requête
      final response = await http.get(url, headers: headers);
      
      print('📡 [FOLLOW_SERVICE] Code de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isFollowingResponse = IsFollowingResponse.fromJson(data);
        
        print('✅ [FOLLOW_SERVICE] Vérification de suivi réussie: ${isFollowingResponse.isFollowing ? 'Suit' : 'Ne suit pas'}');
        return isFollowingResponse;
      } else {
        final errorData = json.decode(response.body);
        print('❌ [FOLLOW_SERVICE] Erreur API: $errorData');
        _handleApiError(errorData, 'Erreur lors de la vérification du suivi');
        throw FollowException('Erreur inattendue');
      }
    } catch (e) {
      print('❌ [FOLLOW_SERVICE] Exception: $e');
      if (e is FollowException) {
        rethrow;
      }
      throw FollowException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Récupère des suggestions d'utilisateurs à suivre
  Future<SuggestedUsersResponse> getSuggestedUsers({int limit = 10}) async {
    try {
      print('🔄 [FOLLOW_SERVICE] Récupération de $limit suggestions d\'utilisateurs à suivre');
      
      // Vérifier l'authentification
      if (!await _isAuthenticated()) {
        throw FollowException(
          'Vous devez être connecté pour obtenir des suggestions d\'utilisateurs',
          code: 'NOT_AUTHENTICATED',
        );
      }
      
      // Préparer la requête
      final url = Uri.parse('${ApiConfig.baseUrl}/api/users/suggestions?limit=$limit');
      final headers = await _getAuthHeaders();
      
      print('🌐 [FOLLOW_SERVICE] URL: $url');
      
      // Effectuer la requête
      final response = await http.get(url, headers: headers);
      
      print('📡 [FOLLOW_SERVICE] Code de réponse: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestedUsersResponse = SuggestedUsersResponse.fromJson(data);
        
        print('✅ [FOLLOW_SERVICE] Suggestions récupérées avec succès: ${suggestedUsersResponse.suggestions.length}');
        return suggestedUsersResponse;
      } else {
        final errorData = json.decode(response.body);
        print('❌ [FOLLOW_SERVICE] Erreur API: $errorData');
        _handleApiError(errorData, 'Erreur lors de la récupération des suggestions');
        throw FollowException('Erreur inattendue');
      }
    } catch (e) {
      print('❌ [FOLLOW_SERVICE] Exception: $e');
      if (e is FollowException) {
        rethrow;
      }
      throw FollowException('Erreur de connexion: ${e.toString()}');
    }
  }

  // 🔧 MÉTHODES UTILITAIRES

  /// Utilitaire pour vérifier et afficher les statistiques de suivi pour un utilisateur
  Future<void> debugFollowStats(int userId) async {
    try {
      print('🔍 [FOLLOW_SERVICE] Débogage des statistiques de suivi pour l\'utilisateur ID $userId');
      
      // Récupérer le nombre d'abonnés
      final followersResponse = await getUserFollowers(userId, page: 1, limit: 1);
      print('👥 [FOLLOW_SERVICE] Nombre total d\'abonnés: ${followersResponse.pagination.total}');
      
      // Récupérer le nombre d'abonnements
      final followingResponse = await getUserFollowing(userId, page: 1, limit: 1);
      print('👥 [FOLLOW_SERVICE] Nombre total d\'abonnements: ${followingResponse.pagination.total}');
      
      // Vérifier si l'utilisateur est connecté
      if (await _isAuthenticated()) {
        // Obtenir les informations de l'utilisateur connecté
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString(_userKey);
        
        if (userStr != null) {
          final user = json.decode(userStr);
          final currentUserId = user['id'];
          
          // Si l'utilisateur connecté est différent de l'utilisateur demandé, vérifier s'il le suit
          if (currentUserId != userId) {
            final isFollowingResponse = await checkIfFollowing(userId);
            print('👥 [FOLLOW_SERVICE] L\'utilisateur connecté ${isFollowingResponse.isFollowing ? 'suit' : 'ne suit pas'} cet utilisateur');
          }
        }
      }
    } catch (e) {
      print('❌ [FOLLOW_SERVICE] Erreur lors du débogage: $e');
    }
  }

  /// Obtient l'utilisateur connecté
  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(_userKey);
      
      if (userStr != null) {
        final userData = json.decode(userStr);
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('❌ [FOLLOW_SERVICE] Erreur récupération utilisateur connecté: $e');
      return null;
    }
  }

  /// Nettoie le cache des données de suivi
  Future<void> clearFollowCache() async {
    try {
      // Ici vous pourriez implémenter un système de cache si nécessaire
      print('🧹 [FOLLOW_SERVICE] Cache des données de suivi nettoyé');
    } catch (e) {
      print('❌ [FOLLOW_SERVICE] Erreur nettoyage cache: $e');
    }
  }
}