// lib/models/cart_model.dart
import 'dart:convert';

/// Modèle pour les images de produit dans le panier
class CartProductImage {
  final String imageUrl;

  CartProductImage({required this.imageUrl});

  factory CartProductImage.fromJson(Map<String, dynamic> json) {
    return CartProductImage(
      imageUrl: json['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
    };
  }

  @override
  String toString() {
    return 'CartProductImage(imageUrl: $imageUrl)';
  }
}

/// Modèle pour un produit dans le panier
class CartProduct {
  final int id;
  final String name;
  final double price;
  final int stock;
  final List<CartProductImage> images;

  CartProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    List<CartProductImage>? images,
  }) : images = images ?? [];

  factory CartProduct.fromJson(Map<String, dynamic> json) {
    return CartProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
      images: (json['images'] as List<dynamic>?)
          ?.map((image) => CartProductImage.fromJson(image))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'images': images.map((image) => image.toJson()).toList(),
    };
  }

  /// Prix formaté en FCFA
  String get formattedPrice => '${price.toStringAsFixed(0)} FCFA';

  /// URL de la première image ou placeholder
  String get firstImageUrl {
    if (images.isNotEmpty) {
      return images.first.imageUrl;
    }
    return '';
  }

  @override
  String toString() {
    return 'CartProduct(id: $id, name: $name, price: $price, stock: $stock, images: ${images.length})';
  }
}

/// Modèle pour un article dans le panier
class CartItem {
  final int id;
  final int cartId;
  final int productId;
  final int quantity;
  final CartProduct product;
  final DateTime createdAt;
  final DateTime updatedAt;

  CartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.quantity,
    required this.product,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? 0,
      cartId: json['cartId'] ?? 0,
      productId: json['productId'] ?? 0,
      quantity: json['quantity'] ?? 0,
      product: CartProduct.fromJson(json['product'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cartId': cartId,
      'productId': productId,
      'quantity': quantity,
      'product': product.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Prix total pour cet article (prix unitaire × quantité)
  double get totalPrice => product.price * quantity;

  /// Prix total formaté
  String get formattedTotalPrice => '${totalPrice.toStringAsFixed(0)} FCFA';

  /// Crée une copie avec une nouvelle quantité
  CartItem copyWithQuantity(int newQuantity) {
    return CartItem(
      id: id,
      cartId: cartId,
      productId: productId,
      quantity: newQuantity,
      product: product,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'CartItem(id: $id, productId: $productId, quantity: $quantity, totalPrice: $totalPrice)';
  }
}

/// Modèle pour le panier complet
class Cart {
  final int id;
  final int userId;
  final List<CartItem> items;
  final double totalPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  Cart({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => CartItem.fromJson(item))
          .toList() ?? [],
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'totalPrice': totalPrice,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Nombre total d'articles dans le panier
  int get itemsCount {
    return items.fold(0, (total, item) => total + item.quantity);
  }

  /// Prix total formaté
  String get formattedTotalPrice => '${totalPrice.toStringAsFixed(0)} FCFA';

  /// Vérifier si le panier est vide
  bool get isEmpty => items.isEmpty;

  /// Vérifier si le panier n'est pas vide
  bool get isNotEmpty => items.isNotEmpty;

  /// Obtenir un article par son ID
  CartItem? getItemById(int itemId) {
    try {
      return items.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  /// Obtenir un article par l'ID du produit
  CartItem? getItemByProductId(int productId) {
    try {
      return items.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  /// Calculer le prix total recalculé (utile pour vérification)
  double get recalculatedTotalPrice {
    return items.fold(0.0, (total, item) => total + item.totalPrice);
  }

  @override
  String toString() {
    return 'Cart(id: $id, userId: $userId, itemsCount: $itemsCount, totalPrice: $totalPrice)';
  }
}

/// Modèle pour les liens WhatsApp
class WhatsAppLink {
  final String shopName;
  final String link;
  final double? totalAmount;
  final int? itemCount;
  final String? logo;
  final List<String> productImages;
  final int? orderNumber;

  WhatsAppLink({
    required this.shopName,
    required this.link,
    this.totalAmount,
    this.itemCount,
    this.logo,
    List<String>? productImages,
    this.orderNumber,
  }) : productImages = productImages ?? [];

  factory WhatsAppLink.fromJson(Map<String, dynamic> json) {
    return WhatsAppLink(
      shopName: json['shopName'] ?? '',
      link: json['link'] ?? '',
      totalAmount: json['totalAmount']?.toDouble(),
      itemCount: json['itemCount'],
      logo: json['logo'],
      productImages: (json['productImages'] as List<dynamic>?)
          ?.map((image) => image.toString())
          .toList(),
      orderNumber: json['orderNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shopName': shopName,
      'link': link,
      'totalAmount': totalAmount,
      'itemCount': itemCount,
      'logo': logo,
      'productImages': productImages,
      'orderNumber': orderNumber,
    };
  }

  /// Montant formaté
  String get formattedAmount {
    if (totalAmount != null) {
      return '${totalAmount!.toStringAsFixed(0)} FCFA';
    }
    return '';
  }

  @override
  String toString() {
    return 'WhatsAppLink(shopName: $shopName, totalAmount: $totalAmount, itemCount: $itemCount)';
  }
}

/// Modèle pour la commande créée
class Order {
  final int id;
  final double totalAmount;
  final String status;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Montant formaté
  String get formattedTotalAmount => '${totalAmount.toStringAsFixed(0)} FCFA';

  @override
  String toString() {
    return 'Order(id: $id, totalAmount: $totalAmount, status: $status)';
  }
}

/// Modèle pour la réponse après création d'une commande
class OrderResponse {
  final String message;
  final Order order;
  final List<WhatsAppLink> whatsappLinks;

  OrderResponse({
    required this.message,
    required this.order,
    required this.whatsappLinks,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      message: json['message'] ?? '',
      order: Order.fromJson(json['order'] ?? {}),
      whatsappLinks: (json['whatsappLinks'] as List<dynamic>?)
          ?.map((link) => WhatsAppLink.fromJson(link))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'order': order.toJson(),
      'whatsappLinks': whatsappLinks.map((link) => link.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'OrderResponse(message: $message, order: ${order.id}, whatsappLinks: ${whatsappLinks.length})';
  }
}

/// Modèles pour les réponses API simples
class CartApiResponse {
  final String message;
  final Cart? cart;

  CartApiResponse({
    required this.message,
    this.cart,
  });

  factory CartApiResponse.fromJson(Map<String, dynamic> json) {
    return CartApiResponse(
      message: json['message'] ?? '',
      cart: json['cart'] != null ? Cart.fromJson(json['cart']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'cart': cart?.toJson(),
    };
  }

  @override
  String toString() {
    return 'CartApiResponse(message: $message, cart: ${cart?.id})';
  }
}

class WhatsAppShareResponse {
  final String message;
  final List<WhatsAppLink> whatsappLinks;

  WhatsAppShareResponse({
    required this.message,
    required this.whatsappLinks,
  });

  factory WhatsAppShareResponse.fromJson(Map<String, dynamic> json) {
    return WhatsAppShareResponse(
      message: json['message'] ?? '',
      whatsappLinks: (json['whatsappLinks'] as List<dynamic>?)
          ?.map((link) => WhatsAppLink.fromJson(link))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'whatsappLinks': whatsappLinks.map((link) => link.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'WhatsAppShareResponse(message: $message, links: ${whatsappLinks.length})';
  }
}

/// Exception personnalisée pour les erreurs de panier
class CartException implements Exception {
  final String message;
  final String? code;

  CartException(this.message, {this.code});

  @override
  String toString() {
    return 'CartException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}