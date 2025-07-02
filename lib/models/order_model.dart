// lib/models/order_model.dart - VERSION CORRIGÉE AVEC MESSAGERIE
import 'dart:convert';

/// Énumération pour les statuts de commande
enum OrderStatus {
  pending('PENDING', 'En attente'),
  confirmed('CONFIRMED', 'Confirmée'),
  shipped('SHIPPED', 'Expédiée'),
  delivered('DELIVERED', 'Livrée'),
  canceled('CANCELED', 'Annulée');

  const OrderStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static OrderStatus fromString(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == status.toUpperCase(),
      orElse: () => OrderStatus.pending,
    );
  }
}

/// Modèle pour les images de produit dans une commande
class OrderProductImage {
  final String imageUrl;

  OrderProductImage({required this.imageUrl});

  factory OrderProductImage.fromJson(Map<String, dynamic> json) {
    return OrderProductImage(
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
    return 'OrderProductImage(imageUrl: $imageUrl)';
  }
}

/// Modèle pour la boutique dans une commande
class OrderShop {
  final int id;
  final String name;
  final String? phoneNumber;

  OrderShop({
    required this.id,
    required this.name,
    this.phoneNumber,
  });

  factory OrderShop.fromJson(Map<String, dynamic> json) {
    return OrderShop(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
    };
  }

  @override
  String toString() {
    return 'OrderShop(id: $id, name: $name, phoneNumber: $phoneNumber)';
  }
}

/// Modèle pour un produit dans une commande
class OrderProduct {
  final int id;
  final String name;
  final double price;
  final List<OrderProductImage> images;
  final OrderShop shop;

  OrderProduct({
    required this.id,
    required this.name,
    required this.price,
    List<OrderProductImage>? images,
    required this.shop,
  }) : images = images ?? [];

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      images: (json['images'] as List<dynamic>?)
          ?.map((image) => OrderProductImage.fromJson(image))
          .toList() ?? [],
      shop: OrderShop.fromJson(json['shop'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'images': images.map((image) => image.toJson()).toList(),
      'shop': shop.toJson(),
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
    return 'OrderProduct(id: $id, name: $name, price: $price, shop: ${shop.name})';
  }
}

/// Modèle pour un article dans une commande
class OrderItem {
  final int id;
  final int productId;
  final int quantity;
  final double price;
  final OrderProduct product;

  OrderItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      productId: json['productId'] ?? 0,
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      product: OrderProduct.fromJson(json['product'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'quantity': quantity,
      'price': price,
      'product': product.toJson(),
    };
  }

  /// Prix total pour cet article (prix × quantité)
  double get totalPrice => price * quantity;

  /// Prix total formaté
  String get formattedTotalPrice => '${totalPrice.toStringAsFixed(0)} FCFA';

  @override
  String toString() {
    return 'OrderItem(id: $id, productId: $productId, quantity: $quantity, totalPrice: $totalPrice)';
  }
}

/// Modèle pour les informations client
class OrderClient {
  final int id;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? email;

  OrderClient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.email,
  });

  factory OrderClient.fromJson(Map<String, dynamic> json) {
    return OrderClient(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phoneNumber: json['phoneNumber'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'email': email,
    };
  }

  /// Nom complet du client
  String get fullName => '$firstName $lastName';

  @override
  String toString() {
    return 'OrderClient(id: $id, fullName: $fullName, phoneNumber: $phoneNumber)';
  }
}

/// Modèle principal pour une commande
class Order {
  final int id;
  final int clientId;
  final OrderStatus status;
  final double totalAmount;
  final List<OrderItem> orderItems;
  final OrderClient? client;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.clientId,
    required this.status,
    required this.totalAmount,
    required this.orderItems,
    this.client,
    required this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      clientId: json['clientId'] ?? 0,
      status: OrderStatus.fromString(json['status'] ?? 'PENDING'),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      orderItems: (json['orderItems'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromJson(item))
          .toList() ?? [],
      client: json['client'] != null ? OrderClient.fromJson(json['client']) : null,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'status': status.value,
      'totalAmount': totalAmount,
      'orderItems': orderItems.map((item) => item.toJson()).toList(),
      'client': client?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Nombre total d'articles dans la commande
  int get itemsCount {
    return orderItems.fold(0, (total, item) => total + item.quantity);
  }

  /// Montant total formaté
  String get formattedTotalAmount => '${totalAmount.toStringAsFixed(0)} FCFA';

  /// Numéro de commande formaté
  String get formattedOrderNumber => 'COMANDE-$id';

  /// Obtenir la liste des boutiques uniques
  List<OrderShop> get uniqueShops {
    final shopMap = <int, OrderShop>{};
    for (var item in orderItems) {
      shopMap[item.product.shop.id] = item.product.shop;
    }
    return shopMap.values.toList();
  }

  /// Vérifier si la commande peut être annulée
  bool get canBeCanceled {
    return status == OrderStatus.pending;
  }

  /// Vérifier si la commande peut être confirmée comme livrée
  bool get canBeMarkedAsDelivered {
    return status == OrderStatus.shipped;
  }

  /// Obtenir la couleur associée au statut
  String get statusColor {
    switch (status) {
      case OrderStatus.pending:
        return '#FFA500'; // Orange
      case OrderStatus.confirmed:
        return '#2196F3'; // Bleu
      case OrderStatus.shipped:
        return '#9C27B0'; // Violet
      case OrderStatus.delivered:
        return '#4CAF50'; // Vert
      case OrderStatus.canceled:
        return '#F44336'; // Rouge
    }
  }

  @override
  String toString() {
    return 'Order(id: $id, status: ${status.value}, totalAmount: $totalAmount, itemsCount: $itemsCount)';
  }
}

/// 🔄 MODIFIÉ: Modèle pour un marchand dans une commande (pour la messagerie)
class OrderMerchant {
  final int merchantId;
  final String shopName;
  final String? merchantFirstName;   // ← NOUVEAU
  final String? merchantLastName;    // ← NOUVEAU
  final String? merchantPhoto;       // ← NOUVEAU
  final bool? isOnline;             // ← NOUVEAU

