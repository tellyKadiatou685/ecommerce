// lib/models/comment_model.dart
import 'dart:convert';

/// Modèle pour un utilisateur dans les commentaires
class CommentUser {
  final int id;
  final String firstName;
  final String lastName;
  final String? photo;

  CommentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
  });

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    return CommentUser(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      photo: json['photo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'photo': photo,
    };
  }

  String get fullName => '$firstName $lastName';

  @override
  String toString() {
    return 'CommentUser(id: $id, name: $fullName, photo: $photo)';
  }
}

/// Modèle pour une réponse à un commentaire
class Reply {
  final int id;
  final int commentId;
  final int userId;
  final String reply;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CommentUser? user;

  Reply({
    required this.id,
    required this.commentId,
    required this.userId,
    required this.reply,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['id'] ?? 0,
      commentId: json['commentId'] ?? 0,
      userId: json['userId'] ?? 0,
      reply: json['reply'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      user: json['user'] != null ? CommentUser.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commentId': commentId,
      'userId': userId,
      'reply': reply,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'user': user?.toJson(),
    };
  }

  @override
  String toString() {
    return 'Reply(id: $id, commentId: $commentId, reply: $reply, user: ${user?.fullName})';
  }
}

/// Modèle pour un commentaire
class Comment {
  final int id;
  final int productId;
  final int userId;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CommentUser? user;
  final List<Reply> replies;

  Comment({
    required this.id,
    required this.productId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    List<Reply>? replies,
  }) : replies = replies ?? [];

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      productId: json['productId'] ?? 0,
      userId: json['userId'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      user: json['user'] != null ? CommentUser.fromJson(json['user']) : null,
      replies: (json['replies'] as List<dynamic>?)
          ?.map((reply) => Reply.fromJson(reply))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'userId': userId,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'user': user?.toJson(),
      'replies': replies.map((reply) => reply.toJson()).toList(),
    };
  }

  /// Crée une copie du commentaire avec de nouvelles réponses
  Comment copyWithReplies(List<Reply> newReplies) {
    return Comment(
      id: id,
      productId: productId,
      userId: userId,
      comment: comment,
      createdAt: createdAt,
      updatedAt: updatedAt,
      user: user,
      replies: newReplies,
    );
  }

  @override
  String toString() {
    return 'Comment(id: $id, productId: $productId, comment: $comment, user: ${user?.fullName}, replies: ${replies.length})';
  }
}

/// Modèle pour la pagination des commentaires
class CommentPagination {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  CommentPagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory CommentPagination.fromJson(Map<String, dynamic> json) {
    return CommentPagination(
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['totalPages'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'page': page,
      'limit': limit,
      'totalPages': totalPages,
    };
  }

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;

  @override
  String toString() {
    return 'CommentPagination(total: $total, page: $page/$totalPages, limit: $limit)';
  }
}

/// Modèle pour la réponse paginée des commentaires
class PaginatedComments {
  final List<Comment> comments;
  final CommentPagination pagination;

  PaginatedComments({
    required this.comments,
    required this.pagination,
  });

  factory PaginatedComments.fromJson(Map<String, dynamic> json) {
    return PaginatedComments(
      comments: (json['comments'] as List<dynamic>?)
          ?.map((comment) => Comment.fromJson(comment))
          .toList() ?? [],
      pagination: CommentPagination.fromJson(json['pagination'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comments': comments.map((comment) => comment.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }

  /// Combine avec d'autres commentaires paginés (pour le loadMore)
  PaginatedComments combineWith(PaginatedComments other) {
    return PaginatedComments(
      comments: [...comments, ...other.comments],
      pagination: other.pagination,
    );
  }

  @override
  String toString() {
    return 'PaginatedComments(comments: ${comments.length}, pagination: $pagination)';
  }
}

/// Modèle pour un nouveau commentaire à créer
class NewComment {
  final String comment;

  NewComment({required this.comment});

  Map<String, dynamic> toJson() {
    return {'comment': comment};
  }

  @override
  String toString() {
    return 'NewComment(comment: $comment)';
  }
}

/// Modèle pour une nouvelle réponse à créer
class NewReply {
  final String reply;

  NewReply({required this.reply});

  Map<String, dynamic> toJson() {
    return {'reply': reply};
  }

  @override
  String toString() {
    return 'NewReply(reply: $reply)';
  }
}

/// Modèle pour la réponse de l'API après ajout d'un commentaire
class CommentResponse {
  final String message;
  final Comment comment;

  CommentResponse({
    required this.message,
    required this.comment,
  });

  factory CommentResponse.fromJson(Map<String, dynamic> json) {
    return CommentResponse(
      message: json['message'] ?? '',
      comment: Comment.fromJson(json['comment'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'comment': comment.toJson(),
    };
  }

  @override
  String toString() {
    return 'CommentResponse(message: $message, comment: ${comment.id})';
  }
}

/// Modèle pour la réponse de l'API après ajout d'une réponse
class ReplyResponse {
  final String message;
  final Reply reply;

  ReplyResponse({
    required this.message,
    required this.reply,
  });

  factory ReplyResponse.fromJson(Map<String, dynamic> json) {
    return ReplyResponse(
      message: json['message'] ?? '',
      reply: Reply.fromJson(json['reply'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'reply': reply.toJson(),
    };
  }

  @override
  String toString() {
    return 'ReplyResponse(message: $message, reply: ${reply.id})';
  }
}

/// Modèle pour la réponse simple de l'API (suppression, etc.)
class ApiResponse {
  final String message;

  ApiResponse({required this.message});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(message: json['message'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'message': message};
  }

  @override
  String toString() {
    return 'ApiResponse(message: $message)';
  }
}

/// Exception personnalisée pour les erreurs de commentaires
class CommentException implements Exception {
  final String message;
  final String? code;

  CommentException(this.message, {this.code});

  @override
  String toString() {
    return 'CommentException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}