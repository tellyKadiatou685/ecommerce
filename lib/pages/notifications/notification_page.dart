// lib/pages/notifications/notification_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  String _selectedFilter = 'Toutes';

  @override

  void initState() {
    super.initState();
    _initializeNotifications();
    _setupNotificationsListener();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadNotifications();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await _notificationService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _errorMessage = null;
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  void _setupNotificationsListener() {
    _notificationsSubscription = _notificationService.notificationsStream.listen(
      (notifications) {
        if (mounted) {
          setState(() {
            _notifications = notifications;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = _getErrorMessage(error);
          });
        }
      },
    );
  }

  String _getErrorMessage(dynamic error) {
    if (error is NotificationException) {
      switch (error.code) {
        case 'NO_TOKEN':
          return 'Vous devez être connecté pour voir vos notifications';
        case 'TIMEOUT':
          return 'Le serveur ne répond pas. Réessayez plus tard.';
        case 'NETWORK_ERROR':
          return 'Pas de connexion internet. Vérifiez votre réseau.';
        default:
          return error.message;
      }
    }
    return 'Une erreur inattendue est survenue';
  }

  List<AppNotification> get _filteredNotifications {
    switch (_selectedFilter) {
      case 'Non lues':
        return _notifications.where((n) => !n.isRead).toList();
      case 'Commandes':
        return _notifications.where((n) => n.type == NotificationType.order).toList();
      case 'Messages':
        return _notifications.where((n) => n.type == NotificationType.message).toList();
      case 'Livraisons':
        return _notifications.where((n) => n.type == NotificationType.shipping).toList();
      case 'Promotions':
        return _notifications.where((n) => n.type == NotificationType.promotion).toList();
      default: // Toutes
        return _notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final unreadCount = _notificationService.unreadCount;
    
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios, color: AppColors.gray800),
      ),
      title: Row(
        children: [
          Text(
            'Notifications',
            style: AppTextStyles.heading1.copyWith(
              fontSize: 20,
              color: AppColors.gray800,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      centerTitle: false,
      actions: [
        if (unreadCount > 0)
          IconButton(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all, color: AppColors.gray600),
            tooltip: 'Tout marquer comme lu',
          ),
        IconButton(
          onPressed: _showFilterOptions,
          icon: const Icon(Icons.filter_list, color: AppColors.gray600),
          tooltip: 'Filtrer',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.gray600),
          onSelected: (value) {
            if (value == 'delete_all') {
              _showDeleteAllConfirmation();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete_all',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Supprimer tout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    
    return _buildNotificationsList();
  }

  Widget _buildNotificationsList() {
    final notifications = _filteredNotifications;

    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      color: AppColors.primaryOrange,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          return _buildNotificationCard(notifications[index], index);
        },
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: notification.isRead 
              ? AppColors.white 
              : AppColors.primaryOrange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead 
                ? AppColors.gray200 
                : AppColors.primaryOrange.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onNotificationTap(notification),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationIcon(notification),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: AppTextStyles.heading1.copyWith(
                                  fontSize: 16,
                                  color: AppColors.gray800,
                                  fontWeight: notification.isRead 
                                      ? FontWeight.w500 
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                if (!notification.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryOrange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    size: 16,
                                    color: AppColors.gray500,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'mark_read' && !notification.isRead) {
                                      _markAsRead(notification.id);
                                    } else if (value == 'delete') {
                                      _showDeleteConfirmation(notification);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (!notification.isRead)
                                      const PopupMenuItem(
                                        value: 'mark_read',
                                        child: Row(
                                          children: [
                                            Icon(Icons.done, size: 16),
                                            SizedBox(width: 8),
                                            Text('Marquer comme lu'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red, size: 16),
                                          SizedBox(width: 8),
                                          Text('Supprimer'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.gray600,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              notification.formattedTime,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.gray500,
                              ),
                            ),
                            _buildNotificationTypeBadge(notification.type),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(AppNotification notification) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: notification.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.color.withOpacity(0.2),
        ),
      ),
      child: Icon(
        notification.icon,
        color: notification.color,
        size: 24,
      ),
    );
  }

  Widget _buildNotificationTypeBadge(NotificationType type) {
    String label;
    Color color;

    switch (type) {
      case NotificationType.order:
        label = 'Commande';
        color = Colors.green;
        break;
      case NotificationType.message:
        label = 'Message';
        color = Colors.blue;
        break;
      case NotificationType.payment:
        label = 'Paiement';
        color = Colors.orange;
        break;
      case NotificationType.shipping:
        label = 'Livraison';
        color = Colors.purple;
        break;
      case NotificationType.promotion:
        label = 'Promotion';
        color = Colors.pink;
        break;
      case NotificationType.system:
        label = 'Système';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_selectedFilter) {
      case 'Non lues':
        message = 'Aucune notification non lue';
        icon = Icons.mark_email_read;
        break;
      case 'Commandes':
        message = 'Aucune notification de commande';
        icon = Icons.shopping_bag_outlined;
        break;
      case 'Messages':
        message = 'Aucune notification de message';
        icon = Icons.message_outlined;
        break;
      default:
        message = 'Aucune notification';
        icon = Icons.notifications_none;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: AppColors.gray300,
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: AppTextStyles.heading1.copyWith(
              fontSize: 20,
              color: AppColors.gray600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos notifications apparaîtront ici',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryOrange,
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Chargement des notifications...',
            style: TextStyle(
              color: AppColors.gray600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur',
              style: AppTextStyles.heading1.copyWith(
                fontSize: 20,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.gray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _initializeNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Réessayer',
                style: AppTextStyles.buttonText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 ACTIONS

  Future<void> _refreshNotifications() async {
    try {
      await _notificationService.refreshNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications actualisées'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'actualisation: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onNotificationTap(AppNotification notification) {
    // Marquer comme lu si pas encore lu
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    // Naviguer selon le type de notification
    switch (notification.type) {
      case NotificationType.order:
        // Naviguer vers les commandes
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation vers les commandes'),
            backgroundColor: AppColors.info,
          ),
        );
        break;
      case NotificationType.message:
        // Naviguer vers les messages
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation vers les messages'),
            backgroundColor: AppColors.info,
          ),
        );
        break;
      case NotificationType.shipping:
        // Naviguer vers le suivi
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation vers le suivi'),
            backgroundColor: AppColors.info,
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications marquées comme lues'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtrer les notifications',
              style: AppTextStyles.heading1.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ...[
              'Toutes',
              'Non lues',
              'Commandes',
              'Messages',
              'Livraisons',
              'Promotions',
            ].map((filter) => _buildFilterOption(filter)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String filter) {
    final isSelected = _selectedFilter == filter;
    
    return ListTile(
      leading: Icon(
        _getFilterIcon(filter),
        color: isSelected ? AppColors.primaryOrange : AppColors.gray600,
      ),
      title: Text(
        filter,
        style: TextStyle(
          color: isSelected ? AppColors.primaryOrange : AppColors.gray800,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primaryOrange)
          : null,
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
        Navigator.pop(context);
      },
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Toutes':
        return Icons.notifications;
      case 'Non lues':
        return Icons.circle;
      case 'Commandes':
        return Icons.shopping_bag;
      case 'Messages':
        return Icons.message;
      case 'Livraisons':
        return Icons.local_shipping;
      case 'Promotions':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  void _showDeleteConfirmation(AppNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la notification'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette notification ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNotification(notification.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer toutes les notifications'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer toutes les notifications ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllNotifications();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Supprimer tout'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(int notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification supprimée'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllNotifications() async {
    try {
      await _notificationService.deleteAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications supprimées'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}