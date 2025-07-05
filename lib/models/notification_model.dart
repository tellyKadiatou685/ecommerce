// lib/models/notification_model.dart
import 'package:flutter/material.dart';

enum NotificationType {
  order,
  message,
  payment,
  shipping,
  system,
  promotion
}

class AppNotification {
  final int id;
  final int userId;
  final String type; // On garde String pour correspondre au backend
  final String message;
  final String? actionUrl;
  final String? resourceId;
  final String? resourceType;
  final int priority;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    this.actionUrl,
    this.resourceId,
    this.resourceType,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
  });

  // 🏭 FACTORY DEPUIS JSON (Backend)
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      type: json['type'] ?? 'system',
      message: json['message'] ?? '',
      actionUrl: json['actionUrl'],
      resourceId: json['resourceId']?.toString(),
      resourceType: json['resourceType'],
      priority: json['priority'] ?? 0,
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
    );
  }

  // 🔄 CONVERSION VERS JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'message': message,
      'actionUrl': actionUrl,
      'resourceId': resourceId,
      'resourceType': resourceType,
      'priority': priority,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  // 🆕 COPIE AVEC MODIFICATIONS
  AppNotification copyWith({
    int? id,
    int? userId,
    String? type,
    String? message,
    String? actionUrl,
    String? resourceId,
    String? resourceType,
    int? priority,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      message: message ?? this.message,
      actionUrl: actionUrl ?? this.actionUrl,
      resourceId: resourceId ?? this.resourceId,
      resourceType: resourceType ?? this.resourceType,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // 📊 GETTERS UTILITAIRES
  
  /// Convertir le type string en enum
  NotificationType get notificationType {
    switch (type.toLowerCase()) {
      case 'order':
        return NotificationType.order;
      case 'message':
        return NotificationType.message;
      case 'payment':
        return NotificationType.payment;
      case 'shipping':
        return NotificationType.shipping;
      case 'promotion':
        return NotificationType.promotion;
      case 'system':
      default:
        return NotificationType.system;
    }
  }

  /// Titre basé sur le type de notification
  String get title {
    switch (notificationType) {
      case NotificationType.order:
        return 'Commande';
      case NotificationType.message:
        return 'Message';
      case NotificationType.payment:
        return 'Paiement';
      case NotificationType.shipping:
        return 'Livraison';
      case NotificationType.promotion:
        return 'Promotion';
      case NotificationType.system:
        return 'Système';
    }
  }

  /// Obtenir l'icône basée sur le type
  IconData get icon {
    switch (notificationType) {
      case NotificationType.order:
        return Icons.shopping_bag;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.shipping:
        return Icons.local_shipping;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.system:
        return Icons.notifications;
    }
  }

  /// Obtenir la couleur basée sur le type
  Color get color {
    switch (notificationType) {
      case NotificationType.order:
        return Colors.green;
      case NotificationType.message:
        return Colors.blue;
      case NotificationType.payment:
        return Colors.orange;
      case NotificationType.shipping:
        return Colors.purple;
      case NotificationType.promotion:
        return Colors.pink;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  /// Formater le temps écoulé depuis la création
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min';
    } else {
      return 'Maintenant';
    }
  }

  /// Vérifier si la notification est récente (moins de 24h)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inHours < 24;
  }

  /// Vérifier si la notification a expiré
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, type: $type, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// 📋 CLASSE POUR LES RÉPONSES D'API
class NotificationsResponse {
  final List<AppNotification> notifications;
  final int total;
  final int unreadCount;

  NotificationsResponse({
    required this.notifications,
    required this.total,
    required this.unreadCount,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    return NotificationsResponse(
      notifications: (json['notifications'] as List<dynamic>?)
          ?.map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      total: json['total'] ?? 0,
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

// ⚠️ EXCEPTION POUR LES NOTIFICATIONS
class NotificationException implements Exception {
  final String message;
  final String code;

  NotificationException(this.message, this.code);

  @override
  String toString() => 'NotificationException($code): $message';
}