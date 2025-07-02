// lib/models/like_model.dart
enum ReactionType {
  LIKE,
  DISLIKE
}

class ProductLike {
  final int id;
  final int productId;
  final int userId;
  final ReactionType type;
  final DateTime createdAt;

  ProductLike({
    required this.id,
    required this.productId,
    required this.userId,
    required this.type,
    required this.createdAt,
  });

  factory ProductLike.fromJson(Map<String, dynamic> json) {
    return ProductLike(
      id: json['id'] ?? 0,
      productId: json['productId'] ?? 0,
      userId: json['userId'] ?? 0,
      type: _parseReactionType(json['type']),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'userId': userId,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static ReactionType _parseReactionType(String? type) {
    switch (type?.toUpperCase()) {
      case 'LIKE':
        return ReactionType.LIKE;
      case 'DISLIKE':
        return ReactionType.DISLIKE;
      default:
        return ReactionType.LIKE;
    }
  }
}

class LikesCount {
  final int likesCount;
  final int dislikesCount;

  LikesCount({
    required this.likesCount,
    required this.dislikesCount,
  });

  factory LikesCount.fromJson(Map<String, dynamic> json) {
    return LikesCount(
      likesCount: json['likesCount'] ?? 0,
      dislikesCount: json['dislikesCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'likesCount': likesCount,
      'dislikesCount': dislikesCount,
    };
  }

  // Factory pour créer à partir d'une liste de likes
  factory LikesCount.fromLikes(List<ProductLike> likes) {
    final likesCount = likes.where((like) => like.type == ReactionType.LIKE).length;
    final dislikesCount = likes.where((like) => like.type == ReactionType.DISLIKE).length;
    
    return LikesCount(
      likesCount: likesCount,
      dislikesCount: dislikesCount,
    );
  }

  @override
  String toString() {
    return 'LikesCount(likes: $likesCount, dislikes: $dislikesCount)';
  }
}

class UserReaction {
  final bool hasLiked;
  final bool hasDisliked;

  UserReaction({
    required this.hasLiked,
    required this.hasDisliked,
  });

  factory UserReaction.fromJson(Map<String, dynamic> json) {
    return UserReaction(
      hasLiked: json['hasLiked'] ?? false,
      hasDisliked: json['hasDisliked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hasLiked': hasLiked,
      'hasDisliked': hasDisliked,
    };
  }

  // État par défaut (non connecté)
  factory UserReaction.defaultState() {
    return UserReaction(
      hasLiked: false,
      hasDisliked: false,
    );
  }

  @override
  String toString() {
    return 'UserReaction(hasLiked: $hasLiked, hasDisliked: $hasDisliked)';
  }
}

class LikeResponse {
  final String message;
  final String action;
  final int likesCount;
  final int dislikesCount;

  LikeResponse({
    required this.message,
    required this.action,
    required this.likesCount,
    required this.dislikesCount,
  });

  factory LikeResponse.fromJson(Map<String, dynamic> json) {
    return LikeResponse(
      message: json['message'] ?? '',
      action: json['action'] ?? '',
      likesCount: json['likesCount'] ?? 0,
      dislikesCount: json['dislikesCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'action': action,
      'likesCount': likesCount,
      'dislikesCount': dislikesCount,
    };
  }

  @override
  String toString() {
    return 'LikeResponse(message: $message, action: $action, likes: $likesCount, dislikes: $dislikesCount)';
  }
}

// Exception personnalisée pour les erreurs de likes
class LikeException implements Exception {
  final String message;
  final String? code;

  LikeException(this.message, {this.code});

  @override
  String toString() {
    return 'LikeException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}