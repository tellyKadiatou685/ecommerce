// lib/services/message_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import 'api_config.dart';

class MessageService {
  static const String _tokenKey = 'auth_token';

  // 🔧 MÉTHODES UTILITAIRES

  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('❌ [MESSAGE_SERVICE] Erreur récupération token: $e');
      return null;
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    if (token != null) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
    }
    return {
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, String>> _getAuthHeadersForFormData() async {
    final token = await _getAuthToken();
    if (token != null) {
      return {
        'Authorization': 'Bearer $token',
      };
    }
    return {};
  }

  void _handleApiError(dynamic error, String defaultMessage) {
    if (error is Map<String, dynamic>) {
      final message = error['message'] ?? defaultMessage;
      final code = error['code'];
      throw MessageException(message, code: code);
    }
    throw MessageException(defaultMessage);
  }

  Future<bool> _isAuthenticated() async {
    final token = await _getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<int?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('current_user_id');
    } catch (e) {
      print('❌ [MESSAGE_SERVICE] Erreur récupération ID utilisateur: $e');
      return null;
    }
  }

// 🔧 REMPLACEZ COMPLÈTEMENT la méthode sendMessage() dans votre MessageService

Future<SendMessageResponse> sendMessage(
  int receiverId,
  String content, {
  File? mediaFile,
}) async {
  try {
    print('🔄 [MESSAGE_SERVICE] Envoi message à utilisateur $receiverId');
    print('   📝 Contenu: "$content"');
    print('   📁 Fichier: ${mediaFile?.path ?? "Aucun"}');

    if (!await _isAuthenticated()) {
      throw MessageException('Vous devez être connecté pour envoyer un message');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/messages/send');
    print('🌐 [MESSAGE_SERVICE] URL: $url');

    http.Response response;

    if (mediaFile != null) {
      // 🔥 MULTIPART POUR FICHIERS - VERSION CORRIGÉE
      print('📎 [MESSAGE_SERVICE] Envoi avec fichier...');
      
      // 🔧 VÉRIFICATION PRÉALABLE DU FICHIER
      if (!await mediaFile.exists()) {
        throw MessageException('Le fichier n\'existe pas');
      }
      
      // 🔧 LIRE LE FICHIER EN BYTES AVANT DE CRÉER LA REQUÊTE
      final fileBytes = await mediaFile.readAsBytes();
      final fileSize = fileBytes.length;
      
      if (fileSize == 0) {
        throw MessageException('Le fichier est vide');
      }
      
      print('📎 [MESSAGE_SERVICE] Taille réelle du fichier: $fileSize bytes');
      print('📎 [MESSAGE_SERVICE] Nom du fichier: ${mediaFile.path.split('/').last}');
      
      final request = http.MultipartRequest('POST', url);
      final headers = await _getAuthHeadersForFormData();
      request.headers.addAll(headers);

      request.fields['receiverId'] = receiverId.toString();
      request.fields['content'] = content;

      // Déterminer le type MIME avec support pour l'audio
      final fileName = mediaFile.path.split('/').last;
      String mimeType = 'application/octet-stream';
      final extension = fileName.toLowerCase().split('.').last;
      
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'mp4':
          mimeType = 'video/mp4';
          break;
        case 'mov':
          mimeType = 'video/quicktime';
          break;
        // 🔧 AJOUT DES TYPES AUDIO
        case 'm4a':
          mimeType = 'audio/mp4';
          break;
        case 'mp3':
          mimeType = 'audio/mpeg';
          break;
        case 'wav':
          mimeType = 'audio/wav';
          break;
        case 'aac':
          mimeType = 'audio/aac';
          break;
        case 'ogg':
          mimeType = 'audio/ogg';
          break;
        default:
          mimeType = 'application/octet-stream';
      }

      print('📎 [MESSAGE_SERVICE] Type MIME détecté: $mimeType');

      // 🔧 UTILISER fromBytes AU LIEU DE fromPath
      final multipartFile = http.MultipartFile.fromBytes(
        'media',
        fileBytes,
        filename: fileName,
        contentType: parser.MediaType.parse(mimeType),
      );
      
      request.files.add(multipartFile);
      print('📎 [MESSAGE_SERVICE] Fichier ajouté depuis bytes: ${mediaFile.path}');

      // 🔧 AJOUTER UN TIMEOUT PLUS LONG POUR L'AUDIO
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45), // Plus de temps pour les fichiers audio
      );
      
      response = await http.Response.fromStream(streamedResponse);
      
    } else {
      // 🔥 REQUÊTE NORMALE POUR TEXTE
      final headers = await _getAuthHeaders();
      response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'receiverId': receiverId,
          'content': content,
        }),
      );
    }

    print('📡 [MESSAGE_SERVICE] Code: ${response.statusCode}');
    print('📄 [MESSAGE_SERVICE] Réponse: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return SendMessageResponse.fromJson(data);
    } else {
      final errorData = json.decode(response.body);
      _handleApiError(errorData, 'Erreur lors de l\'envoi du message');
      throw MessageException('Erreur inattendue');
    }
    
  } catch (e) {
    print('❌ [MESSAGE_SERVICE] Exception: $e');
    
    // 🔧 GESTION SPÉCIFIQUE DES ERREURS DE TAILLE
    if (e.toString().contains('Content size exceeds')) {
      throw MessageException('Erreur de taille de fichier, veuillez réessayer');
    } else if (e.toString().contains('TimeoutException')) {
      throw MessageException('Délai d\'attente dépassé lors de l\'envoi');
    } else if (e.toString().contains('SocketException')) {
      throw MessageException('Erreur de connexion réseau');
    } else if (e is MessageException) {
      rethrow;
    }
    
    throw MessageException('Erreur de connexion: ${e.toString()}');
  }
}
  Future<DeleteMessageResponse> deleteMessage(
    int messageId, {
    bool forEveryone = false,
  }) async {
    try {
      print('🔄 [MESSAGE_SERVICE] Suppression message $messageId, forEveryone: $forEveryone');

      if (!await _isAuthenticated()) {
        throw MessageException('Vous devez être connecté pour supprimer un message');
      }

      // 🔥 CONSTRUIRE L'URL EXACTEMENT COMME VOTRE INTERFACE WEB
      String endpoint = '/api/messages/$messageId';
      if (forEveryone) {
        endpoint += '?forEveryone=true';
      }
      // 🔥 IMPORTANT : Ne pas ajouter forEveryone=false, juste pas de paramètre
      
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getAuthHeaders();
      
      print('🌐 [MESSAGE_SERVICE] URL: $url');
      print('🔧 [MESSAGE_SERVICE] Headers: ${headers.keys.join(", ")}');

      final response = await http.delete(url, headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Délai d\'attente dépassé', const Duration(seconds: 15));
        },
      );

      print('📡 [MESSAGE_SERVICE] Status Code: ${response.statusCode}');
      print('📄 [MESSAGE_SERVICE] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [MESSAGE_SERVICE] Suppression réussie');
        return DeleteMessageResponse.fromJson(data);
      } else if (response.statusCode == 404) {
        throw MessageException('Message non trouvé');
      } else if (response.statusCode == 403) {
        throw MessageException('Vous n\'êtes pas autorisé à supprimer ce message');
      } else if (response.statusCode == 401) {
        throw MessageException('Session expirée, veuillez vous reconnecter');
      } else {
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['message'] ?? 'Erreur lors de la suppression';
          throw MessageException(errorMessage);
        } catch (e) {
          throw MessageException('Erreur serveur (${response.statusCode})');
        }
      }
    } catch (e) {
      print('❌ [MESSAGE_SERVICE] Exception: $e');
      if (e is MessageException) {
        rethrow;
      }
      if (e is TimeoutException) {
        throw MessageException('Délai d\'attente dépassé');
      }
      if (e is SocketException) {
        throw MessageException('Erreur de connexion réseau');
      }
      throw MessageException('Erreur de connexion: ${e.toString()}');
    }
  }

  // 🔥 MÉTHODES HELPER POUR LA COMPATIBILITÉ
  Future<DeleteMessageResponse> deleteMessageForMe(int messageId) async {
    print('🔥 [DELETE_FOR_ME] Suppression pour moi - Message ID: $messageId');
    return await deleteMessage(messageId, forEveryone: false);
  }

  Future<DeleteMessageResponse> deleteMessageForEveryone(int messageId) async {
    print('🔥 [DELETE_FOR_EVERYONE] Suppression pour tous - Message ID: $messageId');
    return await deleteMessage(messageId, forEveryone: true);
  }

  // 💬 RÉCUPÉRER LES CONVERSATIONS
  Future<ConversationsResponse> getConversations() async {
    try {
      print('🔄 [MESSAGE_SERVICE] Récupération des conversations');

      if (!await _isAuthenticated()) {
        throw MessageException('Vous devez être connecté pour accéder à vos conversations');
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/api/messages/conversations');
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers);
      print('📡 [MESSAGE_SERVICE] Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ConversationsResponse.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        _handleApiError(errorData, 'Erreur lors de la récupération des conversations');
        throw MessageException('Erreur inattendue');
      }
    } catch (e) {
      print('❌ [MESSAGE_SERVICE] Exception: $e');
      if (e is MessageException) {
        rethrow;
      }
      throw MessageException('Erreur de connexion: ${e.toString()}');
    }
  }

  // 📩 RÉCUPÉRER LES MESSAGES AVEC FILTRAGE
  Future<MessagesResponse> getMessages(int partnerId) async {
    try {
      print('🔄 [MESSAGE_SERVICE] Récupération des messages avec utilisateur $partnerId');

      if (!await _isAuthenticated()) {
        throw MessageException('Vous devez être connecté pour accéder à vos messages');
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/api/messages/with/$partnerId');
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers);
      print('📡 [MESSAGE_SERVICE] Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messagesResponse = MessagesResponse.fromJson(data);
        
        // 🔥 FILTRER LES MESSAGES SUPPRIMÉS POUR L'UTILISATEUR ACTUEL
        final currentUserId = await _getCurrentUserId();
        if (currentUserId != null && messagesResponse.data.messages.isNotEmpty) {
          final filteredMessages = messagesResponse.data.messages.where((message) {
            // Ne pas afficher si supprimé pour l'utilisateur actuel
            if (message.senderId == currentUserId && message.deletedForSender) {
              print('🚫 [FILTER] Message ${message.id} supprimé pour sender');
              return false;
            }
            if (message.receiverId == currentUserId && message.deletedForReceiver) {
              print('🚫 [FILTER] Message ${message.id} supprimé pour receiver');
              return false;
            }
            return true;
          }).toList();
          
          print('📊 [MESSAGE_SERVICE] Messages avant filtrage: ${messagesResponse.data.messages.length}');
          print('📊 [MESSAGE_SERVICE] Messages après filtrage: ${filteredMessages.length}');
          
          // Créer une nouvelle réponse avec les messages filtrés
          messagesResponse.data.messages.clear();
          messagesResponse.data.messages.addAll(filteredMessages);
        }
        
        return messagesResponse;
      } else {
        final errorData = json.decode(response.body);
        _handleApiError(errorData, 'Erreur lors de la récupération des messages');
        throw MessageException('Erreur inattendue');
      }
    } catch (e) {
      print('❌ [MESSAGE_SERVICE] Exception: $e');
      if (e is MessageException) {
        rethrow;
      }
      throw MessageException('Erreur de connexion: ${e.toString()}');
    }
  }

  // ✏️ METTRE À JOUR UN MESSAGE
  Future<SendMessageResponse> updateMessage(int messageId, String content) async {
    try {
      print('🔄 [MESSAGE_SERVICE] Mise à jour du message $messageId');

      if (!await _isAuthenticated()) {
        throw MessageException('Vous devez être connecté pour modifier un message');
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/api/messages/$messageId');
      final headers = await _getAuthHeaders();

      final response = await http.put(
        url,
        headers: headers,
        body: json.encode({'content': content}),
      );

      print('📡 [MESSAGE_SERVICE] Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SendMessageResponse.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        _handleApiError(errorData, 'Erreur lors de la mise à jour du message');
        throw MessageException('Erreur inattendue');
      }
    } catch (e) {
      print('❌ [MESSAGE_SERVICE] Exception: $e');
      if (e is MessageException) {
        rethrow;
      }
      throw MessageException('Erreur de connexion: ${e.toString()}');
    }
  }

  // ✅ MARQUER TOUS LES MESSAGES COMME LUS
  Future<MarkAsReadResponse> markAllAsRead(int partnerId) async {
    try {
      print('🔄 [MESSAGE_SERVICE] Marquage messages comme lus avec utilisateur $partnerId');

      if (!await _isAuthenticated()) {
        throw MessageException('Vous devez être connecté pour marquer les messages comme lus');
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/api/messages/read/all/$partnerId');
      final headers = await _getAuthHeaders();

      final response = await http.patch(url, headers: headers);
      print('📡 [MESSAGE_SERVICE] Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MarkAsReadResponse.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        _handleApiError(errorData, 'Erreur lors du marquage des messages comme lus');
        throw MessageException('Erreur inattendue');
      }
    } catch (e) {
      print('❌ [MESSAGE_SERVICE] Exception: $e');
      if (e is MessageException) {
        rethrow;
      }
      throw MessageException('Erreur de connexion: ${e.toString()}');
    }
  }

  // 🔧 MÉTHODES DE TEST ET DEBUG

  Future<void> testDeleteMessage(int messageId) async {
    try {
      print('\n🧪 [TEST_DELETE] === TEST SUPPRESSION MESSAGE ===');
      print('   🆔 Message ID: $messageId');
      
      // Test de connectivité
      final headers = await _getAuthHeaders();
      print('   🔑 Headers disponibles: ${headers.keys.join(', ')}');
      
      // Test URL
      final testUrl = Uri.parse('${ApiConfig.baseUrl}/api/messages/$messageId');
      print('   🌐 URL de test: $testUrl');
      
      // Test DELETE
      try {
        final deleteResponse = await http.delete(testUrl, headers: headers);
        print('   📡 Test DELETE Status: ${deleteResponse.statusCode}');
        print('   📄 Test DELETE Body: ${deleteResponse.body}');
        
        if (deleteResponse.statusCode == 200) {
          print('   ✅ Suppression API réussie!');
        } else {
          print('   ⚠️ Suppression API échouée: ${deleteResponse.statusCode}');
        }
      } catch (e) {
        print('   ❌ Test DELETE échoué: $e');
      }
      
      print('🧪 [TEST_DELETE] === FIN TEST ===\n');
      
    } catch (e) {
      print('❌ [TEST_DELETE] Erreur générale: $e');
    }
  }

  Future<void> testConnection() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/messages/conversations');
      final headers = await _getAuthHeaders();
      
      print('🔧 [TEST] Test connexion: $url');
      print('🔧 [TEST] Headers: $headers');
      
      final response = await http.get(url, headers: headers);
      
      print('🔧 [TEST] Status: ${response.statusCode}');
      print('🔧 [TEST] Response: ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}');
      
    } catch (e) {
      print('❌ [TEST] Erreur connexion: $e');
    }
  }

  // 🔥 MÉTHODE DE TEST POUR LA SUPPRESSION
  Future<void> testDeleteMessageFlow(int messageId) async {
    try {
      print('\n🧪 [TEST_DELETE_FLOW] === TEST COMPLET SUPPRESSION ===');
      
      final currentUserId = await _getCurrentUserId();
      print('   👤 Current User ID: $currentUserId');
      
      // 1. Test de connectivité
      print('   🔌 Étape 1: Test connectivité...');
      await testConnection();
      
      // 2. Tester la suppression
      print('   🗑️ Étape 2: Test suppression pour moi...');
      try {
        await deleteMessageForMe(messageId);
        print('   ✅ Suppression API réussie');
      } catch (e) {
        print('   ❌ Erreur suppression API: $e');
        return;
      }
      
      print('🧪 [TEST_DELETE_FLOW] === FIN TEST ===\n');
      
    } catch (e) {
      print('❌ [TEST_DELETE_FLOW] Erreur générale: $e');
    }
  }

  // 🔥 MÉTHODE DE TEST POUR COMPARER AVEC LE WEB
  Future<void> testWebCompatibility(int messageId) async {
    print('\n🌐 [WEB_COMPAT] === TEST COMPATIBILITÉ WEB ===');
    
    try {
      // Test 1: Suppression pour moi (sans paramètre)
      print('   🧪 Test 1: Suppression pour moi (comme le web)');
      await deleteMessage(messageId, forEveryone: false);
      print('   ✅ Test 1: RÉUSSI');
      
      // Test 2: Suppression pour tous (avec paramètre)
      print('   🧪 Test 2: Suppression pour tous (comme le web)');
      await deleteMessage(messageId, forEveryone: true);
      print('   ✅ Test 2: RÉUSSI');
      
    } catch (e) {
      print('   ❌ Erreur test compatibilité: $e');
    }
    
    print('=======================================\n');
  }

  // 🔧 MÉTHODES UTILITAIRES

  Future<bool> hasExistingConversation(int partnerId) async {
    try {
      final conversations = await getConversations();
      return conversations.data.any((conv) => conv.partnerId == partnerId);
    } catch (e) {
      print('❌ [MESSAGE_SERVICE] Erreur vérification conversations: $e');
      return false;
    }
  }

  Future<void> setCurrentUserId(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_user_id', userId);
      print('✅ [MESSAGE_SERVICE] ID utilisateur sauvegardé: $userId');
    } catch (e) {
      print('❌ [MESSAGE_SERVICE] Erreur sauvegarde ID utilisateur: $e');
    }
  }

  bool validateMediaFile(File file) {
    try {
      if (!file.existsSync()) {
        print('❌ [VALIDATION] Fichier n\'existe pas');
        return false;
      }

      final sizeInBytes = file.lengthSync();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      if (sizeInMB > 10) {
        print('❌ [VALIDATION] Fichier trop volumineux: ${sizeInMB.toStringAsFixed(2)} MB');
        return false;
      }

      final extension = file.path.split('.').last.toLowerCase();
      final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'avi'];
      if (!allowedExtensions.contains(extension)) {
        print('❌ [VALIDATION] Extension non autorisée: $extension');
        return false;
      }

      print('✅ [VALIDATION] Fichier valide');
      return true;
    } catch (e) {
      print('❌ [VALIDATION] Erreur validation: $e');
      return false;
    }
  }

  // 🔧 MÉTHODES DE DIAGNOSTIC AVANCÉES

  Future<Map<String, dynamic>> diagnoseUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('current_user_id');
      final token = prefs.getString(_tokenKey);
      
      return {
        'userId': userId,
        'hasToken': token != null,
        'tokenPrefix': token?.substring(0, 10) ?? 'N/A',
        'isAuthenticated': await _isAuthenticated(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> diagnoseMessage(int messageId) async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse('${ApiConfig.baseUrl}/api/messages/with/1'); // Test endpoint
      
      final response = await http.get(url, headers: headers);
      
      return {
        'statusCode': response.statusCode,
        'responseLength': response.body.length,
        'hasAuth': headers.containsKey('Authorization'),
        'baseUrl': ApiConfig.baseUrl,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  // 🔥 MÉTHODE POUR SYNCHRONISER LES MESSAGES APRÈS UNE SUPPRESSION
  Future<void> refreshMessagesAfterDelete(int partnerId) async {
    try {
      print('🔄 [REFRESH_AFTER_DELETE] Synchronisation messages...');
      
      // Recharger les messages depuis le serveur
      final messagesResponse = await getMessages(partnerId);
      
      print('✅ [REFRESH_AFTER_DELETE] Messages synchronisés: ${messagesResponse.data.messages.length}');
      
    } catch (e) {
      print('❌ [REFRESH_AFTER_DELETE] Erreur synchronisation: $e');
    }
  }

  // 🔥 MÉTHODE UTILITAIRE POUR FILTRER LES MESSAGES SUPPRIMÉS
  List<Message> filterDeletedMessages(List<Message> messages, int currentUserId) {
    return messages.where((message) {
      // Ne pas afficher si supprimé pour l'utilisateur actuel
      if (message.senderId == currentUserId && message.deletedForSender) {
        return false;
      }
      if (message.receiverId == currentUserId && message.deletedForReceiver) {
        return false;
      }
      return true;
    }).toList();
  }
}