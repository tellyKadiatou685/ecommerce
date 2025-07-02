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
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? data; // Données supplémentaires (orderId, etc.)

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.data,
  });

  // 🏭 FACTORY DEPUIS JSON
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: _parseNotificationType(json['type']),
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      data: json['data'],
    );
  }

  // 🔄 CONVERSION VERS JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'data': data,
    };
  }

  // 🆕 COPIE AVEC MODIFICATIONS
  AppNotification copyWith({
    int? id,
    String? title,
    String? message,
    NotificationType? type,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      data: data ?? this.data,
    );
  }

  // 📊 GETTERS UTILITAIRES
  
  /// Obtenir l'icône basée sur le type
  IconData get icon {
    switch (type) {
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
    switch (type) {
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

  @override
  String toString() {
    return 'AppNotification(id: $id, title: $title, type: $type, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // 🔧 MÉTHODE HELPER POUR PARSER LE TYPE
  static NotificationType _parseNotificationType(String? typeString) {
    switch (typeString?.toLowerCase()) {
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
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }
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