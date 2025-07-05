// lib/services/notification_service.dart - SERVICE FINAL CORRIGÉ
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/notification_model.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 📊 ÉTAT LOCAL
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // 🔄 STREAM CONTROLLER POUR LES MISES À JOUR EN TEMPS RÉEL
  final StreamController<List<AppNotification>> _notificationsController = 
      StreamController<List<AppNotification>>.broadcast();

  // 🔌 WEBSOCKET NATIF
  WebSocketChannel? _websocketChannel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // 📡 GETTERS
  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _isConnected;
  
  /// Stream des notifications pour écouter les changements
  Stream<List<AppNotification>> get notificationsStream => _notificationsController.stream;
  
  /// Nombre total de notifications
  int get totalCount => _notifications.length;
  
  /// Nombre de notifications non lues
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  
  /// Notifications non lues seulement
  List<AppNotification> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();

  /// Notifications récentes (moins de 24h)
  List<AppNotification> get recentNotifications => 
      _notifications.where((n) => n.isRecent).toList();

  // 🚀 INITIALISATION DU SERVICE
  Future<void> initialize() async {
    print('🚀 [NOTIFICATION_SERVICE] Initialisation avec WebSocket temps réel...');
    await getNotifications();
    await _connectWebSocket();
  }

  // 🔌 CONNEXION WEBSOCKET NATIF
  Future<void> _connectWebSocket() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        print('❌ [NOTIFICATION_SERVICE] Pas de token disponible pour WebSocket');
        return;
      }

      // Construire l'URL WebSocket avec authentification
      final wsUrl = '${ApiConfig.socketUrl}/ws?token=$token';
      
      print('🔌 [NOTIFICATION_SERVICE] Connexion WebSocket à: $wsUrl');
      
      _websocketChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Écouter les messages WebSocket
      _websocketChannel!.stream.listen(
        (message) {
          print('📨 [NOTIFICATION_SERVICE] Message WebSocket reçu: $message');
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('❌ [NOTIFICATION_SERVICE] Erreur WebSocket: $error');
          _handleWebSocketError(error);
        },
        onDone: () {
          print('❌ [NOTIFICATION_SERVICE] WebSocket fermé');
          _handleWebSocketDisconnection();
        },
      );

      // Confirmer la connexion
      _isConnected = true;
      _reconnectAttempts = 0;
      notifyListeners();
      print('✅ [NOTIFICATION_SERVICE] WebSocket connecté avec succès');

    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur connexion WebSocket: $e');
      _handleWebSocketError(e);
    }
  }

  // 📨 GÉRER LES MESSAGES WEBSOCKET
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message);
      final type = data['type'];
      final payload = data['payload'];

      switch (type) {
        case 'new_notification':
          print('🔔 [NOTIFICATION_SERVICE] Nouvelle notification temps réel');
          final notification = AppNotification.fromJson(payload);
          _addNewNotification(notification);
          break;

        case 'notification_updated':
          print('🔄 [NOTIFICATION_SERVICE] Notification mise à jour temps réel');
          final notification = AppNotification.fromJson(payload);
          _updateNotification(notification);
          break;

        case 'notification_deleted':
          print('🗑️ [NOTIFICATION_SERVICE] Notification supprimée temps réel');
          final notificationId = payload['id'];
          _removeNotification(notificationId);
          break;

        case 'notifications_bulk_updated':
          print('🔄 [NOTIFICATION_SERVICE] Mise à jour en masse des notifications');
          // Recharger toutes les notifications
          getNotifications(forceRefresh: true);
          break;

        case 'notifications_bulk_deleted':
          print('🗑️ [NOTIFICATION_SERVICE] Suppression en masse des notifications');
          _notifications.clear();
          _notificationsController.add(_notifications);
          notifyListeners();
          break;

        case 'ping':
          // Répondre au ping pour maintenir la connexion
          _websocketChannel?.sink.add(json.encode({'type': 'pong'}));
          break;

        default:
          print('🤔 [NOTIFICATION_SERVICE] Type de message inconnu: $type');
      }
    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur parsing message WebSocket: $e');
    }
  }

  // ❌ GÉRER LES ERREURS WEBSOCKET
  void _handleWebSocketError(dynamic error) {
    _isConnected = false;
    notifyListeners();
    
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    } else {
      print('❌ [NOTIFICATION_SERVICE] Nombre maximum de tentatives de reconnexion atteint');
    }
  }

  // 🔄 GÉRER LA DÉCONNEXION WEBSOCKET
  void _handleWebSocketDisconnection() {
    _isConnected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  // ⏰ PROGRAMMER UNE RECONNEXION
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    
    final delay = Duration(seconds: 2 * (_reconnectAttempts + 1)); // Délai progressif
    _reconnectAttempts++;
    
    print('🔄 [NOTIFICATION_SERVICE] Reconnexion dans ${delay.inSeconds}s (tentative $_reconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      _connectWebSocket();
    });
  }

  // 📥 RÉCUPÉRER TOUTES LES NOTIFICATIONS DEPUIS L'API
  Future<List<AppNotification>> getNotifications({bool forceRefresh = false}) async {
    if (_notifications.isNotEmpty && !forceRefresh) {
      return _notifications;
    }

    try {
      _setLoading(true);
      _setError(null);

      final token = await AuthService().getToken();
      if (token == null) {
        throw NotificationException('Token d\'authentification manquant', 'NO_TOKEN');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> notificationsJson = json.decode(response.body);
        _notifications = notificationsJson
            .map((json) => AppNotification.fromJson(json))
            .toList();
        
        // Trier par date de création (plus récent en premier)
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        _notificationsController.add(_notifications);
        notifyListeners();
        
        print('✅ [NOTIFICATION_SERVICE] ${_notifications.length} notifications chargées depuis l\'API');
        return _notifications;
      } else {
        final errorMessage = _getErrorMessage(response.statusCode, response.body);
        throw NotificationException(errorMessage, 'API_ERROR');
      }

    } on TimeoutException {
      final error = NotificationException('Délai d\'attente dépassé', 'TIMEOUT');
      _setError(error.message);
      throw error;
    } catch (e) {
      print('💥 [NOTIFICATION_SERVICE] Erreur lors du chargement: $e');
      if (e is! NotificationException) {
        final error = NotificationException('Erreur lors du chargement: ${e.toString()}', 'NETWORK_ERROR');
        _setError(error.message);
        throw error;
      }
      _setError(e.message);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// ✅ MARQUER UNE NOTIFICATION COMME LUE
  Future<void> markAsRead(int notificationId) async {
    try {
      print('🔄 [NOTIFICATION_SERVICE] Marking notification $notificationId as read');
      
      final token = await AuthService().getToken();
      if (token == null) {
        throw NotificationException('Token d\'authentification manquant', 'NO_TOKEN');
      }

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/notifications/$notificationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final updatedNotification = AppNotification.fromJson(json.decode(response.body));
        _updateNotificationLocally(updatedNotification);
        print('✅ [NOTIFICATION_SERVICE] Notification $notificationId marquée comme lue');
      } else {
        final errorMessage = _getErrorMessage(response.statusCode, response.body);
        throw NotificationException(errorMessage, 'MARK_READ_ERROR');
      }
    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur mark as read: $e');
      if (e is! NotificationException) {
        throw NotificationException('Erreur lors du marquage: ${e.toString()}', 'MARK_READ_ERROR');
      }
      rethrow;
    }
  }

  /// ✅ MARQUER TOUTES LES NOTIFICATIONS COMME LUES
  Future<void> markAllAsRead() async {
    try {
      _setLoading(true);
      
      print('🔄 [NOTIFICATION_SERVICE] Marking all notifications as read');
      
      final token = await AuthService().getToken();
      if (token == null) {
        throw NotificationException('Token d\'authentification manquant', 'NO_TOKEN');
      }

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Mettre à jour localement toutes les notifications
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        _notificationsController.add(_notifications);
        notifyListeners();
        
        print('✅ [NOTIFICATION_SERVICE] Toutes les notifications marquées comme lues');
      } else {
        final errorMessage = _getErrorMessage(response.statusCode, response.body);
        throw NotificationException(errorMessage, 'MARK_ALL_READ_ERROR');
      }
    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur mark all as read: $e');
      if (e is! NotificationException) {
        throw NotificationException('Erreur lors du marquage: ${e.toString()}', 'MARK_ALL_READ_ERROR');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 🗑️ SUPPRIMER UNE NOTIFICATION
  Future<void> deleteNotification(int notificationId) async {
    try {
      print('🗑️ [NOTIFICATION_SERVICE] Deleting notification $notificationId');
      
      final token = await AuthService().getToken();
      if (token == null) {
        throw NotificationException('Token d\'authentification manquant', 'NO_TOKEN');
      }

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/notifications/$notificationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _removeNotificationLocally(notificationId);
        print('✅ [NOTIFICATION_SERVICE] Notification $notificationId supprimée');
      } else {
        final errorMessage = _getErrorMessage(response.statusCode, response.body);
        throw NotificationException(errorMessage, 'DELETE_ERROR');
      }
    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur delete: $e');
      if (e is! NotificationException) {
        throw NotificationException('Erreur lors de la suppression: ${e.toString()}', 'DELETE_ERROR');
      }
      rethrow;
    }
  }

  /// 🗑️ SUPPRIMER TOUTES LES NOTIFICATIONS
  Future<void> deleteAllNotifications() async {
    try {
      _setLoading(true);
      
      print('🗑️ [NOTIFICATION_SERVICE] Deleting all notifications');
      
      final token = await AuthService().getToken();
      if (token == null) {
        throw NotificationException('Token d\'authentification manquant', 'NO_TOKEN');
      }

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _notifications.clear();
        _notificationsController.add(_notifications);
        notifyListeners();
        
        print('✅ [NOTIFICATION_SERVICE] Toutes les notifications supprimées');
      } else {
        final errorMessage = _getErrorMessage(response.statusCode, response.body);
        throw NotificationException(errorMessage, 'DELETE_ALL_ERROR');
      }
    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur delete all: $e');
      if (e is! NotificationException) {
        throw NotificationException('Erreur lors de la suppression: ${e.toString()}', 'DELETE_ALL_ERROR');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 🔄 ACTUALISER LES NOTIFICATIONS
  Future<void> refreshNotifications() async {
    print('🔄 [NOTIFICATION_SERVICE] Refreshing notifications');
    await getNotifications(forceRefresh: true);
  }

  /// 📋 FILTRER LES NOTIFICATIONS PAR TYPE
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.notificationType == type).toList();
  }

  /// 🔍 CHERCHER DANS LES NOTIFICATIONS
  List<AppNotification> searchNotifications(String query) {
    if (query.isEmpty) return _notifications;
    
    final lowerQuery = query.toLowerCase();
    return _notifications.where((n) => 
      n.title.toLowerCase().contains(lowerQuery) ||
      n.message.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  // 🛠️ MÉTHODES UTILITAIRES PRIVÉES

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _addNewNotification(AppNotification notification) {
    _notifications.insert(0, notification); // Ajouter en première position
    _notificationsController.add(_notifications);
    notifyListeners();
  }

  void _updateNotification(AppNotification notification) {
    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index != -1) {
      _notifications[index] = notification;
      _notificationsController.add(_notifications);
      notifyListeners();
    }
  }

  void _updateNotificationLocally(AppNotification notification) {
    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index != -1) {
      _notifications[index] = notification;
      _notificationsController.add(_notifications);
      notifyListeners();
    }
  }

  void _removeNotification(int notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notificationsController.add(_notifications);
    notifyListeners();
  }

  void _removeNotificationLocally(int notificationId) {
    final initialLength = _notifications.length;
    _notifications.removeWhere((n) => n.id == notificationId);
    
    if (_notifications.length < initialLength) {
      _notificationsController.add(_notifications);
      notifyListeners();
    }
  }

  String _getErrorMessage(int statusCode, String responseBody) {
    switch (statusCode) {
      case 401:
        return 'Session expirée. Veuillez vous reconnecter.';
      case 403:
        return 'Accès non autorisé aux notifications.';
      case 404:
        return 'Notification non trouvée.';
      case 500:
        return 'Erreur serveur. Réessayez plus tard.';
      default:
        try {
          final data = json.decode(responseBody);
          return data['message'] ?? 'Erreur inconnue';
        } catch (e) {
          return 'Erreur de communication avec le serveur';
        }
    }
  }

  // 🧹 NETTOYAGE
  @override
  void dispose() {
    _websocketChannel?.sink.close(status.goingAway);
    _reconnectTimer?.cancel();
    _notificationsController.close();
    super.dispose();
  }

  /// 🔄 RÉINITIALISER LE SERVICE
  void reset() {
    _notifications.clear();
    _isLoading = false;
    _errorMessage = null;
    _websocketChannel?.sink.close(status.goingAway);
    _reconnectTimer?.cancel();
    _notificationsController.add(_notifications);
    notifyListeners();
  }

  /// 📊 OBTENIR LES STATISTIQUES
  Map<String, int> getNotificationStats() {
    final stats = <String, int>{};
    
    for (final type in NotificationType.values) {
      stats[type.name] = _notifications.where((n) => n.notificationType == type).length;
    }
    
    stats['total'] = totalCount;
    stats['unread'] = unreadCount;
    stats['recent'] = recentNotifications.length;
    
    return stats;
  }

  /// 🔌 DÉCONNECTER LE WEBSOCKET
  void disconnectSocket() {
    _websocketChannel?.sink.close(status.goingAway);
    _isConnected = false;
    notifyListeners();
  }

  /// 🔌 RECONNECTER LE WEBSOCKET
  Future<void> reconnectSocket() async {
    print('🔄 [NOTIFICATION_SERVICE] Reconnexion manuelle du WebSocket...');
    _reconnectAttempts = 0;
    await _connectWebSocket();
  }
}