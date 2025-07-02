// lib/services/notification_service.dart - SUPPRESSION CORRIGÉE
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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

  // 📡 GETTERS
  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
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

  /// 📥 RÉCUPÉRER TOUTES LES NOTIFICATIONS (VERSION TEST)
  Future<List<AppNotification>> getNotifications({bool forceRefresh = false}) async {
    if (_notifications.isNotEmpty && !forceRefresh) {
      return _notifications;
    }

    try {
      _setLoading(true);
      _setError(null);

      // 🧪 SIMULER UN APPEL API AVEC DES DONNÉES DE TEST
      await Future.delayed(const Duration(seconds: 1));

      _notifications = [
        AppNotification(
          id: 1,
          title: 'Commande confirmée',
          message: 'Votre commande #ORD-2024-001 a été confirmée par le marchand Boutique Diallo.',
          type: NotificationType.order,
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
          updatedAt: DateTime.now(),
          data: {'order_id': 'ORD-2024-001'},
        ),
        AppNotification(
          id: 2,
          title: 'Nouveau message',
          message: 'Vous avez reçu un nouveau message de Marie Thiam concernant votre commande.',
          type: NotificationType.message,
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          updatedAt: DateTime.now(),
          data: {'conversation_id': 123},
        ),
        AppNotification(
          id: 3,
          title: 'Livraison en cours',
          message: 'Votre commande #ORD-2024-002 est en cours de livraison. Suivez-la en temps réel.',
          type: NotificationType.shipping,
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          updatedAt: DateTime.now(),
          data: {'order_id': 'ORD-2024-002', 'tracking_code': 'TRK001'},
        ),
        AppNotification(
          id: 4,
          title: 'Paiement reçu',
          message: 'Votre paiement de 125,000 FCFA pour la commande #ORD-2024-003 a été confirmé.',
          type: NotificationType.payment,
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          updatedAt: DateTime.now(),
          data: {'amount': 125000, 'order_id': 'ORD-2024-003'},
        ),
        AppNotification(
          id: 5,
          title: 'Offre spéciale - 20% de réduction !',
          message: 'Profitez de 20% de réduction sur tous les produits électroniques jusqu\'à dimanche.',
          type: NotificationType.promotion,
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now(),
          data: {'discount': 20, 'category': 'electronics', 'expires_at': '2024-12-31'},
        ),
        AppNotification(
          id: 6,
          title: 'Mise à jour système',
          message: 'L\'application a été mise à jour avec de nouvelles fonctionnalités. Découvrez-les !',
          type: NotificationType.system,
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          updatedAt: DateTime.now(),
          data: {'version': '2.1.0'},
        ),
        AppNotification(
          id: 7,
          title: 'Commande expédiée',
          message: 'Votre commande #ORD-2024-004 a été expédiée et arrivera demain matin.',
          type: NotificationType.shipping,
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
          updatedAt: DateTime.now(),
          data: {'order_id': 'ORD-2024-004', 'estimated_delivery': '2024-12-25'},
        ),
      ];
      
      // Trier par date de création (plus récent en premier)
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _notificationsController.add(_notifications);
      notifyListeners();
      
      print('✅ [NOTIFICATION_SERVICE] ${_notifications.length} notifications de test chargées');
      return _notifications;

    } catch (e) {
      print('💥 [NOTIFICATION_SERVICE] Erreur lors du chargement des données de test: $e');
      final error = NotificationException('Erreur lors du chargement: ${e.toString()}', 'TEST_ERROR');
      _setError(error.message);
      throw error;
    } finally {
      _setLoading(false);
    }
  }

  /// ✅ MARQUER UNE NOTIFICATION COMME LUE (VERSION LOCALE)
  Future<void> markAsRead(int notificationId) async {
    try {
      print('🔄 [NOTIFICATION_SERVICE] Marking notification $notificationId as read (LOCAL)');
      
      // 🔧 MISE À JOUR LOCALE POUR LES DONNÉES DE TEST
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _notificationsController.add(_notifications);
        notifyListeners();
        print('✅ [NOTIFICATION_SERVICE] Notification $notificationId marquée comme lue localement');
      } else {
        print('❌ [NOTIFICATION_SERVICE] Notification $notificationId non trouvée');
      }
    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur mark as read: $e');
      throw NotificationException('Erreur lors du marquage: ${e.toString()}', 'MARK_READ_ERROR');
    }
  }

  /// ✅ MARQUER TOUTES LES NOTIFICATIONS COMME LUES (VERSION LOCALE)
  Future<void> markAllAsRead() async {
    try {
      _setLoading(true);
      
      print('🔄 [NOTIFICATION_SERVICE] Marking all notifications as read (LOCAL)');
      
      // 🔧 MISE À JOUR LOCALE
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _notificationsController.add(_notifications);
      notifyListeners();
      
      print('✅ [NOTIFICATION_SERVICE] Toutes les notifications marquées comme lues');
    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur mark all as read: $e');
      throw NotificationException('Erreur lors du marquage: ${e.toString()}', 'MARK_ALL_READ_ERROR');
    } finally {
      _setLoading(false);
    }
  }

  /// 🗑️ SUPPRIMER UNE NOTIFICATION (VERSION LOCALE CORRIGÉE)
  Future<void> deleteNotification(int notificationId) async {
    try {
      print('🗑️ [NOTIFICATION_SERVICE] Deleting notification $notificationId (LOCAL)');
      
      // 🔧 SUPPRESSION LOCALE POUR LES DONNÉES DE TEST
      final initialLength = _notifications.length;
      _notifications.removeWhere((n) => n.id == notificationId);
      
      if (_notifications.length < initialLength) {
        _notificationsController.add(_notifications);
        notifyListeners();
        print('✅ [NOTIFICATION_SERVICE] Notification $notificationId supprimée localement');
      } else {
        print('❌ [NOTIFICATION_SERVICE] Notification $notificationId non trouvée pour suppression');
        throw NotificationException('Notification non trouvée', 'NOT_FOUND');
      }
    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur delete: $e');
      if (e is! NotificationException) {
        throw NotificationException('Erreur lors de la suppression: ${e.toString()}', 'DELETE_ERROR');
      }
      rethrow;
    }
  }

  /// 🗑️ SUPPRIMER TOUTES LES NOTIFICATIONS (VERSION LOCALE CORRIGÉE)
  Future<void> deleteAllNotifications() async {
    try {
      _setLoading(true);
      
      print('🗑️ [NOTIFICATION_SERVICE] Deleting all notifications (LOCAL)');
      
      // 🔧 SUPPRESSION LOCALE
      _notifications.clear();
      _notificationsController.add(_notifications);
      notifyListeners();
      
      print('✅ [NOTIFICATION_SERVICE] Toutes les notifications supprimées');
    } catch (e) {
      print('❌ [NOTIFICATION_SERVICE] Erreur delete all: $e');
      throw NotificationException('Erreur lors de la suppression: ${e.toString()}', 'DELETE_ALL_ERROR');
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
    return _notifications.where((n) => n.type == type).toList();
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
    _notificationsController.close();
    super.dispose();
  }

  /// 🔄 RÉINITIALISER LE SERVICE
  void reset() {
    _notifications.clear();
    _isLoading = false;
    _errorMessage = null;
    _notificationsController.add(_notifications);
    notifyListeners();
  }

  /// 📊 OBTENIR LES STATISTIQUES
  Map<String, int> getNotificationStats() {
    final stats = <String, int>{};
    
    for (final type in NotificationType.values) {
      stats[type.name] = _notifications.where((n) => n.type == type).length;
    }
    
    stats['total'] = totalCount;
    stats['unread'] = unreadCount;
    stats['recent'] = recentNotifications.length;
    
    return stats;
  }
}