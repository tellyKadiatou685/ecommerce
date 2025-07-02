// lib/models/shop_model.dart

// Modèle Shop principal
class Shop {
  final int id;
  final String name;
  final String? description;
  final String? logo;
  final String phoneNumber;
  final String? address;
  final int userId;
  final bool verifiedBadge;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Owner? owner;

  Shop({
    required this.id,
    required this.name,
    this.description,
    this.logo,
    required this.phoneNumber,
    this.address,
    required this.userId,
    required this.verifiedBadge,
    required this.createdAt,
    required this.updatedAt,
    this.owner,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      logo: json['logo'] as String?,
      phoneNumber: json['phoneNumber'] as String,
      address: json['address'] as String?,
      userId: json['userId'] as int,
      verifiedBadge: json['verifiedBadge'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      owner: json['owner'] != null ? Owner.fromJson(json['owner']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'logo': logo,
      'phoneNumber': phoneNumber,
      'address': address,
      'userId': userId,
      'verifiedBadge': verifiedBadge,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'owner': owner?.toJson(),
    };
  }

  // Méthodes utilitaires
  String get displayAddress => address ?? 'Adresse non renseignée';
  String get displayDescription => description ?? 'Aucune description';
  bool get hasLogo => logo != null && logo!.isNotEmpty;
  String get ownerName => owner != null ? '${owner!.firstName} ${owner!.lastName}' : 'Propriétaire inconnu';
}

// Modèle Owner (propriétaire de la boutique)
class Owner {
  final String firstName;
  final String lastName;
  final String? photo;

  Owner({
    required this.firstName,
    required this.lastName,
    this.photo,
  });

  factory Owner.fromJson(Map<String, dynamic> json) {
    return Owner(
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      photo: json['photo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'photo': photo,
    };
  }

  String get fullName => '$firstName $lastName';
  bool get hasPhoto => photo != null && photo!.isNotEmpty;
}

// Modèle Product pour les produits des boutiques
class Product {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String? videoUrl;
  final String category;
  final int shopId;
  final int userId;
  final String status;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductImage> images;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.videoUrl,
    required this.category,
    required this.shopId,
    required this.userId,
    required this.status,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.createdAt,
    required this.updatedAt,
    required this.images,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int,
      videoUrl: json['videoUrl'] as String?,
      category: json['category'] as String,
      shopId: json['shopId'] as int,
      userId: json['userId'] as int,
      status: json['status'] as String,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      images: (json['images'] as List<dynamic>?)
          ?.map((img) => ProductImage.fromJson(img))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'videoUrl': videoUrl,
      'category': category,
      'shopId': shopId,
      'userId': userId,
      'status': status,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'images': images.map((img) => img.toJson()).toList(),
    };
  }

  // Méthodes utilitaires
  String get formattedPrice => '${price.toStringAsFixed(0)} FCFA';
  bool get inStock => stock > 0;
  bool get isPublished => status == 'PUBLISHED';
  String get mainImage => images.isNotEmpty ? images.first.imageUrl : '';
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  String get displayDescription => description ?? 'Aucune description';
}

// Modèle ProductImage
class ProductImage {
  final int id;
  final int productId;
  final String imageUrl;

  ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as int,
      productId: json['productId'] as int,
      imageUrl: json['imageUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'imageUrl': imageUrl,
    };
  }
}

// Réponses API
class ShopResponse {
  final String status;
  final String message;
  final List<Shop> shops;

  ShopResponse({
    required this.status,
    required this.message,
    required this.shops,
  });

  factory ShopResponse.fromJson(Map<String, dynamic> json) {
    return ShopResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      shops: (json['shops'] as List<dynamic>)
          .map((shop) => Shop.fromJson(shop))
          .toList(),
    );
  }

  bool get success => status == 'success';
}

class ShopDetailResponse {
  final String status;
  final String message;
  final Shop shop;
  final List<Product> products;
  final MerchantStats? merchantStats;

  ShopDetailResponse({
    required this.status,
    required this.message,
    required this.shop,
    required this.products,
    this.merchantStats,
  });

  factory ShopDetailResponse.fromJson(Map<String, dynamic> json) {
    return ShopDetailResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      shop: Shop.fromJson(json['shop']),
      products: (json['products'] as List<dynamic>)
          .map((product) => Product.fromJson(product))
          .toList(),
      merchantStats: json['merchantStats'] != null 
          ? MerchantStats.fromJson(json['merchantStats']) 
          : null,
    );
  }

  bool get success => status == 'success';
}

class ShopProductsResponse {
  final String status;
  final String message;
  final List<Product> products;

  ShopProductsResponse({
    required this.status,
    required this.message,
    required this.products,
  });

  factory ShopProductsResponse.fromJson(Map<String, dynamic> json) {
    return ShopProductsResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      products: (json['products'] as List<dynamic>)
          .map((product) => Product.fromJson(product))
          .toList(),
    );
  }

  bool get success => status == 'success';
}

class ContactResponse {
  final String status;
  final String message;
  final ContactInfo? contact;

  ContactResponse({
    required this.status,
    required this.message,
    this.contact,
  });

  factory ContactResponse.fromJson(Map<String, dynamic> json) {
    return ContactResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      contact: json['contact'] != null 
          ? ContactInfo.fromJson(json['contact']) 
          : null,
    );
  }

  bool get success => status == 'success';
}

class ContactInfo {
  final int id;
  final DateTime createdAt;

  ContactInfo({
    required this.id,
    required this.createdAt,
  });

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class MerchantStats {
  final int totalProducts;
  final DateTime memberSince;

  MerchantStats({
    required this.totalProducts,
    required this.memberSince,
  });

  factory MerchantStats.fromJson(Map<String, dynamic> json) {
    return MerchantStats(
      totalProducts: json['totalProducts'] as int,
      memberSince: DateTime.parse(json['memberSince']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalProducts': totalProducts,
      'memberSince': memberSince.toIso8601String(),
    };
  }
}