  OrderMerchant({
    required this.merchantId,
    required this.shopName,
    this.merchantFirstName,         // ← NOUVEAU
    this.merchantLastName,          // ← NOUVEAU
    this.merchantPhoto,             // ← NOUVEAU
    this.isOnline,                  // ← NOUVEAU
  });

  factory OrderMerchant.fromJson(Map<String, dynamic> json) {
    return OrderMerchant(
      merchantId: json['merchantId'] ?? 0,
      shopName: json['shopName'] ?? '',
      merchantFirstName: json['merchantFirstName'],    // ← NOUVEAU
      merchantLastName: json['merchantLastName'],      // ← NOUVEAU
      merchantPhoto: json['merchantPhoto'],            // ← NOUVEAU
      isOnline: json['isOnline'],                      // ← NOUVEAU
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantId': merchantId,
      'shopName': shopName,
      'merchantFirstName': merchantFirstName,    // ← NOUVEAU
      'merchantLastName': merchantLastName,      // ← NOUVEAU
      'merchantPhoto': merchantPhoto,            // ← NOUVEAU
      'isOnline': isOnline,                      // ← NOUVEAU
    };
  }

  /// Nom complet du marchand
  String get fullName {
    final firstName = merchantFirstName ?? '';
    final lastName = merchantLastName ?? '';
    return '$firstName $lastName'.trim();
  }

  /// Nom à afficher (avec fallback sur le nom de la boutique)
  String get displayName {
    final full = fullName;
    return full.isNotEmpty ? full : shopName;
  }

  @override
  String toString() {
    return 'OrderMerchant(merchantId: $merchantId, shopName: $shopName, fullName: $fullName)';
  }
}
class OrderConfirmationResponse {
  final String message;
  final int orderId;
  final OrderStatus status;
  final String? suggestion;
  final List<OrderMerchant>? merchants;

  OrderConfirmationResponse({
    required this.message,
    required this.orderId,
    required this.status,
    this.suggestion,
    this.merchants,
  });

