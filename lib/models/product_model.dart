// lib/models/product_model.dart
class ProductResponse {
  final List<Product> products;
  final Pagination? pagination;

  ProductResponse({
    required this.products,
    this.pagination,
  });

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    return ProductResponse(
      products: (json['products'] as List? ?? [])
          .map((product) => Product.fromJson(product))
          .toList(),
      pagination: json['pagination'] != null 
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class Product {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String? videoUrl;
  final String? category;
  final int shopId;
  final int userId;
  final String status;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final String createdAt;
  final String updatedAt;
  final List<ProductImage> images;
  final ProductShop? shop;
  final ProductCount? count;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.videoUrl,
    this.category,
    required this.shopId,
    required this.userId,
    required this.status,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.createdAt,
    required this.updatedAt,
    required this.images,
    this.shop,
    this.count,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
      videoUrl: json['videoUrl'],
      category: json['category'],
      shopId: json['shopId'] ?? 0,
      userId: json['userId'] ?? 0,
      status: json['status'] ?? 'DRAFT',
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      sharesCount: json['sharesCount'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      images: (json['images'] as List? ?? [])
          .map((image) => ProductImage.fromJson(image))
          .toList(),
      shop: json['shop'] != null ? ProductShop.fromJson(json['shop']) : null,
      count: json['_count'] != null ? ProductCount.fromJson(json['_count']) : null,
    );
  }

  // Getters utiles
  String get formattedPrice {
    return '${price.toStringAsFixed(0)} FCFA';
  }

  bool get isAvailable => stock > 0 && status == 'PUBLISHED';

  String get displayCategory => category ?? 'Non classé';

  String get shopName => shop?.name ?? 'Boutique';

  bool get isShopVerified => shop?.verifiedBadge ?? false;

  // Getter pour les URLs d'images avec la logique de construction d'URL
  List<String> get imageUrls {
    return images.map((img) => img.fullImageUrl).toList();
  }

  // Getter pour l'URL complète de la vidéo
  String? get fullVideoUrl {
    if (videoUrl == null) return null;
    if (videoUrl!.startsWith('http')) {
      return videoUrl; // URL complète (Cloudinary, YouTube, etc.)
    }
    // URL locale - construire avec votre configuration
    return 'http://192.168.1.11:3000/$videoUrl';
  }
}

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
      id: json['id'] ?? 0,
      productId: json['productId'] ?? 0,
      imageUrl: json['imageUrl'] ?? '',
    );
  }

  // Getter pour l'URL complète (même logique que Shop.fullLogoUrl)
  String get fullImageUrl {
    if (imageUrl.startsWith('http')) {
      return imageUrl; // URL Cloudinary complète
    }
    // URL locale - devrait utiliser la même configuration que votre API
    return 'http://192.168.1.11:3000/$imageUrl';
  }
}

class ProductShop {
  final String name;
  final String? logo;
  final bool verifiedBadge;

  ProductShop({
    required this.name,
    this.logo,
    required this.verifiedBadge,
  });

  factory ProductShop.fromJson(Map<String, dynamic> json) {
    return ProductShop(
      name: json['name'] ?? '',
      logo: json['logo'],
      verifiedBadge: json['verifiedBadge'] ?? false,
    );
  }

  // Getter pour l'URL complète du logo (même logique que votre Shop existant)
  String? get fullLogoUrl {
    if (logo == null) return null;
    if (logo!.startsWith('http')) {
      return logo; // URL Cloudinary complète
    }
    return 'http://192.168.1.11:3000/$logo';
  }
}

class ProductCount {
  final int likes;
  final int comments;
  final int shares;

  ProductCount({
    required this.likes,
    required this.comments,
    required this.shares,
  });

  factory ProductCount.fromJson(Map<String, dynamic> json) {
    return ProductCount(
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
    );
  }
}

class Pagination {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  Pagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['totalPages'] ?? 1,
    );
  }

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}