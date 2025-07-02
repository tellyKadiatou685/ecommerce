// lib/models/user_model.dart

class User {
  final int? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? role; // CLIENT ou MERCHANT depuis votre serveur
  final String? phone;
  final String? avatar;
  final String? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.role,
    this.phone,
    this.avatar,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  // 🔥 MÉTHODE fromJson CORRIGÉE - accepte les deux formats
  factory User.fromJson(Map<String, dynamic> json) {
    print('🔍 === DEBUG USER MAPPING ===');
    print('📄 JSON reçu: $json');
    print('🖼️ Photo dans JSON: "${json['photo']}"');
    print('🖼️ Avatar dans JSON: "${json['avatar']}"');
    
    return User(
      id: json['id'] as int?,
      email: json['email'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      role: json['role'] as String?,
      
      // 🔥 FLEXIBLE : accepte 'phone' OU 'phoneNumber'
      phone: (json['phone'] ?? json['phoneNumber']) as String?,
      
      // 🔥 FLEXIBLE : accepte 'avatar' OU 'photo' 
      avatar: (json['avatar'] ?? json['photo']) as String?,
      
      address: json['address'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt']) 
          : null,
    );
  }

  // 🔥 MÉTHODE toJson CORRIGÉE - garde les noms cohérents pour le stockage local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'phone': phone,        // 🔥 GARDE 'phone' (pas phoneNumber)
      'avatar': avatar,      // 🔥 GARDE 'avatar' (pas photo)
      'address': address,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // 🔥 NOUVELLE MÉTHODE pour l'API (quand on envoie au serveur)
  Map<String, dynamic> toJsonForApi() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'phoneNumber': phone,  // 🔥 POUR L'API : phone → phoneNumber
      'photo': avatar,       // 🔥 POUR L'API : avatar → photo
      'address': address,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Propriétés utilitaires
  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  String get name => fullName.isNotEmpty ? fullName : email ?? 'Utilisateur';
  String? get type => role?.toLowerCase(); // 'client' ou 'merchant'
  
  // Méthodes de vérification
  bool get isMerchant => role?.toUpperCase() == 'MERCHANT';
  bool get isClient => role?.toUpperCase() == 'CLIENT';

  // Copie avec modification
  User copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    String? role,
    String? phone,
    String? avatar,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $fullName, role: $role, avatar: $avatar)';
  }
}

// Classe pour la réponse de connexion de votre serveur
class LoginResponse {
  final String status;
  final String? message;
  final String? token;
  final User? user;

  LoginResponse({
    required this.status,
    this.message,
    this.token,
    this.user,
  });

  // Factory pour créer depuis la réponse de votre serveur
  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      status: json['status'] as String? ?? 'error',
      message: json['message'] as String?,
      token: json['token'] as String?,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  // Propriétés utilitaires
  bool get success => status == 'success';

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'token': token,
      'user': user?.toJson(),
    };
  }

  @override
  String toString() {
    return 'LoginResponse(status: $status, message: $message, user: ${user?.fullName})';
  }
}

class ApiError implements Exception {
  final String status;
  final String code;
  final String message;
  final Map<String, dynamic>? errors;

  ApiError({
    required this.status,
    required this.code,
    required this.message,
    this.errors,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      status: json['status'] as String? ?? 'error',
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      message: json['message'] as String? ?? 'Une erreur est survenue',
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'ApiError(status: $status, code: $code, message: $message)';
  }
}

// Réponse pour la vérification d'email
class CheckEmailResponse {
  final bool exists;

  CheckEmailResponse({required this.exists});

  factory CheckEmailResponse.fromJson(Map<String, dynamic> json) {
    return CheckEmailResponse(
      exists: json['exists'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exists': exists,
    };
  }
}

// Réponse pour l'inscription
class RegisterResponse {
  final String message;
  final String email;

  RegisterResponse({
    required this.message,
    required this.email,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      message: json['message'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'email': email,
    };
  }
}

// Réponse pour la vérification de code
class VerifyCodeResponse {
  final String message;
  final User user;

  VerifyCodeResponse({
    required this.message,
    required this.user,
  });

  factory VerifyCodeResponse.fromJson(Map<String, dynamic> json) {
    return VerifyCodeResponse(
      message: json['message'] as String? ?? '',
      user: User.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'user': user.toJson(),
    };
  }
}

// Réponse pour le renvoi de code
class ResendCodeResponse {
  final String message;

  ResendCodeResponse({required this.message});

  factory ResendCodeResponse.fromJson(Map<String, dynamic> json) {
    return ResendCodeResponse(
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
    };
  }
}

// Données de profil
class ProfileData {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phoneNumber;
  final String? photo;
  final String? city;
  final String? country;
  final String? department;
  final String? commune;

  ProfileData({
    this.firstName,
    this.lastName,
    this.email,
    this.phoneNumber,
    this.photo,
    this.city,
    this.country,
    this.department,
    this.commune,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      photo: json['photo'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      department: json['department'] as String?,
      commune: json['commune'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'photo': photo,
      'city': city,
      'country': country,
      'department': department,
      'commune': commune,
    };
  }

  // Méthode pour créer une copie avec modifications
  ProfileData copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? photo,
    String? city,
    String? country,
    String? department,
    String? commune,
  }) {
    return ProfileData(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photo: photo ?? this.photo,
      city: city ?? this.city,
      country: country ?? this.country,
      department: department ?? this.department,
      commune: commune ?? this.commune,
    );
  }
}

// Modèles pour les boutiques
class Boutique {
  final int id;
  final String name;
  final String description;
  final String? logo;
  final String? banner;
  final String category;
  final double rating;
  final int productsCount;
  final int merchantId;
  final String address;
  final String phone;
  final bool isActive;
  final DateTime createdAt;

  Boutique({
    required this.id,
    required this.name,
    required this.description,
    this.logo,
    this.banner,
    required this.category,
    required this.rating,
    required this.productsCount,
    required this.merchantId,
    required this.address,
    required this.phone,
    required this.isActive,
    required this.createdAt,
  });

  factory Boutique.fromJson(Map<String, dynamic> json) {
    return Boutique(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      logo: json['logo'] as String?,
      banner: json['banner'] as String?,
      category: json['category'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      productsCount: json['products_count'] as int? ?? 0,
      merchantId: json['merchant_id'] as int,
      address: json['address'] as String,
      phone: json['phone'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'logo': logo,
      'banner': banner,
      'category': category,
      'rating': rating,
      'products_count': productsCount,
      'merchant_id': merchantId,
      'address': address,
      'phone': phone,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Modèles pour les produits
class Produit {
  final int id;
  final String name;
  final String description;
  final double price;
  final String? image;
  final List<String> images;
  final String category;
  final int stock;
  final bool isActive;
  final int boutiqueId;
  final double rating;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;

  Produit({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.image,
    required this.images,
    required this.category,
    required this.stock,
    required this.isActive,
    required this.boutiqueId,
    required this.rating,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
  });

  factory Produit.fromJson(Map<String, dynamic> json) {
    return Produit(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String?,
      images: List<String>.from(json['images'] ?? []),
      category: json['category'] as String,
      stock: json['stock'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      boutiqueId: json['boutique_id'] as int,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image': image,
      'images': images,
      'category': category,
      'stock': stock,
      'is_active': isActive,
      'boutique_id': boutiqueId,
      'rating': rating,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Méthode utilitaire pour formater le prix
  String get formattedPrice {
    return '${price.toStringAsFixed(0)} FCFA';
  }

  // Méthode pour vérifier si le produit est en stock
  bool get inStock => stock > 0;
  
}