  factory OrderConfirmationResponse.fromJson(Map<String, dynamic> json) {
    return OrderConfirmationResponse(
      message: json['message'] ?? '',
      orderId: json['orderId'] ?? 0,
      status: OrderStatus.fromString(json['status'] ?? 'PENDING'),
      suggestion: json['suggestion'],
      merchants: (json['merchants'] as List<dynamic>?)
          ?.map((merchant) => OrderMerchant.fromJson(merchant))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'orderId': orderId,
      'status': status.value,
      'suggestion': suggestion,
      'merchants': merchants?.map((merchant) => merchant.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'OrderConfirmationResponse(orderId: $orderId, status: ${status.value}, merchants: ${merchants?.length ?? 0})';
  }
}

/// Modèle pour la réponse de feedback des marchands
class MerchantFeedbackResponse {
  final String message;
  final int orderId;
  final List<MerchantInfo> merchants;

  MerchantFeedbackResponse({
    required this.message,
    required this.orderId,
    required this.merchants,
  });

  factory MerchantFeedbackResponse.fromJson(Map<String, dynamic> json) {
    return MerchantFeedbackResponse(
      message: json['message'] ?? '',
      orderId: json['orderId'] ?? 0,
      merchants: (json['merchants'] as List<dynamic>?)
          ?.map((merchant) => MerchantInfo.fromJson(merchant))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'orderId': orderId,
      'merchants': merchants.map((merchant) => merchant.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'MerchantFeedbackResponse(orderId: $orderId, merchants: ${merchants.length})';
  }
}

/// Modèle pour les informations des marchands
class MerchantInfo {
  final int merchantId;
  final int shopId;
  final String shopName;

  MerchantInfo({
    required this.merchantId,
    required this.shopId,
    required this.shopName,
  });

  factory MerchantInfo.fromJson(Map<String, dynamic> json) {
    return MerchantInfo(
      merchantId: json['merchantId'] ?? 0,
      shopId: json['shopId'] ?? 0,
      shopName: json['shopName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantId': merchantId,
      'shopId': shopId,
      'shopName': shopName,
    };
  }

  @override
  String toString() {
    return 'MerchantInfo(merchantId: $merchantId, shopId: $shopId, shopName: $shopName)';
  }
}

/// Modèle pour les réponses API générales des commandes
class OrderApiResponse {
  final String message;
  final Order? order;
  final List<Order>? orders;

  OrderApiResponse({
    required this.message,
    this.order,
    this.orders,
  });

  factory OrderApiResponse.fromJson(Map<String, dynamic> json) {
    return OrderApiResponse(
      message: json['message'] ?? '',
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
      orders: (json['orders'] as List<dynamic>?)
          ?.map((order) => Order.fromJson(order))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'order': order?.toJson(),
      'orders': orders?.map((order) => order.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'OrderApiResponse(message: $message, order: ${order?.id}, orders: ${orders?.length})';
  }
}

/// Modèle pour les commandes de marchand
class MerchantOrder {
  final int id;
  final OrderStatus status;
  final OrderClient client;
  final DateTime createdAt;
  final double totalAmount;
  final List<MerchantOrderItem> items;

  MerchantOrder({
    required this.id,
    required this.status,
    required this.client,
    required this.createdAt,
    required this.totalAmount,
    required this.items,
  });

  factory MerchantOrder.fromJson(Map<String, dynamic> json) {
    return MerchantOrder(
      id: json['id'] ?? 0,
      status: OrderStatus.fromString(json['status'] ?? 'PENDING'),
      client: OrderClient.fromJson(json['client'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => MerchantOrderItem.fromJson(item))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status.value,
      'client': client.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// Nombre total d'articles
  int get itemsCount {
    return items.fold(0, (total, item) => total + item.quantity);
  }

  /// Montant total formaté
  String get formattedTotalAmount => '${totalAmount.toStringAsFixed(0)} FCFA';

  @override
  String toString() {
    return 'MerchantOrder(id: $id, status: ${status.value}, client: ${client.fullName}, totalAmount: $totalAmount)';
  }
}

/// Modèle pour un article de commande marchand
class MerchantOrderItem {
  final int id;
  final MerchantOrderProduct product;
  final int quantity;
  final double price;
  final double subtotal;

  MerchantOrderItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory MerchantOrderItem.fromJson(Map<String, dynamic> json) {
    return MerchantOrderItem(
      id: json['id'] ?? 0,
      product: MerchantOrderProduct.fromJson(json['product'] ?? {}),
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
    };
  }

  /// Sous-total formaté
  String get formattedSubtotal => '${subtotal.toStringAsFixed(0)} FCFA';

  @override
  String toString() {
    return 'MerchantOrderItem(id: $id, product: ${product.name}, quantity: $quantity, subtotal: $subtotal)';
  }
}

/// Modèle pour un produit dans les commandes marchands
class MerchantOrderProduct {
  final int id;
  final String name;
  final double price;
  final List<OrderProductImage> images;

  MerchantOrderProduct({
    required this.id,
    required this.name,
    required this.price,
    List<OrderProductImage>? images,
  }) : images = images ?? [];

  factory MerchantOrderProduct.fromJson(Map<String, dynamic> json) {
    return MerchantOrderProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      images: (json['images'] as List<dynamic>?)
          ?.map((image) => OrderProductImage.fromJson(image))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'images': images.map((image) => image.toJson()).toList(),
    };
  }

  /// URL de la première image
  String get firstImageUrl {
    if (images.isNotEmpty) {
      return images.first.imageUrl;
    }
    return '';
  }

  @override
  String toString() {
    return 'MerchantOrderProduct(id: $id, name: $name, price: $price)';
  }
}

/// Exception personnalisée pour les erreurs de commande
class OrderException implements Exception {
  final String code;
  final String message;

  OrderException(this.code, this.message);

  @override
  String toString() {
    return 'OrderException: $message (Code: $code)';
  }
}
