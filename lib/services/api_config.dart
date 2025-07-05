// lib/services/api_config.dart - AJOUTS POUR LES MESSAGES + IMAGES
class ApiConfig {
  // 🔥 VOTRE IP CORRECTE CONFIRMÉE
  static const String baseUrl = 'http://192.168.1.19:3001';
  static const String socketUrl = 'ws://http://192.168.1.19:3001';
  static const String apiPath = '/api/auth';
  
  // 🔥 NOUVEAUX ENDPOINTS POUR LES MESSAGES
  static const String messagesApiPath = '/api/messages';
  static const String notifications = '/notifications';
  
  // 🔥 AJOUT POUR LES PRODUITS
  static const String productsApiPath = '/api/products';
  static const String likesApiPath = '/api/likes';
  static const String commentsApiPath = '/api/comments';
  static const String cartApiPath = '/api/cart';
  static const String shopsApiPath = '/api/shops';
  
  // Endpoints Auth (existants)
  static const String loginEndpoint = '$baseUrl$apiPath/login';
  static const String registerEndpoint = '$baseUrl$apiPath/register';
  static const String verifyEndpoint = '$baseUrl$apiPath/verify';
  static const String profileEndpoint = '$baseUrl$apiPath/profile';
  
  // 🔥 NOUVEAUX ENDPOINTS MESSAGES
  static const String sendMessageEndpoint = '$baseUrl$messagesApiPath/send';
  static const String conversationsEndpoint = '$baseUrl$messagesApiPath/conversations';
  static const String unreadCountEndpoint = '$baseUrl$messagesApiPath/unread/count';
  static const String searchMessagesEndpoint = '$baseUrl$messagesApiPath/search';
  
  // 🔥 NOUVEAUX ENDPOINTS PRODUITS
  static const String productsEndpoint = '$baseUrl$productsApiPath';
  static const String likesEndpoint = '$baseUrl$likesApiPath';
  static const String commentsEndpoint = '$baseUrl$commentsApiPath';
  static const String cartEndpoint = '$baseUrl$cartApiPath';
  static const String shopsEndpoint = '$baseUrl$shopsApiPath';
  static const String uploadsEndpoint = '$baseUrl/uploads';
  
  // Endpoints dynamiques pour les messages
  static String messagesWithUserEndpoint(int userId) => '$baseUrl$messagesApiPath/with/$userId';
  static String updateMessageEndpoint(int messageId) => '$baseUrl$messagesApiPath/$messageId';
  static String deleteMessageEndpoint(int messageId, {bool forEveryone = false}) {
    return forEveryone 
        ? '$baseUrl$messagesApiPath/$messageId?forEveryone=true'
        : '$baseUrl$messagesApiPath/$messageId';
  }
  static String markAsReadEndpoint(int messageId) => '$baseUrl$messagesApiPath/$messageId/read';
  static String markAllAsReadEndpoint(int partnerId) => '$baseUrl$messagesApiPath/read/all/$partnerId';
  
  // 🔥 NOUVEAUX ENDPOINTS DYNAMIQUES PRODUITS
  static String productLikesEndpoint(int productId) => '$baseUrl$likesApiPath/product/$productId';
  static String productCommentsEndpoint(int productId) => '$baseUrl$commentsApiPath/product/$productId';
  static String addToCartEndpoint() => '$baseUrl$cartApiPath/add';
  static String shopDetailsEndpoint(int shopId) => '$baseUrl$shopsApiPath/$shopId';
  
  // Headers par défaut ANTI-CACHE
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'Expires': '0',
  };
  
  // 🔥 NOUVEAUX HEADERS POUR FORMDATA (UPLOAD FICHIERS)
  static Map<String, String> get formDataHeaders => {
    'Accept': 'application/json',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'Expires': '0',
  };
  
  // ✅ AJOUT : Headers pour ProductService
  static Map<String, String> get headers => defaultHeaders;
  
  // Headers avec authentification
  static Map<String, String> authHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };

  // 🔥 NOUVEAUX HEADERS AVEC AUTH POUR FORMDATA
  static Map<String, String> authFormDataHeaders(String token) => {
    ...formDataHeaders,
    'Authorization': 'Bearer $token',
  };

  // 🔧 NOUVELLES CONSTANTES POUR LES MESSAGES
  static const int maxMessageLength = 1000;
  static const double maxFileSizeMB = 10.0;
  static const List<String> allowedFileExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp',
    'mp4', 'mov', 'avi', 'webm'
  ];
  
  // 🔥 NOUVELLES CONSTANTES POUR LES PRODUITS
  static const int maxCommentLength = 500;
  static const int maxReplyLength = 200;
  static const int defaultPageSize = 20;

  // 🔥 MÉTHODE MANQUANTE - GESTION DES URLs D'IMAGES// 🔧 REMPLACEZ UNIQUEMENT votre méthode getImageUrl() par celle-ci :

static String getImageUrl(String url) {
  if (url.isEmpty) return '';
  
  print('🔧 ApiConfig - URL originale: $url');
  
  // 🔥 NOUVEAU : Gestion des URLs Cloudinary (à ajouter EN PREMIER)
  if (url.startsWith('https://res.cloudinary.com/') || 
      url.startsWith('http://res.cloudinary.com/')) {
    print('✅ ApiConfig - URL Cloudinary détectée, retour direct: $url');
    return url;
  }
  
  // 🔥 NOUVEAU : Gestion de toutes les URLs complètes HTTPS/HTTP
  if (url.startsWith('https://') || url.startsWith('http://')) {
    print('✅ ApiConfig - URL complète détectée, retour direct: $url');
    return url;
  }
  
  // 🔥 CONSERVATION DE VOTRE LOGIQUE EXISTANTE (ne pas modifier)
  
  // Correction du double slash
  if (url.contains('://') && url.contains('//uploads')) {
    String fixed = url.replaceAll('//uploads', '/uploads');
    print('✅ ApiConfig - URL corrigée (double slash): $fixed');
    return fixed;
  }
  
  // Si l'URL commence par file:// (problème local)
  if (url.startsWith('file:///uploads')) {
    String fixed = '$baseUrl${url.substring(7)}'; // Retire 'file://'
    print('✅ ApiConfig - URL corrigée (file): $fixed');
    return fixed;
  }
  
  // Si l'URL est relative
  if (url.startsWith('/uploads')) {
    String fixed = '$baseUrl$url';
    print('✅ ApiConfig - URL corrigée (relative): $fixed');
    return fixed;
  }
  
  // Si c'est juste le nom du fichier
  if (!url.contains('/')) {
    String fixed = '$uploadsEndpoint/$url';
    print('✅ ApiConfig - URL corrigée (nom fichier): $fixed');
    return fixed;
  }
  
  print('✅ ApiConfig - URL inchangée: $url');
  return url;
}
  static bool isFileExtensionAllowed(String extension) {
    return allowedFileExtensions.contains(extension.toLowerCase());
  }

  static bool isFileSizeAllowed(double sizeInMB) {
    return sizeInMB <= maxFileSizeMB;
  }

  static bool isValidMessageContent(String? content) {
    return content != null && 
           content.trim().isNotEmpty && 
           content.length <= maxMessageLength;
  }
  
  // 🔥 NOUVELLES VALIDATIONS POUR LES PRODUITS
  static bool isValidCommentContent(String? content) {
    return content != null && 
           content.trim().isNotEmpty && 
           content.length <= maxCommentLength;
  }
  
  static bool isValidReplyContent(String? content) {
    return content != null && 
           content.trim().isNotEmpty && 
           content.length <= maxReplyLength;
  }
  
 
}