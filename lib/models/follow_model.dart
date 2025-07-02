// lib/models/follow_model.dart

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String? photo;
  final String role;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      photo: json['photo'],
      role: json['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'photo': photo,
      'role': role,
    };
  }

  String get fullName => '$firstName $lastName';

  @override
  String toString() {
    return 'User(id: $id, name: $fullName, role: $role)';
  }
}

class Follower extends User {
  final DateTime followedAt;

  Follower({
    required int id,
    required String firstName,
    required String lastName,
    String? photo,
    required String role,
    required this.followedAt,
  }) : super(
          id: id,
          firstName: firstName,
          lastName: lastName,
          photo: photo,
          role: role,
        );

  factory Follower.fromJson(Map<String, dynamic> json) {
    return Follower(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      photo: json['photo'],
      role: json['role'] ?? 'user',
      followedAt: DateTime.parse(
        json['followedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['followedAt'] = followedAt.toIso8601String();
    return json;
  }

  @override
  String toString() {
    return 'Follower(id: $id, name: $fullName, followedAt: $followedAt)';
  }
}

class Pagination {
  final int total;
  final int page;
  final int limit;
  final int pages;

  Pagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      pages: json['pages'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'page': page,
      'limit': limit,
      'pages': pages,
    };
  }

  bool get hasNextPage => page < pages;
  bool get hasPreviousPage => page > 1;

  @override
  String toString() {
    return 'Pagination(total: $total, page: $page/$pages, limit: $limit)';
  }
}

class FollowResponse {
  final String message;
  final String action; // 'followed' ou 'unfollowed'
  final int followerCount;
  final User userToFollow;

  FollowResponse({
    required this.message,
    required this.action,
    required this.followerCount,
    required this.userToFollow,
  });

  factory FollowResponse.fromJson(Map<String, dynamic> json) {
    return FollowResponse(
      message: json['message'] ?? '',
      action: json['action'] ?? '',
      followerCount: json['followerCount'] ?? 0,
      userToFollow: User.fromJson(json['userToFollow'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'action': action,
      'followerCount': followerCount,
      'userToFollow': userToFollow.toJson(),
    };
  }

  bool get isFollowed => action == 'followed';
  bool get isUnfollowed => action == 'unfollowed';

  @override
  String toString() {
    return 'FollowResponse(action: $action, followerCount: $followerCount)';
  }
}

class FollowersResponse {
  final List<Follower> followers;
  final Pagination pagination;

  FollowersResponse({
    required this.followers,
    required this.pagination,
  });

  factory FollowersResponse.fromJson(Map<String, dynamic> json) {
    return FollowersResponse(
      followers: (json['followers'] as List<dynamic>? ?? [])
          .map((follower) => Follower.fromJson(follower))
          .toList(),
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'followers': followers.map((f) => f.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }

  @override
  String toString() {
    return 'FollowersResponse(followers: ${followers.length}, pagination: $pagination)';
  }
}

class FollowingResponse {
  final List<Follower> following;
  final Pagination pagination;

  FollowingResponse({
    required this.following,
    required this.pagination,
  });

  factory FollowingResponse.fromJson(Map<String, dynamic> json) {
    return FollowingResponse(
      following: (json['following'] as List<dynamic>? ?? [])
          .map((following) => Follower.fromJson(following))
          .toList(),
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'following': following.map((f) => f.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }

  @override
  String toString() {
    return 'FollowingResponse(following: ${following.length}, pagination: $pagination)';
  }
}

class IsFollowingResponse {
  final bool isFollowing;

  IsFollowingResponse({
    required this.isFollowing,
  });

  factory IsFollowingResponse.fromJson(Map<String, dynamic> json) {
    return IsFollowingResponse(
      isFollowing: json['isFollowing'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isFollowing': isFollowing,
    };
  }

  @override
  String toString() {
    return 'IsFollowingResponse(isFollowing: $isFollowing)';
  }
}

class SuggestedUser extends User {
  final int followerCount;

  SuggestedUser({
    required int id,
    required String firstName,
    required String lastName,
    String? photo,
    required String role,
    required this.followerCount,
  }) : super(
          id: id,
          firstName: firstName,
          lastName: lastName,
          photo: photo,
          role: role,
        );

  factory SuggestedUser.fromJson(Map<String, dynamic> json) {
    return SuggestedUser(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      photo: json['photo'],
      role: json['role'] ?? 'user',
      followerCount: json['followerCount'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['followerCount'] = followerCount;
    return json;
  }

  @override
  String toString() {
    return 'SuggestedUser(id: $id, name: $fullName, followers: $followerCount)';
  }
}

class SuggestedUsersResponse {
  final List<SuggestedUser> suggestions;

  SuggestedUsersResponse({
    required this.suggestions,
  });

  factory SuggestedUsersResponse.fromJson(Map<String, dynamic> json) {
    return SuggestedUsersResponse(
      suggestions: (json['suggestions'] as List<dynamic>? ?? [])
          .map((user) => SuggestedUser.fromJson(user))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'suggestions': suggestions.map((s) => s.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'SuggestedUsersResponse(suggestions: ${suggestions.length})';
  }
}

// Exception personnalisée pour les erreurs de follow
class FollowException implements Exception {
  final String message;
  final String? code;

  FollowException(this.message, {this.code});

  @override
  String toString() {
    return 'FollowException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}